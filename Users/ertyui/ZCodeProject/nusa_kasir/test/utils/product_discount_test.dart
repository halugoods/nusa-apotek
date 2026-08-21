import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/product_discount.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

void main() {
  Product _product({int sellPrice = 0, int discountPercent = 0, String discountType = 'persen'}) {
    return Product(
      id: 1,
      name: 'Test',
      sku: null,
      barcode: null,
      category: 'Umum',
      buyPrice: 0,
      sellPrice: sellPrice,
      discountPercent: discountPercent,
      discountType: discountType,
      stock: 0,
      minStock: 0,
      imagePath: null,
      isService: false,
      isOnline: false,
      expiryDate: null,
      productType: null,
      variantsJson: null,
      wholesaleJson: null,
      priceType: 'pcs',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('Diskon persen', () {
    test('10% dari 100.000 = 90.000', () {
      final p = _product(sellPrice: 100000, discountPercent: 10);
      expect(p.effectivePrice, 90000);
      expect(p.hasDiscount, isTrue);
      expect(p.discountLabel, '-10%');
    });

    test('0% = tanpa diskon', () {
      final p = _product(sellPrice: 50000);
      expect(p.effectivePrice, 50000);
      expect(p.hasDiscount, isFalse);
      expect(p.discountLabel, '');
    });
  });

  group('Diskon nominal (Rp)', () {
    test('Rp 10.000 dari 100.000 = 90.000', () {
      final p = _product(sellPrice: 100000, discountPercent: 10000, discountType: 'nominal');
      expect(p.effectivePrice, 90000);
      expect(p.hasDiscount, isTrue);
      expect(p.discountLabel, '-Rp 10.000');
    });

    test('nominal tidak boleh melebihi harga jual (clamp)', () {
      final p = _product(sellPrice: 20000, discountPercent: 50000, discountType: 'nominal');
      expect(p.effectivePrice, 0);
    });

    test('nominal tanpa nilai = tanpa diskon', () {
      final p = _product(sellPrice: 10000, discountType: 'nominal');
      expect(p.effectivePrice, 10000);
      expect(p.hasDiscount, isFalse);
    });
  });

  group('Perbedaan persen vs nominal', () {
    test('nilai sama, tipe beda → hasil beda', () {
      final persen = _product(sellPrice: 100000, discountPercent: 50);
      final nominal = _product(sellPrice: 100000, discountPercent: 50, discountType: 'nominal');
      expect(persen.effectivePrice, 50000);
      expect(nominal.effectivePrice, 99950);
    });
  });
}
