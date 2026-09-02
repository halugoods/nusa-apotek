// Regressi jalur cetak label — crop kanan + centering (v2.2.57+128).
//
// Latar: user laporkan "barcode ke crop, bagian kanan ada bar yg ga ke cetak"
// + "nama produk dan harga ky ga center, lebih ke kanan". Root cause: jalur
// STRUK dirender selebar kertas FISIK (58mm → 462px) padahal printer struk
// hanya mencetak 384 dot (48mm) → 78 dot kanan dibuang printer, dan konten
// di-center pada pusat 462px tampak geser ±5mm ke kanan di kertas.
//
// Konvensi printable (sama dengan receipt renderer): 58mm = 384 dot,
// 80mm = 576 dot. Jalur LABEL (TSPL) tetap margin kanan besar (crop print
// head die-cut) dengan teks di-center pada pusat AREA CETAK.
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nusa_kasir/core/label/label_renderer.dart';

/// Bounding box piksel hitam (kiri & kanan terjauh) di [image].
(int, int) blackExtentX(img.Image image) {
  var minX = image.width, maxX = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if ((img.getRed(p) + img.getGreen(p) + img.getBlue(p)) < 384) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
  }
  return (minX, maxX);
}

/// Bounding box hitam pada rentang baris [y0, y1) — untuk mengukur elemen
/// tertentu (mis. baris harga).
(int, int) blackExtentXIn(img.Image image, int y0, int y1) {
  var minX = image.width, maxX = -1;
  for (var y = y0; y < y1 && y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if ((img.getRed(p) + img.getGreen(p) + img.getBlue(p)) < 384) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
  }
  return (minX, maxX);
}

