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
    final headerPercent = await SecureStore.getReceiptFontHeader(); // 1..100
    final itemsMode = await SecureStore.getReceiptFontItems(); // 0=kecil 1=besar
    final footerMode = await SecureStore.getReceiptFontFooter(); // 0=kecil 1=besar
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
      headerPercent: headerPercent.clamp(1, 100),
      itemsSizePx: itemsMode >= 1 ? 24 : 12,
      footerSizePx: footerMode >= 1 ? 24 : 12,
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

    // Header & footer teks custom (header di-gambar, footer di-teks).
    final headerText = header ?? await SecureStore.getReceiptHeader() ?? '';
    final footerText = footer ?? _footerText;

    // Mode teks rincian/footer: 0 = Kecil (×1), 1 = Besar (×2).
    final itemsMode = await SecureStore.getReceiptFontItems();
    final footerMode = await SecureStore.getReceiptFontFooter();

    final List<int> bytes = [];
    // ESC @ Reset: bersihkan state printer (bit-image mode sebelumnya dll).
    bytes.addAll(generator.reset());

    // ── Bagian ATAS (logo + header) = GAMBAR (ESC * bit-image) ──
    // Ukuran diatur PERSEN dari lebar kertas (1-100) — printer cuma
    // menggambar piksel, jadi ukuran header/logo PASTI tercetak sesuai
    // slider, di printer termal murah apa pun.
    final headerCfg = ReceiptRenderConfig(
      storeName: storeName,
      lines: const [],
      total: 0,
      paperWidth: paperWidth,
      header: headerText,
      footer: '',
      logoBytes: logo,
      showLogo: showLogo ?? true,
    );
    try {
      final headerPng = await renderReceiptHeaderPng(headerCfg);
      final headerImage = img.decodeImage(headerPng);
      if (headerImage != null) {
        bytes.addAll(generator.image(headerImage, align: PosAlign.center));
        bytes.addAll(generator.reset());
      }
    } catch (_) {
      // Header gagal dirender → lewati, struk teks tetap jalan.
    }

    // ── Bagian TENGAH & BAWAH (info, rincian, TOTAL, footer) = TEKS ──
    // Teks ESC/POS biasa → print CEPAT. Mode Kecil(×1)/Besar(×2) dijamin
    // selalu tercetak di printer murah (×3+ tidak dipakai).
    void text(String t, {PosTextSize size = PosTextSize.size1}) {
      bytes.addAll(
        generator.text(
          t,
          styles: PosStyles(height: size, width: size),
        ),
      );
    }

    text('');
    if (invoice.isNotEmpty) text(invoice);
    if (dateStr.isNotEmpty) text(dateStr);
    text('');
    if (cashierName != null && cashierName.isNotEmpty) {
      text('Kasir: $cashierName');
    }
    if (customerName != null && customerName.isNotEmpty) {
      text('Pelanggan: $customerName');
    }
    if (orderType != null && orderType.isNotEmpty) {
      final label = tableName != null && tableName.isNotEmpty
          ? '$orderType - $tableName'
          : orderType;
      text(label);
    }
    bytes.addAll(generator.text('--------------------------------', styles: const PosStyles()));

    final itemsSize = itemsMode >= 1 ? PosTextSize.size2 : PosTextSize.size1;
    final smallSize = PosTextSize.size1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      text(line.name, size: itemsSize);
      final qtyTxt = '${line.qty} x ${_fmt(line.price)}';
      final discSuffix = line.hasDiscount
          ? '( -${_fmt(line.discountTotal)} ) '
          : '';
      final subtotalTxt = '${discSuffix}${_fmt(line.subtotal)}';
      // Baris qty × harga di kiri, subtotal di kanan — rata kanan penuh.
      final note = (itemNotes != null && i < itemNotes.length)
          ? itemNotes[i]
          : null;
      if (note != null && note.isNotEmpty) {
        text('  > $note', size: smallSize);
      }
      text('$qtyTxt', size: smallSize);
      text(subtotalTxt, size: smallSize);
    }
    bytes.addAll(generator.text('--------------------------------', styles: const PosStyles()));

    text('TOTAL', size: PosTextSize.size2);
    text(_fmt(total), size: PosTextSize.size2);
    if (discount > 0) {
      text('Diskon -${_fmt(discount)}', size: smallSize);
    }
    if (downPayment > 0) {
      text('Bayar (${paymentMethod ?? ''}) ${_fmt(downPayment)}', size: smallSize);
      text('Sisa Piutang ${_fmt(remainingDue)}', size: smallSize);
    } else if (paymentMethod != null && paymentMethod.isNotEmpty) {
      text('Bayar (${paymentMethod}) ${_fmt(cashGiven ?? total)}', size: smallSize);
    }
    if (cashReturn != null && cashReturn > 0 && downPayment <= 0) {
      text('Kembali ${_fmt(cashReturn)}', size: smallSize);
    }
    bytes.addAll(generator.text('--------------------------------', styles: const PosStyles()));

    if (footerText.isNotEmpty) {
      text(footerText, size: footerMode >= 1 ? PosTextSize.size2 : PosTextSize.size1);
    }
    text(storeName, size: smallSize);

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
      headerPercent: 24,
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

  /// Format angka jadi "Rp1.234" ringkas untuk teks struk.
  static String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer('Rp');
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  /// Print a TEST KALIBRASI — header (image) sesuai persen, lalu baris
  /// rincian Kecil(×1)/Besar(×2) dan footer Kecil/Besar, plus garis ukuran
  /// penuh supaya user langsung melihat ukuran di kertas.
  Future<bool> printTest(
    String storeName, {
    String paperWidth = '58',
    int headerPercent = 100,
    int itemsMode = 0,
    int footerMode = 0,
    Uint8List? logo,
    bool showLogo = true,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];
    bytes.addAll(generator.reset());

    // Header sebagai GAMBAR (bit-image) — seperti print struk asli.
    final headerCfg = ReceiptRenderConfig(
      storeName: storeName,
      lines: const [],
      total: 0,
      paperWidth: paperWidth,
      header: '',
      footer: '',
      logoBytes: logo,
      showLogo: showLogo,
    );
    try {
      final headerPng = await renderReceiptHeaderPng(headerCfg);
      final headerImage = img.decodeImage(headerPng);
      if (headerImage != null) {
        bytes.addAll(generator.image(headerImage, align: PosAlign.center));
        bytes.addAll(generator.reset());
      }
    } catch (_) {}

    void text(String t, {PosTextSize size = PosTextSize.size1}) {
      bytes.addAll(
        generator.text(
          t,
          styles: PosStyles(height: size, width: size),
        ),
      );
    }

    text('');
    text('= TEST KALIBRASI =');
    text('Header: ${headerPercent}%');
    text('Rincian: ${itemsMode >= 1 ? 'BESAR' : 'kecil'}');
    text('Footer: ${footerMode >= 1 ? 'BESAR' : 'kecil'}');
    bytes.addAll(generator.text('--------------------------------', styles: const PosStyles()));
    text('Baris rincian KECIL (x1)', size: PosTextSize.size1);
    text('Baris rincian BESAR (x2)', size: PosTextSize.size2);
    bytes.addAll(generator.text('--------------------------------', styles: const PosStyles()));
    text('Footer KECIL (x1)', size: PosTextSize.size1);
    text('Footer BESAR (x2)', size: PosTextSize.size2);
    bytes.addAll(generator.text('--------------------------------', styles: const PosStyles()));
    text('Jika garis penuh terpotong,', size: PosTextSize.size1);
    text('pilih kertas 80mm di pengaturan.', size: PosTextSize.size1);

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
