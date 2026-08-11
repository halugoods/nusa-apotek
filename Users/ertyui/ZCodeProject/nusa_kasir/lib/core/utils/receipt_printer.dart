import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// A single line item on a receipt.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.price,
  });

  final String name;
  final int qty;
  final int price;

  int get subtotal => qty * price;
}

/// Sanitize text for thermal printer (strip non-ASCII characters).
/// ESC/POS printers only support ASCII + CP-437 extended (0–255).
/// Unicode characters like emoji, CJK, arrows (↳), ellipsis (…) will crash
/// the printer or cause MethodChannel "invalid character" errors.
String _san(String text) {
  return text.replaceAll(RegExp(r'[^\x00-\xFF]'), '?');
}

/// Truncate text to fit thermal printer column with ellipsis.
/// 58mm paper: ~2 chars per PosColumn width unit.
String _fit(String text, int maxChars) {
  final s = _san(text);
  if (s.length <= maxChars) return s;
  return '${s.substring(0, maxChars - 3)}...';
}

/// Wrap text into multiple lines, each ≤ maxChars.
/// First line returns the first chunk; rest are returned as a list for
/// follow-up rows. This prevents truncation of long product names and
/// instead splits them across multiple printed lines.
List<String> _wrap(String text, int maxChars) {
  final s = _san(text).trimRight();
  if (s.length <= maxChars) return [s];

  final lines = <String>[];
  var remaining = s;
  while (remaining.length > maxChars) {
    // Try to break at a space within the last ~25% of the chunk
    var cut = maxChars;
    final spaceIdx = remaining.lastIndexOf(' ', maxChars);
    if (spaceIdx > maxChars * 0.75) cut = spaceIdx;
    lines.add(remaining.substring(0, cut).trimRight());
    remaining = remaining.substring(cut).trimLeft();
  }
  if (remaining.isNotEmpty) lines.add(remaining);
  return lines;
}

/// A discovered Bluetooth thermal printer.
class PrinterDevice {
  const PrinterDevice({
    required this.name,
    required this.address,
  });

  final String name;
  final String address;
}

/// Cached parameters from the last successful print — enables one-tap reprint.
class LastPrintParams {
  final String storeName;
  final List<ReceiptLine> lines;
  final int total;
  final String? paymentMethod;
  final String? cashierName;
  final String invoice;
  final String dateStr;
  final int discount;
  final int? cashGiven;
  final int? cashReturn;
  final String? customerName;
  final String paperWidth;
  final String? orderType;
  final String? tableName;
  final List<String?>? itemNotes;

  const LastPrintParams({
    required this.storeName,
    required this.lines,
    required this.total,
    this.paymentMethod,
    this.cashierName,
    this.invoice = '',
    this.dateStr = '',
    this.discount = 0,
    this.cashGiven,
    this.cashReturn,
    this.customerName,
    this.paperWidth = '58',
    this.orderType,
    this.tableName,
    this.itemNotes,
  });
}

/// Utility for discovering, connecting to and printing receipts on a
/// Bluetooth thermal (ESC/POS) printer.
///
/// Discovery and connection use native Android SPP (RFCOMM) via
/// `BluetoothUtils` → `MainActivity.kt` MethodChannel.
/// ESC/POS command generation is via `esc_pos_utils`.
class ReceiptPrinter {
  String? _connectedAddress;

  // ── Printer settings (persisted via SecureStore) ──
  static Uint8List? _logoBytes;
  static String _footerText = '';
  static bool _cashDrawerEnabled = false;
  static int _cashDrawerPin = 2;

  /// Cache the last print for one-tap reprint.
  static LastPrintParams? lastPrint;

