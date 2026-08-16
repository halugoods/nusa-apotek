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

/// Ukuran font struk → perbesaran ESC/POS + lebar karakter nyata per baris.
///
/// Prinsip: printer termal mencetak Font A ~12pt @1x, ~24pt @2x (height ×2
/// juga melebar ×2). Jadi ukuran huruf sebenarnya = LITERAL pt, dan lebar
/// baris = LEBAR KERTAS (mm) ÷ lebar karakter, BUKAN lebar karakter dibagi
/// perbesaran. Karakter per baris dihitung dari ukuran huruf yang
/// benar-benar dicetak — bukan kebalikannya (ini yang bikin wrap salah &
/// "Halu Goo\nds").
///
/// Karakter per baris per lebar kertas (Font A, ASC, ~12pt):
///   - 58mm → 32 char @1x, 16 @2x, 8 @4x, 6 @6x, 4 @8x
///   - 80mm → 48 char @1x, 24 @2x, 12 @4x, 8 @6x, 6 @8x
/// Font B ~1.15× lebih ramping (58mm → 42 @1x; 80mm → 64 @1x).
///
/// 5 ukuran literal — termasuk 15pt sebagai "ukuran tengah":
///   - 12pt = Font A ×1 (32 char/baris 58mm)
///   - 15pt = Font B ×2 (21 char/baris 58mm) — LEBIH BESAR dari 12pt tapi
///     lebih ramping dari 18pt (18×34 dot vs 24×48 dot). Dipakai header
///     "Jatibarang Helmet" (17 karakter) yang tidak muat di 18pt.
///   - 18pt = Font A ×2 (16 char/baris 58mm)
///   - 24pt = Font A ×3 (12 char/baris 58mm)
///   - 36pt = Font A ×4 (8 char/baris 58mm)
/// Perbesaran ESC/POS harus bilangan bulat — 15pt BUKAN "perbesaran 1.25",
/// melainkan kombinasi Font B ×2 yang secara fisik berada di antara 12 & 18.
const _literalSizes = [12, 15, 18, 24, 36];

/// Ukuran literal yang tersedia — publik supaya UI (Pengaturan Struk)
/// bisa render 5 pilihan tanpa tahu detail internal.
const List<int> literalSizes = _literalSizes;

/// Ukuran literal → perbesaran + jenis font yang direkomendasikan.
///
/// `mag` selalu 1-5 (indeks literal + 1). `fontB` benar hanya untuk 15pt —
/// ukuran lain memakai Font A (ramping di semua baris).
(int mag, bool fontB) literalSpec(int literal) {
  final idx = _literalSizes.indexOf(literal);
  if (idx < 0) {
    final mag = literal.clamp(1, 5);
    return (mag, false);
  }
  return (idx + 1, literal == 15);
}

int literalToMagnification(int literal) {
  final idx = _literalSizes.indexOf(literal);
  return idx < 0 ? (literal.clamp(1, 5)) : idx + 1;
}

int magnificationToLiteral(int mag) {
  final m = mag.clamp(1, 5);
  return _literalSizes[m - 1];
}

/// Ukuran font PREVIEW (px) yang match hasil cetak.
///
/// - 12/18/24/36 pt: ukuran literal × faktor font global (Font B/Kompak
///   lebih ramping → dikali 0.75).
/// - 15 pt: dicetak Font B ×2 (18×34 dot, ukuran FIX tidak tergantung font
///   global) — preview 15px apa adanya, TIDAK dikali faktor kompak (kalau
///   dikali malah lebih kecil dari 12pt, kontradiksi).
double receiptPreviewSize(int literal, {bool kompak = false}) =>
    literal == 15 ? 15.0 : literal * (kompak ? 0.75 : 1.0);

