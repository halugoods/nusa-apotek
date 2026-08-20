import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Fake path_provider: getApplicationDocumentsDirectory → folder temp.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.dir);
  final Directory dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
  @override
  Future<String?> getTemporaryPath() async => dir.path;
}

/// Verifikasi varian backup (v2.2.42) — mencegah restore data varian LAIN.
/// Kasus nyata 2026-08-20: folder nusa-fnb berisi produk servis
/// (image_path /data/user/0/com.nusa.servis/...) → backup itu harus TOLAK
/// kalau dibuka dari aplikasi fnb.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Baca fixture + inspect via drift (mirip _inspectSqlite internal).
  Future<Map<String, dynamic>?> inspectFixture(String fixturePath) async {
    final src = File(fixturePath);
    if (!src.existsSync()) return null;
    final dir = Directory.systemTemp.createTempSync('nusa_verify_test');
    final live = File('${dir.path}/nusa_verify.sqlite');
    live.writeAsBytesSync(src.readAsBytesSync());
    PathProviderPlatform.instance = FakePathProvider(dir);

    final db = AppDatabase.at('nusa_verify.sqlite');
    await db.customSelect('SELECT 1').get();
    final versionRow =
        await db.customSelect('PRAGMA user_version').getSingle();
    final v = versionRow.data['user_version'] as int? ?? 0;
    final tables = <String>{};
    final tableRows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    for (final row in tableRows) {
      tables.add('${row.data['name']}');
    }
    final packages = <String>[];
    if (tables.contains('products')) {
      final imgs = await db.customSelect(
        "SELECT image_path FROM products WHERE image_path IS NOT NULL AND image_path != '' LIMIT 10",
      ).get();
      for (final row in imgs) {
        final m = RegExp(r'com\.nusa\.[a-z0-9_]+')
            .firstMatch('${row.data['image_path']}');
        if (m != null) packages.add(m.group(0)!);
      }
    }
    await db.close();
    return {
      'user_version': v,
      'has_products': tables.contains('products'),
      'has_employees': tables.contains('employees'),
      'has_transactions': tables.contains('transactions'),
      'packages': packages,
    };
  }

  test('fnb backup yang isi data servis DITOLAK dari varian fnb', () async {
    final res = await inspectFixture('test/fixtures/fnb_real.sqlite');
    if (res == null) {
      markTestSkipped('fixture fnb_real.sqlite tidak ada');
      return;
    }
    // fnb_real = folder nusa-fnb yang tercemar data servis (pkg com.nusa.servis).
    expect(res['packages'], contains('com.nusa.servis'));
    final ok = ActivationRepository.inspectMatchesVariant(
      res,
      expectedPackage: 'com.nusa.fnb',
    );
    expect(ok, isFalse, reason: 'backup servis tidak boleh direstore dari fnb');
  });

  test('kelontong backup DITERIMA dari varian kelontong', () async {
    final res = await inspectFixture('test/fixtures/kelontong_real.sqlite');
    if (res == null) {
      markTestSkipped('fixture kelontong_real.sqlite tidak ada');
      return;
    }
    final ok = ActivationRepository.inspectMatchesVariant(
      res,
      expectedPackage: 'com.nusa.kelontong',
    );
    expect(ok, isTrue);
  });

  test('backup tanpa image_path tetap diterima bila varian cocok', () async {
    final res = {
      'user_version': 44,
      'has_products': true,
      'has_employees': true,
      'has_transactions': true,
      'packages': <String>[],
    };
    expect(
      ActivationRepository.inspectMatchesVariant(
        res,
        expectedPackage: 'com.nusa.fnb',
      ),
      isTrue,
    );
  });

  test('DB rusak / bukan NUSA ditolak', () async {
    final res = {
      'user_version': 5,
      'has_products': false,
      'has_employees': false,
      'has_transactions': false,
      'packages': <String>[],
    };
    expect(
      ActivationRepository.inspectMatchesVariant(
        res,
        expectedPackage: 'com.nusa.fnb',
      ),
      isFalse,
    );
  });
}
