import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'package:nusa_kasir/core/receipt/receipt_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_data.dart';
import 'package:nusa_kasir/core/utils/receipt_header_renderer.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// SATU RECEIPT RENDERER (v2.2.29) — single source of truth untuk layout
/// struk. Semua output (print ESC/POS, share teks/WA, PDF, preview widget)
/// dibangun dari SATU struktur bagian yang sama: [buildReceiptParts].
/// Preview TIDAK MUNGKIN beda dengan print (spec: "Preview terlihat A,
/// Print menghasilkan B" TIDAK BOLEH terjadi).
///
/// Output:
///   [renderBytes]      → bytes ESC/POS untuk printer thermal (print/reprint/
///                        test print/split bill)
///   [renderText]       → teks plain untuk share WhatsApp
///   [renderPdf]        → file PDF asli untuk "Unduh PDF"
///   [buildReceiptParts] → struktur bagian (dipakai [ReceiptPreview] widget)
/// ─────────────────────────────────────────────────────────────────────────

/// Format angka struk TANPA prefix "Rp" (spec: "Total 112.300",
/// "Disc. (-3.000)") — hemat kolom di kertas 58mm.
String receiptNum(int v) =>
    v.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );

/// Sanitize text untuk printer thermal (strip non-ASCII). ESC/POS hanya
/// mendukung ASCII + CP-437 (0–255); emoji/CJK/panah akan crash printer.
String sanReceipt(String text) =>
    text.replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

/// Truncate teks ke kolom printer dengan ellipsis.
String fitReceipt(String text, int maxChars) {
  final s = sanReceipt(text);
  if (s.length <= maxChars) return s;
  return '${s.substring(0, maxChars - 3)}...';
}

/// Wrap teks ke beberapa baris, masing-masing ≤ maxChars (nama item panjang).
List<String> wrapReceipt(String text, int maxChars) {
  final s = sanReceipt(text).trimRight();
  if (s.length <= maxChars) return [s];
  final lines = <String>[];
  var remaining = s;
  while (remaining.length > maxChars) {
    var cut = maxChars;
    final spaceIdx = remaining.lastIndexOf(' ', maxChars);
    if (spaceIdx > maxChars * 0.75) cut = spaceIdx;
    lines.add(remaining.substring(0, cut).trimRight());
    remaining = remaining.substring(cut).trimLeft();
  }
  if (remaining.isNotEmpty) lines.add(remaining);
  return lines;
}

/// ESC/POS perbesaran 1-8 → PosTextSize.
PosTextSize receiptPosSize(int v) => switch (v.clamp(1, 8)) {
  1 => PosTextSize.size1,
  2 => PosTextSize.size2,
  3 => PosTextSize.size3,
  4 => PosTextSize.size4,
  5 => PosTextSize.size5,
  6 => PosTextSize.size6,
  7 => PosTextSize.size7,
  _ => PosTextSize.size8,
};

/// Lebar baris (karakter @×1) per kertas + font.
/// Standar (Font A): 58mm→32, 80mm→48. Kompak (Font B): 58mm→42, 80mm→64.
int receiptLineWidth(ReceiptConfig c, {bool useFontB = false}) {
  final b = c.fontType == 'kompak' || useFontB;
  return c.paperWidth == '80' ? (b ? 64 : 48) : (b ? 42 : 32);
}

// ── Struktur bagian struk (dipakai SEMUA output) ─────────────────────────

/// Bagian struk — setiap output (bytes/text/pdf/widget) merender bagian ini
/// dengan caranya sendiri, TAPI urutan & isi SELALU sama.
sealed class ReceiptPart {
  const ReceiptPart();
}

/// Baris teks biasa (nama item, info, footer, Terima Kasih!).
class ReceiptPartText extends ReceiptPart {
  final String text;
  final bool bold;
  final bool center;
  const ReceiptPartText(this.text, {this.bold = false, this.center = false});
}

/// Baris summary: label kiri, nominal KANAN (sejajar — spec T).
class ReceiptPartRow extends ReceiptPart {
  final String label;
  final String amount;
  final bool bold;
  const ReceiptPartRow(this.label, this.amount, {this.bold = false});
}

