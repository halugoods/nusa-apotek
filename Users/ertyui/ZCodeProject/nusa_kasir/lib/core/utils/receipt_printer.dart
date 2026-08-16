import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/receipt_renderer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// A single line item on a receipt (printer).
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.price,
    this.originalPrice,
  });

  final String name;
  final int qty;
  final int price;

  /// Harga jual sebelum diskon (null = tanpa diskon). Saat diisi, struk
  /// mencetak baris potongan NOMINAL per item ("Diskon: -Rp 5.000").
  final int? originalPrice;

  int get subtotal => qty * price;
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int get discountNominal => hasDiscount ? originalPrice! - price : 0;
  int get discountTotal => hasDiscount ? discountNominal * qty : 0;
}

/// A discovered Bluetooth thermal printer.
class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

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
  final int downPayment;
  final int remainingDue;
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
    this.downPayment = 0,
    this.remainingDue = 0,
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
/// SEMUA struk dicetak sebagai GAMBAR (bit-image ESC *), bukan teks:
/// printer termal murah (klon VSC/Epson) hanya bisa membesarkan teks ×2
/// dengan andal; ×3/×4 diabaikan → "cuma 2 ukuran". Dengan bit-image,
/// printer cuma menggambar piksel yang sudah dirender di HP → ukuran
/// header/rincian/footer/logo BEBAS (12-48px slider) dan PASTI tercetak.
///
/// Discovery and connection use native Android SPP (RFCOMM) via
/// `BluetoothUtils` → `MainActivity.kt` MethodChannel.
/// Rendering via `receipt_renderer.dart`; ESC/POS via `esc_pos_utils`.
class ReceiptPrinter {
  String? _connectedAddress;

  // ── Printer settings (persisted via SecureStore) ──
  static Uint8List? _logoBytes;
  static String _footerText = '';

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

  // ──────────────────────────────────────────────────────────
  // Discovery — native bonded devices
  // ──────────────────────────────────────────────────────────

  /// Discover bonded (paired) Bluetooth SPP devices.
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
    await _disconnect();

    final ok = await BluetoothUtils.connectDevice(device.address);
    if (ok) {
      _connectedAddress = device.address;
      // Give the Bluetooth SPP stack a moment to fully stabilize.
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return ok;
  }

  // ──────────────────────────────────────────────────────────
  // Build + print (bit-image)
  // ──────────────────────────────────────────────────────────

  /// Muat pengaturan struk dari SecureStore → `ReceiptRenderConfig`.
  /// Dipakai oleh print DAN preview (satu sumber pengaturan).
  static Future<ReceiptRenderConfig> loadRenderConfig({
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
    String? orderType,
    String? tableName,
    List<String?>? itemNotes,
    String? header,
    String? footer,
    Uint8List? logoBytes,
    bool showLogo = true,
  }) async {
    final headerSize = await SecureStore.getReceiptFontHeader(); // px 12..48
    final itemsSize = await SecureStore.getReceiptFontItems(); // px 12..48
    final footerSize = await SecureStore.getReceiptFontFooter(); // px 12..48
    final logoRatio = await SecureStore.getReceiptLogoWidthPercent();
    final headerText = header ?? await SecureStore.getReceiptHeader();
    final footerText = footer ?? _footerText;

    return ReceiptRenderConfig(
      storeName: storeName,
      lines: lines
          .map(
            (l) => ReceiptRenderLine(
              name: l.name,
              qty: l.qty,
              price: l.price,
              originalPrice: l.originalPrice,
            ),
          )
          .toList(),
      total: total,
      paymentMethod: paymentMethod,
      cashierName: cashierName,
      invoice: invoice,
      dateStr: dateStr,
      discount: discount,
      cashGiven: cashGiven,
      cashReturn: cashReturn,
      downPayment: downPayment,
      remainingDue: remainingDue,
      customerName: customerName,
      paperWidth: paperWidth,
      orderType: orderType,
      tableName: tableName,
      itemNotes: itemNotes,
      header: headerText ?? '',
      footer: footerText,
      logoBytes: logoBytes ?? _logoBytes,
      showLogo: showLogo,
      headerSizePx: headerSize.clamp(receiptMinPx, receiptMaxPx),
      itemsSizePx: itemsSize.clamp(receiptMinPx, receiptMaxPx),
      footerSizePx: footerSize.clamp(receiptMinPx, receiptMaxPx),
      logoWidthPercent: logoRatio,
    );
  }

