import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';

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

/// B1 (v2.2.45): foto produk & profil karyawan ikut backup cloud sebagai
/// BASE64. Setelah restore di device baru, imagePath/photoPath menunjuk ke
/// file yang hilang → hydrateImages()/hydratePhotos() menulis ulang dari
/// kolom base64 lalu memperbarui path di DB. Test ini memverifikasi end-to-end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('nusa_hydrate');
    PathProviderPlatform.instance = FakePathProvider(dir);
    db = AppDatabase.test();
  });

  tearDown(() async {
    await db.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('product hydrateImages restores missing local file from base64',
      () async {
    final repo = ProductRepository(db);
    final bytes = base64Encode(utf8.encode('FAKE-JPG-BYTES'));
    // Simulasikan produk dari backup: imagePath menunjuk file yang HILANG,
    // imageBase64 berisi data foto sebenarnya.
    final id = await db.into(db.products).insert(ProductsCompanion.insert(
      name: 'Indomie',
      sellPrice: 3500,
      imagePath: Value('${dir.path}/product_deleted.jpg'),
      imageBase64: Value(bytes),
    ));

    // File belum ada → hydrate harus membuatnya.
    final hydrated = await repo.hydrateImages();
    expect(hydrated, 1);

    final p = await repo.byId(id);
    final newPath = p!.imagePath!;
    expect(newPath, isNot('${dir.path}/product_deleted.jpg'));
    expect(File(newPath).existsSync(), isTrue);
    expect(File(newPath).readAsBytesSync(), utf8.encode('FAKE-JPG-BYTES'));

    // Idempoten: file sudah ada → tidak diproses lagi.
    expect(await repo.hydrateImages(), 0);
  });

  test('employee hydratePhotos restores missing photo from base64', () async {
    final repo = AttendanceRepository(db);
    final bytes = base64Encode(utf8.encode('FAKE-PHOTO-BYTES'));
    final id = await repo.addEmployee(
      name: 'Andi',
      pin: '1234',
      role: 'Kasir',
      photoPath: '${dir.path}/photo_deleted.jpg',
      photoBase64: bytes,
    );

    final hydrated = await repo.hydratePhotos();
    expect(hydrated, 1);

    final e = await repo.getEmployee(id);
    final newPath = e!.photoPath!;
    expect(newPath, isNot('${dir.path}/photo_deleted.jpg'));
    expect(File(newPath).existsSync(), isTrue);
    expect(File(newPath).readAsBytesSync(), utf8.encode('FAKE-PHOTO-BYTES'));

    // Idempoten
    expect(await repo.hydratePhotos(), 0);
  });
}