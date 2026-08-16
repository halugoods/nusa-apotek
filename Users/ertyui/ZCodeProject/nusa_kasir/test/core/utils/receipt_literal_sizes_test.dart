import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';

void main() {
  group('literalSizes (5 ukuran: 12/15/18/24/36)', () {
    test('berisi 5 ukuran literal', () {
      expect(literalSizes, [12, 15, 18, 24, 36]);
    });

    test('konversi literal → perbesaran', () {
      expect(literalToMagnification(12), 1);
      expect(literalToMagnification(15), 2); // Font B ×2
      expect(literalToMagnification(18), 3);
      expect(literalToMagnification(24), 4);
      expect(literalToMagnification(36), 5);
    });

    test('konversi perbesaran → literal', () {
      expect(magnificationToLiteral(1), 12);
      expect(magnificationToLiteral(2), 15);
      expect(magnificationToLiteral(3), 18);
      expect(magnificationToLiteral(4), 24);
      expect(magnificationToLiteral(5), 36);
    });

    test('magnificationToLiteral clamp di luar range', () {
      expect(magnificationToLiteral(0), 12);
      expect(magnificationToLiteral(6), 36);
      expect(magnificationToLiteral(99), 36);
    });

    test('label semua ukuran ada dan unik', () {
      for (final s in literalSizes) {
        expect(literalSizeLabel(s).isNotEmpty, isTrue, reason: 'label $s pt');
      }
      expect(literalSizes.toSet().length, literalSizes.length);
    });
  });
}
