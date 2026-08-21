import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final int productId;
  final String name;
  final int price;

  /// Varian produk (rasa/ukuran). Null = produk reguler / belum pilih varian.
  final String? variantName;

  /// Selisih harga varian terhadap harga dasar produk.
  final int variantPriceAdjustment;

  /// Stok khusus varian (dari variantsJson). Null = pakai stok produk.
  final int? variantStock;

  /// Satuan jual terpilih (v2.2.43 satuan dinamis). Null = fallback 'pcs'.
  final String? unitName;

  /// Berapa satuan dasar per satuan jual (mis. dus=12 → 12 pcs). Default 1.
  final double unitQtyPerBase;

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
    this.variantName,
    this.variantPriceAdjustment = 0,
    this.variantStock,
    this.unitName,
    this.unitQtyPerBase = 1,
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

  /// Nama tampilan: produk + varian ("Nama — Varian").
  String get displayName => variantName == null || variantName!.isEmpty
      ? name
      : '$name — $variantName';

  /// Jumlah dalam satuan dasar (qty × qtyPerBase). Dipakai untuk stok
  /// tidak-satuan-dasar & HPP/laporan — qty tetap utuh dalam satuan jual.
  int get qtyInBase => (qty * unitQtyPerBase).round();

  /// Label qty untuk struk/keranjang: "2 dus (24 pcs)" atau "2". Kalau satuan
  /// dasar == satuan jual (qtyPerBase 1, nama sama) cukup tampil qty biasa.
  String get qtyLabel {
    if (unitName == null || unitName!.isEmpty) return '$qty';
    final qtyPart = '$qty $unitName';
    if (unitQtyPerBase <= 1) return qtyPart;
    return '$qtyPart (${qtyInBase} pcs)';
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'qty': qty,
    'note': note,
    if (variantName != null) 'variantName': variantName,
    if (variantPriceAdjustment != 0)
      'variantPriceAdjustment': variantPriceAdjustment,
    if (variantStock != null) 'variantStock': variantStock,
    if (unitName != null) 'unitName': unitName,
    if (unitQtyPerBase != 1) 'unitQtyPerBase': unitQtyPerBase,
    if (originalPrice != null) 'originalPrice': originalPrice,
    if (costPrice != null) 'costPrice': costPrice,
    if (weightKg != null) 'weightKg': weightKg,
  };

  /// Copy helper untuk update qty/varian tanpa menulis ulang semua field.
  CartItem copyWith({
    String? variantName,
    int? variantPriceAdjustment,
    int? variantStock,
    String? unitName,
    double? unitQtyPerBase,
    int? price,
    int? originalPrice,
    int? costPrice,
    int? qty,
    String? note,
    double? weightKg,
  }) => CartItem(
    productId: productId,
    name: name,
    price: price ?? this.price,
    variantName: variantName ?? this.variantName,
    variantPriceAdjustment:
        variantPriceAdjustment ?? this.variantPriceAdjustment,
    variantStock: variantStock ?? this.variantStock,
    unitName: unitName ?? this.unitName,
    unitQtyPerBase: unitQtyPerBase ?? this.unitQtyPerBase,
    originalPrice: originalPrice ?? this.originalPrice,
    costPrice: costPrice ?? this.costPrice,
    qty: qty ?? this.qty,
    note: note ?? this.note,
    weightKg: weightKg ?? this.weightKg,
  );
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
    String? variantName,
    int variantPriceAdjustment = 0,
    int? variantStock,
    String? unitName,
    double unitQtyPerBase = 1,
  }) {
    // Merge key: productId + varian (baris varian berbeda tidak digabung).
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i >= 0) {
      final list = [...state];
      list[i] = CartItem(
        productId: productId,
        name: name,
        price: price,
        variantName: variantName,
        variantPriceAdjustment: variantPriceAdjustment,
        variantStock: variantStock ?? list[i].variantStock,
        unitName: unitName ?? list[i].unitName,
        unitQtyPerBase: unitQtyPerBase != 1 ? unitQtyPerBase : list[i].unitQtyPerBase,
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
          variantName: variantName,
          variantPriceAdjustment: variantPriceAdjustment,
          variantStock: variantStock,
          unitName: unitName,
          unitQtyPerBase: unitQtyPerBase,
          originalPrice: originalPrice,
          costPrice: costPrice,
          note: note,
          weightKg: weightKg,
          qty: qty,
        ),
      ];
    }
  }

  /// Set varian pada baris keranjang (produk ber-varian). Harga mengikuti
  /// harga dasar + adjustment varian; originalPrice dipertahankan.
  void setVariant(
    int productId,
    String variantName,
    int price,
    int adjustment,
    int? variantStock,
  ) {
    final i = state.indexWhere(
      (e) => e.productId == productId && (e.variantName == null || e.variantName == variantName),
    );
    if (i < 0) return;
    final list = [...state];
    final item = list[i];
    list[i] = CartItem(
      productId: productId,
      name: item.name,
      price: price,
      variantName: variantName,
      variantPriceAdjustment: adjustment,
      variantStock: variantStock,
      originalPrice: item.originalPrice,
      costPrice: item.costPrice,
      qty: item.qty,
      note: item.note,
      weightKg: item.weightKg,
    );
    state = list;
  }

  /// Set satuan jual pada baris keranjang (satuan dinamis v2.2.43).
  /// [unitName] mis. "dus", [qtyPerBase] mis. 12 → qty tetap utuh di dus,
  /// qtyInBase = qty × 12 untuk stok & laporan.
  void setUnit(int productId, String? unitName, double qtyPerBase,
      {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].copyWith(unitName: unitName, unitQtyPerBase: qtyPerBase);
    state = list;
  }

  void changeQty(int productId, int delta, {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    final nq = list[i].qty + delta;
    if (nq <= 0)
      list.removeAt(i);
    else
      list[i] = list[i].copyWith(qty: nq);
    state = list;
  }

  /// Set qty langsung (dari kolom qty editable di kartu grid POS).
  /// qty <= 0 menghapus item; weightKg (per-kg) dipertahankan.
  void setQty(int productId, int qty, {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    if (qty <= 0) {
      list.removeAt(i);
    } else {
      list[i] = list[i].copyWith(qty: qty);
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

  void setNote(int productId, String? note, {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].copyWith(note: note);
    state = list;
  }

  /// Set weight (kg) for a per-kg product. Setting null reverts to pcs mode.
  void setWeight(int productId, double? weightKg, {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].copyWith(
      qty: weightKg == null ? list[i].qty : 1,
      weightKg: weightKg,
    );
    state = list;
  }

  void remove(int productId, {String? variantName}) => state = state
      .where(
        (e) => !(e.productId == productId && e.variantName == variantName),
      )
      .toList();
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
