import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class LaundryOrderRepository {
  final AppDatabase db;
  LaundryOrderRepository(this.db);

  Future<int> add({required String customerName, String? customerPhone, required String itemsJson, int total = 0, String? notes}) =>
      db.into(db.laundryOrders).insert(LaundryOrdersCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            itemsJson: itemsJson,
            total: Value(total),
            notes: Value(notes),
          ));

  Future<List<LaundryOrder>> getAll() =>
      (db.select(db.laundryOrders)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
          .get();

  Future<LaundryOrder?> byId(int id) =>
      (db.select(db.laundryOrders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.laundryOrders)..where((t) => t.id.equals(id)))
          .write(LaundryOrdersCompanion(status: Value(status)));

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.laundryOrders)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  Future<int> countPending() async {
    final rows = await (db.select(db.laundryOrders)
          ..where((t) => t.status.equals('Diambil').not()))
        .get();
    return rows.length;
  }

  Future<void> update(int id, {String? customerName, String? customerPhone, String? itemsJson, int? total, String? notes}) async {
    var c = const LaundryOrdersCompanion();
    if (customerName != null) c = c.copyWith(customerName: Value(customerName));
    if (customerPhone != null) c = c.copyWith(customerPhone: Value(customerPhone));
    if (itemsJson != null) c = c.copyWith(itemsJson: Value(itemsJson));
    if (total != null) c = c.copyWith(total: Value(total));
    if (notes != null) c = c.copyWith(notes: Value(notes));
    await (db.update(db.laundryOrders)..where((t) => t.id.equals(id))).write(c);
  }

  Future<void> delete(int id) =>
      (db.delete(db.laundryOrders)..where((t) => t.id.equals(id))).go();
}
