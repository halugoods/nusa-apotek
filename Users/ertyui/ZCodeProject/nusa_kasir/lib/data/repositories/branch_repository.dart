import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class BranchRepository {
  final AppDatabase db;
  BranchRepository(this.db);

  Future<List<Branche>> getAll() async {
    final q = db.select(db.branches);
    q.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    return q.get();
  }

  Future<int> add(String name, {String? address, String? phone, String? status}) async {
    return db.into(db.branches).insert(BranchesCompanion.insert(
      name: name,
      address: Value(address),
      phone: Value(phone),
      status: Value(status ?? 'Aktif'),
    ));
  }

  Future<void> update(int id, String name, {String? address, String? phone, String? status}) async {
    await (db.update(db.branches)..where((t) => t.id.equals(id)))
        .write(BranchesCompanion(
      name: Value(name),
      address: Value(address),
      phone: Value(phone),
      status: Value(status ?? 'Aktif'),
    ));
  }

  Future<void> delete(int id) async {
    await (db.delete(db.branches)..where((t) => t.id.equals(id))).go();
  }

  Future<Branche?> byId(int id) async =>
      (db.select(db.branches)..where((t) => t.id.equals(id))).getSingleOrNull();
}
