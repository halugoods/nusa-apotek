import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class PrintOrderRepository {
  final AppDatabase db;
  PrintOrderRepository(this.db);

  Future<int> add({required String customerName, String? customerPhone, required String serviceType, int pages = 0, int copies = 1, String paperSize = 'A4', int total = 0, String? notes}) =>
      db.into(db.printOrders).insert(PrintOrdersCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            serviceType: serviceType,
            pages: Value(pages),
            copies: Value(copies),
            paperSize: Value(paperSize),
            total: Value(total),
            notes: Value(notes),
          ));

  Future<List<PrintOrder>> getAll() =>
      (db.select(db.printOrders)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
          .get();

  Future<List<PrintOrder>> byService(String serviceType) =>
      (db.select(db.printOrders)
            ..where((t) => t.serviceType.equals(serviceType))
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
          .get();

  Future<PrintOrder?> byId(int id) =>
      (db.select(db.printOrders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.printOrders)..where((t) => t.id.equals(id)))
          .write(PrintOrdersCompanion(status: Value(status)));

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.printOrders)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  Future<int> countPending() async {
    final rows = await (db.select(db.printOrders)
          ..where((t) => t.status.equals('Diambil').not()))
        .get();
    return rows.length;
  }

  Future<void> delete(int id) =>
      (db.delete(db.printOrders)..where((t) => t.id.equals(id))).go();
}
