import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final int productId;
  final String name;
  final int price;
  int qty;
  CartItem({required this.productId, required this.name, required this.price, this.qty = 1});
  int get subtotal => price * qty;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);
  void addProduct(int productId, String name, int price) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i >= 0) { final list = [...state]; list[i] = CartItem(productId: productId, name: name, price: price, qty: list[i].qty + 1); state = list; }
    else { state = [...state, CartItem(productId: productId, name: name, price: price)]; }
  }
  void changeQty(int productId, int delta) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    final nq = list[i].qty + delta;
    if (nq <= 0) list.removeAt(i); else list[i] = CartItem(productId: productId, name: list[i].name, price: list[i].price, qty: nq);
    state = list;
  }
  void remove(int productId) => state = state.where((e) => e.productId != productId).toList();
  void clear() => state = [];
  int get total => state.fold(0, (s, e) => s + e.subtotal);
  int get count => state.fold(0, (s, e) => s + e.qty);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