/// Band baris terbawah yang berisi piksel hitam (blok teks harga — baris
/// dipindai dari bawah, diberi toleransi gap 2 baris antar baris glyph).
/// Return (y0, y1, minX, maxX); empty → minX > maxX.
(int, int, int, int) lowestInkBand(img.Image image) {
  var minY = -1, maxY = -1, minX = image.width, maxX = -1;
  for (var y = image.height - 1; y >= 0; y--) {
    final (_, rowMax) = blackExtentXIn(image, y, y + 1);
    final hasInk = rowMax >= 0;
    if (hasInk) {
      if (maxY == -1) maxY = y;
      minY = y;
    } else if (maxY != -1 && maxY - y > 2) {
      break; // band selesai (gap > 2 baris di bawah elemen atasnya)
    }
  }
  if (maxY == -1) return (-1, -1, image.width, -1);
  (minX, maxX) = blackExtentXIn(image, minY, maxY + 1);
  return (minY, maxY, minX, maxX);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v2.2.57+128 — printable struk (384 dot @58mm)', () {
    test('strukPrintablePx konvensi 58/80mm', () {
      expect(LabelRenderer.strukPrintablePx(paperMm: 58), 384);
      expect(LabelRenderer.strukPrintablePx(paperMm: 80), 576);
    });

    test('renderStrukLabelBitmap @58mm: lebar 384, barcode rata kiri-kanan',
        () {
      final bitmap = LabelRenderer.renderStrukLabelBitmap(
        barcode: '8991234567890',
        name: 'PRODUK A',
        price: 12500,
        showName: true,
        showPrice: true,
        showBarcode: true,
        paperMm: 58,
      );
      expect(bitmap.width, 384, reason: 'printable 58mm = 384 dot');
      final (minX, maxX) = blackExtentX(bitmap);
      // Barcode full-width: bar terjauh kanan-kiri ±margin simetris 8px
      // (≈1mm quiet zone Code128) dari EDGE printable.
      expect(minX, lessThanOrEqualTo(10), reason: 'baris kiri sampai tepi');
      expect(maxX, greaterThanOrEqualTo(373),
          reason: 'baris kanan sampai tepi (384-8-3 rounding)');
      // ignore: avoid_print
      print('STRUK 58mm: width=${bitmap.width} minX=$minX maxX=$maxX');
    });

    test('nama & harga center pada pusat printable (192 @384px)', () {
      final bitmap = LabelRenderer.renderStrukLabelBitmap(
        barcode: '8991234567890',
        name: 'PRODUK A',
        price: 12500,
        showName: true,
        showPrice: true,
        showBarcode: true,
        paperMm: 58,
      );
      // Ukur BAND TEKS TERBAWAH (blok harga) — bukan N baris terbawah
      // mentah: kalau region kosong, (minX+maxX)/2 = (width-1)/2 = trivial
      // pass (bug test lama: asersi jalan tanpa mengukur apa pun).
      final (y0, y1, pMinX, pMaxX) = lowestInkBand(bitmap);
      expect(y0, greaterThan(0), reason: 'baris harga harus ada');
      final mid = (pMinX + pMaxX) / 2;
      expect(mid, closeTo(192, 5),
          reason: 'pusat printable = 384/2 = 192 — tidak geser kanan');
      // ignore: avoid_print
      print('Harga struk: band=$y0..$y1 minX=$pMinX maxX=$pMaxX mid=$mid');
    });

    test('renderStrukLabelBitmap @80mm: lebar 576', () {
      final bitmap = LabelRenderer.renderStrukLabelBitmap(
        barcode: '8991234567890',
        name: 'PRODUK A',
        price: 12500,
        showName: true,
        showPrice: true,
        showBarcode: true,
        paperMm: 80,
      );
      expect(bitmap.width, 576);
      final (minX, maxX) = blackExtentX(bitmap);
      expect(minX, lessThanOrEqualTo(10));
      expect(maxX, greaterThanOrEqualTo(565));
    });
  });

  group('v2.2.57+128 — jalur LABEL TSPL (margin kanan crop dipertahankan)', () {
    test('barcode 40mm berhenti sebelum margin kanan 16px; teks center area cetak', () {
      final bitmap = LabelRenderer.renderLabelBitmap(
        barcode: '8991234567890',
        name: 'PRODUK A',
        price: 12500,
        showName: true,
        showPrice: true,
        showBarcode: true,
        widthPx: 320,
        heightPx: 240,
      );
      final (minX, maxX) = blackExtentX(bitmap);
      expect(maxX, lessThanOrEqualTo(320 - 1 - 16),
          reason: 'guard margin kanan 16px tetap aktif di jalur label');
      // Center area cetak: pusat = 8 + (320-8-16)/2 = 160. Band teks
      // terbawah (blok harga) diukur nyata — region kosong = mid trivial.
      final (y0, y1, pMinX, pMaxX) = lowestInkBand(bitmap);
      expect(y0, greaterThan(0), reason: 'baris harga harus ada');
      final mid = (pMinX + pMaxX) / 2;
      expect(mid, closeTo(160, 5),
          reason: 'teks center pada pusat area cetak, bukan geser kanan');
      // ignore: avoid_print
      print('TSPL 40mm: minX=$minX maxX=$maxX harga band=$y0..$y1 mid=$mid');
    });

    test('barcode TSPL center VISUAL terhadap area cetak (bukan kapalioff)', () {
      // Barcode pendek: konten harus center pada pusat area cetak
      // [8..304] → pusat 156, bukan canvas center 160.
      final bitmap = LabelRenderer.renderLabelBitmap(
        barcode: '8991234567890',
        name: 'PRODUK A',
        price: 12500,
        showName: false, // isolasi band barcode (ink teratas)
        showPrice: false,
        showBarcode: true,
        widthPx: 320,
        heightPx: 240,
      );
      // Barcode = satu-satunya tinta → extent global = extent barcode.
      final (minX, maxX) = blackExtentX(bitmap);
      final mid = (minX + maxX) / 2;
      expect(mid, closeTo(156, 5),
          reason: 'pusat area cetak TSPL = 8 + (320-8-16)/2 = 156');
      // ignore: avoid_print
      print('TSPL barcode: minX=$minX maxX=$maxX mid=$mid (pusat 156)');
    });
  });
}
