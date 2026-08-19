import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Opsi cicilan piutang — paket jumlah bulan yang bisa dipilih kasir saat
/// checkout dengan DP. CRUD hanya Owner (di layar Piutang).
class InstallmentOptionRepository {
  final AppDatabase db;
  InstallmentOptionRepository(this.db);

  Future<List<InstallmentOption>> getAll() =>
      (db.select(db.installmentOptions)
            ..orderBy([(t) => OrderingTerm(expression: t.months, mode: OrderingMode.asc)]))
          .get();

  Future<InstallmentOption?> byId(int id) =>
      (db.select(db.installmentOptions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Paket dengan jumlah bulan tertentu (untuk resolusi saat checkout).
  Future<InstallmentOption?> byMonths(int months) =>
      (db.select(db.installmentOptions)..where((t) => t.months.equals(months))).getSingleOrNull();

  Future<int> add(int months, {String? label}) =>
      db.into(db.installmentOptions).insert(
            InstallmentOptionsCompanion.insert(
              months: months,
              label: Value(label ?? '$months× bulanan'),
            ),
          );

  Future<void> update(int id, int months, {String? label}) =>
      (db.update(db.installmentOptions)..where((t) => t.id.equals(id))).write(
        InstallmentOptionsCompanion(
          months: Value(months),
          label: Value(label ?? '$months× bulanan'),
        ),
      );

  /// Hapus paket. Kembalikan false bila masih dipakai hutang aktif
  /// (guard CRUD — paket tidak boleh dihapus saat masih ada cicilan).
  Future<bool> deleteIfUnused(int id) async {
    final opt = await byId(id);
    if (opt == null) return true;
    final used = await (db.select(db.customerDebts)
          ..where((t) => t.installmentMonths.equals(opt.months) &
              t.status.equals('Belum Lunas')))
        .get();
    if (used.isNotEmpty) return false;
    await (db.delete(db.installmentOptions)..where((t) => t.id.equals(id))).go();
    return true;
  }
}
