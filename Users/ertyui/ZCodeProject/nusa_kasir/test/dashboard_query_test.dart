import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Fake path_provider: getApplicationDocumentsDirectory → folder temp yang
/// berisi nusa_kasir.sqlite = backup asli hasil decrypt (schema 44).
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

void main() {
  Future<void> checkFixture(String fixturePath, String label) async {
    final src = File(fixturePath);
    if (!src.existsSync()) {
      markTestSkipped('fixture $label tidak ada');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('nusa_dash_$label');
    final live = File('${dir.path}/nusa_kasir.sqlite');
    live.writeAsBytesSync(src.readAsBytesSync());
    PathProviderPlatform.instance = FakePathProvider(dir);

    final db = AppDatabase();
    await db.customSelect('SELECT 1').get(); // open → beforeOpen repair

    Future<void> q(String n, Future<Object?> Function() f) async {
      try {
        final r = await f();
        print('OK   [$label] $n → ${r.toString().length} chars');
      } catch (e) {
        print('FAIL [$label] $n → $e');
        rethrow;
      }
    }

    await q('employees', () => db.select(db.employees).get());
    await q('products', () => db.select(db.products).get());
    await q('transactions', () => db.select(db.transactions).get());
    await q('settings', () => db.select(db.settings).get());
    await q('branches', () => db.select(db.branches).get());
    await q('cashier_sessions', () => db.select(db.cashierSessions).get());
    await q('customer_debts', () => db.select(db.customerDebts).get());
    await q('debt_payments', () => db.select(db.debtPayments).get());
    await q('roles', () => db.select(db.roles).get());

    await db.close();
  }

  test('dashboard queries jalan di DB restore fnb + kelontong (schema 44)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await checkFixture('test/fixtures/fnb_real.sqlite', 'fnb');
    await checkFixture('test/fixtures/kelontong_real.sqlite', 'kelontong');
  });
}
