import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';

void main() {
  late ProductRepository repo;
  setUp(() { repo = ProductRepository(AppDatabase.test()); });
  test('addProduct auto-generates barcode and byBarcode finds it', () async {
    final id = await repo.addProduct(
      name: 'Indomie Goreng', category: 'Makanan',
      buyPrice: 2000, sellPrice: 3500, stock: 10, minStock: 5);
    final p = await repo.byId(id);
    expect(p, isNotNull);
    expect(p!.barcode, isNotEmpty);
    final found = await repo.byBarcode(p.barcode!);
    expect(found!.id, id);
  });
  test('adjustStock changes stock', () async {
    final id = await repo.addProduct(
      name: 'Aqua', category: 'Minuman',
      buyPrice: 1500, sellPrice: 3000, stock: 5, minStock: 2);
    await repo.adjustStock(id, -2);
    final p = await repo.byId(id);
    expect(p!.stock, 3);
  });
}
