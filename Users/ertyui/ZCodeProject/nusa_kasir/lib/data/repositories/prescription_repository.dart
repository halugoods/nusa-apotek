import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class PrescriptionRepository {
  final AppDatabase db;
  PrescriptionRepository(this.db);

  Future<int> add({required String patientName, String? doctorName, required String itemsJson, String? dosage, int total = 0, String? notes}) =>
      db.into(db.prescriptions).insert(PrescriptionsCompanion.insert(
            patientName: patientName,
            doctorName: Value(doctorName),
            itemsJson: itemsJson,
            dosage: Value(dosage),
            total: Value(total),
            notes: Value(notes),
          ));

  Future<List<Prescription>> getAll() =>
      (db.select(db.prescriptions)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
          .get();

  Future<Prescription?> byId(int id) =>
      (db.select(db.prescriptions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.prescriptions)..where((t) => t.id.equals(id)))
          .write(PrescriptionsCompanion(status: Value(status)));

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.prescriptions)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  Future<int> countPending() async {
    final rows = await (db.select(db.prescriptions)
          ..where((t) => t.status.equals('Diambil').not()))
        .get();
    return rows.length;
  }

  Future<void> delete(int id) =>
      (db.delete(db.prescriptions)..where((t) => t.id.equals(id))).go();
}
