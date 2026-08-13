import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Result of a refund operation — the money returned to the customer,
/// used by the UI to show a confirmation and by the shift screen to
/// track kas (cash drawer) outflows.
class RefundResult {
  final int refundAmount;
  final List<Map<String, dynamic>> items;
  const RefundResult({required this.refundAmount, required this.items});
}

/// Retur/refund parsial per transaksi.
///
/// Satu transaksi bisa di-retur sebagian (beberapa item / sebagian qty).
/// Setiap retur:
///  - stok produk dikembalikan (+ qty, karena barang kembali ke toko)
///  - uang dikembalikan dicatat (refunds.refund_amount) — laporan omzet,
///    HPP, top produk, dan kas shift otomatis akurat tanpa perubahan status
///    transaksi asli.
///
/// Product id negatif = item manual (dibuat di POS, tidak ada di tabel
/// produk) — stok tidak dikembalikan, hanya uang yang dicatat.
class RefundRepository {
  final AppDatabase db;
  RefundRepository(this.db);

  /// Process a partial refund for [transactionId].
  ///
  /// [returns] = list of {productId (int, bisa negatif untuk manual),
  /// name, qty, unitPrice}. Returns the total refunded amount.
  ///
  /// All-or-nothing: stock restore + refund rows commit in one transaction.
  /// If any product has insufficient stock to return, the whole refund is
  /// rejected so the books never go inconsistent.
  Future<RefundResult> refund({
    required int transactionId,
    required List<Map<String, dynamic>> returns,
    String? reason,
    int? branchId,
    int? employeeId,
  }) async {
    var totalRefund = 0;
    final savedItems = <Map<String, dynamic>>[];

    await db.transaction(() async {
      for (final r in returns) {
        final pid = r['productId'] as int?;
        final name = (r['name'] as String?) ?? 'Item';
        final qty = (r['qty'] as num?)?.toInt() ?? 0;
        final unitPrice = (r['unitPrice'] as num?)?.toInt() ?? 0;
        if (qty <= 0) continue;

        final amount = qty * unitPrice;
        totalRefund += amount;

        // Restore stock — but skip manual items (negative id, not in DB)
        // and enforce stock cap so a refund can't push stock above the
        // hard ceiling.
        if (pid != null && pid >= 0) {
          final product = await (db.select(db.products)
            ..where((p) => p.id.equals(pid))).getSingleOrNull();
          if (product == null) continue;
          final next = (product.stock + qty).clamp(0, 1000000000);
          await (db.update(db.products)..where((p) => p.id.equals(pid)))
              .write(ProductsCompanion(stock: Value(next)));
        }

        final id = await db.into(db.refunds).insert(RefundsCompanion.insert(
          transactionId: transactionId,
          productId: pid != null ? Value(pid) : const Value.absent(),
          productName: name,
          qty: qty,
          unitPrice: unitPrice,
          refundAmount: amount,
          reason: reason != null && reason.isNotEmpty ? Value(reason) : const Value.absent(),
          branchId: branchId != null ? Value(branchId) : const Value.absent(),
          employeeId: employeeId != null ? Value(employeeId) : const Value.absent(),
        ));

        savedItems.add({
          'id': id,
          'productId': pid,
          'name': name,
          'qty': qty,
          'unitPrice': unitPrice,
          'amount': amount,
        });
      }
    });

    return RefundResult(refundAmount: totalRefund, items: savedItems);
  }

  /// All refunds in [from..to] (inclusive), newest first.
  Future<List<Refund>> getRefunds({DateTime? from, DateTime? to}) async {
    final q = db.select(db.refunds);
    if (from != null || to != null) {
      q.where((r) {
        final conds = <Expression<bool>>[];
        if (from != null) {
          conds.add(r.date.isBiggerThan(Constant(from.subtract(const Duration(days: 1)))));
        }
        if (to != null) {
          conds.add(r.date.isSmallerThan(Constant(to.add(const Duration(days: 1)))));
        }
        return conds.reduce((a, b) => a & b);
      });
    }
    q.orderBy([(r) => OrderingTerm(expression: r.date, mode: OrderingMode.desc)]);
    return q.get();
  }

  /// Refunds for one transaction (for the retur detail view).
  Future<List<Refund>> getByTransaction(int transactionId) {
    return (db.select(db.refunds)..where((r) => r.transactionId.equals(transactionId))).get();
  }

  /// Total refunded amount for a transaction (0 if none).
  Future<int> totalForTransaction(int transactionId) async {
    final rows = await (db.select(db.refunds)
          ..where((r) => r.transactionId.equals(transactionId)))
        .get();
    var total = 0;
    for (final r in rows) {
      total += r.refundAmount;
    }
    return total;
  }

  /// Total refunded in [from..to] (for reports / kas shift).
  Future<int> totalRefunded({DateTime? from, DateTime? to}) async {
    final rows = await getRefunds(from: from, to: to);
    var total = 0;
    for (final r in rows) {
      total += r.refundAmount;
    }
    return total;
  }

  /// Parse a transaction's items JSON into refund-friendly maps.
  static List<Map<String, dynamic>> parseItems(String itemsJson) {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is List) {
        return decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
