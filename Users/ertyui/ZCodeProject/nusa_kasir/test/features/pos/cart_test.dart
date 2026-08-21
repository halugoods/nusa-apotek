import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/features/pos/cart.dart';

void main() {
  test('manual item carries costPrice through addManualItem', () {
    final n = CartNotifier();
    n.addManualItem('Jasa angkut', 15000, qty: 2, costPrice: 10000);
    final item = n.state.single;
    expect(item.isManual, isTrue);
    expect(item.productId, lessThan(0));
    expect(item.price, 15000);
    expect(item.costPrice, 10000);
    expect(item.qty, 2);
    expect(item.subtotal, 30000);
  });

  test('manual item without costPrice keeps null', () {
    final n = CartNotifier();
    n.addManualItem('Biaya parkir', 5000);
    expect(n.state.single.costPrice, isNull);
  });

  test('toJson includes costPrice only when set', () {
    final n = CartNotifier();
    n.addManualItem('Jasa', 10000, costPrice: 7000);
    final json = n.state.single.toJson();
    expect(json['costPrice'], 7000);
    expect(json['productId'], lessThan(0));

    n.clear();
    n.addManualItem('Jasa 2', 10000);
    expect(n.state.single.toJson().containsKey('costPrice'), isFalse);
  });

  test('qty merge preserves costPrice', () {
    final n = CartNotifier();
    n.addManualItem('Jasa', 10000, costPrice: 7000);
    n.changeQty(n.state.single.productId, 1);
    final item = n.state.single;
    expect(item.qty, 2);
    expect(item.costPrice, 7000);
    expect(item.subtotal, 20000);
  });

  test('two manual items in one cart get distinct ids', () {
    final n = CartNotifier();
    n.addManualItem('A', 1000);
    n.addManualItem('B', 2000);
    expect(n.state.length, 2);
    expect(n.state[0].productId, isNot(n.state[1].productId));
    expect(n.state[0].productId, lessThan(0));
    expect(n.state[1].productId, lessThan(0));
    // Lines stay separate — no merging of same-name manual items
    expect(n.state[0].qty, 1);
    expect(n.state[1].qty, 1);
  });

  group('Varian (v2.2.43)', () {
    test('variant items do not merge across different variants', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      n.addProduct(1, 'Kopi', 15000, variantName: 'Mentai');
      expect(n.state.length, 2);
      expect(n.state[0].variantName, 'Original');
      expect(n.state[1].variantName, 'Mentai');
    });

    test('same variant merges qty', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      expect(n.state.length, 1);
      expect(n.state.single.qty, 2);
    });

    test('setVariant switches variant on the line', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000);
      n.setVariant(1, 'Original', 17000, 2000, 10);
      final item = n.state.single;
      expect(item.variantName, 'Original');
      expect(item.price, 17000);
      expect(item.variantPriceAdjustment, 2000);
      expect(item.variantStock, 10);
      expect(item.displayName, 'Kopi — Original');
    });

    test('changeQty with variant targets only that line', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      n.addProduct(1, 'Kopi', 15000, variantName: 'Mentai');
      n.changeQty(1, 1, variantName: 'Original');
      expect(n.state[0].qty, 2);
      expect(n.state[1].qty, 1);
    });

    test('toJson includes variant fields', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Mentai',
          variantPriceAdjustment: 5000, variantStock: 3);
      final json = n.state.single.toJson();
      expect(json['variantName'], 'Mentai');
      expect(json['variantPriceAdjustment'], 5000);
      expect(json['variantStock'], 3);
    });
  });

  group('Satuan dinamis (v2.2.43)', () {
    test('default unit is pcs with qtyPerBase 1', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 20000);
      expect(n.state.single.unitName, isNull);
      expect(n.state.single.unitQtyPerBase, 1);
      expect(n.state.single.qtyInBase, 1);
    });

    test('setUnit changes qtyInBase for stock math', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 20000);
      n.setUnit(1, 'dus', 12);
      final item = n.state.single;
      expect(item.unitName, 'dus');
      expect(item.qtyInBase, 12);
      // qty utuh tetap dalam satuan jual
      expect(item.qty, 1);
      expect(item.qtyLabel, '1 dus (12 pcs)');
    });

    test('qtyLabel simple when qtyPerBase is 1', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 5000);
      n.setUnit(1, 'pcs', 1);
      expect(n.state.single.qtyLabel, '1 pcs');
    });

    test('toJson includes unitName only when set', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 20000);
      expect(n.state.single.toJson().containsKey('unitName'), isFalse);
      n.setUnit(1, 'dus', 12);
      final json = n.state.single.toJson();
      expect(json['unitName'], 'dus');
      expect(json['unitQtyPerBase'], 12);
    });
  });
}
