import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final int productId;
  final String name;
  final int price;
  int qty;
  String? note;
  /// Weight in kg — when non-null, pricing is per-kg (subtotal = price × weightKg).
  double? weightKg;
  CartItem({required this.productId, required this.name, required this.price, this.qty = 1, this.note, this.weightKg});

  bool get isPerKg => weightKg != null;
  int get subtotal => isPerKg ? (price * weightKg!).ceil() : price * qty;

  Map<String, dynamic> toJson() => {
    'productId': productId, 'name': name, 'price': price,
    'qty': qty, 'note': note,
    if (weightKg != null) 'weightKg': weightKg,
  };
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);
  void addProduct(int productId, String name, int price, {String? note, double? weightKg}) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i >= 0) { final list = [...state]; list[i] = CartItem(productId: productId, name: name, price: price, qty: list[i].qty + 1, note: list[i].note ?? note, weightKg: list[i].weightKg ?? weightKg); state = list; }
    else { state = [...state, CartItem(productId: productId, name: name, price: price, note: note, weightKg: weightKg)]; }
  }
  void changeQty(int productId, int delta) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    final nq = list[i].qty + delta;
    if (nq <= 0) list.removeAt(i); else list[i] = CartItem(productId: productId, name: list[i].name, price: list[i].price, qty: nq, note: list[i].note, weightKg: list[i].weightKg);
    state = list;
  }
  void setNote(int productId, String? note) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    list[i] = CartItem(productId: list[i].productId, name: list[i].name, price: list[i].price, qty: list[i].qty, note: note, weightKg: list[i].weightKg);
    state = list;
  }
  /// Set weight (kg) for a per-kg product. Setting null reverts to pcs mode.
  void setWeight(int productId, double? weightKg) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    list[i] = CartItem(productId: list[i].productId, name: list[i].name, price: list[i].price, qty: weightKg == null ? list[i].qty : 1, note: list[i].note, weightKg: weightKg);
    state = list;
  }
  void remove(int productId) => state = state.where((e) => e.productId != productId).toList();
  void clear() => state = [];
  int get total => state.fold(0, (s, e) => s + e.subtotal);
  int get count => state.fold(0, (s, e) => s + e.qty);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
