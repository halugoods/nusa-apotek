import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/receipt_header_renderer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// A single line item on a receipt.
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

  /// Subtotal KOTOR (sebelum diskon item) — dipakai struk supaya harga yang
  /// dicetak adalah harga ASLI, bukan harga yang sudah dipotong diskon.
  int get grossSubtotal => qty * (originalPrice ?? price);

  /// Potongan diskon item TOTAL untuk semua qty (per unit × qty).
  int get discountTotal => hasDiscount ? discountNominal * qty : 0;
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

/// ESC/POS perbesaran 1-8 → PosTextSize (class dengan static const, bukan
/// enum — jadi tidak punya `.values`; mapping manual 1:1).
PosTextSize _posSize(int v) => switch (v.clamp(1, 8)) {
  1 => PosTextSize.size1,
  2 => PosTextSize.size2,
  3 => PosTextSize.size3,
  4 => PosTextSize.size4,
  5 => PosTextSize.size5,
  6 => PosTextSize.size6,
  7 => PosTextSize.size7,
  _ => PosTextSize.size8,
};

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
    // Default 60 = ukuran statis yang sama seperti yang pernah diatur
    // user (default bawa) — tidak diubah-ubah dari pengaturan struk.
    int logoWidthPercent = 60,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    // ── Font settings (per section, dari Pengaturan Struk) ──
    // Jenis font: 'standar' = Font A (universal — DEFAULT; printer clone
    // murah seperti VSC merender Font B kosong/garbled, jadi Standar dipakai
    // supaya rincian selalu muncul), 'kompak' = Font B (huruf ramping).
    // Ukuran rincian & footer: 1 = Kecil (×1), 2 = Besar (×2). Header
    // memakai ukuran PIXEL image (nusa_receipt_header_px, 12–48px).
    final fontType = await SecureStore.getReceiptFontType();
    final headerPx = await SecureStore.getReceiptHeaderPx();
    final headerWeight = await SecureStore.getReceiptHeaderWeight();
    // Rincian & footer SELALU ukuran kecil (×1) — user minta satu ukuran saja
    // (v2.2.27+): "rincian sm footer gausah di kasih 2 ukuran deh 1 ukuran aja
    // pke yg kecil". Key lama (fontItems/fontFooter) tidak lagi dibaca.
    // Jenis font satu untuk seluruh struk (global) — pilihan per bagian
    // dihapus di v2.2.21 supaya pengaturan sederhana (1 pilihan font saja).
    final useFontB = fontType == 'kompak';
    // Font global dipakai untuk semua baris struk (rincian, footer,
    // invoice, kasir, payment, "Terima Kasih!").
    final itemFont = useFontB ? PosFontType.fontB : PosFontType.fontA;
    final useItemsFontB = itemFont == PosFontType.fontB;

    // Header struk custom (Teks Header di Pengaturan Struk). Kosong →
    // fallback ke nama toko — SAMA persis perilaku preview di settings.
    final customHeader = await SecureStore.getReceiptHeader();
    final headerText = (customHeader != null && customHeader.trim().isNotEmpty)
        ? customHeader.trim()
        : storeName;

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
          // Lebar logo = PERSEN dari lebar kertas (default 60% — ukuran
          // statis yang sama seperti yang pernah diatur user).
          final pct = logoWidthPercent.clamp(1, 100) / 100;
          final maxWidth = ((paperWidth == '80' ? 320 : 160) * pct).round();
          // Cap BOTH dimensions: raster height is limited by the printer's
          // bit-image buffer (~3 bytes/column); a tall logo would otherwise
          // be cut off or produce garbage. Proportional resize keeps the
          // aspect ratio.
          final maxHeight = paperWidth == '80' ? 160 : 96;
          var resized = logoImage;
          if (logoImage.width > maxWidth || logoImage.height > maxHeight) {
            final scale = (maxWidth / logoImage.width).clamp(0.0, 1.0);
            final hScale = maxHeight / logoImage.height;
            final s = scale < hScale ? scale : hScale;
            resized = img.copyResize(
              logoImage,
              width: (logoImage.width * s).round(),
              height: (logoImage.height * s).round(),
            );
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

    // ── HEADER — nama toko / header custom sebagai IMAGE (bit-image ESC *) ──
    // HANYA nama toko/header custom yang dirender image (besar, sesuai slider
    // 12–48px). Invoice, tanggal, kasir, pelanggan, tipe pesanan TIDAK ikut
    // image — dicetak sebagai teks ESC/POS biasa (cepat, tidak perbesar
    // waktu print, ukuran huruf normal). Preview memakai renderer sama.
    try {
      final headerPng = await renderReceiptHeaderPng(
        paperWidth: paperWidth,
        storeName: storeName,
        customHeader: customHeader ?? '',
        headerPx: headerPx,
        headerWeight: headerWeight,
      );
      final headerImage = img.decodeImage(headerPng);
      if (headerImage != null) {
        bytes.addAll(generator.image(headerImage, align: PosAlign.center));
        bytes.addAll(generator.feed(1));
        // Keluar dari bit-image mode sebelum teks rincian.
        bytes.addAll(generator.reset());
      }
    } catch (_) {
      // Render header gagal → cetak nama toko sebagai teks biasa supaya
      // struk tetap jalan.
      bytes.addAll(
        generator.text(
          _san(headerText),
          styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            fontType: itemFont,
          ),
        ),
      );
    }

    // ── INFO HEADER — teks ESC/POS (bukan image): invoice, tanggal, kasir ──
    // User: "invoice tgl kasir jgn image ya" — dipindah dari header image ke
    // teks supaya print cepat & huruf normal (tidak ikut slider besar).
    final isWide = paperWidth == '80';
    final infoLineWidth = isWide ? (useItemsFontB ? 64 : 48) : (useItemsFontB ? 42 : 32);
    void infoText(String t, {bool bold = false, PosAlign align = PosAlign.center}) {
      if (t.trim().isEmpty) return;
      for (final part in _wrap(t, infoLineWidth)) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: PosStyles(
              align: align,
              bold: bold,
              fontType: itemFont,
            ),
          ),
        );
      }
    }
    if (invoice.isNotEmpty) infoText(invoice, bold: true);
    if (dateStr.isNotEmpty) infoText(dateStr);
    if (cashierName != null && cashierName.isNotEmpty) {
      infoText('Kasir: $cashierName', align: PosAlign.left);
    }
    if (customerName != null && customerName.isNotEmpty) {
      infoText('Pelanggan: $customerName', align: PosAlign.left);
    }
    if (orderType != null && orderType.isNotEmpty) {
      final label = tableName != null && tableName.isNotEmpty
          ? '$orderType - $tableName'
          : orderType;
      infoText(label, bold: true);
    }

    // Line items — manual text formatting for precise wrapping.
    // generator.row()+PosColumn internally clips text; generator.text() doesn't.
    //
    // Jenis font per section menentukan lebar baris:
    //   Standar (Font A): 58mm → 32 char, 80mm → 48 char  (universal)
    //   Kompak  (Font B): 58mm → 42 char, 80mm → 64 char  (ramping)
    // Default = Standar: printer clone murah (VSC dkk) merender Font B
    // kosong/garbled, sehingga rincian hilang. Standar selalu muncul.
    final itemBaseLineWidth = isWide
        ? (useItemsFontB ? 64 : 48)
        : (useItemsFontB ? 42 : 32);
    // Ukuran rincian SELALU Kecil (×1) — pilihan Besar dihapus v2.2.27.
    final itemMag = 1;
    final itemStyles = PosStyles(
      align: PosAlign.left,
      fontType: itemFont,
      height: _posSize(itemMag),
      width: _posSize(itemMag),
    );
    // Lebar rincian: rincian selalu ×1 → lebar penuh baris.
    final itemLineWidth = itemBaseLineWidth;
    final qtyPriceWidth = useItemsFontB ? 14 : 12; // "2xRp10.000" max
    final subWidth = useItemsFontB ? 11 : 10; // "Rp20.000" max
    // ── NAMA ITEM PAKAI LEBAR PENUH KERTAS ──
    // Sebelumnya nama di-squeeze ke sisa setelah qty×harga + subtotal
    // (58mm Font A → hanya 8 karakter → "enter2 kebawah" dengan ~15 char).
    // Komplain user: "menu item harus hbisin margin kertas dulu baru enter
    // kebawah". Baris nama full width; qty×harga + subtotal baris sendiri.
    final nameWidth = itemLineWidth;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final nameParts = _wrap(line.name, nameWidth);
      // Harga per unit = harga ASLI SEBELUM diskon (originalPrice) — diskon
      // ditampilkan sebagai "( -Rp X )" di sampingnya. User minta struk
      // menunjukkan: qty × harga asli − diskon (kurung) − subtotal NETTO.
      // (Sebelum v2.2.27 tampil harga FINAL — itu salah.)
      final unitPrice = line.originalPrice ?? line.price;
      final qtyPrice = _fit(
        '${line.qty}x${formatRupiah(unitPrice)}',
        qtyPriceWidth,
      );
      // Subtotal yang ditampilkan = NETTO (qty × harga FINAL) — subtotal
      // sudah berkurang diskon, konsisten dengan TOTAL.
      final subtotal = _fit(
        formatRupiah(line.subtotal),
        subWidth,
      );

      // Baris 1: nama item (wrap). Nama sendiri — tidak digabung dengan qty.
      for (final part in nameParts) {
        bytes.addAll(generator.text(_san(part), styles: itemStyles));
      }

      // Diskon item per produk — kurung "( -Rp X )" setelah harga asli,
      // SEBELUM subtotal: urutan = qty × harga ASLI lalu diskon (kurung)
      // lalu subtotal NETTO. User minta urutan ini biar notice potongannya.
      final discSuffix = line.hasDiscount
          ? '( -${formatRupiah(line.discountTotal)} )'
          : '';

      // Rincian SELALU ukuran kecil (×1) — satu baris = qty x harga asli di
      // KIRI, lalu diskon (kurung), lalu subtotal NETTO di KANAN (v2.2.27).
      final totalRight = '$discSuffix $subtotal'.trim();
      final gap = itemLineWidth - qtyPrice.length - totalRight.length;
      final line2 = gap >= 3
          ? '$qtyPrice${' ' * (gap - 2)}  $totalRight'
          : '$qtyPrice  $totalRight';
      bytes.addAll(generator.text(_san(line2), styles: itemStyles));

      // Item notes
      if (itemNotes != null &&
          i < itemNotes.length &&
          itemNotes[i] != null &&
          itemNotes[i]!.isNotEmpty) {
        final noteParts = _wrap('  > ${itemNotes[i]!}', itemLineWidth - 2);
        for (final part in noteParts) {
          bytes.addAll(generator.text(_san(part), styles: itemStyles));
        }
      }
    }
    bytes.addAll(generator.hr());

    // Total. Rincian selalu ×1 — tidak perlu jarak ekstra.
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'TOTAL',
          width: isWide ? 8 : 6,
          styles: PosStyles(
            bold: true,
            height: PosTextSize.size2,
            fontType: itemFont,
          ),
        ),
        PosColumn(
          text: _fit(formatRupiah(total), isWide ? 16 : 11),
          width: isWide ? 8 : 6,
          styles: PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
            fontType: itemFont,
          ),
        ),
      ]),
    );

    // ── ANDA HEMAT — total diskon (item + transaksi) tepat di bawah TOTAL ──
    // User: "di total itu bawahnya harus ada anda hemat brp diskonnya jd biar
    // di notice sm pembeli". Hitung total potongan item (originalPrice vs
    // price × qty) + diskon transaksi, cetak bold supaya menonjol.
    final itemDiscTotal = lines.fold<int>(
      0,
      (acc, l) =>
          acc + (l.hasDiscount ? (l.originalPrice! - l.price) * l.qty : 0),
    );
    final andaHemat = itemDiscTotal + discount;
    if (andaHemat > 0) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'Anda Hemat',
            width: isWide ? 8 : 6,
            styles: PosStyles(bold: true, fontType: itemFont),
          ),
          PosColumn(
            text: _fit('-${formatRupiah(andaHemat)}', isWide ? 16 : 11),
            width: isWide ? 8 : 6,
            styles: PosStyles(
              bold: true,
              align: PosAlign.right,
              fontType: itemFont,
            ),
          ),
        ]),
      );
    }

    // Total diskon — baris sendiri TEPAT DI BAWAH TOTAL (komplain user:
    // "total diskon di total bawah"). Diskon item sudah dicetak per item
    // ("Diskon: -Rp X" di bawah tiap item) — baris ini hanya diskon
    // TRANSAKSI (promo/manual/tier/poin) supaya tidak dobel hitung.
    if (discount > 0) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'Diskon',
            width: isWide ? 8 : 6,
            styles: PosStyles(fontType: itemFont),
          ),
          PosColumn(
            text: _fit('-${formatRupiah(discount)}', isWide ? 16 : 11),
            width: isWide ? 8 : 6,
            styles: PosStyles(align: PosAlign.right, fontType: itemFont),
          ),
        ]),
      );
    }

    // Payment details. When DP is active, show uang muka + sisa piutang
    // instead of the generic Bayar line (cashGiven holds the DP amount).
    if (downPayment > 0) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'Bayar ($paymentMethod)',
            width: isWide ? 8 : 6,
            styles: PosStyles(fontType: itemFont),
          ),
          PosColumn(
            text: _fit(formatRupiah(downPayment), isWide ? 16 : 11),
            width: isWide ? 8 : 6,
            styles: PosStyles(align: PosAlign.right, fontType: itemFont),
          ),
        ]),
      );
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'Sisa Piutang',
            width: isWide ? 8 : 6,
            styles: PosStyles(fontType: itemFont),
          ),
          PosColumn(
            text: _fit(formatRupiah(remainingDue), isWide ? 16 : 11),
            width: isWide ? 8 : 6,
            styles: PosStyles(align: PosAlign.right, fontType: itemFont),
          ),
        ]),
      );
    } else if (paymentMethod != null && paymentMethod.isNotEmpty) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'Bayar ($paymentMethod)',
            width: isWide ? 8 : 6,
            styles: PosStyles(fontType: itemFont),
          ),
          PosColumn(
            text: _fit(formatRupiah(cashGiven ?? total), isWide ? 16 : 11),
            width: isWide ? 8 : 6,
            styles: PosStyles(align: PosAlign.right, fontType: itemFont),
          ),
        ]),
      );
    }
    if (cashReturn != null && cashReturn > 0 && downPayment <= 0) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'Kembali',
            width: isWide ? 8 : 6,
            styles: PosStyles(fontType: itemFont),
          ),
          PosColumn(
            text: _fit(formatRupiah(cashReturn), isWide ? 16 : 11),
            width: isWide ? 8 : 6,
            styles: PosStyles(align: PosAlign.right, fontType: itemFont),
          ),
        ]),
      );
    }

    bytes.addAll(generator.hr());

    // Footer — wrap long text. Ukuran SELALU Kecil (×1) — v2.2.27.
    final footerText = footer ?? _footerText;
    if (footerText.isNotEmpty) {
      final footerMag = 1;
      final footerBase = isWide
          ? (useItemsFontB ? 64 : 48)
          : (useItemsFontB ? 42 : 32);
      // Lebar footer = lebar baris ÷ perbesaran (rincian 2x → setengah).
      final footerLineChars = (footerBase ~/ footerMag).clamp(4, 40);
      final footerParts = _wrap(footerText, footerLineChars);
      for (final part in footerParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: PosStyles(
              align: PosAlign.center,
              fontType: itemFont,
              height: _posSize(footerMag),
              width: _posSize(footerMag),
            ),
          ),
        );
      }
      // Footer besar butuh jarak sebelum "Terima Kasih!" agar tidak nempel.
      if (footerMag > 1) {
        bytes.addAll(generator.feed(1));
      }
    }
    bytes.addAll(
      generator.text(
        _san('Terima Kasih!'),
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          fontType: itemFont,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        _san(storeName),
        styles: PosStyles(align: PosAlign.center, fontType: itemFont),
      ),
    );
    bytes.addAll(generator.feed(2));
    // Kembalikan ke Font A — printer clone murah TIDAK mereset Font B sendiri
    // (mereka abaikan ESC M 1 → state macet). Jaga printer selalu di Font A
    // agar cetakan berikutnya tidak berubah font.
    bytes.addAll(
      generator.text(
        '',
        styles: PosStyles(fontType: PosFontType.fontA),
      ),
    );
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

  /// Print a simple test receipt (v2.2.11 style — bukan kalibrasi 5 ukuran).
  /// Kalibrasi dihapus: pilihan ukuran kembali ke 2 (Kecil/Besar) + header
  /// image slider, jadi tes cukup memastikan printer jalan + kertas benar.
  Future<bool> printTest(
    String storeName, {
    String paperWidth = '58',
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        _san('TEST PRINT'),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        _san(storeName),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        _san('Printer thermal berfungsi dengan baik.'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _san('Kertas: ${paperWidth}mm'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    final now = DateTime.now();
    bytes.addAll(
      generator.text(
        _san(
          '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}',
        ),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        _san('NUSA Kasir'),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
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
