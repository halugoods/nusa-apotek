import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Repository F&B: bahan baku (raw material) + resep + mutasi stok bahan.
/// v2.2.43 — hanya dipakai saat [NusaConfig.isFnbVariant].
///
/// Bahan baku punya stok sendiri + harga modal (costPrice). Stok berkurang
/// otomatis saat checkout produk yang punya resep; kalau kurang hanya
/// PERINGATAN (transaksi tetap jalan — keputusan user).
class RecipeRepository {
  final AppDatabase db;
  RecipeRepository(this.db);

  // ── Bahan baku (RawMaterials) ─────────────────────────────────

  Future<int> addMaterial({
    required String name,
    int? unitId,
    int stock = 0,
    int minStock = 0,
    int costPrice = 0,
    int? supplierId,
  }) {
    return db.into(db.rawMaterials).insert(RawMaterialsCompanion.insert(
          name: name,
          unitId: Value(unitId),
          stock: Value(stock),
          minStock: Value(minStock),
          costPrice: Value(costPrice),
          supplierId: Value(supplierId),
        ));
  }

  Future<void> updateMaterial(
    int id, {
    String? name,
    int? unitId,
    int? minStock,
    int? costPrice,
    int? supplierId,
  }) async {
    var c = const RawMaterialsCompanion();
    if (name != null) c = c.copyWith(name: Value(name));
    if (unitId != null) c = c.copyWith(unitId: Value(unitId));
    if (minStock != null) c = c.copyWith(minStock: Value(minStock));
    if (costPrice != null) c = c.copyWith(costPrice: Value(costPrice));
    if (supplierId != null) c = c.copyWith(supplierId: Value(supplierId));
    c = c.copyWith(updatedAt: Value(DateTime.now()));
    await (db.update(db.rawMaterials)..where((t) => t.id.equals(id))).write(c);
  }

  Future<void> deleteMaterial(int id) async {
    await db.transaction(() async {
      await (db.delete(db.rawMaterials)..where((t) => t.id.equals(id))).go();
      await (db.delete(db.recipes)..where((t) => t.materialId.equals(id))).go();
      await (db.delete(db.ingredientStocks)
            ..where((t) => t.materialId.equals(id)))
          .go();
    });
  }

