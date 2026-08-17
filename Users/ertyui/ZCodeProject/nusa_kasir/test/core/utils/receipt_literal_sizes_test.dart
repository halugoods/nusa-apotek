import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/receipt_header_renderer.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';

void main() {
  group('ukuran struk v2.2.27 (2 pilihan ×1/×2 + header image)', () {
    test('rincian/footer hanya 2 pilihan perbesaran', () {
      expect(receiptItemsMinMag, 1);
      expect(receiptItemsMaxMag, 2);
    });

    test('receiptPreviewSize: ×1 = 11px, ×2 = 13px (standar)', () {
      expect(receiptPreviewSize(1), 11.0);
      expect(receiptPreviewSize(2), 13.0);
    });

    test('receiptPreviewSize: kompak lebih ramping', () {
      expect(receiptPreviewSize(1, kompak: true), 10.0);
      expect(receiptPreviewSize(2, kompak: true), 14.0);
    });

    test('receiptPreviewSize clamp ke 1-2 (nilai basi lama diabaikan)', () {
      expect(receiptPreviewSize(5), 13.0);
      expect(receiptPreviewSize(0), 11.0);
    });

    test('header px: rentang slider 12-48, default 24', () {
      expect(receiptHeaderMinPx, 12);
      expect(receiptHeaderMaxPx, 48);
      expect(receiptHeaderDefaultPx, 24);
    });

    test('lebar kertas header image: 58mm=384, 80mm=576', () {
      expect(receiptPaperWidthPx('58'), 384);
      expect(receiptPaperWidthPx('80'), 576);
    });
  });
}
