import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:nusa_kasir/core/activation/activation_key.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class ProductRepository {
  final AppDatabase db;
  ProductRepository(this.db);

  Future<int> addProduct({
    required String name,
    required String category,
    required int buyPrice,
    required int sellPrice,
    required int stock,
    required int minStock,
    String? sku,
    String? imagePath,
    String? barcode,
    bool isOnline = false,
    DateTime? expiryDate,
    String? productType,
    int discountPercent = 0,
    String discountType = 'persen',
  }) async {
    final code = barcode ?? ActivationKey.generateSerial();
    return db.into(db.products).insert(ProductsCompanion.insert(
      name: name,
      sellPrice: sellPrice,
      category: Value(category),
      buyPrice: Value(buyPrice),
      stock: Value(stock),
      minStock: Value(minStock),
      sku: Value(sku),
      imagePath: Value(imagePath),
      barcode: Value(code),
      isOnline: Value(isOnline),
      expiryDate: Value(expiryDate),
      productType: Value(productType),
      discountPercent: Value(discountPercent),
      discountType: Value(discountType),
    ));
  }

  Future<Product?> byId(int id) =>
    (db.select(db.products)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Varian produk (dari variantsJson): nama + selisih harga + stok.
  static List<({String name, int priceAdjustment, int stock})> parseVariants(
    Product p,
  ) {
    final raw = p.variantsJson;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            (
              name: (e['name'] ?? '').toString(),
              priceAdjustment:
                  (e['priceAdjustment'] as num?)?.toInt() ?? 0,
              stock: (e['stock'] as num?)?.toInt() ?? 0,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Normalisasi barcode untuk pencocokan alfanumerik yang konsisten:
  /// trim + UPPERCASE + buang semua karakter non [A-Z0-9].
  /// Akar "kode berhuruf tidak ditemukan" = `byBarcode` membandingkan dengan
  /// `equals` mentah, jadi kode 'ABC-123' tidak cocok dengan 'abc 123' hasil
  /// scan. SEMUA call site (POS, kamera, produk/stok/pembelian, form) wajib
  /// lewat fungsi ini supaya kode berhuruf & simbol yang di-scan scanner
  /// eksternal (HID) selalu ketemu produk.
  static String normalizeBarcode(String raw) {
    final b = raw.trim().toUpperCase();
    final sb = StringBuffer();
    for (final c in b.codeUnits) {
      if ((c >= 0x30 && c <= 0x39) || // 0-9
          (c >= 0x41 && c <= 0x5A) || // A-Z
          c == 0x2D || c == 0x2B || c == 0x2F || c == 0x5F) { // - + / _
        sb.writeCharCode(c);
      }
    }
    return sb.toString();
  }

  /// Lookup by normalized barcode. Menangani kode berhuruf/simbol dan data
  /// lama yang belum ternormalisasi (mis. 'ABC-123' vs 'abc_123').
  Future<Product?> byBarcode(String barcode) {
    final norm = normalizeBarcode(barcode);
    if (norm.isEmpty) return Future.value(null);
    final q = db.select(db.products);
    final all = q.get();
    return all.then((list) {
      for (final p in list) {
        if (normalizeBarcode(p.barcode ?? '') == norm) return p;
      }
      return null;
    });
  }

  /// Search by name OR barcode (case-insensitive substring) — barcode juga
  /// dinormalisasi agar kode berhuruf ikut cocok.
  Future<List<Product>> searchProducts(String query) {
    final q = db.select(db.products);
    final pattern = '%$query%';
    q.where((t) => t.name.like(pattern) | t.barcode.like(pattern));
    return q.get();
  }

  Future<List<Product>> getProducts({
    String? category,
    String? status,
    String? productType,
    bool? isService,
  }) async {
    final q = db.select(db.products);
    if (category != null && category != 'Semua') {
      q.where((t) => t.category.equals(category));
    }
    if (productType != null && productType.isNotEmpty) {
      q.where((t) => t.productType.equals(productType));
    }
    // B10 (v2.2.44): filter jasa vs barang. isService=true → layanan;
    // isService=false → produk biasa. null → semua.
    if (isService != null) {
      q.where((t) => t.isService.equals(isService));
    }
    // server-side status filter
    if (status == 'Aktif') {
      q.where((t) => t.stock.isBiggerThanValue(0));
    } else if (status == 'Non Aktif' || status == 'Habis') {
      q.where((t) => t.stock.equals(0));
    }
    return q.get();
  }

  /// Semua produk layanan (isService == true) — dipakai tab Layanan (B10).
  Future<List<Product>> getServices() => getProducts(isService: true);

  /// Semua produk biasa (isService == false) — dipakai POS segmen Produk.
  Future<List<Product>> getRegularProducts() => getProducts(isService: false);

  Future<void> adjustStock(int id, int delta) async {
    final p = await byId(id);
    if (p == null) return;
    final next = (p.stock + delta).clamp(0, 1000000000);
    await (db.update(db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(stock: Value(next)));
  }

  /// Adjust stock of ONE variant (inside variantsJson) by [delta].
  /// No-op when [variantName] is null/empty or not found in the JSON list.
  Future<void> adjustVariantStock(int id, String? variantName, int delta) async {
    if (variantName == null || variantName.isEmpty) return;
    final p = await byId(id);
    if (p == null) return;
    final variants = parseVariants(p);
    if (variants.isEmpty) return;
    var changed = false;
    final list = <Map<String, dynamic>>[];
    for (final v in variants) {
      var stock = v.stock;
      if (v.name == variantName) {
        stock = (stock + delta).clamp(0, 1000000000);
        changed = true;
      }
      list.add({
        'name': v.name,
        'priceAdjustment': v.priceAdjustment,
        'stock': stock,
      });
    }
    if (!changed) return;
    await (db.update(db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(variantsJson: Value(jsonEncode(list))));
  }

  Future<void> updateProduct(int id,
    {String? name, String? category, int? buyPrice, int? sellPrice, int? minStock,
     int? discountPercent, String? discountType}) async {
    var companion = const ProductsCompanion();
    if (name != null) companion = companion.copyWith(name: Value(name));
    if (category != null) companion = companion.copyWith(category: Value(category));
    if (buyPrice != null) companion = companion.copyWith(buyPrice: Value(buyPrice));
    if (sellPrice != null) companion = companion.copyWith(sellPrice: Value(sellPrice));
    if (minStock != null) companion = companion.copyWith(minStock: Value(minStock));
    if (discountPercent != null) companion = companion.copyWith(discountPercent: Value(discountPercent));
    if (discountType != null) companion = companion.copyWith(discountType: Value(discountType));
    await (db.update(db.products)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> deleteProduct(int id) async {
    await (db.delete(db.products)..where((t) => t.id.equals(id))).go();
  }

  /// Set price type for a product ('pcs' or 'kg').
  Future<void> setPriceType(int id, String type) async {
    await (db.update(db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(priceType: Value(type)));
  }

  /// Set product type ('jasa' or 'produk'). Used by salon variant.
  Future<void> setProductType(int id, String? type) async {
    await (db.update(db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(productType: Value(type)));
  }

  /// Get product counts grouped by category.
  Future<Map<String, int>> categoryProductCounts() async {
    final all = await db.select(db.products).get();
    final map = <String, int>{};
    for (final p in all) {
      map[p.category] = (map[p.category] ?? 0) + 1;
    }
    return map;
  }
}
