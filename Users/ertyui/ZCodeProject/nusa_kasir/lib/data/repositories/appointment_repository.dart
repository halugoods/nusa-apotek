import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class AppointmentRepository {
  final AppDatabase db;
  AppointmentRepository(this.db);

  Future<int> add({required String customerName, String? customerPhone, required String service, String? stylist, required DateTime date, required String timeSlot, String? notes}) =>
      db.into(db.appointments).insert(AppointmentsCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            service: service,
            stylist: Value(stylist),
            date: date,
            timeSlot: timeSlot,
            notes: Value(notes),
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

  Future<void> delete(int id) =>
      (db.delete(db.appointments)..where((t) => t.id.equals(id))).go();
}
