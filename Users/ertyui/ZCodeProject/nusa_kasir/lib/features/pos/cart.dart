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

  /// HARGA SEMENTARA per unit (v2.2.57+116) — diskon manual per produk dari
  /// bottom-sheet "Ubah Harga" di keranjang. Mengganti [price] untuk
  /// subtotal & transaksi, originalPrice tetap jadi coret. Null = pakai
  /// harga normal [price].
  final int? tempPrice;

  /// Diskon nominal per SATUAN (qty) (v2.2.57+116) — dari bottom-sheet
  /// "Ubah Diskon". Dipotong dari harga per unit; total potongan =
  /// discountPerItem × qty. Tampil sebagai baris "Disc." di struk.
  final int? discountPerItem;

  /// Tampilkan baris produk ini di struk cetak (v2.2.57+116). Default true.
  /// Saat false, item TIDAK dicetak di struk (opsi "informasikan di struk").
  final bool showInReceipt;

  /// Harga modal (cost) per unit. Hanya diisi untuk item manual (ad-hoc);
  /// produk reguler pakai buyPrice dari tabel produk saat hitung HPP.
  /// Tidak dipakai untuk harga jual — murni untuk laporan laba.
  final int? costPrice;
  int qty;
  String? note;

  /// Berat dalam kg — saat non-null, harga per-kg (subtotal = price × weightKg).
  double? weightKg;

  /// B10 (v2.2.44): baris = LAYANAN (isService) — tidak dilacak stoknya
  /// (skip guard & decrement saat checkout).
  final bool isService;
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
    this.tempPrice,
    this.discountPerItem,
    this.showInReceipt = true,
    this.costPrice,
    this.qty = 1,
    this.note,
    this.weightKg,
    this.isService = false,
  });

  /// True for ad-hoc items added from the "+" manual sheet (not in the
  /// products table). These carry a synthetic NEGATIVE productId and are
  /// skipped by stock validation/deduction and report aggregation.
  bool get isManual => productId < 0;
  bool get isPerKg => weightKg != null;

  /// Harga per unit yang dipakai transaksi — tempPrice (harga sementara)
  /// lebih tinggi prioritasnya dari harga normal [price] (v2.2.57+116).
  int get unitPrice => tempPrice ?? price;

  /// True bila item memakai harga sementara ATAU harga normal turun
  /// (diskon grosir/standalone) — menampilkan coret di keranjang.
  bool get hasDiscount {
    final base = originalPrice;
    if (base == null) return false;
    return base > unitPrice || discountPerItem != null;
  }

  /// Potongan diskon per SATUAN (gabungan harga sementara + diskon per qty).
  /// Dipakai subtotal & baris "Disc." di struk.
  int get effectiveDiscountPerItem =>
      ((originalPrice ?? unitPrice) - unitPrice).clamp(0, (originalPrice ?? unitPrice)) +
      (discountPerItem ?? 0);

  /// Nominal total diskon item (per satuan × qty / berat).
  int get itemDiscountTotal => (effectiveDiscountPerItem *
          (isPerKg ? 1 : qty));

  /// Subtotal — harga SEMENTARA (tempPrice) bila ada, sisanya [price].
  /// Diskon per satuan TIDAK dikurangkan di sini (dipotong di transaksi
  /// total via [itemDiscountTotal], konsisten baris "Disc." struk).
  int get subtotal {
    final base = isPerKg ? (unitPrice * weightKg!).ceil() : unitPrice * qty;
    return base;
  }

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
    if (tempPrice != null) 'tempPrice': tempPrice,
    if (discountPerItem != null) 'discountPerItem': discountPerItem,
    if (!showInReceipt) 'showInReceipt': false,
    if (costPrice != null) 'costPrice': costPrice,
    if (weightKg != null) 'weightKg': weightKg,
    if (isService) 'isService': isService,
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
    int? tempPrice,
    int? discountPerItem,
    bool? showInReceipt,
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
    tempPrice: tempPrice ?? this.tempPrice,
    discountPerItem: discountPerItem ?? this.discountPerItem,
    showInReceipt: showInReceipt ?? this.showInReceipt,
    costPrice: costPrice ?? this.costPrice,
    qty: qty ?? this.qty,
    note: note ?? this.note,
    weightKg: weightKg ?? this.weightKg,
    isService: isService,
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
    bool isService = false,
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
        tempPrice: list[i].tempPrice,
        discountPerItem: list[i].discountPerItem,
        showInReceipt: list[i].showInReceipt,
        costPrice: list[i].costPrice ?? costPrice,
        qty: list[i].qty + qty,
        note: list[i].note ?? note,
        weightKg: list[i].weightKg ?? weightKg,
        isService: list[i].isService || isService,
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
          isService: isService,
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
      tempPrice: item.tempPrice,
      discountPerItem: item.discountPerItem,
      showInReceipt: item.showInReceipt,
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

  /// Recompute the per-unit price of an item from its wholesale tiers.
  ///
  /// [wholesalePriceForQty] returns the best wholesale price for a given qty
  /// (in base units) or null when the item has no applicable wholesale tier.
  /// [normalPrice] = harga jual biasa (effectivePrice) — dipakai saat tidak
  /// ada tier yang terpenuhi. [fullPrice] = harga sebelum diskon (sellPrice)
  /// — baseline coret saat grosir aktif (konsisten dengan _addToCart).
  ///
  /// Fix grosir (v2.2.44): sebelumnya `-` dan qty editable TIDAK pernah
  /// menghitung ulang harga grosir → harga "beku" di tier tinggi walau qty
  /// sudah turun di bawah ambang. Sekarang semua jalur (decrement, setQty,
  /// ganti varian, ganti satuan) lewat sini supaya harga selalu sinkron qty.
  void recomputeWholesale(
    int productId, {
    required int? Function(int qtyInBase) wholesalePriceForQty,
    required int normalPrice,
    required int fullPrice,
    String? variantName,
  }) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0 || state[i].isManual || state[i].isPerKg) return;
    final list = [...state];
    final item = list[i];
    final wPrice = wholesalePriceForQty(item.qtyInBase);
    final newPrice = wPrice ?? normalPrice;
    // Coret harga asli tampil saat grosir aktif ATAU produk punya diskon
    // standalone (normal < full). Konsisten dengan _addToCart.
    final hasStandaloneDiscount = normalPrice < fullPrice;
    final newOriginal = (wPrice != null || hasStandaloneDiscount)
        ? fullPrice
        : null;
    if (newPrice == item.price && newOriginal == item.originalPrice) return;
    // Catatan: pakai constructor langsung, bukan copyWith — copyWith tidak
    // bisa men-set originalPrice kembali ke null (`?? this.originalPrice`).
    list[i] = CartItem(
      productId: item.productId,
      name: item.name,
      price: newPrice,
      variantName: item.variantName,
      variantPriceAdjustment: item.variantPriceAdjustment,
      variantStock: item.variantStock,
      unitName: item.unitName,
      unitQtyPerBase: item.unitQtyPerBase,
      originalPrice: newOriginal,
      tempPrice: item.tempPrice,
      discountPerItem: item.discountPerItem,
      showInReceipt: item.showInReceipt,
      costPrice: item.costPrice,
      qty: item.qty,
      note: item.note,
      weightKg: item.weightKg,
    );
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

  /// Set HARGA SEMENTARA per unit (v2.2.57+116) — dipakai subtotal & struk.
  /// null = kembali ke harga normal [price]. Menaikkan harga lebih rendah
  /// dari harga normal → tetap valid (harga sementara bisa lebih murah).
  void setTempPrice(int productId, int? tempPrice, {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].copyWith(tempPrice: tempPrice);
    state = list;
  }

  /// Set DISKON nominal per SATUAN (v2.2.57+116). null = tanpa diskon.
  void setDiscountPerItem(int productId, int? discountPerItem,
      {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].copyWith(discountPerItem: discountPerItem);
    state = list;
  }

  /// Set toggle "informasikan di struk cetak" (v2.2.57+116).
  void setShowInReceipt(int productId, bool show, {String? variantName}) {
    final i = state.indexWhere(
      (e) => e.productId == productId && e.variantName == variantName,
    );
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].copyWith(showInReceipt: show);
    state = list;
  }

  /// Restore SATU item dari map JSON (lanjutkan pesanan / tab terbuka).
  /// Mengembalikan field harga sementara, diskon per satuan, catatan, dan
  /// toggle struk — sama persis saat disimpan (v2.2.57+116).
  void restoreFromJson(Map<String, dynamic> m) {
    final qty = (m['qty'] as num?)?.toInt() ?? 1;
    addProduct(
      m['productId'] as int,
      m['name'] as String,
      (m['price'] as num).toInt(),
      note: m['note'] as String?,
      isService: (m['isService'] as bool?) ?? false,
      weightKg: (m['weightKg'] as num?)?.toDouble(),
      variantName: m['variantName'] as String?,
      variantPriceAdjustment:
          ((m['variantPriceAdjustment'] as num?)?.toInt()) ?? 0,
      variantStock: (m['variantStock'] as num?)?.toInt(),
      unitName: m['unitName'] as String?,
      unitQtyPerBase: ((m['unitQtyPerBase'] as num?)?.toDouble()) ?? 1,
      qty: 1,
    );
    final i = state.indexWhere(
      (e) => e.productId == (m['productId'] as int) &&
          e.variantName == (m['variantName'] as String?),
    );
    if (i < 0) return;
    final list = [...state];
    var item = list[i];
    if (qty > 1) item = item.copyWith(qty: qty);
    final tempPrice = (m['tempPrice'] as num?)?.toInt();
    final discountPerItem = (m['discountPerItem'] as num?)?.toInt();
    final showInReceipt = (m['showInReceipt'] as bool?) ?? true;
    item = item.copyWith(
      tempPrice: tempPrice,
      discountPerItem: discountPerItem,
      showInReceipt: showInReceipt,
      originalPrice: (m['originalPrice'] as num?)?.toInt(),
      costPrice: (m['costPrice'] as num?)?.toInt(),
    );
    list[i] = item;
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