  /// Load printer logo from app dir.
  static Future<void> loadLogo(String? path) async {
    if (path == null || path.isEmpty) {
      _logoBytes = null;
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        _logoBytes = await file.readAsBytes();
      }
    } catch (_) {
      _logoBytes = null;
    }
  }

  /// Set custom footer text.
  static void setFooter(String text) => _footerText = text;

  /// Enable/disable cash drawer auto-open after print.
  static void setCashDrawer({required bool enabled, int pin = 2}) {
    _cashDrawerEnabled = enabled;
    _cashDrawerPin = pin;
  }

  // ──────────────────────────────────────────────────────────
  // Discovery — native bonded devices
  // ──────────────────────────────────────────────────────────

  /// Discover bonded (paired) Bluetooth SPP devices.
  ///
  /// Uses native Android `BluetoothAdapter.getBondedDevices()` which
  /// correctly discovers classic Bluetooth thermal printers.
  Future<List<PrinterDevice>> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final rawDevices = await BluetoothUtils.scanDevices();
    return rawDevices
        .map((d) => PrinterDevice(
              name: d['name'] ?? 'Printer',
              address: d['address'] ?? '',
            ))
        .where((d) => d.address.isNotEmpty)
        .toList();
  }

  // ──────────────────────────────────────────────────────────
  // Connect
  // ──────────────────────────────────────────────────────────

  /// Connect to a printer by its Bluetooth MAC address.
  Future<bool> connect(PrinterDevice device) async {
    // Disconnect previous first
    await _disconnect();

    final ok = await BluetoothUtils.connectDevice(device.address);
    if (ok) {
      _connectedAddress = device.address;
      // Give the Bluetooth SPP stack a moment to fully stabilize.
      // Without this delay some Android/device combos report
      // isConnected()==true but drop the first write.
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return ok;
  }

  // ──────────────────────────────────────────────────────────
  // Print
  // ──────────────────────────────────────────────────────────

  /// Build the ESC/POS bytes for a receipt and send them to the connected
  /// printer. Returns `true` if the print job completed successfully.
  Future<bool> printReceipt({
    required String storeName,
    required List<ReceiptLine> lines,
    required int total,
    String? paymentMethod,
    String? cashierName,
    String invoice = '',
    String dateStr = '',
    int discount = 0,
    int? cashGiven,
    int? cashReturn,
    String? customerName,
    String paperWidth = '58',
    Uint8List? logo,
    String? footer,
    bool? showLogo,
    bool openDrawer = false,
    String? orderType,
    int? tableId,
    String? tableName,
    List<String?>? itemNotes,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];

    // ── ESC @ Reset: ensure printer is in a clean state ──
    // Cheap thermal printers have small buffers (~4 KB). If a previous job
    // left the printer in bit-image mode (ESC *), all subsequent text is
    // rendered as garbage pixels until paper runs out. Resetting first
    // guarantees known-good state regardless of what happened before.
    bytes.addAll(generator.reset());

    // ── Logo ──
    // showLogo=false explicitly skips the logo block entirely (no pixels
    // on paper), while still honoring a configured logo for other receipts.
    final renderLogo = showLogo ?? true;
    final logoBytes = logo ?? _logoBytes;
    if (renderLogo && logoBytes != null) {
      try {
        final logoImage = img.decodeImage(logoBytes);
        if (logoImage != null) {
          final maxWidth = paperWidth == '80' ? 320 : 160;
          // Cap BOTH dimensions: raster height is limited by the printer's
          // bit-image buffer (~3 bytes/column); a tall logo would otherwise
          // be cut off or produce garbage. Proportional resize keeps the
          // aspect ratio.
          final maxHeight = paperWidth == '80' ? 160 : 96;
          var resized = logoImage;
          if (logoImage.width > maxWidth ||
              logoImage.height > maxHeight) {
            final scale =
                (maxWidth / logoImage.width).clamp(0.0, 1.0);
            final hScale = maxHeight / logoImage.height;
            final s = scale < hScale ? scale : hScale;
            resized = img.copyResize(logoImage,
                width: (logoImage.width * s).round(),
                height: (logoImage.height * s).round());
          }
          // ESC * bit-image (image()) is far more widely supported than
          // GS v 0 raster (imageRaster()) on cheap thermal printers — many
          // Epson/SNBC clones render GS v 0 as garbage. Bit image renders
          // cleanly and the explicit reset() below exits bit-image mode.
          bytes.addAll(generator.image(resized, align: PosAlign.center));
          bytes.addAll(generator.feed(1));
          // ── CRITICAL: force printer OUT of bit-image mode ──
          // Cheap printers (&lt;4KB buffer) often lose the auto-reset that
          // esc_pos_utils appends, staying stuck in bit-image mode. Calling
          // reset() here sends ESC @ (initialize), which unconditionally
          // exits bit-image mode before any text.
          bytes.addAll(generator.reset());
        }
      } catch (_) {}
    }

    // Header — wrap long store names.
    bytes.addAll(generator.text(
      _san(storeName),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    ));
    if (invoice.isNotEmpty) {
      bytes.addAll(generator.text(_san(invoice),
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (dateStr.isNotEmpty) {
      bytes.addAll(generator.text(_san(dateStr),
          styles: const PosStyles(align: PosAlign.center)));
    }
    final isWide = paperWidth == '80';
    if (cashierName != null && cashierName.isNotEmpty) {
      final csrParts = _wrap('Kasir: $cashierName', isWide ? 30 : 24);
      for (final part in csrParts) {
        bytes.addAll(generator.text(_san(part),
            styles: const PosStyles(align: PosAlign.left)));
      }
    }
    if (customerName != null && customerName.isNotEmpty) {
      final custParts = _wrap('Pelanggan: $customerName', isWide ? 30 : 24);
      for (final part in custParts) {
        bytes.addAll(generator.text(_san(part),
            styles: const PosStyles(align: PosAlign.left)));
      }
    }
    if (orderType != null && orderType.isNotEmpty) {
      String line = orderType;
      if (tableName != null && tableName.isNotEmpty) line += ' - $tableName';
      bytes.addAll(generator.text(_san(line),
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    bytes.addAll(generator.hr());

    // Line items — manual text formatting for precise wrapping.
    // generator.row()+PosColumn internally clips text; generator.text() doesn't.
    //
    // 58mm uses Font B (compressed/small) like Alfamart/Indomaret receipts —
    // 42 chars/line vs 32 for Font A, so product names get ~2× the space
    // without wrapping. Prices stay in full Rupiah format.
    // 80mm stays on Font A (48 chars/line) — already spacious enough.
    final useFontB = !isWide;
    final itemStyles = useFontB
        ? const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB)
        : const PosStyles(align: PosAlign.left);
    final lineWidth = useFontB ? 42 : 48;         // usable chars per line
    final qtyPriceWidth = useFontB ? 12 : 15;     // "2 x Rp10.000" max
    final subWidth = useFontB ? 10 : 10;          // "Rp20.000" max
    final nameWidth = lineWidth - qtyPriceWidth - subWidth - 4; // 4 = 2 spaces

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final nameParts = _wrap(line.name, nameWidth);
      final qtyPrice = _fit('${line.qty}x${formatRupiah(line.price)}', qtyPriceWidth);
      final subtotal = _fit(formatRupiah(line.subtotal), subWidth);

      // First line: name | qty x price | subtotal
      // Pad each column to fixed width for alignment.
      bytes.addAll(generator.text(
        _san(nameParts.first.padRight(nameWidth) + '  ' + qtyPrice.padRight(qtyPriceWidth) + '  ' + subtotal.padLeft(subWidth)),
        styles: itemStyles,
      ));

      // Continuation lines for wrapped name
      for (var j = 1; j < nameParts.length; j++) {
        bytes.addAll(generator.text(
          _san(nameParts[j]),
          styles: itemStyles,
        ));
      }

      // Item notes
      if (itemNotes != null &&
          i < itemNotes.length &&
          itemNotes[i] != null &&
          itemNotes[i]!.isNotEmpty) {
        final noteParts = _wrap('  > ${itemNotes[i]!}', lineWidth - 2);
        for (final part in noteParts) {
          bytes.addAll(generator.text(
            _san(part),
            styles: itemStyles,
          ));
        }
      }
    }
    bytes.addAll(generator.hr());

    // Discount.
    if (discount > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Diskon', width: isWide ? 8 : 6),
        PosColumn(
          text: _fit('-${formatRupiah(discount)}', isWide ? 16 : 11),
          width: isWide ? 8 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    // Total.
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: isWide ? 8 : 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _fit(formatRupiah(total), isWide ? 16 : 11),
        width: isWide ? 8 : 6,
        styles: const PosStyles(
            bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]));

    // Payment details.
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Bayar ($paymentMethod)', width: isWide ? 8 : 6),
        PosColumn(
          text: _fit(formatRupiah(cashGiven ?? total), isWide ? 16 : 11),
          width: isWide ? 8 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    if (cashReturn != null && cashReturn > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Kembali', width: isWide ? 8 : 6),
        PosColumn(
          text: _fit(formatRupiah(cashReturn), isWide ? 16 : 11),
          width: isWide ? 8 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());

    // Footer — wrap long text.
    final footerText = footer ?? _footerText;
    if (footerText.isNotEmpty) {
      final footerParts = _wrap(footerText, isWide ? 40 : 32);
      for (final part in footerParts) {
        bytes.addAll(generator.text(
          _san(part),
          styles: const PosStyles(align: PosAlign.center),
        ));
      }
    }
    bytes.addAll(generator.text(
      _san('Terima Kasih!'),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(_san(storeName),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    // ── Cash drawer trigger ──
    // Standard ESC/POS kick command: ESC p m t1 t2  → 1B 70 00 19 19 (pin 2)
    // or 1B 70 01 19 19 (pin 5). esc_pos_utils' drawer() emits the text form
    // 1B 70 30 33 30 ('p030') which many cheap Epson-compatible printers
    // reject — so we send the binary form directly.
    if (openDrawer || _cashDrawerEnabled) {
      final ok = await BluetoothUtils.sendBytes(_drawerBytes(_cashDrawerPin));
      if (!ok) {
        debugPrint('[ReceiptPrinter] Cash drawer trigger failed to send');
      }
    }

    // Send receipt bytes over native SPP connection.
    final ok = await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));

    if (ok) {
      // Cache for reprint
      lastPrint = LastPrintParams(
        storeName: storeName,
        lines: lines,
        total: total,
        paymentMethod: paymentMethod,
        cashierName: cashierName,
        invoice: invoice,
        dateStr: dateStr,
        discount: discount,
        cashGiven: cashGiven,
        cashReturn: cashReturn,
        customerName: customerName,
        paperWidth: paperWidth,
        orderType: orderType,
        tableName: tableName,
        itemNotes: itemNotes,
      );
    }

    return ok;
  }

  /// Reprint the last receipt.
  Future<bool> printLastReceipt({bool openDrawer = false}) async {
    final p = lastPrint;
    if (p == null) return false;
    return printReceipt(
      storeName: p.storeName,
      lines: p.lines,
      total: p.total,
      paymentMethod: p.paymentMethod,
      cashierName: p.cashierName,
      invoice: p.invoice,
      dateStr: p.dateStr,
      discount: p.discount,
      cashGiven: p.cashGiven,
      cashReturn: p.cashReturn,
      customerName: p.customerName,
      paperWidth: p.paperWidth,
      openDrawer: openDrawer,
      orderType: p.orderType,
      tableName: p.tableName,
      itemNotes: p.itemNotes,
    );
  }

  /// Print a servis/workshop ticket (bengkel) to the connected thermal
  /// printer. Unlike a sales receipt there are no per-item prices — the
  /// ticket shows vehicle info, complaint, technician and cost breakdown.
  /// Uses only static/global state, so it can be called without an instance.
  static Future<bool> printTicket({
    required String storeName,
    required List<ReceiptLine> lines,
    required int total,
    String paperWidth = '58',
    String dateStr = '',
    String ticketNo = '',
    String? customerName,
    String? customerPhone,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];
    bytes.addAll(generator.reset());

    // Header
    bytes.addAll(generator.text(
      _san('TIKET SERVIS'),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    ));
    bytes.addAll(generator.text(
      _san(storeName),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    if (ticketNo.isNotEmpty) {
      bytes.addAll(generator.text(
        _san(ticketNo),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
    }
    if (dateStr.isNotEmpty) {
      bytes.addAll(generator.text(
        _san(dateStr),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (customerName != null && customerName.isNotEmpty) {
      final custParts = _wrap('Pelanggan: $customerName', 24);
      for (final part in custParts) {
        bytes.addAll(generator.text(
          _san(part),
          styles: const PosStyles(align: PosAlign.left),
        ));
      }
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      bytes.addAll(generator.text(
        _san('HP: $customerPhone'),
        styles: const PosStyles(align: PosAlign.left),
      ));
    }
    bytes.addAll(generator.hr());

    // Ticket lines (info rows, wrapped)
    for (final line in lines) {
      final nameParts = _wrap(line.name, 32);
      for (final part in nameParts) {
        bytes.addAll(generator.text(
          _san(part),
          styles: const PosStyles(align: PosAlign.left),
        ));
      }
    }

    bytes.addAll(generator.hr());

    // Total (bold, size2)
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _fit(formatRupiah(total), 11),
        width: 6,
        styles: const PosStyles(
            bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]));

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      _san('Simpan tiket ini untuk pengambilan'),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      _san('Terima Kasih!'),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return BluetoothUtils.sendBytes(Uint8List.fromList(bytes));
  }

  /// Print a kitchen order to the kitchen printer (FnB only).
  /// No prices or totals — just item names, quantities, and notes.
  Future<bool> printKitchenOrder({
    required String orderType,
    required List<ReceiptLine> lines,
    List<String?>? itemNotes,
    String? tableName,
  }) async {
    // Save main printer address before switching
    final mainAddr = _connectedAddress;
    final kitchenAddr = await SecureStore.getKitchenPrinterAddress();
    final kitchenEnabled = await SecureStore.getKitchenPrinterEnabled();

    if (!kitchenEnabled || kitchenAddr == null || kitchenAddr.isEmpty) {
      return false; // No kitchen printer configured
    }

    // Disconnect current (main) and connect to kitchen printer
    await BluetoothUtils.disconnectDevice();
    final ok = await BluetoothUtils.connectDevice(kitchenAddr);
    if (!ok) {
      // Reconnect back to main if kitchen connection failed
      if (mainAddr != null && mainAddr.isNotEmpty) {
        await BluetoothUtils.connectDevice(mainAddr);
        _connectedAddress = mainAddr;
      }
      return false;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    final List<int> bytes = [];

    // ── ESC @ Reset: ensure printer is in a clean state ──
    bytes.addAll(generator.reset());

    // Big bold header: "DAPUR"
    bytes.addAll(generator.text(
      _san('DAPUR'),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    ));

    // Table name
    if (tableName != null && tableName.isNotEmpty) {
      bytes.addAll(generator.text(
        _san(tableName),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
    }

    // Order type badge
    bytes.addAll(generator.text(
      _san(orderType),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(generator.hr());

    // Items: name (size2, bold) + qty, no prices. Wrap long names.
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Wrap long item names across multiple lines.
      final nameParts = _wrap(line.name, 16); // 16 chars for size2 text on 58mm
      for (final part in nameParts) {
        bytes.addAll(generator.text(
          _san(part),
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
          ),
        ));
      }
      bytes.addAll(generator.text(
        _san('Qty: ${line.qty}'),
        styles: const PosStyles(align: PosAlign.left),
      ));

      if (itemNotes != null &&
          i < itemNotes.length &&
          itemNotes[i] != null &&
          itemNotes[i]!.isNotEmpty) {
        final noteParts = _wrap('  > ${itemNotes[i]!}', 20);
        for (final part in noteParts) {
          bytes.addAll(generator.text(
            _san(part),
            styles: const PosStyles(align: PosAlign.left),
          ));
        }
      }
    }

    bytes.addAll(generator.hr());

    // Timestamp
    final now = DateTime.now();
    bytes.addAll(generator.text(
      '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}:${now.second}',
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    final result = await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));

    // Reconnect back to main printer
    await BluetoothUtils.disconnectDevice();
    if (mainAddr != null && mainAddr.isNotEmpty) {
      await BluetoothUtils.connectDevice(mainAddr);
      _connectedAddress = mainAddr;
    }

    return result;
  }

  /// Open cash drawer only.
  Future<bool> openDrawer({int pin = 2}) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;
    try {
      return await BluetoothUtils.sendBytes(_drawerBytes(pin));
    } catch (_) {
      return false;
    }
  }

  /// Standard ESC/POS cash drawer kick: 1B 70 m t1 t2.
  /// pin 2 → m=0x00, t1=0x19 (25), t2=0x19 (25); pin 5 → m=0x01.
  static Uint8List _drawerBytes(int pin) {
    final m = pin == 2 ? 0x00 : 0x01;
    return Uint8List.fromList([0x1B, 0x70, m, 0x19, 0x19]);
  }

  /// Print a test receipt.
  Future<bool> printTest(String storeName, {String paperWidth = '58'}) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_san('TEST PRINT'),
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text(_san(storeName),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(_san('Printer thermal berfungsi dengan baik.'),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text(_san('Kertas: ${paperWidth}mm'),
        styles: const PosStyles(align: PosAlign.center)));
    final now = DateTime.now();
    bytes.addAll(generator.text(
        _san('${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}'),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(_san('NUSA Kasir'),
        styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));
  }

  /// Quick check if connected.
  Future<bool> get isConnected => BluetoothUtils.isConnected();

  /// The address of the currently connected device.
  String? get connectedAddress => _connectedAddress;

  /// Ensure Bluetooth permissions are granted and Bluetooth is enabled.
  /// Call this before [discover] or [connect] to avoid silent failures
  /// on Android 12+ where runtime permissions are required.
  ///
  /// Returns `true` if ready to proceed, `false` if permissions or
  /// Bluetooth state block the operation.
  static Future<bool> ensureBluetoothReady() async {
    // 1. Check & request runtime Bluetooth permissions (Android 12+)
    if (Platform.isAndroid) {
      if (!await BluetoothUtils.hasBluetoothPermissions()) {
        final granted = await BluetoothUtils.requestBluetoothPermissions();
        if (!granted) return false;
      }
    }
    // 2. Check Bluetooth is enabled
    if (!await BluetoothUtils.isBluetoothEnabled()) {
      return false;
    }
    return true;
  }

  /// Disconnect the Bluetooth connection.
  Future<void> _disconnect() async {
    _connectedAddress = null;
    await BluetoothUtils.disconnectDevice();
  }

  /// Disconnect and release resources.
  Future<void> dispose() async {
    await _disconnect();
  }
}
