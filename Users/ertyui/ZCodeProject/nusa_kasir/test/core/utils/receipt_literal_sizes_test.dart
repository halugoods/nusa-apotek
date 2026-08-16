import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/receipt_renderer.dart';

void main() {
  group('ukuran struk v2 (bit-image, pixel 12-48)', () {
    test('default ukuran header/rincian/footer + logo', () {
      expect(receiptHeaderDefaultPx, 24);
      expect(receiptItemsDefaultPx, 12);
      expect(receiptFooterDefaultPx, 12);
      expect(receiptLogoDefaultPercent, 60);
      expect(receiptMinPx, 12);
      expect(receiptMaxPx, 48);
    });

    test('clamp ukuran pixel ke 12..48', () {
      expect(0.clamp(receiptMinPx, receiptMaxPx), 12);
      expect(24.clamp(receiptMinPx, receiptMaxPx), 24);
      expect(99.clamp(receiptMinPx, receiptMaxPx), 48);
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

    test('ReceiptRenderConfig default & paper width', () {
      const cfg = ReceiptRenderConfig(
        storeName: 'Toko',
        lines: [],
        total: 0,
      );
      expect(cfg.paperWidthPx, 384); // 58mm
      expect(cfg.headerSizePx, receiptHeaderDefaultPx);
      expect(cfg.itemsSizePx, receiptItemsDefaultPx);
      expect(cfg.footerSizePx, receiptFooterDefaultPx);
      expect(cfg.logoWidthPercent, receiptLogoDefaultPercent);

      const cfg80 = ReceiptRenderConfig(
        storeName: 'Toko',
        lines: [],
        total: 0,
        paperWidth: '80',
      );
      expect(cfg80.paperWidthPx, 576); // 80mm
    });
  });
}