/// Divider horizontal (spec U: hanya setelah info, setelah item, setelah
/// Kembalian — TIDAK antar baris summary).
class ReceiptPartHr extends ReceiptPart {
  const ReceiptPartHr();
}

/// Gambar (logo atau header image PNG).
class ReceiptPartImage extends ReceiptPart {
  final Uint8List png;
  final int paperPx;
  final String align; // 'left' | 'center' | 'right'
  const ReceiptPartImage(this.png, this.paperPx, {this.align = 'center'});
}

/// Layout item struk (spec R): nama full-width, lalu "qty x harga ASLI" di
/// kiri + subtotal NETTO di kanan; item berdiskon tambah baris "Disc. (-RpX)".
class ReceiptPartItem extends ReceiptPart {
  final String name;
  final String qtyPrice; // "2 x 15.000"
  final String subtotal; // "27.000" (netto)
  final String? disc; // "(-3.000)" — null = tanpa diskon
  final String? note;
  const ReceiptPartItem(
    this.name,
    this.qtyPrice,
    this.subtotal,
    this.disc,
    this.note,
  );
}

/// Bagian header — dirender PNG (satu renderer SAMA untuk print & preview).
class ReceiptPartHeader extends ReceiptPart {
  final ReceiptConfig config;
  const ReceiptPartHeader(this.config);
}

/// Lebar maks logo dalam PIXEL per kertas (dipakai print + preview + PDF).
int receiptLogoBasePx(String paperWidth) =>
    paperWidth == '80' ? 320 : 160;

