import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Item baris pembelian yang belum dicatat (dari form).
class PurchaseItemInput {
  final int productId;
  final int qty;
  final int buyPrice;
  PurchaseItemInput(this.productId, this.qty, this.buyPrice);
}

/// Pembelian/restok dari supplier.
///
/// `recordPurchase` mencatat semuanya atomically dalam satu transaksi DB:
/// 1. header [PurchaseOrders] + item [PurchaseOrderItems]
/// 2. stok produk masuk (`adjustStock` setara: stock += qty)
/// 3. harga modal (buyPrice) produk diperbarui ke harga beli terbaru
///    → HPP / laba rugi jadi presisi
/// 4. riwayat [StockMovements] type 'in' dengan note pembelian
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

      // ── 2. Item + 3. stok masuk + 4. harga modal terbaru ──
      for (final item in items) {
        if (item.qty <= 0) continue;
        final name = await _productName(item.productId);
        await db.into(db.purchaseOrderItems).insert(
              PurchaseOrderItemsCompanion.insert(
                purchaseOrderId: orderId,
                productId: item.productId,
                productName: name,
                qty: item.qty,
                buyPrice: item.buyPrice,
                total: item.qty * item.buyPrice,
              ),
            );
        // Stok bertambah (tanpa clamp — restok memang menambah stok).
        final p = await (db.select(db.products)
              ..where((t) => t.id.equals(item.productId)))
            .getSingleOrNull();
        if (p == null) continue;
        final next = p.stock + item.qty;
        await (db.update(db.products)..where((t) => t.id.equals(item.productId)))
            .write(ProductsCompanion(
          stock: Value(next),
          // Harga modal mengikuti harga beli terbaru — HPP presisi.
          buyPrice: Value(item.buyPrice),
        ));
        // Riwayat stok masuk, biar laporan Stok lengkap.
        await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              productId: item.productId,
              type: 'in',
              qty: item.qty,
              note: Value('Pembelian $supplierName'),
            ));
      }
    });
    return orderId;
  }

  Future<String> _productName(int productId) async {
    final p = await (db.select(db.products)..where((t) => t.id.equals(productId)))
        .getSingleOrNull();
    return p?.name ?? 'Produk #$productId';
  }

  /// Nomor invoice pembelian: PB-YYYYMMDD-<urutan per hari>.
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
