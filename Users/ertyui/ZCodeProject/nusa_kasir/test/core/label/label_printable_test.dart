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
        if (x > pMaxX(maxX, x)) maxX = x;
      }
    }
  }
  return (minX, maxX);
}

int pMaxX(int cur, int x) => x > cur ? x : cur;

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
      final (pMinX, pMaxX) = blackExtentXIn(bitmap, bitmap.height - 24, bitmap.height);
      final mid = (pMinX + pMaxX) / 2;
      expect(mid, closeTo(192, 5),
          reason: 'pusat printable = 384/2 = 192 — tidak geser kanan');
      // ignore: avoid_print
      print('Harga struk: mid=$mid (pusat 192)');
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
      // Center area cetak: pusat = 8 + (320-8-16)/2 = 160.
      final (pMinX, pMaxX) = blackExtentXIn(bitmap, bitmap.height - 24, bitmap.height);
      final mid = (pMinX + pMaxX) / 2;
      expect(mid, closeTo(160, 5),
          reason: 'teks center pada pusat area cetak, bukan geser kanan');
      // ignore: avoid_print
      print('TSPL 40mm: minX=$minX maxX=$maxX harga mid=$mid');
    });
  });
}
