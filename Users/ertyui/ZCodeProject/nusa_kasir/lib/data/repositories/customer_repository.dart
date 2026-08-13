import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class CustomerRepository {
  final AppDatabase db;
  CustomerRepository(this.db);

  Future<int> addCustomer({required String name, String? phone, String? address}) =>
    db.into(db.customers).insert(CustomersCompanion.insert(
      name: name, phone: Value(phone), address: Value(address)));

  Future<Customer?> byId(int id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Customer>> getCustomers() => db.select(db.customers).get();

  Future<Customer?> byPhone(String phone) =>
      (db.select(db.customers)..where((t) => t.phone.equals(phone))).getSingleOrNull();

  Future<void> addSpent(int id, int amount, {int pointsPerRupiah = 100, int goldThreshold = 1000, int platinumThreshold = 5000, int? transactionId}) async {
    final c = await byId(id);
    if (c == null) return;
    final total = c.totalSpent + amount;
    final points = total ~/ pointsPerRupiah;
    final level = points >= platinumThreshold ? 'Platinum' : points >= goldThreshold ? 'Gold' : 'Silver';
    await (db.update(db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(totalSpent: Value(total), points: Value(points), level: Value(level)));
    // Riwayat poin: catat poin yang didapat transaksi ini (delta),
    // plus kenaikan tier otomatis agar terlihat di riwayat.
    final prevPoints = c.points;
    final earned = (points - prevPoints).clamp(0, points);
    if (earned > 0 || level != c.level) {
      await db.into(db.pointHistories).insert(PointHistoriesCompanion.insert(
        customerId: id,
        type: 'earn',
        points: earned,
        transactionId: transactionId != null ? Value(transactionId) : const Value.absent(),
        note: level != c.level
            ? Value('Tier naik: ${c.level} → $level')
            : const Value.absent(),
      ));
    }
  }

  /// Redeem points for discount. Returns the discount amount in Rupiah (1 poin = Rp 1).
  /// Returns null if customer not found or insufficient points.
  Future<int?> redeemPoints(int id, int pointsToRedeem, {int? transactionId}) async {
    final c = await byId(id);
    if (c == null || c.points < pointsToRedeem) return null;
    final newPoints = c.points - pointsToRedeem;
    await (db.update(db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(points: Value(newPoints)));
    // Riwayat poin: catat pemakaian poin.
    await db.into(db.pointHistories).insert(PointHistoriesCompanion.insert(
      customerId: id,
      type: 'redeem',
      points: -pointsToRedeem,
      transactionId: transactionId != null ? Value(transactionId) : const Value.absent(),
      note: Value('Tukar poin (1 poin = Rp 1)'),
    ));
    return pointsToRedeem; // 1 poin = Rp 1
  }

  /// Point history for a customer, newest first.
  Future<List<PointHistory>> pointHistory(int customerId, {int limit = 50}) async {
    final q = db.select(db.pointHistories)
      ..where((h) => h.customerId.equals(customerId))
      ..orderBy([(h) => OrderingTerm(expression: h.date, mode: OrderingMode.desc)])
      ..limit(limit);
    return q.get();
  }

  /// Total points earned in a period (for reporting).
  Future<int> totalEarned({DateTime? from, DateTime? to}) async {
    final q = db.select(db.pointHistories)
      ..where((h) => h.type.equals('earn'));
    final rows = await q.get();
    var total = 0;
    for (final r in rows) {
      if (from != null && r.date.isBefore(from)) continue;
      if (to != null && r.date.isAfter(to.add(const Duration(days: 1)))) continue;
      total += r.points;
    }
    return total;
  }

  Future<void> deleteCustomer(int id) async {
    await (db.delete(db.customers)..where((t) => t.id.equals(id))).go();
  }

  /// Get auto-discount percentage based on loyalty tier.
  static double tierDiscountPercent(String level) {
    switch (level) {
      case 'Platinum': return 5;
      case 'Gold': return 2;
      default: return 0;
    }
  }
}
