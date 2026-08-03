import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class SupplierRepository {
  final AppDatabase db;
  SupplierRepository(this.db);

  Future<int> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? contactPerson,
    String? note,
  }) {
    return db.into(db.suppliers).insert(SuppliersCompanion.insert(
          name: name,
          phone: Value(phone),
          address: Value(address),
          contactPerson: Value(contactPerson),
          note: Value(note),
        ));
  }

  Future<List<Supplier>> getSuppliers() =>
      (db.select(db.suppliers)
            ..orderBy([
              (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)
            ]))
          .get();

  Future<void> updateSupplier(int id,
      {String? name,
      String? phone,
      String? address,
      String? contactPerson,
      String? note}) async {
    var companion = const SuppliersCompanion();
    if (name != null) companion = companion.copyWith(name: Value(name));
    if (phone != null) companion = companion.copyWith(phone: Value(phone));
    if (address != null) companion = companion.copyWith(address: Value(address));
    if (contactPerson != null) {
      companion = companion.copyWith(contactPerson: Value(contactPerson));
    }
    if (note != null) companion = companion.copyWith(note: Value(note));
    await (db.update(db.suppliers)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<void> deleteSupplier(int id) =>
      (db.delete(db.suppliers)..where((t) => t.id.equals(id))).go();
}
