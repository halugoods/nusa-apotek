import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';

import 'package:nusa_kasir/core/receipt/receipt_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_data.dart';
import 'package:nusa_kasir/core/receipt/receipt_renderer.dart';
import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// A single line item on a receipt.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.price,
    this.originalPrice,
    this.discountPerItem,
    this.productDiscount,
  });

  final String name;
  final int qty;

  /// Harga final per unit (termasuk harga sementara tempPrice & diskon
  /// produk). Dipakai sebagai harga TERSIMPAN di struk.
  final int price;

  /// Harga jual sebelum diskon (null = tanpa diskon). Saat diisi, struk
  /// mencetak baris potongan NOMINAL per item ("Diskon: -Rp 5.000").
  final int? originalPrice;

  /// Diskon nominal per SATUAN (v2.2.57+116) — dari fitur "Ubah Diskon"
  /// manual di kasir. Diteruskan ke ReceiptItem.
  final int? discountPerItem;

  /// Diskon dari menu Produk per satuan (v2.2.57+126).
  final int? productDiscount;

  int get subtotal => qty * grossUnitPrice;
  bool get hasDiscount =>
      (originalPrice != null && originalPrice! > price) ||
      (productDiscount != null && productDiscount! > 0) ||
      (discountPerItem != null && discountPerItem! > 0);
  int get discountNominal =>
      (productDiscount ?? 0) + (discountPerItem ?? 0);

  /// Harga ASLI per unit (sebelum diskon produk manapun).
  int get grossUnitPrice => originalPrice ?? (price + (productDiscount ?? 0));

  /// Subtotal KOTOR — harga asli × qty (potongan jadi baris "Disc.").
  int get grossSubtotal => subtotal;

  /// Potongan diskon item TOTAL untuk semua qty (per unit × qty).
  int get discountTotal => discountNominal * qty;
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

/// Ukuran font RINCIAN & FOOTER struk — mundur ke gaya v2.2.11:
/// hanya 2 pilihan perbesaran ESC/POS ×1 (Kecil) / ×2 (Besar).
///
/// Ukuran LITERAL yang dicetak (Font A ~12pt @1x, ~24pt @2x):
///   - ×1 → 12pt (58mm → 32 char/baris, 80mm → 48 char/baris)
///   - ×2 → 24pt (58mm → 16 char/baris, 80mm → 24 char/baris)
/// Font B ~1.15× lebih ramping (58mm → 42 @1x; 80mm → 64 @1x).
const int receiptItemsMinMag = 1;
const int receiptItemsMaxMag = 2;

/// Ukuran font PREVIEW (px) untuk rincian/footer yang match hasil cetak.
/// ×1 → 11px, ×2 → 13px (pendekatan visual — Font B/Kompak lebih ramping).
double receiptPreviewSize(int mag, {bool kompak = false}) {
  final m = mag.clamp(receiptItemsMinMag, receiptItemsMaxMag);
  if (m == 2) return kompak ? 14.0 : 13.0;
  return kompak ? 10.0 : 11.0;
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
  const PrinterDevice({required this.name, required this.address});

  final String name;
  final String address;
}

/// Cached data dari print terakhir — reprint memakai DATA lama + CONFIG
/// TERBARU (spec AA: reprint transaksi lama = data lama, template baru).
class LastPrintParams {
  final String storeName;
  final ReceiptData data;

  const LastPrintParams({required this.storeName, required this.data});
}

