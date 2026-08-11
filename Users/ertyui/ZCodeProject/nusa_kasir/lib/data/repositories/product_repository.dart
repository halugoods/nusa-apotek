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
    ));
  }

  Future<Product?> byId(int id) =>
    (db.select(db.products)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Product?> byBarcode(String barcode) =>
    (db.select(db.products)..where((t) => t.barcode.equals(barcode))).getSingleOrNull();

  /// Search by name OR barcode (case-insensitive substring).
  Future<List<Product>> searchProducts(String query) {
    final q = db.select(db.products);
    final pattern = '%$query%';
    q.where((t) => t.name.like(pattern) | t.barcode.like(pattern));
    return q.get();
  }

  Future<List<Product>> getProducts({String? category, String? status, String? productType}) async {
    final q = db.select(db.products);
    if (category != null && category != 'Semua') {
      q.where((t) => t.category.equals(category));
    }
    if (productType != null && productType.isNotEmpty) {
      q.where((t) => t.productType.equals(productType));
    }
    // server-side status filter
    if (status == 'Aktif') {
      q.where((t) => t.stock.isBiggerThanValue(0));
    } else if (status == 'Non Aktif' || status == 'Habis') {
      q.where((t) => t.stock.equals(0));
    }
    return q.get();
  }

  Future<void> adjustStock(int id, int delta) async {
    final p = await byId(id);
    if (p == null) return;
    final next = (p.stock + delta).clamp(0, 1000000000);
    await (db.update(db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(stock: Value(next)));
  }

  Future<void> updateProduct(int id,
    {String? name, String? category, int? buyPrice, int? sellPrice, int? minStock,
     int? discountPercent}) async {
    var companion = const ProductsCompanion();
    if (name != null) companion = companion.copyWith(name: Value(name));
    if (category != null) companion = companion.copyWith(category: Value(category));
    if (buyPrice != null) companion = companion.copyWith(buyPrice: Value(buyPrice));
    if (sellPrice != null) companion = companion.copyWith(sellPrice: Value(sellPrice));
    if (minStock != null) companion = companion.copyWith(minStock: Value(minStock));
    if (discountPercent != null) companion = companion.copyWith(discountPercent: Value(discountPercent));
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