/// Bangun SATU struktur bagian struk dari [config] + [data] + [storeName].
/// Dipanggil oleh renderBytes/renderText/renderPdf DAN ReceiptPreview widget
/// — sehingga preview literal render dari struktur yang sama.
List<ReceiptPart> buildReceiptParts({
  required ReceiptConfig config,
  required ReceiptData data,
  required String storeName,
  Uint8List? logoBytes,
}) {
  final parts = <ReceiptPart>[];

  // ── Logo (bit-image) — lebar PERSEN dari kertas, alignment mengikuti ──
  if (config.showLogo && logoBytes != null) {
    final pct = config.logoWidthPercent.clamp(1, 100) / 100;
    parts.add(ReceiptPartImage(
      logoBytes,
      (receiptLogoBasePx(config.paperWidth) * pct).round(),
      align: config.logoAlign,
    ));
  }

  // ── Header — nama toko / header custom sebagai GAMBAR (spec L/M) ──
  // HANYA nama toko/header custom yang image; invoice/tgl/kasir = teks.
  parts.add(ReceiptPartHeader(config));

  // ── Sub-header (alamat toko, v2.2.30) — teks kecil di bawah header ──
  if (config.subHeader.trim().isNotEmpty) {
    for (final line in config.subHeader.split('\n')) {
      if (line.trim().isEmpty) continue;
      parts.add(ReceiptPartText(line.trim(), center: true));
    }
  }

  // ── Info header — teks biasa (BUKAN image, v2.2.27) ──
  if (config.showInvoice && data.invoiceNumber.isNotEmpty) {
    parts.add(ReceiptPartText(data.invoiceNumber, bold: true, center: true));
  }
  if (config.showDate && data.dateStr.isNotEmpty) {
    parts.add(ReceiptPartText(data.dateStr, center: true));
  }
  if (config.showCashier &&
      data.cashierName != null &&
      data.cashierName!.isNotEmpty) {
    // v2.2.30: kasir ikut CENTER, sejajar invoice & tanggal (keputusan user).
    parts.add(ReceiptPartText('Kasir: ${data.cashierName}', center: true));
  }
  if (data.customerName != null && data.customerName!.isNotEmpty) {
    parts.add(ReceiptPartText('Pelanggan: ${data.customerName}'));
  }
  if (data.orderType != null && data.orderType!.isNotEmpty) {
    final label = (data.tableName != null && data.tableName!.isNotEmpty)
        ? '${data.orderType} - ${data.tableName}'
        : data.orderType!;
    parts.add(ReceiptPartText(label, bold: true, center: true));
  }
  parts.add(const ReceiptPartHr());

  // ── Items (compact, tanpa divider antar item — spec R/S) ──
  // v2.2.57+122: diskon TRANSAKSI dibagi proporsional ke tiap item
  // (allocatedTransactionDiscounts) → subtotal per-item NETTO mencerminkan
  // Grand Total (Σ item = Total), dan baris "Disc. (-RpX)" per item
  // menampilkan potongan item + porsi diskon transaksinya.
  final txnAlloc = data.allocatedTransactionDiscounts;
  for (var i = 0; i < data.items.length; i++) {
    final item = data.items[i];
    final alloc = i < txnAlloc.length ? txnAlloc[i] : 0;
    final unitPrice = item.originalPrice ?? item.price;
    final qtyPrice = item.isPerKg
        ? '${item.qtyLabel} x ${receiptNum(unitPrice)}/kg'
        : '${item.qtyLabel} x ${receiptNum(unitPrice)}';
    final netSubtotal = item.subtotal - alloc;
    final itemDiscTotal = item.discountTotal + alloc;
    parts.add(ReceiptPartItem(
      item.name,
      qtyPrice,
      receiptNum(netSubtotal),
      itemDiscTotal > 0 ? '(-${receiptNum(itemDiscTotal)})' : null,
      item.note,
    ));
  }
  parts.add(const ReceiptPartHr());

  // ── Summary — SATU section, nominal sejajar, TANPA divider antar baris
  // (spec T/U): Total / Disc. (total diskon item+transaksi) / Bayar /
  // Kembalian. "Anda Hemat" & baris "Diskon" digantikan baris "Disc."
  // (keputusan user — ikut spec baru).
  final totalDisc = data.totalDiscount;
  parts.add(ReceiptPartRow('Total', receiptNum(data.total), bold: true));
  if (totalDisc > 0) {
    parts.add(ReceiptPartRow('Disc.', '(-${receiptNum(totalDisc)})'));
  }
  // v2.2.30: label bayar ringkas ("Bayar:") supaya nama metode penuh
  // (EDC / Kartu, Transfer, QRIS) TIDAK terpotong di kolom 58mm — metode
  // penuh tetap terlihat karena label & nominal satu baris sejajar.
  if (data.downPayment > 0) {
    parts.add(ReceiptPartRow(
      'Bayar: ${data.paymentMethod}',
      receiptNum(data.downPayment),
    ));
    parts.add(ReceiptPartRow('Sisa Piutang', receiptNum(data.remainingDue)));
  } else if (data.remainingDue > 0 && data.cashGiven == 0) {
    // Mode HUTANG penuh: bayar 0, seluruh total jadi hutang.
    parts.add(ReceiptPartRow(
      'Bayar: ${data.paymentMethod}',
      receiptNum(0),
    ));
    parts.add(ReceiptPartRow('Hutang', receiptNum(data.remainingDue)));
  } else if (data.paymentMethod.isNotEmpty) {
    parts.add(ReceiptPartRow(
      'Bayar: ${data.paymentMethod}',
      receiptNum(data.cashGiven ?? data.total),
    ));
  }
  if (data.cashReturn != null && data.cashReturn! > 0 && data.downPayment <= 0) {
    parts.add(ReceiptPartRow('Kembali', receiptNum(data.cashReturn!)));
  }
  parts.add(const ReceiptPartHr());

  // ── Footer (spec V: cukup ucapan + info toko, tanpa branding aplikasi) ──
  // v2.2.30: footer = ISI USER SAJA — hardcode "Terima Kasih!" + nama toko
  // dihapus (keputusan user: footer yang mana isi user).
  final footerText = config.footer.trim().isNotEmpty ? config.footer : '';
  for (final line in footerText.split('\n')) {
    if (line.trim().isEmpty) continue;
    parts.add(ReceiptPartText(line.trim(), center: true));
  }

  return parts;
}

/// Header image PNG — dipakai renderBytes & preview (satu renderer).
Future<Uint8List> renderHeaderPng(ReceiptConfig config, String storeName) {
  return renderReceiptHeaderPng(
    paperWidth: config.paperWidth,
    storeName: storeName,
    customHeader: config.header,
    headerPx: config.headerPx,
    headerWeight: config.headerWeight,
  );
}

