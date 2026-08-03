import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;

import 'package:nusa_kasir/core/utils/format_rupiah.dart';

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
  });
}

/// Utility for discovering, connecting to and printing receipts on a
/// Bluetooth thermal (ESC/POS) printer.
///
/// Backed by `esc_pos_bluetooth` + `esc_pos_utils`.
///
/// Future: WiFi/Ethernet/USB printer support via `esc_pos_printer` package.
class ReceiptPrinter {
  final PrinterBluetoothManager _manager = PrinterBluetoothManager();

  final Map<String, PrinterBluetooth> _discovered = {};
  PrinterBluetooth? _selected;
  StreamSubscription<List<PrinterBluetooth>>? _scanSubscription;

  /// Cache the last print for one-tap reprint.
  static LastPrintParams? lastPrint;

  // ── Printer settings (persisted via SecureStore) ──
  static Uint8List? _logoBytes;
  static String _footerText = '';
  static bool _cashDrawerEnabled = false;
  static int _cashDrawerPin = 2; // default: pin 2 (common on most printers)

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

  /// Set custom footer text (e.g. "Jam operasional: 08:00–22:00").
  static void setFooter(String text) => _footerText = text;

  /// Enable/disable cash drawer auto-open after print.
  static void setCashDrawer({required bool enabled, int pin = 2}) {
    _cashDrawerEnabled = enabled;
    _cashDrawerPin = pin;
  }

  /// Scan for paired/classic Bluetooth thermal printers and return them.
  ///
  /// Returns an empty list if no printers are found or scanning fails.
  Future<List<PrinterDevice>> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _discovered.clear();
    final devices = <PrinterDevice>[];

    _scanSubscription = _manager.scanResults.listen((printers) {
      for (final printer in printers) {
        final address = printer.address;
        if (address == null || address.isEmpty) continue;
        if (_discovered.containsKey(address)) continue;
        _discovered[address] = printer;
        devices.add(
          PrinterDevice(
            name: printer.name?.isNotEmpty == true ? printer.name! : 'Printer',
            address: address,
          ),
        );
      }
    });

    _manager.startScan(timeout);
    // Give the scan time to complete, then stop it.
    await Future<void>.delayed(timeout + const Duration(seconds: 1));
    await _stopScan();

    return List<PrinterDevice>.unmodifiable(devices);
  }

  /// Connect to a printer previously returned by [discover], by address.
  Future<void> connect(PrinterDevice device) async {
    final printer = _discovered[device.address];
    if (printer == null) {
      throw StateError(
        'Printer ${device.address} was not discovered. '
        'Call discover() before connect().',
      );
    }
    _manager.selectPrinter(printer);
    _selected = printer;
  }

  /// Build the ESC/POS bytes for a receipt and send them to the connected
  /// printer. Returns `true` if the print job completed successfully.
  ///
  /// After a successful print the parameters are cached in [lastPrint]
  /// so that [printLastReceipt] can reprint without re-entering data.
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
  }) async {
    if (_selected == null) {
      return false;
    }

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];

    // ── Logo ──
    final logoBytes = logo ?? _logoBytes;
    if (logoBytes != null) {
      try {
        final logoImage = img.decodeImage(logoBytes);
        if (logoImage != null) {
          bytes.addAll(generator.imageRaster(logoImage, align: PosAlign.center));
          bytes.addAll(generator.feed(1));
        }
      } catch (_) {
        // Skip logo if decode fails
      }
    }

    // Header.
    bytes.addAll(generator.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    ));
    if (invoice.isNotEmpty) {
      bytes.addAll(generator.text(invoice,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (dateStr.isNotEmpty) {
      bytes.addAll(generator.text(dateStr,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (cashierName != null && cashierName.isNotEmpty) {
      bytes.addAll(generator.text('Kasir: $cashierName'));
    }
    if (customerName != null && customerName.isNotEmpty) {
      bytes.addAll(generator.text('Pelanggan: $customerName'));
    }
    bytes.addAll(generator.hr());

    // Line items: name | qty x price | subtotal.
    for (final line in lines) {
      bytes.addAll(generator.row([
        PosColumn(
          text: line.name,
          width: paperWidth == '80' ? 7 : 5,
        ),
        PosColumn(
          text: '${line.qty} x ${formatRupiah(line.price)}',
          width: paperWidth == '80' ? 5 : 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: formatRupiah(line.subtotal),
          width: paperWidth == '80' ? 4 : 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());

    // Discount.
    if (discount > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Diskon', width: paperWidth == '80' ? 8 : 6),
        PosColumn(
          text: '-${formatRupiah(discount)}',
          width: paperWidth == '80' ? 8 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    // Total.
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: paperWidth == '80' ? 8 : 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: formatRupiah(total),
        width: paperWidth == '80' ? 8 : 6,
        styles: const PosStyles(
            bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]));

    // Payment details.
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      bytes.addAll(generator.row([
        PosColumn(
            text: 'Bayar ($paymentMethod)',
            width: paperWidth == '80' ? 8 : 6),
        PosColumn(
          text: formatRupiah(cashGiven ?? total),
          width: paperWidth == '80' ? 8 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    if (cashReturn != null && cashReturn > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Kembali', width: paperWidth == '80' ? 8 : 6),
        PosColumn(
          text: formatRupiah(cashReturn),
          width: paperWidth == '80' ? 8 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());

    // Footer.
    final footerText = footer ?? _footerText;
    if (footerText.isNotEmpty) {
      bytes.addAll(generator.text(
        footerText,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    bytes.addAll(generator.text(
      'Terima Kasih!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    // ── Cash drawer trigger ──
    if (openDrawer || _cashDrawerEnabled) {
      final pin = _cashDrawerPin == 2 ? PosDrawer.pin2 : PosDrawer.pin5;
      bytes.addAll(generator.drawer(pin: pin));
    }

    final result = await _manager.printTicket(bytes);

    if (result == PosPrintResult.success) {
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
      );
    }

    return result == PosPrintResult.success;
  }

  /// Reprint the last receipt (if available).
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
    );
  }

  /// Open cash drawer only (no print).
  Future<bool> openDrawer({int pin = 2}) async {
    if (_selected == null) return false;
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = generator.drawer(
        pin: pin == 2 ? PosDrawer.pin2 : PosDrawer.pin5,
      );
      final result = await _manager.printTicket(bytes);
      return result == PosPrintResult.success;
    } catch (_) {
      return false;
    }
  }

  /// Print a test receipt to verify the printer is working.
  Future<bool> printTest(String storeName, {String paperWidth = '58'}) async {
    if (_selected == null) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];
    bytes.addAll(generator.text('TEST PRINT',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Printer thermal berfungsi dengan baik.',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Kertas: ${paperWidth}mm',
        styles: const PosStyles(align: PosAlign.center)));
    final now = DateTime.now();
    bytes.addAll(generator.text(
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('NUSA Kasir',
        styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    final result = await _manager.printTicket(bytes);
    return result == PosPrintResult.success;
  }

  /// Quick check if a printer is currently selected/connected.
  bool get isConnected => _selected != null;

  /// Disconnect and release any active scan subscription.
  Future<void> dispose() async {
    await _stopScan();
    _selected = null;
    _discovered.clear();
  }

  Future<void> _stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _manager.stopScan();
  }
}
