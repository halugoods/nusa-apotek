import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/recipe_repository.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository recipe;
  late ProductRepository products;

  setUp(() {
    db = AppDatabase.test();
    recipe = RecipeRepository(db);
    products = ProductRepository(db);
  });

  group('normalizeBarcode (v2.2.43)', () {
    test('uppercase + trim + strip simbol non-alfanumerik', () {
      expect(ProductRepository.normalizeBarcode('abc-123'), 'ABC-123');
      expect(ProductRepository.normalizeBarcode('  indo mie  '), 'INDOMIE');
      expect(ProductRepository.normalizeBarcode('abc_123+45/6'),
          'ABC_123+45/6');
      expect(ProductRepository.normalizeBarcode('a.b&c'), 'ABC');
      expect(ProductRepository.normalizeBarcode(''), '');
    });

    test('byBarcode cocok kode berhuruf & data lama belum ternormalisasi',
        () async {
      // Simpan dengan barcode campuran huruf + simbol (seperti scanner HID).
      final id = await products.addProduct(
        name: 'Kopi ABC',
        category: 'Minuman',
        buyPrice: 5000,
        sellPrice: 10000,
        stock: 5,
        minStock: 0,
        barcode: 'ABC-123',
      );
      // Pencarian pakai huruf kecil + spasi → harus tetap ketemu.
      final found = await products.byBarcode('  abc-123 ');
      expect(found!.id, id);
      final found2 = await products.byBarcode('abc123'); // simpang: tanpa '-'
      expect(found2, isNull); // simbol dipertahankan → beda
    });
  });

  group('Satuan dinamis (v2.2.43)', () {
    test('setProductUnits: base + selling, qtyPerBase, getBaseUnitName', () async {
      final pcsId = await recipe.addUnit('pcs');
      final dusId = await recipe.addUnit('dus');
      await recipe.addUnit('karton');
      final pId = await products.addProduct(
        name: 'Air Galon',
        category: 'Minuman',
        buyPrice: 20000,
        sellPrice: 25000,
        stock: 100,
        minStock: 0,
      );
      // base = pcs, jual = dus (12 pcs)
      await recipe.setProductUnits(pId, pcsId, [(dusId, 12)]);
      expect(await recipe.getBaseUnitName(pId), 'pcs');
      final labels = await recipe.getProductUnitLabels(pId);
      final dus = labels.firstWhere((l) => l.name == 'dus');
      expect(dus.qtyPerBase, 12);
      expect(dus.isBase, isFalse);
      final pcs = labels.firstWhere((l) => l.name == 'pcs');
      expect(pcs.isBase, isTrue);
    });

    test('produk tanpa ProductUnits → fallback pcs (kompat data lama)',
        () async {
      final pId = await products.addProduct(
        name: 'Snack',
        category: 'Makanan',
        buyPrice: 500,
        sellPrice: 1000,
        stock: 10,
        minStock: 0,
      );
      expect(await recipe.getBaseUnitName(pId), isNull);
      expect(await recipe.getProductUnitLabels(pId), isEmpty);
    });
  });

  group('Bahan baku + Resep + HPP (v2.2.43, F&B)', () {
    test('setRecipe + getRecipeCost = Σ qty × costPrice bahan', () async {
      final unitId = await recipe.addUnit('pcs');
      final tepungId = await recipe.addMaterial(
        name: 'Tepung', unitId: unitId, stock: 100, costPrice: 500);
      final telurId = await recipe.addMaterial(
        name: 'Telur', unitId: unitId, stock: 50, costPrice: 2000);
      final pId = await products.addProduct(
        name: 'Kue',
        category: 'F&B',
        buyPrice: 0,
        sellPrice: 15000,
        stock: 0,
        minStock: 0,
      );
      await recipe.setRecipe(pId, [
        (tepungId, 2.0), // 2 × 500 = 1000
        (telurId, 3.0), // 3 × 2000 = 6000
      ]);
      expect(await recipe.getRecipeCost(pId), 7000);
    });

    test('consumeRecipe mengurangi stok bahan + return peringatan bila kurang',
        () async {
      final unitId = await recipe.addUnit('pcs');
      final tepungId = await recipe.addMaterial(
        name: 'Tepung', unitId: unitId, stock: 10, costPrice: 500);
      final pId = await products.addProduct(
        name: 'Kue',
        category: 'F&B',
        buyPrice: 0,
        sellPrice: 15000,
        stock: 0,
        minStock: 0,
      );
      await recipe.setRecipe(pId, [(tepungId, 2.0)]);

      // Konsumsi 3 porsi → tepung butuh 6, sisa 4.
      final warnings = await recipe.consumeRecipe(pId, 3);
      final material = await recipe.getMaterialById(tepungId);
      expect(material!.stock, 4);
      expect(warnings, isEmpty);

      // Konsumsi 5 porsi → butuh 10 > sisa 4 → peringatan (tidak blokir).
      final warnings2 = await recipe.consumeRecipe(pId, 5);
      expect(warnings2, isNotEmpty);
      final material2 = await recipe.getMaterialById(tepungId);
      // clamp 0, sisa 4-10 → 0 (stok tidak minus).
      expect(material2!.stock, 0);
    });

    test('addMaterialStock tambah stok tanpa ubah HPP', () async {
      final unitId = await recipe.addUnit('pcs');
      final mId = await recipe.addMaterial(
        name: 'Plastik', unitId: unitId, stock: 0, costPrice: 100);
      await recipe.addMaterialStock(mId, 20);
      final m = await recipe.getMaterialById(mId);
      expect(m!.stock, 20);
      expect(m.costPrice, 100); // costPrice tidak berubah oleh Stok Masuk
    });

    test('deleteUnit menanggalkan unitId bahan lalu hapus', () async {
      final dusId = await recipe.addUnit('dus');
      final mId = await recipe.addMaterial(
        name: 'Box', unitId: dusId, stock: 5, costPrice: 300);
      await recipe.deleteUnit(dusId);
      final m = await recipe.getMaterialById(mId);
      expect(m!.unitId, isNull);
      expect(await recipe.getUnitById(dusId), isNull);
    });
  });
}