/// Label ukuran literal — dipakai di UI Pengaturan Struk.
String literalSizeLabel(int literal) => switch (literal) {
  12 => 'Kecil',
  15 => 'Sedang',
  18 => 'Normal',
  24 => 'Besar',
  _ => 'Extra Besar',
};

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
/// Struk dicetak sebagai TEKS ESC/POS biasa (cepat) dengan ukuran literal
/// 12/15/18/24/36 pt — kertas 58/80mm dibagi ukuran huruf menentukan jumlah
/// karakter per baris. Logo dicetak sebagai bit-image ESC * dengan lebar
/// PERSEN dari lebar kertas (default 60% — ukuran statis).
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
    // Ukuran per section adalah perbesaran ESC/POS: header 1/2/3 (Kecil/
    // Normal/Besar), rincian 1/2, footer 1/2.
    final fontType = await SecureStore.getReceiptFontType();
    final headerSize = await SecureStore.getReceiptFontHeader();
    final itemsSize = await SecureStore.getReceiptFontItems();
    final footerSize = await SecureStore.getReceiptFontFooter();
    // Jenis font satu untuk seluruh struk (global) — pilihan per bagian
    // dihapus di v2.2.21 supaya pengaturan sederhana (1 pilihan font saja).
    final useFontB = fontType == 'kompak';
    // Font global dipakai untuk semua baris struk (header, rincian, footer,
    // invoice, kasir, payment, "Terima Kasih!").
    final itemFont = useFontB ? PosFontType.fontB : PosFontType.fontA;
    final useItemsFontB = itemFont == PosFontType.fontB;

    // Header struk custom (Teks Header di Pengaturan Struk). Kosong →
    // fallback ke nama toko — SAMA persis perilaku preview di settings.
    // Sebelumnya printer SELALU mencetak storeName → teks header custom
    // tidak pernah tercetak (komplain user: "header gabisa dibesarin").
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

    // Header — teks header custom (atau nama toko jika kosong). Ukuran dari
    // Pengaturan Struk: nilai literal 12/15/18/24/36 → perbesaran 1x-5x.
    //
    // Ukuran besar (GS !) memangkas jumlah karakter per baris: di 58mm,
    // perbesaran N → ~32/N karakter. Ukuran selalu dicetak APA ADANYA (tanpa
    // cap): preview dan print selalu 5 ukuran berbeda (12/15/18/24/36).
    //
    // 15pt = "ukuran tengah" (Font B ×2 — 21 char/baris di 58mm): dipakai
    // header seperti "Jatibarang Helmet" (17 karakter) yang tidak muat di
    // 18pt (16 char/baris) tapi 12pt terlalu kecil.
    final hSpec = literalSpec(headerSize);
    final headerMag = hSpec.$1.clamp(1, 5);
    // Font yang dipakai untuk mencetak ukuran ini: 15pt WAJIB Font B ×2
    // (18×34 dot — secara fisik antara 12pt dan 18pt). Bila user memilih
    // Font Standar, cetak Font A ×2 (18pt) sebagai gantinya — printer tidak
    // bisa mencetak 15pt dengan Font A (perbesaran harus bilangan bulat).
    final hFont = hSpec.$2 ? PosFontType.fontB : itemFont;
    final isWideHeader = paperWidth == '80';
    // Lebar header = LEBAR KERTAS ÷ perbesaran: 58mm → 32/N, 80mm → 48/N
    // (Font B ramping: 42/N & 64/N). Ukuran huruf = perbesaran × 12pt literal.
    final headerBaseLineWidth = isWideHeader
        ? (hFont == PosFontType.fontB ? 64 : 48)
        : (hFont == PosFontType.fontB ? 42 : 32);
    final headerLineChars = (headerBaseLineWidth ~/ headerMag).clamp(4, 40);
    final headerParts = _wrap(headerText, headerLineChars);
    final headerHeight = _posSize(headerMag);
    for (final part in headerParts) {
      bytes.addAll(
        generator.text(
          _san(part),
          styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            height: headerHeight,
            width: headerHeight,
            fontType: hFont,
          ),
        ),
      );
    }
    // Feed proporsional: header besar (>2x) butuh jarak agar tidak nempel
    // dengan baris invoice/kasir berikutnya (kadang malah terlihat "kecil"
    // karena tumpang tindih dengan baris berikut).
    if (headerMag > 2) {
      bytes.addAll(generator.feed(headerMag >= 4 ? 2 : 1));
    }
    if (invoice.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _san(invoice),
          styles: PosStyles(align: PosAlign.center, fontType: itemFont),
        ),
      );
    }
    if (dateStr.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _san(dateStr),
          styles: PosStyles(align: PosAlign.center, fontType: itemFont),
        ),
      );
    }
    final isWide = paperWidth == '80';
    if (cashierName != null && cashierName.isNotEmpty) {
      final csrParts = _wrap('Kasir: $cashierName', isWide ? 30 : 24);
      for (final part in csrParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: PosStyles(align: PosAlign.left, fontType: itemFont),
          ),
        );
      }
    }
    if (customerName != null && customerName.isNotEmpty) {
      final custParts = _wrap('Pelanggan: $customerName', isWide ? 30 : 24);
      for (final part in custParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: PosStyles(align: PosAlign.left, fontType: itemFont),
          ),
        );
      }
    }
    if (orderType != null && orderType.isNotEmpty) {
      String line = orderType;
      if (tableName != null && tableName.isNotEmpty) line += ' - $tableName';
      bytes.addAll(
        generator.text(
          _san(line),
          styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            fontType: itemFont,
          ),
        ),
      );
    }
    bytes.addAll(generator.hr());

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
    // Ukuran rincian: 12/15/18/24/36 pt → perbesaran 1x-5x, dicetak APA ADANYA
    // (tanpa cap — preview = print, 5 ukuran selalu berbeda).
    final iSpec = literalSpec(itemsSize);
    final itemMag = iSpec.$1.clamp(1, 5);
    final itemBig = itemMag > 1;
    // 15pt hanya bisa dicetak dengan Font B ×2; bila font global Standar,
    // turunkan ke Font A ×2 (18pt) — printer tidak bisa mencetak 15pt Font A.
    final iFont = iSpec.$2 ? PosFontType.fontB : itemFont;
    final itemStyles = PosStyles(
      align: PosAlign.left,
      fontType: iFont,
      height: _posSize(itemMag),
      width: _posSize(itemMag),
    );
    // Lebar rincian = LEBAR KERTAS ÷ perbesaran (bukan "lebar ÷ N karakter"):
    // ukuran huruf nyata = perbesaran × 12pt, jadi karakter/baris = base/N.
    final itemLineWidth = itemBig
        ? (itemBaseLineWidth ~/ itemMag)
        : itemBaseLineWidth;
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
      // Harga per unit = harga FINAL (sudah dipotong diskon item) — diskon
      // ditampilkan sebagai "( -Rp X )" di sampingnya supaya customer notice.
      final unitPrice = line.price;
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

      // Diskon item per produk — kurung "( -Rp X )" setelah subtotal supaya
      // customer notice potongannya. Nominal = potongan per unit × qty.
      final discSuffix = line.hasDiscount
          ? '( -${formatRupiah(line.discountTotal)} )'
          : '';

      if (itemBig) {
        // Rincian "Besar" (2x): qty x harga final baris sendiri (KIRI),
        // subtotal NETTO baris sendiri menempel KANAN (sejajar TOTAL).
        bytes.addAll(generator.text(_san(qtyPrice), styles: itemStyles));
        bytes.addAll(
          generator.text(
            _san('$subtotal $discSuffix'.trimRight().padLeft(itemLineWidth)),
            styles: itemStyles,
          ),
        );
      } else {
        // Rincian "Kecil" (default): satu baris = qty x harga final di KIRI,
        // subtotal NETTO + diskon (kurung) di KANAN (menempel tepi kanan).
        final totalRight = '$subtotal $discSuffix'.trimRight();
        final gap = itemLineWidth - qtyPrice.length - totalRight.length;
        final line2 = gap >= 3
            ? '$qtyPrice${' ' * (gap - 2)}  $totalRight'
            : '$qtyPrice  $totalRight';
        bytes.addAll(generator.text(_san(line2), styles: itemStyles));
      }

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

    // Total. Beri jarak ekstra jika rincian besar — baris TOTAL 2x bisa
    // nempel dengan baris rincian terakhir.
    if (itemBig) {
      bytes.addAll(generator.feed(itemMag >= 4 ? 2 : 1));
    }
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

    // Footer — wrap long text. Ukuran 12/15/18/24/36 → perbesaran 1x-5x,
    // dicetak apa adanya (tanpa cap).
    final footerText = footer ?? _footerText;
    if (footerText.isNotEmpty) {
      final fSpec = literalSpec(footerSize);
      final footerMag = fSpec.$1.clamp(1, 5);
      final fFont = fSpec.$2 ? PosFontType.fontB : itemFont;
      final footerBase = isWide
          ? (fFont == PosFontType.fontB ? 64 : 48)
          : (fFont == PosFontType.fontB ? 42 : 32);
      // Lebar footer = LEBAR KERTAS ÷ perbesaran (ukuran huruf × 12pt literal).
      final footerLineChars = (footerBase ~/ footerMag).clamp(4, 40);
      final footerParts = _wrap(footerText, footerLineChars);
      for (final part in footerParts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: PosStyles(
              align: PosAlign.center,
              fontType: fFont,
              height: _posSize(footerMag),
              width: _posSize(footerMag),
            ),
          ),
        );
      }
      // Footer besar butuh jarak sebelum "Terima Kasih!" agar tidak nempel.
      if (footerMag > 2) {
        bytes.addAll(generator.feed(footerMag >= 4 ? 2 : 1));
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

  /// Print a TEST KALIBRASI — mencetak semua 5 ukuran literal sekaligus
  /// (12/15/18/24/36) supaya user langsung melihat di kertas ukuran mana yang
  /// printer-nya dukung (verifikasi fisik, bukan tebak-tebakan). Jika 24/36
  /// tercetak sama besar dengan 12/18 → printer hanya dukung sampai ukuran
  /// tsb; tinggal pilih ukuran terbesar yang tercetak dengan benar.
  Future<bool> printTest(
    String storeName, {
    String paperWidth = '58',
    int headerSize = 2,
    int itemsSize = 1,
    int footerSize = 1,
  }) async {
    final connected = await BluetoothUtils.isConnected();
    if (!connected) return false;

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    final isWide = paperWidth == '80';

    final List<int> bytes = [];
    bytes.addAll(generator.reset());

    // Judul tes kalibrasi.
    bytes.addAll(
      generator.text(
        _san('TES UKURAN FONT'),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        _san('Kertas ${paperWidth}mm — cek ukuran terbesar yang tercetak'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());

    // Jenis font global (1 pilihan saja di v2.2.21+ — font per bagian dihapus).
    final fontType = await SecureStore.getReceiptFontType();
    final testFont = fontType == 'kompak' ? PosFontType.fontB : PosFontType.fontA;

    // Tes cetak UKURAN LITERAL 12/15/18/24/36 (bukan 1x-8x) — user memilih
    // "seberapa besar huruf" (lebar kertas ÷ ukuran huruf = karakter/baris).
    // Kelima ukuran dicetak apa adanya — tidak ada cap.
    final fontLabel = fontType == 'kompak' ? 'Ramping (Font B)' : 'Standar (Font A)';
    bytes.addAll(
      generator.text(
        _san('Ukuran yang dicetak: $fontLabel'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    for (final literal in literalSizes) {
      // 15pt dicetak sebagai Font B ×2 (18×34 dot — antara 12pt dan 18pt);
      // bila user pilih Standar (Font A), cetak Font A ×2 (18pt) sebagai
      // gantinya — printer tidak bisa mencetak 15pt dengan Font A.
      final spec = literalSpec(literal);
      final useFontB = spec.$2 ? true : (testFont == PosFontType.fontB);
      final mag = spec.$1;
      final lw = isWide ? (useFontB ? 64 : 48) : (useFontB ? 42 : 32);
      final chars = (lw ~/ mag).clamp(4, lw);
      final fontForLine = useFontB ? PosFontType.fontB : PosFontType.fontA;
      bytes.addAll(
        generator.text(
          _san('$literal pt (${chars} kar/baris)'),
          styles: PosStyles(align: PosAlign.center, fontType: fontForLine),
        ),
      );
      final parts = _wrap(storeName, chars);
      for (final part in parts) {
        bytes.addAll(
          generator.text(
            _san(part),
            styles: PosStyles(
              align: PosAlign.center,
              bold: true,
              height: _posSize(mag),
              width: _posSize(mag),
              fontType: fontForLine,
            ),
          ),
        );
      }
      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(
      generator.text(
        _san('Semua 5 ukuran dicetak apa adanya di struk.'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _san('Ukuran = 12/15/18/24/36 pt — karakter/baris = lebar kertas ÷ ukuran.'),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(2));
    // Reset ke Font A (lihat catatan di printReceipt) — printer clone murah
    // tidak mereset Font B sendiri.
    bytes.addAll(
      generator.text(
        '',
        styles: const PosStyles(fontType: PosFontType.fontA),
      ),
    );
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
