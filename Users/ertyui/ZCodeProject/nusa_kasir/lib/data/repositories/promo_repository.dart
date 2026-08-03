import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class PromoRepository {
  final AppDatabase db;
  PromoRepository(this.db);

  Future<int> addPromo({
    required String name,
    required String code,
    required String type, // 'persen' | 'nominal'
    required int value,
    int minBelanja = 0,
    DateTime? startDate,
    DateTime? endDate,
    int? maxUses,
    String status = 'Aktif',
  }) {
    return db.into(db.promos).insert(PromosCompanion.insert(
          name: name,
          code: code,
          type: type,
          value: value,
          minBelanja: Value(minBelanja),
          startDate: Value(startDate),
          endDate: Value(endDate),
          maxUses: Value(maxUses),
          status: Value(status),
        ));
  }

  Future<List<Promo>> getPromos() =>
      (db.select(db.promos)
            ..orderBy([
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)
            ]))
          .get();

  Future<Promo?> byId(int id) =>
      (db.select(db.promos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.promos)..where((t) => t.id.equals(id)))
          .write(PromosCompanion(status: Value(status)));

  Future<void> incrementUsed(int id) async {
    final p = await byId(id);
    if (p == null) return;
    await (db.update(db.promos)..where((t) => t.id.equals(id)))
        .write(PromosCompanion(usedCount: Value(p.usedCount + 1)));
  }

  Future<void> updatePromo(int id,
      {String? name,
      String? code,
      String? type,
      int? value,
      int? minBelanja,
      DateTime? startDate,
      DateTime? endDate,
      int? maxUses,
      String? status}) async {
    var companion = const PromosCompanion();
    if (name != null) companion = companion.copyWith(name: Value(name));
    if (code != null) companion = companion.copyWith(code: Value(code));
    if (type != null) companion = companion.copyWith(type: Value(type));
    if (value != null) companion = companion.copyWith(value: Value(value));
    if (minBelanja != null) {
      companion = companion.copyWith(minBelanja: Value(minBelanja));
    }
    if (startDate != null) {
      companion = companion.copyWith(startDate: Value(startDate));
    }
    if (endDate != null) {
      companion = companion.copyWith(endDate: Value(endDate));
    }
    if (maxUses != null) companion = companion.copyWith(maxUses: Value(maxUses));
    if (status != null) companion = companion.copyWith(status: Value(status));
    await (db.update(db.promos)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> deletePromo(int id) =>
      (db.delete(db.promos)..where((t) => t.id.equals(id))).go();
}
