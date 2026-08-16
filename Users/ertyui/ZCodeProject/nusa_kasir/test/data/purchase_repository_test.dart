import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/purchase_repository.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';

void main() {
  late AppDatabase db;
  late PurchaseRepository repo;
  late int productId;
  late int supplierId;

  setUp(() async {
    db = AppDatabase.test();
    repo = PurchaseRepository(db);
    productId = await ProductRepository(db).addProduct(
      name: 'Produk A',
      category: 'Umum',
      buyPrice: 0, // modal awal 0 — persis skenario user
      sellPrice: 5000,
      stock: 0,
      minStock: 0,
    );
    supplierId = await SupplierRepository(db).addSupplier(name: 'Supplier X');
  });

  test('ongkir dibagi rata ke total qty → modal per unit + total konsisten',
      () async {
    // User: produk A qty=3, harga beli baru 1000, ongkir 1000.
    final orderId = await repo.recordPurchase(
      supplierId: supplierId,
      supplierName: 'Supplier X',
      items: [
        PurchaseItemInput(
          productId: productId,
          name: 'Produk A',
          qty: 3,
          buyPrice: 1000,
        ),
      ],
      extraCosts: [
        PurchaseExtraCost(name: 'ongkir', amount: 1000),
      ],
    );

    // Modal per unit = harga 1000 + 1000/3 = 333 → 1333 (floor, sisa 1).
    final p = await ProductRepository(db).byId(productId);
    expect(p!.buyPrice, 1333);

    // Header total = subtotal 3000 + ongkir 1000 = 4000.
    final order = await repo.orderById(orderId);
    expect(order!.total, 4000);

    // Item total = 3×1333 + sisa 1 = 4000 → Σ item == header PERSIS.
    final items = await repo.getItems(orderId);
    final sumItems = items.fold<int>(0, (s, i) => s + i.total);
    expect(sumItems, order.total);
    expect(items.single.total, 4000);
  });

  test('biaya dibagi rata: qty 20 + biaya 10000 → +500 per unit', () async {
    final orderId = await repo.recordPurchase(
      supplierId: supplierId,
      supplierName: 'Supplier X',
      items: [
        PurchaseItemInput(
          productId: productId,
          name: 'Produk A',
          qty: 20,
          buyPrice: 1000,
        ),
      ],
      extraCosts: [
        PurchaseExtraCost(name: 'ongkir', amount: 10000),
      ],
    );

    final p = await ProductRepository(db).byId(productId);
    expect(p!.buyPrice, 1500); // 1000 + 10000/20 = 1500
    final order = await repo.orderById(orderId);
    expect(order!.total, 30000); // 20000 + 10000
    final items = await repo.getItems(orderId);
    expect(items.fold<int>(0, (s, i) => s + i.total), order.total);
  });

  test('tanpa biaya tambahan: modal = harga beli, total = subtotal', () async {
    final orderId = await repo.recordPurchase(
      supplierId: supplierId,
      supplierName: 'Supplier X',
      items: [
        PurchaseItemInput(
          productId: productId,
          name: 'Produk A',
          qty: 3,
          buyPrice: 1000,
        ),
      ],
    );
    final p = await ProductRepository(db).byId(productId);
    expect(p!.buyPrice, 1000);
    final order = await repo.orderById(orderId);
    expect(order!.total, 3000);
  });
}