  /// Render struk → PNG via `receipt_renderer`, kirim sebagai bit-image.
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
    String? header,
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

    // Render struk jadi bitmap (satu-satunya sumber — preview = print).
    final cfg = await loadRenderConfig(
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
      downPayment: downPayment,
      remainingDue: remainingDue,
      customerName: customerName,
      paperWidth: paperWidth,
      orderType: orderType,
      tableName: tableName,
      itemNotes: itemNotes,
      header: header == null ? null : header,
      footer: footer,
      logoBytes: logo,
      showLogo: showLogo ?? true,
    );
    final png = await renderReceiptPng(cfg);

    final List<int> bytes = [];
    // ESC @ Reset: bersihkan state printer (bit-image mode sebelumnya dll).
    bytes.addAll(generator.reset());

    // ── Cetak struk sebagai GAMBAR (ESC * bit-image) ──
    // Printer cuma menggambar piksel — tidak menafsirkan perbesaran teks.
    // Jalur ini SAMA dengan logo yang selama ini selalu muncul di printer
    // user, jadi hasilnya pasti tampil (ukuran bebas 12-48px).
    try {
      final receiptImage = img.decodeImage(png);
      if (receiptImage != null) {
        bytes.addAll(generator.image(receiptImage, align: PosAlign.center));
        bytes.addAll(generator.reset());
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    // ── Cash drawer trigger ──
    if (openDrawer || await SecureStore.getCashDrawerEnabled()) {
      final ok = await BluetoothUtils.sendBytes(_drawerBytes(await SecureStore.getCashDrawerPin()));
      if (!ok) {
        debugPrint('[ReceiptPrinter] Cash drawer trigger failed to send');
      }
    }

    final ok = await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));

