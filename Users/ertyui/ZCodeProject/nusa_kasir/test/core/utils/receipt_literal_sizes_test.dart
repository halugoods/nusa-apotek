import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';

void main() {
  group('ukuran struk v2.2.23 (teks ESC/POS literal 12-36pt)', () {
    test('5 ukuran literal tersedia', () {
      expect(literalSizes, [12, 15, 18, 24, 36]);
    });

    test('literal → magnification = indeks + 1', () {
      expect(literalToMagnification(12), 1);
      expect(literalToMagnification(15), 2);
      expect(literalToMagnification(18), 3);
      expect(literalToMagnification(24), 4);
      expect(literalToMagnification(36), 5);
    });

    test('magnification → literal', () {
      expect(magnificationToLiteral(1), 12);
      expect(magnificationToLiteral(2), 15);
      expect(magnificationToLiteral(3), 18);
      expect(magnificationToLiteral(4), 24);
      expect(magnificationToLiteral(5), 36);
      // clamp keluar rentang
      expect(magnificationToLiteral(0), 12);
      expect(magnificationToLiteral(9), 36);
    });

    test('literalSpec: 15pt = Font B ×2, sisanya Font A ×1-×4', () {
      expect(literalSpec(12), (1, false));
      expect(literalSpec(15), (2, true));
      expect(literalSpec(18), (3, false));
      expect(literalSpec(24), (4, false));
      expect(literalSpec(36), (5, false));
    });

    test('receiptPreviewSize: 15pt tetap 15 (tidak dikali kompak)', () {
      expect(receiptPreviewSize(12), 12.0);
      expect(receiptPreviewSize(15), 15.0);
      expect(receiptPreviewSize(18), 18.0);
      expect(receiptPreviewSize(24), 24.0);
      expect(receiptPreviewSize(36), 36.0);
      // kompak (Font B) mengrampingkan 12/18/24/36, tapi 15pt tidak
      expect(receiptPreviewSize(12, kompak: true), 9.0);
      expect(receiptPreviewSize(15, kompak: true), 15.0);
      expect(receiptPreviewSize(24, kompak: true), 18.0);
    });

    test('label ukuran literal', () {
      expect(literalSizeLabel(12), 'Kecil');
      expect(literalSizeLabel(15), 'Sedang');
      expect(literalSizeLabel(18), 'Normal');
      expect(literalSizeLabel(24), 'Besar');
      expect(literalSizeLabel(36), 'Extra Besar');
    });
  });
}
