import 'package:barcode/barcode.dart' as bc;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renderer label barcode produk — SATU sumber render untuk 3 jalur cetak
/// (v2.2.57+115, Area B):
///
/// 1. **TSPL** (printer label khusus — Rongta/HPRT/Godex/BluePrint, dll):
///    dirender ke BITMAP MONOKROM lalu diputar jadi bytes TSPL generik
///    (TSPL/TSPL2 standar) — kompatibel SEMUA merk label printer.
/// 2. **ESC/POS thermal struk 58mm**: bit-image ESC `*` (raster) — printer
///    struk yang sudah dipakai user otomatis bisa.
/// 3. **PDF A4 grid**: `package:pdf` — label ukuran default 40×30mm, grid
///    rapi siap gunting, share/unduh.
///
/// Isi label DINAMIS (checkbox): Nama / Harga / Barcode — bebas kombinasi.
///
/// Semua jalur memakai layout yang SAMA: [buildLabel] → [renderLabelPng] →
/// bitmap monokrom → bytes TSPL / ESC-POS / widget PDF. Preview ≠ print
/// TIDAK BOLEH terjadi (spesifikasi konsisten, sama seperti ReceiptRenderer).
class LabelRenderer {
  /// Ukuran label standar (mm). Default 40×30 — pas label harga umum.
  static const double defaultWidthMm = 40;
  static const double defaultHeightMm = 30;

  /// Ukuran label dalam piksel pada skala [LabelDpi.dpi203] (203 DPI —
  /// standar thermal label). 40mm ≈ 320px, 30mm ≈ 240px.
  static double mmToPx(double mm, {int dpi = LabelDpi.dpi203}) =>
      mm * dpi / 25.4;

