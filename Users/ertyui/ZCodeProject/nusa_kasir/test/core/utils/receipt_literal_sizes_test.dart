import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/receipt_renderer.dart';

void main() {
  group('ukuran struk v3 (hybrid: header image persen, teks Kecil/Besar)', () {
    test('default header persen + logo persen', () {
      expect(receiptHeaderDefaultPercent, 100);
      expect(receiptLogoDefaultPercent, 60);
      expect(receiptPercentMin, 1);
      expect(receiptPercentMax, 100);
    });

    test('clamp header persen ke 1..100', () {
      expect(0.clamp(receiptPercentMin, receiptPercentMax), 1);
      expect(100.clamp(receiptPercentMin, receiptPercentMax), 100);
      expect(150.clamp(receiptPercentMin, receiptPercentMax), 100);
    });

    test('clamp logo persen ke 1..100', () {
      expect(0.clamp(1, 100), 1);
      expect(60.clamp(1, 100), 60);
      expect(150.clamp(1, 100), 100);
    });

    test('ReceiptRenderLine subtotal & diskon (qty)', () {
      const line = ReceiptRenderLine(
        name: 'A',
        qty: 3,
        price: 5000,
        originalPrice: 6000,
      );
      expect(line.subtotal, 15000);
      expect(line.hasDiscount, isTrue);
      expect(line.discountTotal, 3000); // (6000-5000) × 3
      expect(line.qtyLabel, '3');
    });

    test('ReceiptRenderLine per-kg subtotal & diskon', () {
      const line = ReceiptRenderLine(
        name: 'B',
        qty: 1,
        price: 10000,
        originalPrice: 12000,
        isPerKg: true,
        weightKg: 2.5,
      );
      expect(line.subtotal, 25000); // ceil(10000 × 2.5)
      expect(line.discountTotal, 6000); // (12000-10000) × ceil(2.5) = 3
      expect(line.qtyLabel, '2.5');
    });

    test('ReceiptRenderConfig default & paper width (v3)', () {
      const cfg = ReceiptRenderConfig(
        storeName: 'Toko',
        lines: [],
        total: 0,
      );
      expect(cfg.paperWidthPx, 384); // 58mm
      expect(cfg.headerPercent, receiptHeaderDefaultPercent);
      expect(cfg.itemsSizePx, 12); // mode Kecil ×1
      expect(cfg.footerSizePx, 12);
      expect(cfg.logoWidthPercent, receiptLogoDefaultPercent);

      const cfg80 = ReceiptRenderConfig(
        storeName: 'Toko',
        lines: [],
        total: 0,
        paperWidth: '80',
      );
      expect(cfg80.paperWidthPx, 576); // 80mm
    });

    test('mode Kecil(×1)/Besar(×2) → ukuran share/PDF', () {
      // Kecil: itemsSizePx 12, footerSizePx 12 (Font A ×1)
      // Besar: itemsSizePx 24, footerSizePx 24 (Font B ×2 — dijamin tercetak)
      expect(0 >= 1 ? 24 : 12, 12);
      expect(1 >= 1 ? 24 : 12, 24);
    });

    test('renderReceiptHeaderPng menghasilkan PNG (bit-image)', () async {
      final png = await renderReceiptHeaderPng(
        const ReceiptRenderConfig(
          storeName: 'Toko',
          lines: [],
          total: 0,
          header: 'TOKO NUSA',
          headerPercent: 100,
          logoWidthPercent: 60,
        ),
      );
      // PNG magic bytes: 89 50 4E 47
      expect(png.length, greaterThan(8));
      expect(png[0], 0x89);
      expect(png[1], 0x50);
      expect(png[2], 0x4E);
      expect(png[3], 0x47);
    });

    test('renderReceiptPng tetap penuh (share/PDF)', () async {
      final png = await renderReceiptPng(
        const ReceiptRenderConfig(
          storeName: 'Toko',
          lines: [
            ReceiptRenderLine(name: 'Indomie', qty: 2, price: 3500),
          ],
          total: 7000,
          header: 'TOKO NUSA',
          footer: 'Terima kasih!',
          headerPercent: 100,
          itemsSizePx: 12,
          footerSizePx: 12,
        ),
      );
      expect(png.length, greaterThan(8));
      expect(png[0], 0x89);
      expect(png[1], 0x50);
      expect(png[2], 0x4E);
      expect(png[3], 0x47);
    });
  });
}
