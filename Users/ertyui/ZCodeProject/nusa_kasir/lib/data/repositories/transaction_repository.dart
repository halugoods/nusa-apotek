import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/features/pos/cart.dart';

class TransactionRepository {
  final AppDatabase db;
  TransactionRepository(this.db);

  Future<int> saveTransaction({
    required List<CartItem> items,
    required int total,
    required String paymentMethod,
    int discount = 0,
    int? customerId,
    int? cashGiven,
    int? cashReturn,
    String? cashierName,
    int? branchId,
  }) async {
    final invoice = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final itemsJson = jsonEncode(items.map((e) => {
      'productId': e.productId, 'name': e.name, 'qty': e.qty, 'price': e.price
    }).toList());
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      invoice: invoice,
      items: itemsJson,
      total: Value(total),
      discount: Value(discount),
      paymentMethod: Value(paymentMethod),
      customerId: Value(customerId),
      cashGiven: Value(cashGiven),
      cashReturn: Value(cashReturn),
      cashierName: Value(cashierName),
      branchId: Value(branchId),
    ));
  }

  /// For online orders — take raw items + invoice string.
  Future<int> addTransaction({
    required String invoice,
    required String items,     // JSON string
    required int total,
    int discount = 0,
    String? cashierName,
    String? paymentMethod,
    int? branchId,
    int? cashGiven,
    int? cashReturn,
    int? customerId,
  }) async {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      invoice: invoice,
      items: items,
      total: Value(total),
      discount: Value(discount),
      paymentMethod: Value(paymentMethod ?? 'Tunai'),
      cashierName: Value(cashierName),
      branchId: Value(branchId),
      cashGiven: Value(cashGiven),
      cashReturn: Value(cashReturn),
      customerId: Value(customerId),
    ));
  }

  Future<List<Transaction>> getTransactions() =>
      db.select(db.transactions).get();

  /// Get transactions ordered by date descending with customer name/phone joined.
  /// Returns maps with all Transaction fields plus 'customerName' and 'customerPhone'.
  Future<List<Map<String, dynamic>>> getTransactionsWithCustomer() async {
    final query = db.select(db.transactions).join([
      leftOuterJoin(db.customers, db.customers.id.equalsExp(db.transactions.customerId)),
    ]);
    query.orderBy([OrderingTerm(expression: db.transactions.date, mode: OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((row) {
      final tx = row.readTable(db.transactions);
      final cust = row.readTableOrNull(db.customers);
      return {
        ...tx.toJson(),
        'customerName': cust?.name,
        'customerPhone': cust?.phone,
      };
    }).toList();
  }

  Future<List<Transaction>> getToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (db.select(db.transactions)
          ..where((t) => t.date.isBiggerThanValue(today)))
        .get();
  }

  /// Void a transaction: mark status, restore stock, record reason.
  /// Returns null on success, or an error string.
  Future<String?> voidTransaction(int id, String reason) async {
    final tx = await (db.select(db.transactions)
      ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (tx == null) return 'Transaksi tidak ditemukan';
    if (tx.status != 'Normal') return 'Transaksi sudah di-void';

    await db.transaction(() async {
      // 1. Mark as voided
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          status: const Value('Void'),
          voidReason: Value(reason),
          voidedAt: Value(DateTime.now()),
        ),
      );

      // 2. Restore stock for each item
      final items = _parseItemsJson(tx.items);
      for (final item in items) {
        final pid = item['productId'] as int?;
        final qty = item['qty'] as int? ?? 0;
        if (pid != null && qty > 0) {
          // Use direct DB access to avoid repository dependency
          final product = await (db.select(db.products)
            ..where((p) => p.id.equals(pid))).getSingleOrNull();
          if (product != null) {
            final next = (product.stock + qty).clamp(0, 1000000000);
            await (db.update(db.products)..where((p) => p.id.equals(pid)))
                .write(ProductsCompanion(stock: Value(next)));
          }
        }
      }
    });

    return null; // success
  }

  List<Map<String, dynamic>> _parseItemsJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }
}