  Future<List<RawMaterial>> getMaterials() =>
      (db.select(db.rawMaterials)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<RawMaterial?> getMaterialById(int id) =>
      (db.select(db.rawMaterials)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Cari bahan by nama (case-insensitive) — dipakai pembelian bahan.
  Future<RawMaterial?> findMaterialByName(String name) async {
    final all = await getMaterials();
    final target = name.trim().toLowerCase();
    for (final m in all) {
      if (m.name.trim().toLowerCase() == target) return m;
    }
    return null;
  }

  /// Mutasi stok bahan: 'in' | 'out'. qty REAL (bisa 1.5). Dicatat ke
  /// IngredientStocks + stok bahan di-update.
  Future<void> adjustMaterialStock(
    int materialId, {
    required String type,
    required double qty,
    String? note,
  }) async {
    await db.transaction(() async {
      final m = await getMaterialById(materialId);
      if (m == null) return;
      final next =
          type == 'out' ? m.stock - qty.round() : m.stock + qty.round();
      await (db.update(db.rawMaterials)..where((t) => t.id.equals(materialId)))
          .write(RawMaterialsCompanion(
        stock: Value(next < 0 ? 0 : next),
        updatedAt: Value(DateTime.now()),
      ));
      await db.into(db.ingredientStocks).insert(IngredientStocksCompanion
          .insert(materialId: materialId, type: type, qty: qty, note: Value(note)));
    });
  }

  /// Stok masuk cepat (dari tab Bahan → "Stok Masuk"). TIDAK mengubah
  /// costPrice/HPP — dipakai stok awal / hitung manual.
  Future<void> addMaterialStock(int materialId, double qty, {String? note}) =>
      adjustMaterialStock(materialId, type: 'in', qty: qty, note: note);

  Future<List<IngredientStock>> getMaterialMovements(int materialId) =>
      (db.select(db.ingredientStocks)
            ..where((t) => t.materialId.equals(materialId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  // ── Satuan (Units — kamus global, dipakai bahan & produk) ─────

  Future<List<Unit>> getUnits() =>
      (db.select(db.units)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<Unit?> getUnitById(int? id) {
    if (id == null) return Future.value(null);
    return (db.select(db.units)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Tambah satuan baru; return id. Throw kalau nama sudah ada (unique).
  Future<int> addUnit(String name) => db.into(db.units).insert(
        UnitsCompanion.insert(name: name.trim()),
      );

  // ── ProductUnits (konversi satuan per produk) ─────────────────

  Future<List<ProductUnit>> getProductUnits(int productId) =>
      (db.select(db.productUnits)..where((t) => t.productId.equals(productId)))
          .get();

  /// Nama satuan dasar sebuah produk; null kalau produk belum punya konversi
  /// (fallback 'pcs' oleh pemanggil).
  Future<String?> getBaseUnitName(int productId) async {
    final rows = await (db.select(db.productUnits)
          ..where((t) => t.productId.equals(productId) & t.isBase.equals(true)))
        .get();
    if (rows.isEmpty) return null;
    return getUnitById(rows.first.unitId).then((u) => u?.name);
  }

  /// Daftar satuan produk yang siap dipakai di POS/keranjang:
  /// (unitId, name, qtyPerBase, isBase). Kosong = belum atur → fallback 'pcs'.
  Future<List<({int unitId, String name, int? unitStock, double qtyPerBase, bool isBase})>>
      getProductUnitLabels(int productId) async {
    final rows = await getProductUnits(productId);
    if (rows.isEmpty) return const [];
    final kamus = await getUnits();
    final nameOf =
        (int? id) => kamus.where((u) => u.id == id).firstOrNull?.name ?? '';
    return [
      for (final pu in rows)
        (
          unitId: pu.unitId,
          name: nameOf(pu.unitId),
          unitStock: null,
          qtyPerBase: pu.qtyPerBase,
          isBase: pu.isBase,
        ),
    ];
  }

  /// Simpan konversi satuan sebuah produk. [baseUnitId] = satuan dasar
  /// (qtyPerBase=1), [sellingUnits] = (unitId, qtyPerBase).
  Future<void> setProductUnits(
    int productId,
    int? baseUnitId,
    List<(int unitId, double qtyPerBase)> sellingUnits,
  ) async {
    await db.transaction(() async {
      await (db.delete(db.productUnits)
            ..where((t) => t.productId.equals(productId)))
          .go();
      if (baseUnitId != null) {
        await db.into(db.productUnits).insert(ProductUnitsCompanion.insert(
          productId: productId,
          unitId: baseUnitId,
          qtyPerBase: const Value(1),
          isBase: const Value(true),
        ));
      }
      for (final (unitId, qtyPerBase) in sellingUnits) {
        if (qtyPerBase <= 0 || unitId == baseUnitId) continue;
        await db.into(db.productUnits).insert(ProductUnitsCompanion.insert(
          productId: productId,
          unitId: unitId,
          qtyPerBase: Value(qtyPerBase),
        ));
      }
    });
  }

  Future<void> renameUnit(int id, String name) async {
    await (db.update(db.units)..where((t) => t.id.equals(id)))
        .write(UnitsCompanion(name: Value(name.trim())));
  }

  Future<void> deleteUnit(int id) async {
    await db.transaction(() async {
      // Satuan yang dipakai bahan → bahan di-null-kan unit-nya (bukan dihapus).
      await (db.update(db.rawMaterials)..where((t) => t.unitId.equals(id)))
          .write(RawMaterialsCompanion(unitId: Value(null)));
      await (db.delete(db.units)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Resep (Recipes) ──────────────────────────────────────────

  Future<void> setRecipe(int productId, List<(int materialId, double qty)> items) async {
    await db.transaction(() async {
      await (db.delete(db.recipes)..where((t) => t.productId.equals(productId)))
          .go();
      for (final (materialId, qty) in items) {
        if (qty <= 0) continue;
        await db.into(db.recipes).insert(RecipesCompanion.insert(
          productId: productId,
          materialId: materialId,
          qty: Value(qty),
        ));
      }
    });
  }

  Future<List<Recipe>> getRecipesForProduct(int productId) =>
      (db.select(db.recipes)..where((t) => t.productId.equals(productId)))
          .get();

  /// HPP resep = Σ qty × costPrice bahan. 0 kalau produk tidak punya resep.
  Future<int> getRecipeCost(int productId) async {
    final recipes = await getRecipesForProduct(productId);
    if (recipes.isEmpty) return 0;
    int total = 0;
    for (final r in recipes) {
      final m = await getMaterialById(r.materialId);
      if (m != null) total += (r.qty * m.costPrice).round();
    }
    return total;
  }

  /// Bahan + qty per produk, dengan nama bahan ter-resolve (untuk UI form
  /// resep & estimasi HPP live).
  Future<List<({int materialId, String name, double qty, int costPrice})>>
      getRecipeWithNames(int productId) async {
    final recipes = await getRecipesForProduct(productId);
    final out = <({int materialId, String name, double qty, int costPrice})>[];
    for (final r in recipes) {
      final m = await getMaterialById(r.materialId);
      if (m == null) continue;
      out.add((
        materialId: m.id,
        name: m.name,
        qty: r.qty,
        costPrice: m.costPrice,
      ));
    }
    return out;
  }

  /// Konsumsi stok bahan saat checkout: untuk tiap bahan di resep produk,
  /// kurangi stok bahan (PERINGATAN saja bila kurang — transaksi tetap jalan).
  /// Return daftar bahan yang stoknya MENIPIS (tersisa ≤ 0) untuk toast/sheet.
  Future<List<String>> consumeRecipe(int productId, int qty) async {
    final recipes = await getRecipesForProduct(productId);
    final warnings = <String>[];
    for (final r in recipes) {
      final m = await getMaterialById(r.materialId);
      if (m == null) continue;
      final need = (r.qty * qty);
      await adjustMaterialStock(m.id, type: 'out', qty: need, note: 'Checkout');
      final after = await getMaterialById(m.id);
      if (after != null && after.stock <= 0) {
        warnings.add('${m.name} (tersisa ${after.stock})');
      }
    }
    return warnings;
  }
}