  /// Bangun daftar elemen barcode CODE128 untuk [data] — dipakai renderer
  /// bitmap (bukan text widget). `make` mengembalikan operasi gambar
  /// (BarcodeBar: posisi + lebar + hitam/putih) dalam koordinat `width×height`.
  static List<bc.BarcodeElement> barcodeBars(
    String data,
    double width,
    double height, {
    bool drawText = false,
  }) {
    try {
      return bc.Barcode.code128().make(
        data,
        width: width,
        height: height,
        drawText: drawText,
      ).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Render SATU label ke bitmap MONOKROM (1-bit) ukuran [widthPx]×[heightPx].
  ///
  /// Layout (v2.2.57+115, dirombak dari umpan balik user):
  ///   ┌──────────────────────────────┐
  ///   │          ▓▓▓▓▓▓▓▓▓▓          │  ← barcode CODE128, PENDEK & di TENGAH
  ///   │         nama produk          │  ← nama, center, 1–2 baris
  ///   │           Rp 12.500          │  ← harga, center, bold
  ///   └──────────────────────────────┘
  ///
  /// Semua elemen CENTER (tidak menempel kiri). Barcode dibuat ramping:
  /// tingginya ~28% label, di posisi atas — bukan memenuhi label yang bikin
  /// teks nama/harga terpisah jauh dari barcode (keluhan user).
  ///
  /// Isi label dinamis via [showName]/[showPrice]/[showBarcode]. Mengembalikan
  /// [img.Image] RGBA (putih/hitam) — output yang sama dipakai pratinjau
  /// (encodePng), TSPL, dan ESC/POS (konsistensi render).
  static img.Image renderLabelBitmap({
    required String barcode,
    required String name,
    required int price,
    required bool showName,
    required bool showPrice,
    required bool showBarcode,
    required int widthPx,
    required int heightPx,
  }) {
    final image = img.Image(widthPx, heightPx)
      ..fill(img.getColor(255, 255, 255)); // putih
    const margin = 8;
    final cx = widthPx ~/ 2; // pusat horizontal

    // Baris elemen (dihitung dari atas). Urutan: barcode → nama → harga.
    // Pakai "blok" supaya tidak ada gap ngaco: setiap elemen menempati
    // slotnya sendiri, sisanya disebar merata di atas-bawah (center vertikal).
    var y = margin;

    // ── 1) Barcode CODE128 — PENDEK & CENTER ──
    //    Tinggi barcode = 26% tinggi label (bukan memenuhi label). Pakai
    //    operasi dari package `barcode` supaya scan HID/kamera yang sama di
    //    app ini membaca label yang sama.
    if (showBarcode && barcode.trim().isNotEmpty) {
      final bw = widthPx - margin * 2;
      final bh = (heightPx * 0.26).round().clamp(24, 80);
      final bars = barcodeBars(barcode, bw.toDouble(), bh.toDouble());
      // Hitung bounding box barcode (bar paling kiri & kanan) supaya bisa
      // di-center secara visual.
      var minX = widthPx, maxX = 0;
      for (final el in bars) {
        if (el is bc.BarcodeBar && el.black) {
          final x0 = (margin + el.left).round();
          final x1 = x0 + el.width.round();
          if (x0 < minX) minX = x0;
          if (x1 > maxX) maxX = x1;
        }
      }
      final barW = maxX - minX;
      final offX = barW > 0 ? cx - barW ~/ 2 : 0;
      final topY = y;
      for (final el in bars) {
        if (el is bc.BarcodeBar && el.black) {
          final x0 = (margin + el.left).round() + offX - minX;
          final y0 = topY + el.top.round();
          final w = el.width.round();
          final h = el.height.round();
          for (var yy = y0; yy < y0 + h && yy < heightPx; yy++) {
            for (var xx = x0; xx < x0 + w && xx < widthPx; xx++) {
              if (xx >= 0 && xx < widthPx) image.setPixelRgba(xx, yy, 0, 0, 0);
            }
          }
        }
      }
      y += bh + 4; // + jarak kecil ke teks
    }

    // ── 2) Nama produk — center, maks 2 baris ──
    if (showName && name.trim().isNotEmpty) {
      final nameLines = _wrapName(name, widthPx - margin * 2);
      for (var i = 0; i < nameLines.length && i < 2; i++) {
        final lineW = nameLines[i].length * 6; // lebar teks 5×7 + spasi
        final lx = (cx - lineW ~/ 2).clamp(margin, widthPx - margin - lineW);
        _drawText5x7(image, widthPx, nameLines[i], lx, y, blackColor: true);
        y += 10;
      }
      y += 2;
    }

    // ── 3) Harga — center, bold-ish ──
    if (showPrice) {
      final priceText = 'Rp ${_formatPrice(price)}';
      final lineW = priceText.length * 6;
      final lx = (cx - lineW ~/ 2).clamp(margin, widthPx - margin - lineW);
      _drawText5x7(image, widthPx, priceText, lx, y, blackColor: true);
      y += 12;
    }

    return image;
  }

  /// Ambil daftar piksel MONOKROM (true = hitam) dari hasil [renderLabelBitmap]
  /// — dipakai renderer ESC/POS & TSPL (bit-image butuh 1-bit baris).
  static List<bool> toMonochromeList(img.Image image) {
    final width = image.width;
    final black = List<bool>.filled(width * image.height, false);
    for (var y = 0; y < image.height; y++) {
      final rowStart = y * width;
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        // Ambil luminance sederhana dari RGB (putih ~ 255 → false, hitam → true).
        black[rowStart + x] = (img.getRed(p) + img.getGreen(p) + img.getBlue(p)) < 384;
      }
    }
    return black;
  }

  /// Wrap teks nama ke baris (maks 2 baris) supaya tidak melebihi lebar label.
  static List<String> _wrapName(String name, int maxPx) {
    const charW = 5; // lebar karakter font 5×7
    final words = name.split(' ');
    final lines = <String>[];
    var cur = '';
    for (final w in words) {
      final candidate = cur.isEmpty ? w : '$cur $w';
      if (candidate.length * charW <= maxPx || cur.isEmpty) {
        cur = candidate;
      } else {
        lines.add(cur);
        cur = w;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines;
  }

  /// Gambar teks pakai font bitmap 5×7 (angka/huruf dasar) ke [img.Image].
  /// Cukup untuk nama produk + harga label kecil.
  static void _drawText5x7(
    img.Image image,
    int widthPx,
    String text,
    int x,
    int y, {
    bool blackColor = true,
  }) {
    final chars = text.toUpperCase().split('');
    var cx = x;
    for (final ch in chars) {
      final glyph = _font5x7(ch);
      if (glyph == null) {
        cx += 5;
        continue;
      }
      for (var row = 0; row < 7; row++) {
        final bits = glyph[row];
        for (var col = 0; col < 5; col++) {
          if ((bits & (1 << (4 - col))) != 0) {
            final px = (y + row) * widthPx + (cx + col);
            if (px >= 0 && px < image.width * image.height) {
              if (blackColor) {
                image.setPixelRgba(cx + col, y + row, 0, 0, 0);
              }
            }
          }
        }
      }
      cx += 6; // 1px spasi antar karakter
    }
  }

  /// Format harga: "12500" → "12.500" (pemisah ribuan titik).
  static String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ─────────────────────────────────────────────
  // PDF A4 grid (jalur 3)
  // ─────────────────────────────────────────────

  /// Bangun widget label untuk PDF (A4 grid). Ukuran [widthMm]×[heightMm]
  /// — default 40×30. Isi label DINAMIS (checkbox) — SAMA dengan jalur cetak
  /// lain (konsistensi render): barcode di atas center, nama, lalu harga.
  static pw.Widget pdfLabel({
    required String barcode,
    required String name,
    required int price,
    required bool showName,
    required bool showPrice,
    required bool showBarcode,
    double widthMm = defaultWidthMm,
    double heightMm = defaultHeightMm,
  }) {
    const PdfColor ink = PdfColor.fromInt(0xFF111827);
    const PdfColor paper = PdfColor.fromInt(0xFFFFFFFF);

    final children = <pw.Widget>[];

    // Barcode — di ATAS, center, pendek (tinggi ~ 22% label, bukan separuh).
    if (showBarcode && barcode.trim().isNotEmpty) {
      children.add(
        pw.Center(
          child: pw.BarcodeWidget(
            data: barcode,
            barcode: bc.Barcode.code128(),
            width: widthMm * PdfPageFormat.mm * 0.9,
            height: heightMm * PdfPageFormat.mm * 0.22,
            drawText: false, // teks barcode tidak wajib — bersih & pendek
          ),
        ),
      );
      children.add(pw.SizedBox(height: 1.5 * PdfPageFormat.mm));
    }

    // Nama — center, bold.
    if (showName && name.trim().isNotEmpty) {
      children.add(
        pw.Center(
          child: pw.Text(
            name,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      );
      children.add(pw.SizedBox(height: 0.8 * PdfPageFormat.mm));
    }

    // Harga — center, bold.
    if (showPrice) {
      children.add(
        pw.Center(
          child: pw.Text(
            'Rp ${_formatPrice(price)}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
        ),
      );
    }

    return pw.Container(
      width: widthMm * PdfPageFormat.mm,
      height: heightMm * PdfPageFormat.mm,
      padding: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        color: paper,
        border: pw.Border.all(color: ink, width: 0.3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// DPI label thermal standar.
class LabelDpi {
  LabelDpi._();
  static const int dpi203 = 203;
  static const int dpi300 = 300;
}

/// Font bitmap 5×7 untuk teks label monokrom (angka + huruf dasar).
/// Setiap entri = 7 baris × 5 bit (bit paling kiri = bit 4).
List<int>? _font5x7(String ch) {
  const glyphs = <String, List<int>>{
    '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
    '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
    '2': [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
    '3': [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
    '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
    '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
    '6': [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
    '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
    '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
    '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
    '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C],
    'R': [0x1E, 0x11, 0x11, 0x1E, 0x12, 0x11, 0x11],
    'P': [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    'A': [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
    'B': [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
    'C': [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
    'D': [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E],
    'E': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
    'F': [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
    'G': [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F],
    'H': [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
    'I': [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
    'J': [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
    'K': [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
    'L': [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
    'M': [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
    'N': [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11],
    'O': [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
    'Q': [0x0E, 0x11, 0x11, 0x15, 0x13, 0x11, 0x0E],
    'S': [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
    'T': [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
    'U': [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
    'V': [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
    'W': [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11],
    'X': [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
    'Y': [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
    'Z': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
    '-': [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
  };
  return glyphs[ch];
}
