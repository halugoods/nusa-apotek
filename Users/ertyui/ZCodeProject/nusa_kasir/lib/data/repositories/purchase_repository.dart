import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Item baris pembelian yang belum dicatat (dari form).
///
/// [isMaterial] true → bahan non-produk (mis. plastik): hanya dicatat
/// riwayatnya (item + MaterialPrices), TIDAK menyentuh stok produk.
/// [isMaterial] false → produk: stok masuk + harga modal (buyPrice) update.
class PurchaseItemInput {
  final int? productId;
  final String name; // nama produk atau bahan
  final int qty;
  final int buyPrice;
  final bool isMaterial;
  PurchaseItemInput({
    this.productId,
    required this.name,
    required this.qty,
    required this.buyPrice,
    this.isMaterial = false,
  });
}

/// Pembelian/restok dari supplier.
///
/// `recordPurchase` mencatat semuanya atomically dalam satu transaksi DB:
/// 1. header [PurchaseOrders] + item [PurchaseOrderItems]
/// 2. untuk item PRODUK: stok masuk (`adjustStock` setara: stock += qty)
///    + harga modal (buyPrice) diperbarui → HPP / laba rugi presisi
///    + riwayat [StockMovements] type 'in'
/// 3. untuk item BAHAN: hanya dicatat di item + [MaterialPrices] (riwayat
///    harga beli bahan per supplier) — tanpa menyentuh stok produk
class PurchaseRepository {
  final AppDatabase db;
  PurchaseRepository(this.db);

  Future<List<PurchaseOrder>> getOrders() => (db.select(db.purchaseOrders)
        ..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
        ]))
      .get();

  Future<List<PurchaseOrderItem>> getItems(int orderId) =>
      (db.select(db.purchaseOrderItems)
            ..where((t) => t.purchaseOrderId.equals(orderId)))
          .get();

  Future<PurchaseOrder?> orderById(int id) =>
      (db.select(db.purchaseOrders)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Riwayat harga beli bahan per supplier (untuk melihat kenaikan/penurunan).
  Future<List<MaterialPrice>> getMaterialPrices(int supplierId) =>
      (db.select(db.materialPrices)
            ..where((t) => t.supplierId.equals(supplierId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
            ]))
          .get();

  /// Daftar nama bahan unik yang pernah dibeli (untuk filter/riwayat).
  Future<List<String>> getMaterialNames() async {
    final rows = await (db.select(db.materialPrices)).get();
    return rows.map((r) => r.materialName).toSet().toList()..sort();
  }

  /// Catat pembelian supplier: stok masuk + harga modal dinamis + riwayat.
  Future<int> recordPurchase({
    required int supplierId,
    required String supplierName,
    required List<PurchaseItemInput> items,
    String? note,
  }) async {
    var orderId = 0;
    await db.transaction(() async {
      // ── 1. Header ──
      final total = items.fold<int>(0, (sum, i) => sum + (i.qty * i.buyPrice));
      final invoice = await _nextInvoice();
      orderId = await db.into(db.purchaseOrders).insert(
            PurchaseOrdersCompanion.insert(
              invoice: invoice,
              supplierId: supplierId,
              supplierName: supplierName,
              total: Value(total),
              note: Value(note),
            ),
          );

      // ── 2. Item + stok/harga modal (produk) atau riwayat bahan ──
      for (final item in items) {
        if (item.qty <= 0) continue;
        await db.into(db.purchaseOrderItems).insert(
              PurchaseOrderItemsCompanion.insert(
                purchaseOrderId: orderId,
                productId: Value(item.productId),
                productName: item.name,
                qty: item.qty,
                buyPrice: item.buyPrice,
                total: item.qty * item.buyPrice,
                isMaterial: Value(item.isMaterial),
              ),
            );

        if (item.isMaterial) {
          // Bahan non-produk: simpan riwayat harga beli per supplier.
          await db.into(db.materialPrices).insert(MaterialPricesCompanion.insert(
                supplierId: supplierId,
                orderId: orderId,
                materialName: item.name,
                price: item.buyPrice,
                qty: Value(item.qty),
                date: Value(DateTime.now()),
              ));
          continue;
        }

        final pid = item.productId;
        if (pid == null) continue;
        // Stok bertambah (tanpa clamp — restok memang menambah stok).
        final p = await (db.select(db.products)
              ..where((t) => t.id.equals(pid)))
            .getSingleOrNull();
        if (p == null) continue;
        final next = p.stock + item.qty;
        await (db.update(db.products)..where((t) => t.id.equals(pid)))
            .write(ProductsCompanion(
          stock: Value(next),
          // Harga modal mengikuti harga beli terbaru — HPP presisi.
          buyPrice: Value(item.buyPrice),
        ));
        // Riwayat stok masuk, biar laporan Stok lengkap.
        await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              productId: pid,
              type: 'in',
              qty: item.qty,
              note: Value('Pembelian $supplierName'),
            ));
      }
    });
    return orderId;
  }

  Future<String> _nextInvoice() async {
    final now = DateTime.now();
    final prefix = 'PB-${now.year}${_2(now.month)}${_2(now.day)}';
    final count = await (db.select(db.purchaseOrders)
          ..where((t) => t.invoice.like('$prefix%')))
        .get();
    return '$prefix-${(count.length + 1).toString().padLeft(3, '0')}';
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  /// Total pengeluaran pembelian pada rentang tanggal (untuk laporan keuangan).
  Future<int> totalSpentBetween(DateTime from, DateTime to) async {
    final rows = await (db.select(db.purchaseOrders)
          ..where((t) =>
              t.date.isBiggerOrEqual(Constant(from)) &
              t.date.isSmallerOrEqual(Constant(to))))
        .get();
    return rows.fold<int>(0, (sum, o) => sum + o.total);
  }
}
