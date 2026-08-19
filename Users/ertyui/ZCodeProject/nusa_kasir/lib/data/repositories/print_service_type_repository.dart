import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Repository jenis layanan percetakan (custom — tanpa icon bulat).
class PrintServiceTypeRepository {
  final AppDatabase db;
  PrintServiceTypeRepository(this.db);

  Future<List<PrintServiceType>> getAll() =>
      (db.select(db.printServiceTypes)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc)]))
          .get();

  Future<PrintServiceType?> byId(int id) =>
      (db.select(db.printServiceTypes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<PrintServiceType?> byName(String name) =>
      (db.select(db.printServiceTypes)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> add(String name) =>
      db.into(db.printServiceTypes).insert(
            PrintServiceTypesCompanion.insert(name: name, isDefault: const Value(false)),
          );

  Future<void> rename(int id, String name) =>
      (db.update(db.printServiceTypes)..where((t) => t.id.equals(id)))
          .write(PrintServiceTypesCompanion(name: Value(name)));

  /// v2.2.35: config field form per layanan (JSON list string).
  /// null = semua field default tampil.
  Future<void> setFieldsJson(int id, String? fieldsJson) =>
      (db.update(db.printServiceTypes)..where((t) => t.id.equals(id)))
          .write(PrintServiceTypesCompanion(fieldsJson: Value(fieldsJson)));

  Future<void> delete(int id) =>
      (db.delete(db.printServiceTypes)..where((t) => t.id.equals(id))).go();
}
