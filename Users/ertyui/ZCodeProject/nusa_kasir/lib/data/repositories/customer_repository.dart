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

  Future<void> addSpent(int id, int amount, {int pointsPerRupiah = 100, int goldThreshold = 1000, int platinumThreshold = 5000}) async {
    final c = await byId(id);
    if (c == null) return;
    final total = c.totalSpent + amount;
    final points = total ~/ pointsPerRupiah;
    final level = points >= platinumThreshold ? 'Platinum' : points >= goldThreshold ? 'Gold' : 'Silver';
    await (db.update(db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(totalSpent: Value(total), points: Value(points), level: Value(level)));
  }

  /// Redeem points for discount. Returns the discount amount in Rupiah (1 poin = Rp 1).
  /// Returns null if customer not found or insufficient points.
  Future<int?> redeemPoints(int id, int pointsToRedeem) async {
    final c = await byId(id);
    if (c == null || c.points < pointsToRedeem) return null;
    final newPoints = c.points - pointsToRedeem;
    await (db.update(db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(points: Value(newPoints)));
    return pointsToRedeem; // 1 poin = Rp 1
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
