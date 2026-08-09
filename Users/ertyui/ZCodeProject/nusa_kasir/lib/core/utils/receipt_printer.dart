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

/// Truncate text to fit thermal printer column.
/// 58mm paper: ~2 chars per PosColumn width unit.
String _fit(String text, int maxChars) {
  final s = _san(text);
  if (s.length <= maxChars) return s;
  return '${s.substring(0, maxChars - 3)}...';
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
    final logoBytes = logo ?? _logoBytes;
    if (logoBytes != null) {
      try {
        final logoImage = img.decodeImage(logoBytes);
        if (logoImage != null) {
          // Resize: max 200px wide for 58mm, 360px for 80mm.
          // Keeping the logo compact avoids overflowing cheap printer buffers.
          final maxWidth = paperWidth == '80' ? 360 : 200;
          img.Image resized;
          if (logoImage.width > maxWidth) {
            resized = img.copyResize(logoImage, width: maxWidth);
          } else {
            resized = logoImage;
          }
          bytes.addAll(generator.imageRaster(resized, align: PosAlign.center));
          bytes.addAll(generator.feed(1));
        }
      } catch (_) {}
    }

    // Header.
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
    if (cashierName != null && cashierName.isNotEmpty) {
      bytes.addAll(generator.text(_san('Kasir: $cashierName')));
    }
    if (customerName != null && customerName.isNotEmpty) {
      bytes.addAll(generator.text(_san('Pelanggan: $customerName')));
    }
    if (orderType != null && orderType.isNotEmpty) {
      String line = orderType!;
      if (tableName != null && tableName.isNotEmpty) line += ' - $tableName';
      bytes.addAll(generator.text(_san(line),
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    bytes.addAll(generator.hr());

    // Line items.
    final isWide = paperWidth == '80';
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final nameCol = isWide ? 7 : 5;
      final qtyCol = isWide ? 5 : 4;
      final subCol = isWide ? 4 : 3;
      // ~2 chars per column width unit on 58mm paper
      final nameMax = isWide ? 14 : 9;
      final qtyMax = isWide ? 10 : 7;
      final subMax = isWide ? 8 : 5;

      bytes.addAll(generator.row([
        PosColumn(
          text: _fit(line.name, nameMax),
          width: nameCol,
        ),
        PosColumn(
          text: _fit('${line.qty} x ${formatRupiah(line.price)}', qtyMax),
          width: qtyCol,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: _fit(formatRupiah(line.subtotal), subMax),
          width: subCol,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));

      if (itemNotes != null &&
          i < itemNotes.length &&
          itemNotes[i] != null &&
          itemNotes[i]!.isNotEmpty) {
        bytes.addAll(generator.text(
          _san('  > ${itemNotes[i]}'),
          styles: const PosStyles(align: PosAlign.left),
        ));
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

    // Footer.
    final footerText = footer ?? _footerText;
    if (footerText.isNotEmpty) {
      bytes.addAll(generator.text(
        _san(footerText),
        styles: const PosStyles(align: PosAlign.center),
      ));
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
    if (openDrawer || _cashDrawerEnabled) {
      final pin = _cashDrawerPin == 2 ? PosDrawer.pin2 : PosDrawer.pin5;
      bytes.addAll(generator.drawer(pin: pin));
    }

    // Send bytes over native SPP connection.
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

    // Items: name (size2, bold) + qty, no prices
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      bytes.addAll(generator.text(
        _san(line.name),
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
        ),
      ));
      bytes.addAll(generator.text(
        _san('Qty: ${line.qty}'),
        styles: const PosStyles(align: PosAlign.left),
      ));

      if (itemNotes != null &&
          i < itemNotes.length &&
          itemNotes[i] != null &&
          itemNotes[i]!.isNotEmpty) {
        bytes.addAll(generator.text(
          _san('  > ${itemNotes[i]}'),
          styles: const PosStyles(align: PosAlign.left),
        ));
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
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = generator.drawer(
        pin: pin == 2 ? PosDrawer.pin2 : PosDrawer.pin5,
      );
      return await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));
    } catch (_) {
      return false;
    }
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
