import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class DiningTableRepository {
  final AppDatabase db;
  DiningTableRepository(this.db);

  Future<int> add({required String name, int capacity = 4}) =>
      db.into(db.diningTables).insert(DiningTablesCompanion.insert(
            name: name,
            capacity: Value(capacity),
          ));

  Future<List<DiningTable>> getAll() =>
      (db.select(db.diningTables)
            ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
          .get();

  Future<DiningTable?> byId(int id) =>
      (db.select(db.diningTables)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> update(int id, {String? name, int? capacity}) async {
    var c = const DiningTablesCompanion();
    if (name != null) c = c.copyWith(name: Value(name));
    if (capacity != null) c = c.copyWith(capacity: Value(capacity));
    await (db.update(db.diningTables)..where((t) => t.id.equals(id))).write(c);
  }

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.diningTables)..where((t) => t.id.equals(id)))
          .write(DiningTablesCompanion(status: Value(status)));

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.diningTables)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  Future<void> delete(int id) =>
      (db.delete(db.diningTables)..where((t) => t.id.equals(id))).go();
}