/// Utility for discovering, connecting to and printing receipts on a
/// Bluetooth thermal (ESC/POS) printer.
///
/// Struk dicetak dengan arsitektur HYBRID (v2.2.27):
///  - HEADER (nama toko / header custom + invoice/tanggal/kasir/pelanggan/
///    tipe) dirender sebagai IMAGE (PNG bit-image ESC *) — ukuran huruf
///    header dari slider 12–48px (`nusa_receipt_header_px`). Preview
///    memakai renderer yang SAMA, jadi selalu match dengan print.
///  - RINCIAN & FOOTER dicetak sebagai TEKS ESC/POS biasa (cepat) dengan
///    2 pilihan ukuran: ×1 Kecil / ×2 Besar (gaya v2.2.11).
///  - LOGO dicetak bit-image ESC * terpisah (lebar PERSEN dari kertas).
///
/// Discovery and connection use native Android SPP (RFCOMM) via
/// `BluetoothUtils` → `MainActivity.kt` MethodChannel.
/// ESC/POS command generation is via `esc_pos_utils`.
class ReceiptPrinter {
  String? _connectedAddress;

  // ── Printer settings (persisted via SecureStore) ──
  static Uint8List? _logoBytes;
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
        .map(
          (d) => PrinterDevice(
            name: d['name'] ?? 'Printer',
            address: d['address'] ?? '',
          ),
        )
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
  ///
  /// v2.2.29: layout SELURUHNYA dari [ReceiptRenderer.renderBytes] — SATU
  /// renderer yang SAMA dengan preview/PDF/share. Config dibaca dari
  /// [config] (default: [ReceiptConfig.loadFromStore]) — TIDAK membaca
  /// SecureStore di dalam lagi.
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
    int downPayment = 0,
    int remainingDue = 0,
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
    // Lebar logo saat print — PERSEN dari lebar kertas (1-100).
    int logoWidthPercent = 60,
    ReceiptConfig? config,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final cfg = config ?? await ReceiptConfig.loadFromStore();
    // Caller dapat override field tertentu (split bill dsb).
    var cfg2 = cfg;
    if (paperWidth != '58' && paperWidth != cfg.paperWidth) {
      cfg2 = cfg2.copyWith(paperWidth: paperWidth);
    }
    if (footer != null) cfg2 = cfg2.copyWith(footer: footer);
    if (logoWidthPercent != 60 && logoWidthPercent != cfg.logoWidthPercent) {
      cfg2 = cfg2.copyWith(logoWidthPercent: logoWidthPercent);
    }
    if (showLogo != null) cfg2 = cfg2.copyWith(showLogo: showLogo);

    final data = ReceiptData(
      invoiceNumber: invoice,
      dateStr: dateStr,
      cashierName: cashierName,
      customerName: customerName,
      orderType: orderType,
      tableName: tableName,
      items: [
        for (var i = 0; i < lines.length; i++)
          ReceiptItem(
            name: lines[i].name,
            qty: lines[i].qty,
            price: lines[i].price,
            originalPrice: lines[i].originalPrice,
            discountPerItem: lines[i].discountPerItem,
            productDiscount: lines[i].productDiscount,
            note: (itemNotes != null && i < itemNotes.length)
                ? itemNotes[i]
                : null,
          ),
      ],
      discount: discount,
      total: total,
      cashGiven: cashGiven,
      cashReturn: cashReturn,
      downPayment: downPayment,
      remainingDue: remainingDue,
      paymentMethod: paymentMethod ?? '',
    );

    final bytes = await renderBytes(
      config: cfg2,
      data: data,
      storeName: storeName,
      logoBytes: logo ?? _logoBytes,
      openDrawer: openDrawer,
      drawerPin: _cashDrawerPin,
    );

    // Cash drawer — binary ESC p via drawer bytes (jika belum termasuk
    // di renderBytes karena openDrawer dari state).
    if (_cashDrawerEnabled && !openDrawer) {
      final ok = await BluetoothUtils.sendBytes(_drawerBytes(_cashDrawerPin));
      if (!ok) {
        debugPrint('[ReceiptPrinter] Cash drawer trigger failed to send');
      }
    }

