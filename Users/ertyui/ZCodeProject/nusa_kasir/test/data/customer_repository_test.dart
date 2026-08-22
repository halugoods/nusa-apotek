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

  test('byBarcode finds member by normalized barcode (B11)', () async {
    // Form member menormalisasi barcode saat simpan (spasi/dash dibuang) —
    // sama dengan scan HID/kamera (customers_screen._normBarcode).
    final id = await repo.addCustomer(
      name: 'Budi',
      phone: '0813',
      barcode: 'MBRABC123',
    );
    // Simulasi scan HID/kamera: spasi/dash dihilangkan.
    final found = await repo.byBarcode('MBR ABC-123');
    expect(found, isNotNull);
    expect(found!.id, id);
    expect(found.barcode, 'MBRABC123');
    // Barcode yang tidak ada → null
    final miss = await repo.byBarcode('MBR-NOPE');
    expect(miss, isNull);
  });

  test('byBarcode menolak input kosong', () async {
    expect(await repo.byBarcode(''), isNull);
    expect(await repo.byBarcode('   '), isNull);
  });
}
