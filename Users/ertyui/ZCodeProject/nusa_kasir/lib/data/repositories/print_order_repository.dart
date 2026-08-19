import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class PrintOrderRepository {
  final AppDatabase db;
  PrintOrderRepository(this.db);

  Future<int> add({
    required String customerName,
    String? customerPhone,
    required String serviceType,
    int pages = 0,
    int copies = 1,
    String paperSize = 'A4',
    int? widthCm,
    int? lengthCm,
    String? estimateReady,
    int total = 0,
    String? notes,
    String? customFieldsJson,
  }) =>
      db.into(db.printOrders).insert(PrintOrdersCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            serviceType: serviceType,
            pages: Value(pages),
            copies: Value(copies),
            paperSize: Value(paperSize),
            widthCm: Value(widthCm),
            lengthCm: Value(lengthCm),
            estimateReady: Value(estimateReady),
            total: Value(total),
            notes: Value(notes),
            customFieldsJson: Value(customFieldsJson),
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

  /// Update penuh (form edit) — semua field kecuali id/createdAt.
  Future<void> update(
    int id, {
    required String customerName,
    String? customerPhone,
    required String serviceType,
    int pages = 0,
    int copies = 1,
    String paperSize = 'A4',
    int? widthCm,
    int? lengthCm,
    String? estimateReady,
    int total = 0,
    String? notes,
    String? status,
    String? customFieldsJson,
  }) =>
      (db.update(db.printOrders)..where((t) => t.id.equals(id)))
          .write(PrintOrdersCompanion(
            customerName: Value(customerName),
            customerPhone: Value(customerPhone),
            serviceType: Value(serviceType),
            pages: Value(pages),
            copies: Value(copies),
            paperSize: Value(paperSize),
            widthCm: Value(widthCm),
            lengthCm: Value(lengthCm),
            estimateReady: Value(estimateReady),
            total: Value(total),
            notes: Value(notes),
            status: status != null ? Value(status) : const Value.absent(),
            customFieldsJson:
                customFieldsJson != null ? Value(customFieldsJson) : const Value.absent(),
          ));

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

  /// Jumlah order yang dibuat pada hari tertentu (untuk stats dashboard).
  Future<int> countByDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (db.select(db.printOrders)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerThanValue(end)))
        .get();
    return rows.length;
  }

  Future<void> delete(int id) =>
      (db.delete(db.printOrders)..where((t) => t.id.equals(id))).go();
}