    // Send receipt bytes over native SPP connection.
    final ok = await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));

    if (ok) {
      // Cache untuk reprint — DATA lama + config TERBARU (spec AA).
      lastPrint = LastPrintParams(storeName: storeName, data: data);
    }

    return ok;
  }

  /// Reprint the last receipt — memakai CONFIG TERBARU (spec AA).
  Future<bool> printLastReceipt({bool openDrawer = false}) async {
    final p = lastPrint;
    if (p == null) return false;
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;
    final bytes = await renderBytes(
      config: await ReceiptConfig.loadFromStore(),
      data: p.data,
      storeName: p.storeName,
      logoBytes: _logoBytes,
      openDrawer: openDrawer,
      drawerPin: _cashDrawerPin,
    );
    if (_cashDrawerEnabled && !openDrawer) {
      await BluetoothUtils.sendBytes(_drawerBytes(_cashDrawerPin));
    }
    return BluetoothUtils.sendBytes(Uint8List.fromList(bytes));
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
    bytes.addAll(
      generator.text(
        _san('TIKET SERVIS'),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
        linesAfter: 1,
      ),
    );
    bytes.addAll(
      generator.text(
        _san(storeName),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    if (ticketNo.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _san(ticketNo),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }
    if (dateStr.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _san(dateStr),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (customerName != null && customerName.isNotEmpty) {
      final custParts = _wrap('Pelanggan: $customerName', 24);
      for (final part in custParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: const PosStyles(align: PosAlign.left),
          ),
        );
      }
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _san('HP: $customerPhone'),
          styles: const PosStyles(align: PosAlign.left),
        ),
      );
    }
    bytes.addAll(generator.hr());

    // Ticket lines (info rows, wrapped)
    for (final line in lines) {
      final nameParts = _wrap(line.name, 32);
      for (final part in nameParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: const PosStyles(align: PosAlign.left),
          ),
        );
      }
    }

    bytes.addAll(generator.hr());

    // Total (bold, size2)
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: _fit(formatRupiah(total), 11),
          width: 6,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
          ),
        ),
      ]),
    );

    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        _san('Simpan tiket ini untuk pengambilan'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _san('Terima Kasih!'),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
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
    bytes.addAll(
      generator.text(
        _san('DAPUR'),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
        linesAfter: 1,
      ),
    );

    // Table name
    if (tableName != null && tableName.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _san(tableName),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }

    // Order type badge
    bytes.addAll(
      generator.text(
        _san(orderType),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    bytes.addAll(generator.hr());

    // Items: name (size2, bold) + qty, no prices. Wrap long names.
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Wrap long item names across multiple lines.
      final nameParts = _wrap(line.name, 16); // 16 chars for size2 text on 58mm
      for (final part in nameParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: const PosStyles(bold: true, height: PosTextSize.size2),
          ),
        );
      }
      bytes.addAll(
        generator.text(
          _san('Qty: ${line.qty}'),
          styles: const PosStyles(align: PosAlign.left),
        ),
      );

      if (itemNotes != null &&
          i < itemNotes.length &&
          itemNotes[i] != null &&
          itemNotes[i]!.isNotEmpty) {
        final noteParts = _wrap('  > ${itemNotes[i]!}', 20);
        for (final part in noteParts) {
          bytes.addAll(
            generator.text(
              _san(part),
              styles: const PosStyles(align: PosAlign.left),
            ),
          );
        }
      }
    }

    bytes.addAll(generator.hr());

    // Timestamp
    final now = DateTime.now();
    bytes.addAll(
      generator.text(
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}:${now.second}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

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

  /// Print tes struk — memakai renderer YANG SAMA + config SAAT INI +
  /// data sample (spec W). Output di kertas = persis preview Pengaturan
  /// Struk (satu renderer; v2.2.29 — sebelumnya layout teks sendiri).
  Future<bool> printTest(
    String storeName, {
    String paperWidth = '58',
    ReceiptConfig? config,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final cfg = (config ?? await ReceiptConfig.loadFromStore()).copyWith(
      paperWidth: paperWidth == '80' ? '80' : '58',
    );

    final bytes = await renderBytes(
      config: cfg,
      data: ReceiptData.sample(),
      storeName: storeName.trim().isEmpty ? 'NUSA Kasir' : storeName.trim(),
      logoBytes: _logoBytes,
    );

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
