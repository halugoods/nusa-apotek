import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final int productId;
  final String name;
  final int price;

  /// Harga jual sebelum diskon standalone per produk (null = tanpa diskon).
  /// Dipakai untuk menampilkan coret harga asli di keranjang.
  final int? originalPrice;

  /// Harga modal (cost) per unit. Hanya diisi untuk item manual (ad-hoc);
  /// produk reguler pakai buyPrice dari tabel produk saat hitung HPP.
  /// Tidak dipakai untuk harga jual — murni untuk laporan laba.
  final int? costPrice;
  int qty;
  String? note;

  /// Weight in kg — when non-null, pricing is per-kg (subtotal = price × weightKg).
  double? weightKg;
  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.originalPrice,
    this.costPrice,
    this.qty = 1,
    this.note,
    this.weightKg,
  });

  /// True for ad-hoc items added from the "+" manual sheet (not in the
  /// products table). These carry a synthetic NEGATIVE productId and are
  /// skipped by stock validation/deduction and report aggregation.
  bool get isManual => productId < 0;
  bool get isPerKg => weightKg != null;
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int get subtotal => isPerKg ? (price * weightKg!).ceil() : price * qty;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'qty': qty,
    'note': note,
    if (originalPrice != null) 'originalPrice': originalPrice,
    if (costPrice != null) 'costPrice': costPrice,
    if (weightKg != null) 'weightKg': weightKg,
  };
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Unique synthetic id for manual (non-product) items. Negative so it never
  /// collides with real product ids; reset on clear so lines are distinct.
  int _manualSeq = 0;
  void addProduct(
    int productId,
    String name,
    int price, {
    String? note,
    double? weightKg,
    int? originalPrice,
    int? costPrice,
    int qty = 1,
  }) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i >= 0) {
      final list = [...state];
      list[i] = CartItem(
        productId: productId,
        name: name,
        price: price,
        originalPrice: list[i].originalPrice,
        costPrice: list[i].costPrice ?? costPrice,
        qty: list[i].qty + qty,
        note: list[i].note ?? note,
        weightKg: list[i].weightKg ?? weightKg,
      );
      state = list;
    } else {
      state = [
        ...state,
        CartItem(
          productId: productId,
          name: name,
          price: price,
          originalPrice: originalPrice,
          costPrice: costPrice,
          note: note,
          weightKg: weightKg,
          qty: qty,
        ),
      ];
    }
  }

  void changeQty(int productId, int delta) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    final nq = list[i].qty + delta;
    if (nq <= 0)
      list.removeAt(i);
    else
      list[i] = CartItem(
        productId: productId,
        name: list[i].name,
        price: list[i].price,
        originalPrice: list[i].originalPrice,
        costPrice: list[i].costPrice,
        qty: nq,
        note: list[i].note,
        weightKg: list[i].weightKg,
      );
    state = list;
  }

  /// Set qty langsung (dari kolom qty editable di kartu grid POS).
  /// qty <= 0 menghapus item; weightKg (per-kg) dipertahankan.
  void setQty(int productId, int qty) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    if (qty <= 0) {
      list.removeAt(i);
    } else {
      list[i] = CartItem(
        productId: productId,
        name: list[i].name,
        price: list[i].price,
        originalPrice: list[i].originalPrice,
        costPrice: list[i].costPrice,
        qty: qty,
        note: list[i].note,
        weightKg: list[i].weightKg,
      );
    }
    state = list;
  }

  /// Add an ad-hoc item that has no row in the products table (e.g. "jasa
  /// angkut"). Gets a fresh synthetic NEGATIVE id so it never merges with a
  /// real product and each manual line stays distinct.
  /// [costPrice] = harga modal per unit (opsional) — dipakai laporan HPP/laba.
  void addManualItem(String name, int price, {int qty = 1, int? costPrice}) {
    _manualSeq--;
    addProduct(_manualSeq, name, price, qty: qty, costPrice: costPrice);
  }

  void setNote(int productId, String? note) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    list[i] = CartItem(
      productId: list[i].productId,
      name: list[i].name,
      price: list[i].price,
      originalPrice: list[i].originalPrice,
      costPrice: list[i].costPrice,
      qty: list[i].qty,
      note: note,
      weightKg: list[i].weightKg,
    );
    state = list;
  }

  /// Set weight (kg) for a per-kg product. Setting null reverts to pcs mode.
  void setWeight(int productId, double? weightKg) {
    final i = state.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final list = [...state];
    list[i] = CartItem(
      productId: list[i].productId,
      name: list[i].name,
      price: list[i].price,
      originalPrice: list[i].originalPrice,
      costPrice: list[i].costPrice,
      qty: weightKg == null ? list[i].qty : 1,
      note: list[i].note,
      weightKg: weightKg,
    );
    state = list;
  }

  void remove(int productId) =>
      state = state.where((e) => e.productId != productId).toList();
  void clear() {
    _manualSeq = 0;
    state = [];
  }

  int get total => state.fold(0, (s, e) => s + e.subtotal);
  int get count => state.fold(0, (s, e) => s + e.qty);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);
