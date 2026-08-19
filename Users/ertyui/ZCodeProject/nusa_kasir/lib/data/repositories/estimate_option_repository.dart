import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Preset estimasi selesai Order Cetak — dropdown CRUD di form Order Cetak
/// supaya estimasi konsisten (bukan free-text semrawut).
class EstimateOptionRepository {
  final AppDatabase db;
  EstimateOptionRepository(this.db);

  Future<List<EstimateOption>> getAll() =>
      (db.select(db.estimateOptions)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc)]))
          .get();

  Future<EstimateOption?> byLabel(String label) =>
      (db.select(db.estimateOptions)..where((t) => t.label.equals(label))).getSingleOrNull();

  Future<int> add(String label) =>
      db.into(db.estimateOptions).insert(EstimateOptionsCompanion.insert(label: label));

  Future<void> rename(int id, String label) =>
      (db.update(db.estimateOptions)..where((t) => t.id.equals(id)))
          .write(EstimateOptionsCompanion(label: Value(label)));

  Future<void> delete(int id) =>
      (db.delete(db.estimateOptions)..where((t) => t.id.equals(id))).go();
}
