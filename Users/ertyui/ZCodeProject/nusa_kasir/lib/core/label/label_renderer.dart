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
  /// Layout (v2.2.57+116, adaptif):
  ///   ┌──────────────────────────────┐
  ///   │         ▓▓▓▓▓▓▓▓▓▓▓▓         │  ← barcode CODE128, CENTER (atau
  ///   │        nama produk           │     FULL lebar kertas utk struk)
  ///   │         Rp 12.500            │  ← nama, center, 1–2 baris
  ///   └──────────────────────────────┘
  ///
  /// Isi label dinamis via [showName]/[showPrice]/[showBarcode]. Ukuran font
  /// nama & harga bisa diatur user via [nameFontScale]/[priceFontScale]
  /// (1.0–3.0, langkah 0.1 — v2.2.57+116). Font dirender fraksional:
  /// supersampling 8× lalu downsampling, jadi tiap kenaikan 0.1x TERLIHAT
  /// perubahannya (bukan dibulatkan).
  ///
  /// [fullWidthBarcode] (v2.2.57+116): barcode diregangkan selebar label
  /// (margin kecil) — dipakai jalur struk thermal supaya barcode nyambung
  /// rata kiri-kanan. Default false = barcode pendek di tengah (TSPL).
  ///
  /// Mengembalikan [img.Image] RGBA (putih/hitam) — output yang sama dipakai
  /// pratinjau (encodePng), TSPL, dan ESC/POS (konsistensi render).
  static img.Image renderLabelBitmap({
    required String barcode,
    required String name,
    required int price,
    required bool showName,
    required bool showPrice,
    required bool showBarcode,
    required int widthPx,
    required int heightPx,
    double nameFontScale = 1.0,
    double priceFontScale = 1.0,
    bool fullWidthBarcode = false,
  }) {
    final image = img.Image(widthPx, heightPx)
      ..fill(img.getColor(255, 255, 255)); // putih
    const margin = 8;
    final cx = widthPx ~/ 2; // pusat horizontal

    // Baris elemen (dihitung dari atas). Urutan: barcode → nama → harga.
    // Pakai "blok" supaya tidak ada gap ngaco: setiap elemen menempati
    // slotnya sendiri, sisanya disebar merata di atas-bawah (center vertikal).
    var y = margin;

    // ── 1) Barcode CODE128 ──
    //    TSPL: pendek & center (26% tinggi label). Struk: FULL lebar
    //    (rata kiri-kanan) — [fullWidthBarcode].
    if (showBarcode && barcode.trim().isNotEmpty) {
      final bw = fullWidthBarcode
          ? widthPx - margin * 2
          : widthPx - margin * 2;
      final bh = (heightPx * 0.26).round().clamp(24, 80);
      final bars = barcodeBars(barcode, bw.toDouble(), bh.toDouble());
      // Hitung bounding box barcode (bar paling kiri & kanan) supaya bisa
      // di-center secara visual (TSPL) atau dipakai penuh (struk).
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
      // Struk: baris barcode direntang penuh ke kiri-kanan (pixel-accurate
      // terhadap elemen barcode). TSPL: center.
      final offX = fullWidthBarcode
          ? margin - minX
          : barW > 0
              ? cx - barW ~/ 2
              : 0;
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
    //    v2.2.57+116: bila nama MENTOK ke bawah (melebihi ruang ke harga),
    //    nama ditaruh LEBIH RENDAH (di bawah barcode) dan harga digeser ke
    //    bawah — supaya tidak tabrakan. Ditangani _placeName/_placePrice.
    if (showName && name.trim().isNotEmpty) {
      y = _placeName(
        image,
        widthPx,
        heightPx,
        name,
        y,
        cx,
        margin,
        nameFontScale.clamp(1.0, 3.0),
        priceShown: showPrice && price >= 0,
      );
    }

    // ── 3) Harga — center, bold-ish ──
    if (showPrice) {
      y = _placePrice(
        image,
        widthPx,
        heightPx,
        price,
        y,
        cx,
        margin,
        priceFontScale.clamp(1.0, 3.0),
      );
    }

    return image;
  }

  /// Tempatkan nama (center, maks 2 baris) — kembali ke y setelah nama.
  /// Bila nama 2 baris penuh dan harga masih perlu ruang, nama dipindah
  /// turun (di bawah barcode) dan ruang bawah dibagi rata (v2.2.57+116).
  static int _placeName(
    img.Image image,
    int widthPx,
    int heightPx,
    String name,
    int y,
    int cx,
    int margin,
    double scale, {
    required bool priceShown,
  }) {
    final charW = _fractionalTextAdvance(scale); // lebar char 5×7 fraksional
    final advance = _fractionalTextAdvance(scale);
    final lineH = _fractionalLineHeight(scale, isName: true);
    final nameLines = _wrapName(name, widthPx - margin * 2, charW: charW);
    final lineCount = nameLines.length > 2 ? 2 : nameLines.length;
    final nameBlockH = lineCount * lineH;

    // Ruang tersisa setelah nama → harga. Bila nama 2 baris dan ruang
    // tersisa kurang dari tinggi harga → geser nama ke bawah (center blok
    // di ruang bawah label).
    final priceBlockH = priceShown ? _fractionalLineHeight(scale, isName: false) + 4 : 0;
    final spaceBelow = heightPx - margin - y - priceBlockH;
    final int nameY;
    if (spaceBelow < nameBlockH + 2) {
      // Nama mentok ke harga → letakkan nama di tengah ruang bawah label.
      final availTop = y;
      final availBot = heightPx - margin;
      final availH = availBot - availTop;
      nameY = availTop + ((availH - nameBlockH) ~/ 2).clamp(0, availH - nameBlockH);
    } else {
      nameY = y;
    }

    for (var i = 0; i < lineCount; i++) {
      final line = nameLines[i];
      final lineW = line.length * advance;
      final lx = (cx - lineW ~/ 2).clamp(margin, widthPx - margin - lineW);
      _drawText5x7Fractional(image, widthPx, line, lx, nameY + i * lineH,
          scale: scale);
    }
    return nameY + nameBlockH;
  }

  /// Tempatkan harga (center) — kembali ke y setelah harga.
  static int _placePrice(
    img.Image image,
    int widthPx,
    int heightPx,
    int price,
    int y,
    int cx,
    int margin,
    double scale,
  ) {
    final advance = _fractionalTextAdvance(scale);
    final lineH = _fractionalLineHeight(scale, isName: false);
    final priceText = 'Rp ${_formatPrice(price)}';
    final lineW = priceText.length * advance;
    final lx = (cx - lineW ~/ 2).clamp(margin, widthPx - margin - lineW);
    _drawText5x7Fractional(image, widthPx, priceText, lx, y, scale: scale);
    return y + lineH;
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
  /// [charW] = lebar karakter dalam px — menyesuaikan skala font (v2.2.57+116).
  static List<String> _wrapName(String name, int maxPx, {int charW = 5}) {
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

  /// Lebar karakter fraksional (px) — 5px × skala (v2.2.57+116).
  static int _fractionalTextAdvance(double scale) =>
      (6 * scale).round().clamp(6, 24);

  /// Tinggi baris fraksional — nama 10px×skala, harga 12px×skala.
  static int _fractionalLineHeight(double scale, {required bool isName}) =>
      ((isName ? 10 : 12) * scale).round().clamp(10, 48);

  /// Gambar teks pakai font bitmap 5×7 (angka/huruf dasar) ke [img.Image].
  /// Cukup untuk nama produk + harga label kecil.
  ///
  /// [scale] = perbesaran font FRAKSIONAL (v2.2.57+116): 1.0 = 5×7 px,
  /// 1.5 = 7.5×10.5 px, 2.0 = 10×14 px, dst. Tiap 0.1x TERLIHAT perubahannya.
  /// Teknik: gambar glyph di "supersurface" 8× lebih besar, lalu
  /// box-downsample rata-rata ke ukuran asli → teks tetap tegas (anti-
  /// alias ringan) dan cocok printer thermal 1-bit (threshold 50%).
  static void _drawText5x7Fractional(
    img.Image image,
    int widthPx,
    String text,
    int x,
    int y, {
    double scale = 1.0,
  }) {
    final s = scale.clamp(1.0, 3.0);
    // Ukuran glyph fraksional dalam satuan "dot" (1 dot = 1/8 supersample).
    final dotAdv = (6 * s); // advance per char
    final dotH = (7 * s); // tinggi glyph
    // Ukuran supersurface (8× resolusi) untuk seluruh teks.
    final ss = 8;
    final totalW = (text.length * dotAdv * ss).ceil();
    final totalH = (dotH * ss).ceil();
    if (totalW <= 0 || totalH <= 0) return;
    final buffer = img.Image(totalW, totalH)
      ..fill(img.getColor(255, 255, 255));
    final chars = text.toUpperCase().split('');
    for (var ci = 0; ci < chars.length; ci++) {
      final glyph = _font5x7(chars[ci]);
      if (glyph == null) continue;
      // Posisi char dalam supersurface (float, pakai dot*ss).
      final charLeft = ci * dotAdv * ss;
      final charTop = 0.0;
      for (var row = 0; row < 7; row++) {
        final bits = glyph[row];
        for (var col = 0; col < 5; col++) {
          if ((bits & (1 << (4 - col))) == 0) continue;
          // Kotak piksel glyph → persegi supersurface.
          final px0 = (charLeft + col * s * ss).round();
          final py0 = (charTop + row * s * ss).round();
          final px1 = (charLeft + (col + 1) * s * ss).round();
          final py1 = (charTop + (row + 1) * s * ss).round();
          for (var by = py0; by < py1 && by < totalH; by++) {
            for (var bx = px0; bx < px1 && bx < totalW; bx++) {
              buffer.setPixelRgba(bx, by, 0, 0, 0);
            }
          }
        }
      }
    }
    // Box-downsample 8× → target px, threshold 50% hitam.
    for (var ty = 0; ty < totalH; ty += ss) {
      final dstY = y + (ty / ss).round();
      if (dstY < 0 || dstY >= image.height) continue;
      for (var tx = 0; tx < totalW; tx += ss) {
        final dstX = x + (tx / ss).round();
        if (dstX < 0 || dstX >= image.width) continue;
        // Hitung rata-rata blok ss×ss.
        var sum = 0;
        var cnt = 0;
        for (var by = ty; by < ty + ss && by < totalH; by++) {
          for (var bx = tx; bx < tx + ss && bx < totalW; bx++) {
            final p = buffer.getPixel(bx, by);
            if (img.getRed(p) < 128) sum++;
            cnt++;
          }
        }
        if (cnt > 0 && sum * 2 >= cnt) {
          image.setPixelRgba(dstX, dstY, 0, 0, 0);
        }
      }
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
  ///
  /// [nameFontScale]/[priceFontScale] (v2.2.57+116): skala font user
  /// (1.0–3.0) — fontSize dasar 7.5 (nama) / 8 (harga) dikalikan skala.
  static pw.Widget pdfLabel({
    required String barcode,
    required String name,
    required int price,
    required bool showName,
    required bool showPrice,
    required bool showBarcode,
    double widthMm = defaultWidthMm,
    double heightMm = defaultHeightMm,
    double nameFontScale = 1.0,
    double priceFontScale = 1.0,
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

    // Nama — center, bold. fontSize diskalakan dari 7.5 (v2.2.57+116).
    if (showName && name.trim().isNotEmpty) {
      children.add(
        pw.Center(
          child: pw.Text(
            name,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7.5 * nameFontScale.clamp(1.0, 3.0),
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

    // Harga — center, bold. fontSize diskalakan dari 8 (v2.2.57+116).
    if (showPrice) {
      children.add(
        pw.Center(
          child: pw.Text(
            'Rp ${_formatPrice(price)}',
            style: pw.TextStyle(
              fontSize: 8 * priceFontScale.clamp(1.0, 3.0),
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