    if (ok) {
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
        downPayment: downPayment,
        remainingDue: remainingDue,
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
      downPayment: p.downPayment,
      remainingDue: p.remainingDue,
      customerName: p.customerName,
      paperWidth: p.paperWidth,
      openDrawer: openDrawer,
      orderType: p.orderType,
      tableName: p.tableName,
      itemNotes: p.itemNotes,
    );
  }

  /// Print a servis/workshop ticket (bengkel) — juga bit-image.
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

    final cfg = ReceiptRenderConfig(
      storeName: 'TIKET SERVIS',
      lines: [
        ...lines.map(
          (l) => ReceiptRenderLine(name: l.name, qty: l.qty, price: l.price),
        ),
        ReceiptRenderLine(name: 'No: $ticketNo', qty: 1, price: 0),
        if (dateStr.isNotEmpty)
          ReceiptRenderLine(name: dateStr, qty: 1, price: 0),
        if (customerName != null && customerName.isNotEmpty)
          ReceiptRenderLine(name: 'Pelanggan: $customerName', qty: 1, price: 0),
        if (customerPhone != null && customerPhone.isNotEmpty)
          ReceiptRenderLine(name: 'HP: $customerPhone', qty: 1, price: 0),
      ],
      total: total,
      paperWidth: paperWidth,
      footer: 'Simpan tiket ini untuk pengambilan',
    );

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final png = await renderReceiptPng(cfg);
    final receiptImage = img.decodeImage(png);
    if (receiptImage == null) return false;

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.image(receiptImage, align: PosAlign.center));
    bytes.addAll(generator.reset());
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return BluetoothUtils.sendBytes(Uint8List.fromList(bytes));
  }

  /// Print a kitchen order to the kitchen printer (FnB only) — bit-image.
  Future<bool> printKitchenOrder({
    required String orderType,
    required List<ReceiptLine> lines,
    List<String?>? itemNotes,
    String? tableName,
  }) async {
    final mainAddr = _connectedAddress;
    final kitchenAddr = await SecureStore.getKitchenPrinterAddress();
    final kitchenEnabled = await SecureStore.getKitchenPrinterEnabled();

    if (!kitchenEnabled || kitchenAddr == null || kitchenAddr.isEmpty) {
      return false;
    }

    await BluetoothUtils.disconnectDevice();
    final ok = await BluetoothUtils.connectDevice(kitchenAddr);
    if (!ok) {
      if (mainAddr != null && mainAddr.isNotEmpty) {
        await BluetoothUtils.connectDevice(mainAddr);
        _connectedAddress = mainAddr;
      }
      return false;
    }

    final cfg = ReceiptRenderConfig(
      storeName: 'DAPUR',
      lines: lines
          .map(
            (l) => ReceiptRenderLine(name: l.name, qty: l.qty, price: 0),
          )
          .toList(),
      total: 0,
      paperWidth: '58',
      orderType: orderType,
      tableName: tableName,
      itemNotes: itemNotes,
      footer: '',
      header: 'DAPUR',
      headerSizePx: 24,
      itemsSizePx: 14,
      footerSizePx: 12,
    );

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    final png = await renderReceiptPng(cfg);
    final receiptImage = img.decodeImage(png);
    if (receiptImage == null) {
      if (mainAddr != null && mainAddr.isNotEmpty) {
        await BluetoothUtils.connectDevice(mainAddr);
        _connectedAddress = mainAddr;
      }
      return false;
    }

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.image(receiptImage, align: PosAlign.center));
    bytes.addAll(generator.reset());
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    final result = await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));

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
  static Uint8List _drawerBytes(int pin) {
    final m = pin == 2 ? 0x00 : 0x01;
    return Uint8List.fromList([0x1B, 0x70, m, 0x19, 0x19]);
  }

  /// Print a TEST KALIBRASI — mencetak satu struk contoh (bit-image) dengan
  /// ukuran header/rincian/footer yang sedang dipilih, plus baris "semua
  /// ukuran" supaya user langsung melihat ukuran slider bekerja di kertas.
  Future<bool> printTest(
    String storeName, {
    String paperWidth = '58',
    int headerSize = 24,
    int itemsSize = 12,
    int footerSize = 12,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final cfg = ReceiptRenderConfig(
      storeName: storeName,
      lines: [
        ReceiptRenderLine(name: 'Tes Ukuran Font', qty: 1, price: 0),
        ReceiptRenderLine(name: 'Header ${headerSize}px', qty: 1, price: 0),
        ReceiptRenderLine(name: 'Rincian ${itemsSize}px', qty: 1, price: 0),
        ReceiptRenderLine(name: 'Footer ${footerSize}px', qty: 1, price: 0),
        ReceiptRenderLine(name: 'Struk kini dicetak sebagai gambar', qty: 1, price: 0),
      ],
      total: 0,
      paperWidth: paperWidth,
      headerSizePx: headerSize.clamp(receiptMinPx, receiptMaxPx),
      itemsSizePx: itemsSize.clamp(receiptMinPx, receiptMaxPx),
      footerSizePx: footerSize.clamp(receiptMinPx, receiptMaxPx),
      footer: '',
    );

    final png = await renderReceiptPng(cfg);
    final receiptImage = img.decodeImage(png);
    if (receiptImage == null) return false;

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.image(receiptImage, align: PosAlign.center));
    bytes.addAll(generator.reset());
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return await BluetoothUtils.sendBytes(Uint8List.fromList(bytes));
  }

  /// Quick check if connected.
  Future<bool> get isConnected => BluetoothUtils.isConnected();

  /// The address of the currently connected device.
  String? get connectedAddress => _connectedAddress;

  /// Ensure Bluetooth permissions are granted and Bluetooth is enabled.
  static Future<bool> ensureBluetoothReady() async {
    if (Platform.isAndroid) {
      if (!await BluetoothUtils.hasBluetoothPermissions()) {
        final granted = await BluetoothUtils.requestBluetoothPermissions();
        if (!granted) return false;
      }
    }
    if (!await BluetoothUtils.isBluetoothEnabled()) {
      return false;
    }
    return true;
  }

  Future<void> _disconnect() async {
    _connectedAddress = null;
    await BluetoothUtils.disconnectDevice();
  }

  Future<void> dispose() async {
    await _disconnect();
  }
}
