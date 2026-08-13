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

  test('default roles seeded with pembelian access', () async {
    final roles = await repo.getRoles();
    final owner = roles.firstWhere((r) => r['name'] == 'Owner');
    final gudang = roles.firstWhere((r) => r['name'] == 'Gudang');
    final finance = roles.firstWhere((r) => r['name'] == 'Finance');
    final kasir = roles.firstWhere((r) => r['name'] == 'Kasir');
    expect(owner['access'], contains('pembelian'));
    expect(gudang['access'], contains('pembelian'));
    expect(finance['access'], contains('pembelian'));
    // Kasir tidak dapat akses pembelian
    expect(kasir['access'], isNot(contains('pembelian')));
  });

  test('backfill adds pembelian to pre-existing default roles without clobbering', () async {
    // Simulasi DB lama (device yang sudah terpasang): role Owner/Gudang
    // tersimpan TANPA 'pembelian', plus kustomisasi admin (Owner kehilangan
    // 'transaksi' dari default, punya 'pengaturan' tambahan).
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

    // pembelian ditambahkan
    expect(owner['access'], contains('pembelian'));
    expect(gudang['access'], contains('pembelian'));
    // kustomisasi tidak ditimpa: 'pengaturan' tetap ada, 'kasir' tetap ada
    expect(owner['access'], contains('pengaturan'));
    expect(owner['access'], contains('kasir'));
    // menu default lain yang hilang TIDAK di-backfill (hanya menu baru)
    expect(owner['access'], isNot(contains('transaksi')));
    expect(owner['access'], isNot(contains('presensi')));
    // pembelian TIDAK ditambahkan ke role yang tidak tercantum (mis. Kasir)
    final kasir = roles.firstWhere((r) => r['name'] == 'Kasir');
    expect(kasir['access'], isNot(contains('pembelian')));
  });
}