// ── OUTPUT 1: ESC/POS bytes (printer thermal) ─────────────────────────────

/// Bangun bytes ESC/POS untuk struk. Transport (Bluetooth) dilakukan
/// ReceiptPrinter — fungsi ini MURNI layout.
Future<List<int>> renderBytes({
  required ReceiptConfig config,
  required ReceiptData data,
  required String storeName,
  Uint8List? logoBytes,
  bool openDrawer = false,
  int drawerPin = 2,
}) async {
  final profile = await CapabilityProfile.load();
  final paperSize = config.paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58;
  final generator = Generator(paperSize, profile);

  final useFontB = config.fontType == 'kompak';
  final itemFont = useFontB ? PosFontType.fontB : PosFontType.fontA;
  final isWide = config.paperWidth == '80';
  final lineW = receiptLineWidth(config);

  final bytes = <int>[];
  bytes.addAll(generator.reset());

  for (final part in buildReceiptParts(
    config: config,
    data: data,
    storeName: storeName,
    logoBytes: logoBytes,
  )) {
    switch (part) {
      case ReceiptPartImage(:final png, :final paperPx, :final align):
        try {
          final decoded = img.decodeImage(png);
          if (decoded == null) break;
          var resized = decoded;
          // Logo: batasi lebar + tinggi bit-image buffer printer murah.
          final maxH = config.paperWidth == '80' ? 160 : 96;
          if (decoded.width > paperPx || decoded.height > maxH) {
            final scale = (paperPx / decoded.width).clamp(0.0, 1.0);
            final hScale = maxH / decoded.height;
            final s = scale < hScale ? scale : hScale;
            resized = img.copyResize(
              decoded,
              width: (decoded.width * s).round(),
              height: (decoded.height * s).round(),
            );
          }
          final posAlign = switch (align) {
            'left' => PosAlign.left,
            'right' => PosAlign.right,
            _ => PosAlign.center,
          };
          bytes.addAll(generator.image(resized, align: posAlign));
          bytes.addAll(generator.feed(1));
          // CRITICAL: keluar dari bit-image mode (printer murah kehilangan
          // auto-reset) sebelum teks berikutnya.
          bytes.addAll(generator.reset());
        } catch (_) {}
      case ReceiptPartHeader(:final config):
        try {
          final headerPng = await renderHeaderPng(config, storeName);
          final headerImage = img.decodeImage(headerPng);
          if (headerImage != null) {
            bytes.addAll(generator.image(headerImage, align: PosAlign.center));
            bytes.addAll(generator.feed(1));
            bytes.addAll(generator.reset());
          }
        } catch (_) {
          // Render gagal → cetak nama toko sebagai teks biasa (struk tetap jalan).
          final headerText = config.header.trim().isNotEmpty
              ? config.header.trim()
              : storeName;
          bytes.addAll(
            generator.text(
              sanReceipt(headerText),
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
      case ReceiptPartText(:final text, :final bold, :final center):
        for (final part in wrapReceipt(text, lineW)) {
          bytes.addAll(
            generator.text(
              sanReceipt(part),
              styles: PosStyles(
                align: center ? PosAlign.center : PosAlign.left,
                bold: bold,
                fontType: itemFont,
              ),
            ),
          );
        }
      case ReceiptPartHr():
        bytes.addAll(generator.hr());
      case ReceiptPartItem(
          :final name,
          :final qtyPrice,
          :final subtotal,
          :final disc,
          :final note
        ):
        // Baris 1: nama item full-width (wrap).
        for (final part in wrapReceipt(name, lineW)) {
          bytes.addAll(
            generator.text(
              sanReceipt(part),
              styles: PosStyles(
                align: PosAlign.left,
                fontType: itemFont,
                height: receiptPosSize(1),
                width: receiptPosSize(1),
              ),
            ),
          );
        }
        // Baris 2: "2 x 15.000" KIRI + subtotal NETTO KANAN.
        final qtyPriceW = useFontB ? 14 : 12;
        final subW = useFontB ? 11 : 10;
        final qp = fitReceipt(qtyPrice, qtyPriceW);
        final sub = fitReceipt(subtotal, subW);
        final gap = lineW - qp.length - sub.length;
        final line2 = gap >= 3 ? '$qp${' ' * (gap - 2)}  $sub' : '$qp  $sub';
        bytes.addAll(
          generator.text(
            sanReceipt(line2),
            styles: PosStyles(
              align: PosAlign.left,
              fontType: itemFont,
              height: receiptPosSize(1),
              width: receiptPosSize(1),
            ),
          ),
        );
        // Baris 3: "Disc. (-3.000)" hanya untuk item berdiskon (spec S).
        if (disc != null) {
          bytes.addAll(
            generator.text(
              sanReceipt('Disc. $disc'),
              styles: PosStyles(
                align: PosAlign.left,
                fontType: itemFont,
              ),
            ),
          );
        }
        if (note != null && note.isNotEmpty) {
          for (final part in wrapReceipt('  > $note', lineW - 2)) {
            bytes.addAll(
              generator.text(
                sanReceipt(part),
                styles: PosStyles(align: PosAlign.left, fontType: itemFont),
              ),
            );
          }
        }
      case ReceiptPartRow(:final label, :final amount, :final bold):
        // v2.2.31: lebar kolom DINAMIS + label TIDAK di-truncate. Sebelumnya
        // fitReceipt(label, 11) @58mm memotong "Bayar: Tunai" (12 char)
        // menjadi "Bayar: Tuna" — teks hilang diam-diam. Sekarang label
        // dikirim utuh; esc_pos_utils.row() otomatis membungkus ke baris
        // berikutnya bila melebihi kolom, jadi tidak ada yang hilang.
        // Metode terpanjang: "EDC / Kartu" (19 char) tetap tampil penuh.
        final labelRaw = sanReceipt(label);
        final amountRaw = sanReceipt(amount);
        // Nominal butuh ~6 unit kolom @58/@80 (angka 7 digit + pemisah),
        // label ambil sisa — minimal 4 unit biar total kolom = 12.
        final amountW = 6;
        final labelW = (12 - amountW).clamp(4, 8);
        final amountChars = (amountRaw.length + 1).clamp(6, isWide ? 16 : 11);
        bytes.addAll(
          generator.row([
            PosColumn(
              text: labelRaw,
              width: labelW,
              styles: PosStyles(
                bold: bold,
                align: PosAlign.left,
                fontType: itemFont,
              ),
            ),
            PosColumn(
              text: fitReceipt(amountRaw, amountChars),
              width: 12 - labelW,
              styles: PosStyles(
                bold: bold,
                align: PosAlign.right,
                fontType: itemFont,
              ),
            ),
          ]),
        );
    }
  }

  // Kembalikan ke Font A — printer clone murah TIDAK mereset Font B sendiri.
  bytes.addAll(generator.text('', styles: PosStyles(fontType: PosFontType.fontA)));
  bytes.addAll(generator.feed(2));
  bytes.addAll(generator.cut());

  // Cash drawer — binary ESC p (banyak printer murah tolak bentuk teks).
  if (openDrawer) {
    final m = drawerPin == 2 ? 0x00 : 0x01;
    bytes.addAll([0x1B, 0x70, m, 0x19, 0x19]);
  }

  return bytes;
}

// ── OUTPUT 2: teks plain (share WhatsApp) ─────────────────────────────────

/// Bangun teks struk untuk share WA — struktur SAMA dengan print (spec:
/// preview/print/share berasal dari renderer yang sama).
String renderText({
  required ReceiptConfig config,
  required ReceiptData data,
  required String storeName,
}) {
  final sb = StringBuffer();
  final div = '━━━━━━━━━━━━━━━━━';

  sb.writeln('*${storeName.trim().isEmpty ? 'Struk' : storeName.trim()}*');
  if (config.header.isNotEmpty) sb.writeln(config.header);
  if (config.subHeader.trim().isNotEmpty) sb.writeln(config.subHeader.trim());
  sb.writeln(div);
  if (config.showInvoice && data.invoiceNumber.isNotEmpty) {
    sb.writeln('ID  : ${data.invoiceNumber}');
  }
  if (config.showDate && data.dateStr.isNotEmpty) {
    sb.writeln('Tgl : ${data.dateStr}');
  }
  if (config.showCashier &&
      data.cashierName != null &&
      data.cashierName!.isNotEmpty) {
    sb.writeln('Kasir: ${data.cashierName}');
  }
  if (data.customerName != null && data.customerName!.isNotEmpty) {
    sb.writeln('Pel  : ${data.customerName}');
  }
  if (data.orderType != null && data.orderType!.isNotEmpty) {
    final label = (data.tableName != null && data.tableName!.isNotEmpty)
        ? '${data.orderType} — ${data.tableName}'
        : data.orderType!;
    sb.writeln('*$label*');
  }
  sb.writeln(div);

  // v2.2.57+122: diskon transaksi dialokasikan proporsional ke item
  // (sama dengan renderBytes/buildReceiptParts — Σ item = Total).
  final txnAlloc = data.allocatedTransactionDiscounts;
  for (var i = 0; i < data.items.length; i++) {
    final item = data.items[i];
    final alloc = i < txnAlloc.length ? txnAlloc[i] : 0;
    sb.writeln(item.name);
    final unitPrice = item.originalPrice ?? item.price;
    final qtyTxt = item.isPerKg
        ? '${item.qtyLabel} x ${receiptNum(unitPrice)}/kg'
        : '${item.qtyLabel} x ${receiptNum(unitPrice)}';
    final itemDiscTotal = item.discountTotal + alloc;
    final discTxt = itemDiscTotal > 0
        ? '(-${receiptNum(itemDiscTotal)})'
        : '';
    sb.writeln(
      '  $qtyTxt  $discTxt ${receiptNum(item.subtotal - alloc)}'.trimRight(),
    );
    if (item.note != null && item.note!.isNotEmpty) {
      sb.writeln('  ↳ ${item.note}');
    }
  }
  sb.writeln(div);

  final totalDisc = data.totalDiscount;
  sb.writeln('*Total      : ${receiptNum(data.total)}*');
  if (totalDisc > 0) sb.writeln('Disc.      : (-${receiptNum(totalDisc)})');
  if (data.downPayment > 0) {
    sb.writeln('Bayar: ${data.paymentMethod} : ${receiptNum(data.downPayment)}');
    sb.writeln('Sisa Piutang: ${receiptNum(data.remainingDue)}');
  } else if (data.remainingDue > 0 && data.cashGiven == 0) {
    sb.writeln('Bayar: ${data.paymentMethod} : ${receiptNum(0)}');
    sb.writeln('Hutang: ${receiptNum(data.remainingDue)}');
  } else if (data.paymentMethod.isNotEmpty) {
    sb.writeln(
      'Bayar: ${data.paymentMethod} : ${receiptNum(data.cashGiven ?? data.total)}',
    );
  }
  if (data.cashReturn != null && data.cashReturn! > 0) {
    sb.writeln('Kembali     : ${receiptNum(data.cashReturn!)}');
  }
  sb.writeln(div);

  final footerText = config.footer.trim().isNotEmpty ? config.footer : '';
  sb.writeln(footerText);
  return sb.toString();
}

// ── OUTPUT 3: PDF asli ("Unduh PDF") ──────────────────────────────────────

/// Bangun file PDF struk — konten SAMA dengan renderText/renderBytes.
/// Menggantikan share .txt lama (v2.2.29: PDF asli via package `pdf`).
Future<File> renderPdf({
  required ReceiptConfig config,
  required ReceiptData data,
  required String storeName,
  String invoice = 'struk',
}) async {
  final pdf = pw.Document(title: 'Struk $storeName', author: storeName);

  // Halaman sempit seperti kertas thermal 58mm (~50mm content).
  final pageWidth = 50 * PdfPageFormat.mm;
  final pageHeight = 240 * PdfPageFormat.mm;

  pw.Widget textRow(String label, String amount, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget centerLine(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  final widgets = <pw.Widget>[];

  // Header: nama toko + header custom sebagai teks (PDF tidak pakai
  // bit-image; konten sama).
  widgets.add(centerLine(storeName.trim().isEmpty ? 'Struk' : storeName.trim(), bold: true));
  if (config.header.isNotEmpty) widgets.add(centerLine(config.header));
  // Sub-header (alamat toko) — v2.2.30
  if (config.subHeader.trim().isNotEmpty) {
    for (final line in config.subHeader.split('\n')) {
      if (line.trim().isNotEmpty) widgets.add(centerLine(line.trim()));
    }
  }

  // Info
  if (config.showInvoice && data.invoiceNumber.isNotEmpty) {
    widgets.add(centerLine(data.invoiceNumber, bold: true));
  }
  if (config.showDate && data.dateStr.isNotEmpty) {
    widgets.add(centerLine(data.dateStr));
  }
  if (config.showCashier && data.cashierName != null && data.cashierName!.isNotEmpty) {
    widgets.add(pw.Text('Kasir: ${data.cashierName}'));
  }
  if (data.customerName != null && data.customerName!.isNotEmpty) {
    widgets.add(pw.Text('Pelanggan: ${data.customerName}'));
  }
  widgets.add(pw.Divider(color: PdfColors.grey600));

  // Items — v2.2.57+122: diskon transaksi dialokasikan proporsional ke item
  // (sama dengan renderBytes/renderText — Σ item = Total).
  final txnAlloc = data.allocatedTransactionDiscounts;
  for (var i = 0; i < data.items.length; i++) {
    final item = data.items[i];
    final alloc = i < txnAlloc.length ? txnAlloc[i] : 0;
    widgets.add(pw.Text(item.name, style: const pw.TextStyle(fontSize: 9)));
    final unitPrice = item.originalPrice ?? item.price;
    final qtyTxt = item.isPerKg
        ? '${item.qtyLabel} x ${receiptNum(unitPrice)}/kg'
        : '${item.qtyLabel} x ${receiptNum(unitPrice)}';
    final itemDiscTotal = item.discountTotal + alloc;
    final discTxt = itemDiscTotal > 0
        ? 'Disc. (-${receiptNum(itemDiscTotal)})'
        : '';
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(qtyTxt, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
            pw.Text(receiptNum(item.subtotal - alloc), style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
    if (discTxt.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Text(discTxt, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ),
      );
    }
    if (item.note != null && item.note!.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8),
          child: pw.Text('↳ ${item.note}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ),
      );
    }
  }
  widgets.add(pw.Divider(color: PdfColors.grey600));

  // Summary (satu section, nominal sejajar)
  widgets.add(textRow('Total', receiptNum(data.total), bold: true));
  final totalDisc = data.totalDiscount;
  if (totalDisc > 0) widgets.add(textRow('Disc.', '(-${receiptNum(totalDisc)})'));
  if (data.downPayment > 0) {
    widgets.add(textRow('Bayar: ${data.paymentMethod}', receiptNum(data.downPayment)));
    widgets.add(textRow('Sisa Piutang', receiptNum(data.remainingDue)));
  } else if (data.remainingDue > 0 && data.cashGiven == 0) {
    widgets.add(textRow('Bayar: ${data.paymentMethod}', receiptNum(0)));
    widgets.add(textRow('Hutang', receiptNum(data.remainingDue)));
  } else if (data.paymentMethod.isNotEmpty) {
    widgets.add(textRow(
      'Bayar: ${data.paymentMethod}',
      receiptNum(data.cashGiven ?? data.total),
    ));
  }
  if (data.cashReturn != null && data.cashReturn! > 0 && data.downPayment <= 0) {
    widgets.add(textRow('Kembali', receiptNum(data.cashReturn!)));
  }
  widgets.add(pw.Divider(color: PdfColors.grey600));

  // Footer — v2.2.30: isi USER SAJA (hardcode Terima Kasih! + nama toko
  // dihapus, sinkron dengan renderBytes/renderText).
  final footerText = config.footer.trim().isNotEmpty ? config.footer : '';
  for (final line in footerText.split('\n')) {
    if (line.trim().isNotEmpty) widgets.add(centerLine(line.trim()));
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(pageWidth, pageHeight),
      margin: const pw.EdgeInsets.all(6),
      build: (_) => widgets,
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final safeInvoice = invoice.replaceAll(RegExp(r'[^\w\-]'), '_');
  final file = File(
    '${dir.path}/struk_${safeInvoice.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : safeInvoice}.pdf',
  );
  await file.writeAsBytes(await pdf.save());
  return file;
}
