import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class OnlineOrderRepository {
  final AppDatabase db;
  OnlineOrderRepository(this.db);

  Future<List<OnlineOrder>> getAll({String? status}) async {
    final q = db.select(db.onlineOrders)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    if (status != null && status.isNotEmpty) {
      q.where((t) => t.status.equals(status));
    }
    return q.get();
  }

  Future<OnlineOrder?> byId(int id) =>
      (db.select(db.onlineOrders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> upsert(OnlineOrdersCompanion companion) async {
    // Check if invoice already exists
    final invoice = companion.invoice.present ? companion.invoice.value : null;
    if (invoice != null) {
      final existing = await (db.select(db.onlineOrders)..where((t) => t.invoice.equals(invoice))).getSingleOrNull();
      if (existing != null) {
        // Update
        await (db.update(db.onlineOrders)..where((t) => t.id.equals(existing.id))).write(companion);
        return existing.id;
      }
    }
    return db.into(db.onlineOrders).insert(companion);
  }

  Future<void> updateStatus(int id, String status, {String? processedBy}) async {
    var companion = OnlineOrdersCompanion(status: Value(status));
    if (processedBy != null) {
      companion = companion.copyWith(processedBy: Value(processedBy));
    }
    await (db.update(db.onlineOrders)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<int> countByStatus(String status) async {
    final result = await (db.selectOnly(db.onlineOrders)
      ..addColumns([db.onlineOrders.id.count()])
      ..where(db.onlineOrders.status.equals(status)))
    .getSingle();
    return result.read(db.onlineOrders.id.count()) ?? 0;
  }

  Future<int> countPending() async {
    final result = await (db.selectOnly(db.onlineOrders)
      ..addColumns([db.onlineOrders.id.count()])
      ..where(db.onlineOrders.status.equals('Online Baru')))
    .getSingle();
    return result.read(db.onlineOrders.id.count()) ?? 0;
  }
}
