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
}
