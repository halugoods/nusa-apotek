import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/role_repository.dart';

void main() {
  late AppDatabase db;
  late RoleRepository repo;

  setUp(() {
    db = AppDatabase.test();
    repo = RoleRepository(db);
  });

  test('default roles seeded with expected access', () async {
    final roles = await repo.getRoles();
    final owner = roles.firstWhere((r) => r['name'] == 'Owner');
    final gudang = roles.firstWhere((r) => r['name'] == 'Gudang');
    final finance = roles.firstWhere((r) => r['name'] == 'Finance');
    final kasir = roles.firstWhere((r) => r['name'] == 'Kasir');

    // Owner punya supplier; Kasir tidak
    expect(owner['access'], contains('supplier'));
    expect(kasir['access'], isNot(contains('supplier')));
    // Gudang/Finance akses stok & supplier (konteks restok)
    expect(gudang['access'], contains('stok'));
    expect(finance['access'], contains('supplier'));
  });

  test('existing roles are preserved verbatim on reload', () async {
    // Simulasi DB lama: role Owner tersimpan dengan kustomisasi admin
    // (kehilangan 'transaksi' dari default, punya 'pengaturan' tambahan).
    await db.into(db.roles).insert(RolesCompanion.insert(
      name: 'Owner',
      color: Value('0xFF8B5CF6'),
      accessJson: Value(jsonEncode([
        'home', 'kasir', 'produk', 'stok', 'pelanggan',
        'laporan', 'supplier', 'pengaturan',
      ])),
    ));
    await db.into(db.roles).insert(RolesCompanion.insert(
      name: 'Gudang',
      color: const Value('0xFFF59E0B'),
      accessJson: Value(jsonEncode(['home', 'produk', 'stok', 'laporan', 'supplier'])),
    ));

    final roles = await repo.getRoles();
    final owner = roles.firstWhere((r) => r['name'] == 'Owner');
    final gudang = roles.firstWhere((r) => r['name'] == 'Gudang');

    // Kustomisasi admin TIDAK ditimpa
    expect(owner['access'], contains('pengaturan'));
    expect(owner['access'], contains('kasir'));
    expect(owner['access'], isNot(contains('transaksi')));
    // Data role lain tidak berubah
    expect(gudang['access'], contains('supplier'));
    // Default yang belum ada tetap di-seed
    final kasir = roles.firstWhere((r) => r['name'] == 'Kasir');
    expect(kasir['access'], isNotEmpty);
  });
}
