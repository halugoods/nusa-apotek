import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';

void main() {
  late CustomerRepository repo;
  setUp(() => repo = CustomerRepository(AppDatabase.test()));
  test('addSpent updates total, points (Rp100=1), and level', () async {
    final id = await repo.addCustomer(name: 'Siti', phone: '0812');
    await repo.addSpent(id, 100000); // 1000 points -> Gold
    final c = await repo.byId(id);
    expect(c!.totalSpent, 100000);
    expect(c.points, 1000);
    expect(c.level, 'Gold');
  });
}
