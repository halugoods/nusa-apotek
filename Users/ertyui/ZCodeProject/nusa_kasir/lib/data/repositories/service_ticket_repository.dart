import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class ServiceTicketRepository {
  final AppDatabase db;
  ServiceTicketRepository(this.db);

  Future<int> add({required String customerName, String? customerPhone, required String deviceName, required String issue, int estimatedCost = 0, String? notes}) =>
      db.into(db.serviceTickets).insert(ServiceTicketsCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            deviceName: deviceName,
            issue: issue,
            estimatedCost: Value(estimatedCost),
            notes: Value(notes),
          ));

  Future<List<ServiceTicket>> getAll() =>
      (db.select(db.serviceTickets)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
          .get();

  Future<ServiceTicket?> byId(int id) =>
      (db.select(db.serviceTickets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.serviceTickets)..where((t) => t.id.equals(id)))
          .write(ServiceTicketsCompanion(status: Value(status)));

  Future<void> updateCost(int id, {int? finalCost, String? notes}) async {
    var c = const ServiceTicketsCompanion();
    if (finalCost != null) c = c.copyWith(finalCost: Value(finalCost));
    if (notes != null) c = c.copyWith(notes: Value(notes));
    await (db.update(db.serviceTickets)..where((t) => t.id.equals(id))).write(c);
  }

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.serviceTickets)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  Future<int> countPending() async {
    final rows = await (db.select(db.serviceTickets)
          ..where((t) => t.status.equals('Diambil').not()))
        .get();
    return rows.length;
  }

  Future<void> delete(int id) =>
      (db.delete(db.serviceTickets)..where((t) => t.id.equals(id))).go();
}
