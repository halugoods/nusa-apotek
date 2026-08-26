import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class AppointmentRepository {
  final AppDatabase db;
  AppointmentRepository(this.db);

  Future<int> add({
    required String customerName,
    String? customerPhone,
    required String service,
    String? stylist,
    int? stylistId,
    int? transactionId,
    required DateTime date,
    required String timeSlot,
    String? notes,
    int? estimatedDuration,
    int? counterId,
  }) =>
      db.into(db.appointments).insert(AppointmentsCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            service: service,
            stylist: Value(stylist),
            stylistId: Value(stylistId),
            transactionId: Value(transactionId),
            date: date,
            timeSlot: timeSlot,
            notes: Value(notes),
            estimatedDuration: Value(estimatedDuration),
            counterId: Value(counterId),
          ));

  Future<List<Appointment>> getAll() =>
      (db.select(db.appointments)
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc), (t) => OrderingTerm(expression: t.timeSlot, mode: OrderingMode.asc)]))
          .get();

  Future<List<Appointment>> byDate(DateTime date) =>
      (db.select(db.appointments)
            ..where((t) {
              final next = DateTime(date.year, date.month, date.day + 1);
              return t.date.isBiggerOrEqualValue(date) & t.date.isSmallerThanValue(next);
            })
            ..orderBy([(t) => OrderingTerm(expression: t.timeSlot, mode: OrderingMode.asc)]))
          .get();

  Future<Appointment?> byId(int id) =>
      (db.select(db.appointments)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.appointments)..where((t) => t.id.equals(id)))
          .write(AppointmentsCompanion(status: Value(status)));

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.appointments)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  Future<List<Appointment>> getByCustomer(String customerName) =>
      (db.select(db.appointments)
            ..where((t) => t.customerName.equals(customerName))
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .get();

  Future<int> getNextCounter(DateTime date) async {
    final next = DateTime(date.year, date.month, date.day + 1);
    final today = await (db.select(db.appointments)
          ..where((t) => t.date.isBiggerOrEqualValue(date) & t.date.isSmallerThanValue(next)))
        .get();
    return today.length + 1;
  }

  Future<void> delete(int id) =>
      (db.delete(db.appointments)..where((t) => t.id.equals(id))).go();
}
