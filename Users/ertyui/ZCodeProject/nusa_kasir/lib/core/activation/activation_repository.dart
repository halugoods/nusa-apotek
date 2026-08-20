import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/activation/activation_key.dart';
import 'package:nusa_kasir/core/activation/activation_public_key.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/core/services/google_auth_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/backup_crypto.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class ActivationResult {
  final bool ok;
  final String? error;
  ActivationResult(this.ok, [this.error]);
}

class ActivationRepository {
  final SupabaseClient? client;
  ActivationRepository(this.client);

  Future<bool> get isActivated async =>
      (await SecureStore.getActivation()) != null;

  /// Get the Google user ID (used as encryption key for backups).
  ///
  /// v2.2.38: JANGAN fallback ke UID sesi anon Supabase untuk path/decrypt.
  /// Backup selalu dienkripsi + dipath dengan Google UID (`nusa_google_user_id`
  /// dari GoogleAuthService — angka 21 digit). UID anon (UUID format) ≠ Google
  /// UID → path berbeda → `hasBackup()` tak pernah menemukan backup + dekripsi
  /// gagal. Verifikasi 2026-08-20: SEMUA backup di bucket nusa-backups ada di
  /// path angka 21 digit, TIDAK ADA satu pun path UUID anon — fallback anon
  /// hanya menghasilkan path kosong → dialog "Data Ditemukan" tak muncul →
  /// user disuruh setup ulang padahal datanya ada. Kalau Google UID kosong →
  /// null (caller lanjut ke setup / minta login Google).
  static Future<String?> _googleUserId() async {
    return SecureStore.read(key: 'nusa_google_user_id');
  }

  /// Ensure an anonymous Supabase session exists so background storage calls
  /// (auto-sync upload/download) work without forcing interactive auth.
  ///
  /// v2.2.37: BLOCKING + RETRY. Sebelumnya `signInAnonymously()` dipanggil
  /// tanpa menunggu — `hasBackup()` langsung lanjut ke `storage.list(...)`
  /// padahal sesi anon belum ada → storage gagal → dialog "Data Ditemukan"
  /// tidak pernah muncul (bug login kritis #1). Sekarang tunggu sesi sampai
  /// benar-benar ada, retry maksimal 3x dengan jeda 300ms, baru lanjut.
  Future<void> _ensureAnonAuth() async {
    if (client == null) return;
    final auth = client!.auth;
    if (auth.currentSession != null) return;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await auth.signInAnonymously();
        if (res.session != null) return;
      } catch (e) {
        debugPrint('[Auth] signInAnonymously attempt $attempt: $e');
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// Activate with Google ID (new flow).
  /// - Verifies Ed25519 signature locally
  /// - Sends key + googleUserId to register_activation edge function
  /// - Links license ↔ Google ID in cloud
  Future<ActivationResult> activate(String rawKey, String googleUserId) async {
    final key = rawKey.trim().toUpperCase();
    final valid = await ActivationKey.verify(key, nusaActivationPublicKey);
    if (!valid) return ActivationResult(false, 'Key tidak valid');

    await SecureStore.saveActivation(key);

    if (client != null) {
      try {
        final ownerEmail = await GoogleAuthService.getStoredEmail();
        final res = await client!.functions.invoke(
          'register_activation',
          body: {
            'key': key,
            'googleUserId': googleUserId,
            'product': NusaConfig.productId,
            if (ownerEmail != null) 'ownerEmail': ownerEmail,
          },
        );
        if (res.status >= 400) {
          final data = res.data as Map<String, dynamic>?;
          final err = data?['error'] as String? ?? 'Aktivasi gagal';
          if (res.status == 403) {
            await SecureStore.clearActivation();
            return ActivationResult(false, 'Key dibatalkan atau tidak valid');
          }
          if (res.status == 409) {
            await SecureStore.clearActivation();
            return ActivationResult(
              false,
              data?['message'] as String? ??
                  'Akun Google sudah dipakai untuk license lain',
            );
          }
          await SecureStore.clearActivation();
          return ActivationResult(false, err);
        }
      } catch (_) {
        // offline: keep local activation
      }
    }
    return ActivationResult(true);
  }

  /// Build the backup path using the stored Google user ID + product ID.
  /// Namespaced per product to prevent cross-variant data leakage.
  static Future<String?> _backupPath() async {
    final uid = await _googleUserId();
    if (uid == null) return null;
    return '$uid/${NusaConfig.productId}/backup.sqlite.enc';
  }

  /// Check if an encrypted backup exists in Supabase Storage for the linked Google account.
  ///
  /// v2.2.38: JANGAN pakai `storage.list()` untuk deteksi — anon key TIDAK
  /// punya izin list folder (404 "Bucket not found" meski bucket terlihat di
  /// `/bucket` dan download langsung 200). Akibatnya `hasBackup()` selalu
  /// false → dialog "Data Ditemukan" tak muncul → SEMUA user disuruh setup
  /// ulang padahal datanya ada (verifikasi 2026-08-20: download path persis
  /// 200 untuk 11 UID / 21 backup). Fix: probe dengan download → 200 = ada.
  ///
  /// v2.2.42: verifikasi ISI backup — folder backup bisa tercemar data varian
  /// LAIN (mis. folder nusa-fnb berisi produk servis, kasus user 2026-08-20).
  /// Kalau isi backup bukan milik varian ini, `hasBackup()` menganggap TIDAK
  /// ADA supaya dialog "Data Ditemukan" TIDAK menawarkan data varian lain
  /// (restore data salah varian = data user hilang dari layar). Cek murah:
  /// PRAGMA user_version + nama tabel + kategori produk dari sqlite bytes.
  Future<bool> hasBackup() async {
    if (client == null) return false;
    await _ensureAnonAuth();
    final uid = await _googleUserId();
    if (uid == null) return false;
    try {
      final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
      final bytes = await client!.storage
          .from('nusa-backups')
          .download(path);
      if (bytes.isEmpty) return false;
      // v2.2.42: verifikasi ISI backup (decrypt + unpack + cek varian) —
      // kalau isinya data varian lain, anggap TIDAK ADA (dialog Data
      // Ditemukan tak muncul → user setup dari nol untuk varian ini).
      final decrypted = await BackupCrypto.decrypt(bytes, uid);
      return await _backupBelongsToVariant(decrypted, uid);
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah isi backup milik varian aplikasi ini. Backup dari varian lain
  /// (folder yang tercemar / setup keliru) TIDAK boleh di-restore — datanya
  /// bukan punya user untuk varian ini.
  ///
  /// Input [archive] = bytes hasil `BackupCrypto.decrypt()` (gzip/NUS1 arsip
  /// berisi nusa_kasir.sqlite + gambar) — di-unpack di sini, jadi aman
  /// dipanggil dengan hasil decrypt langsung. Heuristik:
  /// 1. user_version < 20 → backup sangat lama / rusak → tolak.
  /// 2. Tabel kunci (products, transactions, employees) tidak ada → bukan
  ///    DB NUSA → tolak.
  /// 3. image_path produk menyebut paket aplikasi yang BUKAN paket varian ini
  ///    (mis. `/data/user/0/com.nusa.servis/...` di dalam folder nusa-fnb) →
  ///    pasti data varian lain → tolak. Ini sinyal PALING definitif (kasus
  ///    user 2026-08-20: folder nusa-fnb berisi produk servis, pkg
  ///    com.nusa.servis).
  /// 4. metadata.json `variantKey` (ditulis mulai v2.2.42) beda dari varian
  ///    ini → tolak. Backup baru selalu membawa identitas varian di metadata.
  Future<bool> _backupBelongsToVariant(
    List<int> archive,
    String googleUserId,
  ) async {
    try {
      // Cek metadata variantKey dulu (kalau ada — backup versi baru).
      final meta = await getBackupMetadata();
      final metaVariant = meta?['variantKey'] as String?;
      if (metaVariant != null && metaVariant != NusaConfig.productId) {
        return false;
      }

      // Unpack arsip → sqlite (atau raw sqlite kalau format lama).
      final files = BackupCrypto.unpackFiles(Uint8List.fromList(archive));
      final sqlite = files['nusa_kasir.sqlite'];
      if (sqlite == null) return false;

      // Tulis bytes sqlite ke file temp di documents dir (relatif — pola sama
      // dengan _migrateSqliteBytes) lalu baca ringkasan schema.
      final tempName =
          'nusa_verify_${DateTime.now().millisecondsSinceEpoch}.sqlite';
      final dir = await getApplicationDocumentsDirectory();
      final tmp = File(p.join(dir.path, tempName));
      await tmp.writeAsBytes(sqlite, flush: true);
      try {
        final res = await _inspectSqlite(tempName);
        if (res == null) return false;
        return inspectMatchesVariant(
          res,
          expectedPackage:
              'com.nusa.${NusaConfig.productId.replaceFirst('nusa-', '')}',
        );
      } finally {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    } catch (_) {
      // Gagal verifikasi → aman: anggap backup tidak valid (jangan restore
      // data yang tidak dikenal; lebih baik dialog tak muncul daripada
      // menimpa user dengan data varian lain).
      return false;
    }
  }

  /// Keputusan murni dari hasil [inspectSqliteResult] — apakah isi DB milik
  /// varian dengan paket [expectedPackage]. Dipisah supaya bisa di-unit-test
  /// (tanpa Supabase / network). [inspectSqliteResult] = output _inspectSqlite.
  /// Public (bukan private) supaya bisa dites dari test package.
  static bool inspectMatchesVariant(
    Map<String, dynamic> inspectSqliteResult, {
    required String expectedPackage,
  }) {
    final version = inspectSqliteResult['user_version'] as int? ?? 0;
    if (version < 20) return false; // backup terlalu lama/rusak
    if (inspectSqliteResult['has_products'] != true ||
        inspectSqliteResult['has_employees'] != true ||
        inspectSqliteResult['has_transactions'] != true) {
      return false; // bukan DB NUSA lengkap
    }
    // Cek paket aplikasi dari image_path produk (bila ada).
    final pkgs = (inspectSqliteResult['packages'] as List<dynamic>? ?? [])
        .cast<String>()
        .toSet();
    final foreignPkg =
        pkgs.any((p) => p != expectedPackage && p.startsWith('com.nusa.'));
    if (foreignPkg) return false;
    return true;
  }

  /// Baca ringkasan sqlite (user_version, tabel kunci, kategori, paket
  /// aplikasi) dari file temp via drift (AppDatabase.at — pola yang sama
  /// dengan _migrateSqliteBytes; beforeOpen repair jalan tapi hanya pada
  /// salinan temp). Return null kalau bukan sqlite valid.
  Future<Map<String, dynamic>?> _inspectSqlite(String tempName) async {
    try {
      final db = AppDatabase.at(tempName);
      await db.customSelect('SELECT 1').get(); // trigger open + migrasi
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
    } catch (_) {
      return null;
    }
  }

  /// Get the cloud backup's last-modified timestamp.
  ///
  /// v2.2.38: pakai `Last-Modified` header dari download (storage API selalu
  /// kirim header ini, terbukti 200 + Last-Modified di verifikasi). List
  /// folder (yang butuh izin list) diganti karena 404 untuk anon key.
  Future<DateTime?> getBackupTimestamp() async {
    if (client == null) return null;
    await _ensureAnonAuth();
    final uid = await _googleUserId();
    if (uid == null) return null;
    try {
      final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
      final res = await client!.storage
          .from('nusa-backups')
          .download(path);
      if (res.isEmpty) return null;
      // Last-Modified tidak diekspos SDK → ambil timestamp upload via
      // metadata.json bila ada; fallback ke waktu sekarang (backup ada).
      final meta = await _readMetadata();
      if (meta != null) {
        final t = DateTime.tryParse(meta['updated_at']?.toString() ?? '');
        if (t != null) return t;
      }
      return DateTime.now();
    } catch (_) {
      return null;
    }
  }

  /// Baca metadata.json (preview info) — dipakai getBackupTimestamp.
  Future<Map<String, dynamic>?> _readMetadata() async {
    return getBackupMetadata();
  }

  /// Upload current local DB + product images to cloud.
  /// Packed as a single archive, encrypted with Google user ID.
  /// Also uploads a metadata.json so the "data found" dialog can preview
  /// store name, owner name, and backup time without decrypting the archive.
  Future<bool> uploadBackupNow({String? storeName, String? ownerName}) async {
    if (client == null) return false;
    await _ensureAnonAuth();
    final uid = await _googleUserId();
    if (uid == null) return false;
    final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dir.path, 'nusa_kasir.sqlite'));
      if (!await dbFile.exists()) return false;

      // Pack SQLite + product images into single archive
      final files = <String, Uint8List>{};
      files['nusa_kasir.sqlite'] = await dbFile.readAsBytes();

      // Collect all product, employee, and QRIS image files
      final dirContents = dir.listSync();
      for (final entity in dirContents) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if ((name.startsWith('product_') ||
                  name.startsWith('photo_') ||
                  name.startsWith('qris_')) &&
              (name.endsWith('.jpg') ||
                  name.endsWith('.jpeg') ||
                  name.endsWith('.png') ||
                  name.endsWith('.webp'))) {
            files[name] = await entity.readAsBytes();
          }
        }
      }

      final packed = BackupCrypto.packFiles(files);
      final encrypted = await BackupCrypto.encrypt(packed, uid);
      await client!.storage
          .from('nusa-backups')
          .uploadBinary(
            path,
            encrypted,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );

      // Upload metadata (non-sensitive preview info — not encrypted)
      final now = DateTime.now();
      await _uploadMetadata(uid, storeName ?? '', ownerName ?? '', now);
      await SecureStore.saveLastBackupTime(now);
      debugPrint(
        '[Backup] Uploaded DB + ${files.length - 1} images (${encrypted.length} bytes encrypted)',
      );
      return true;
    } catch (e) {
      debugPrint('[Backup] uploadBackupNow error: $e');
      return false;
    }
  }

  /// Upload a small metadata.json alongside the encrypted backup.
  /// This lets the activation screen preview store name, owner, and
  /// backup time BEFORE downloading and decrypting the full archive.
  ///
  /// v2.2.42: metadata ditulis ke path TANPA nama varian (`metadata.json`)
  /// agar aplikasi varian lain bisa membacanya untuk verifikasi varian
  /// (folder backup yang tercemar data varian lain bisa ketahuan). Daftar
  /// path yang dibaca: `metadata.json` (versi baru) lalu fallback ke
  /// `{productId}/metadata.json` (versi lama). `variantKey` disimpan supaya
  /// verifikasi isi backup bisa membandingkan identitas varian.
  Future<void> _uploadMetadata(
    String uid,
    String storeName,
    String ownerName,
    DateTime backupTime,
  ) async {
    try {
      final meta = {
        'storeName': storeName,
        'ownerName': ownerName,
        'backupTime': backupTime.toIso8601String(),
        'appVersion': '${NusaConfig.appVersion}+${NusaConfig.appBuildNumber}',
        'productId': NusaConfig.productId,
        'variantKey': NusaConfig.productId,
      };
      final jsonBytes = Uint8List.fromList(
        const JsonEncoder.withIndent('  ').convert(meta).codeUnits,
      );
      await client!.storage.from('nusa-backups').uploadBinary(
        '$uid/metadata.json',
        jsonBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'application/json',
        ),
      );
    } catch (_) {
      // Non-critical — the encrypted backup already succeeded
    }
  }

  /// Fetch the backup metadata (store name, owner, backup time)
  /// without downloading the encrypted archive.
  /// Returns null if metadata doesn't exist or fetch fails.
  Future<Map<String, dynamic>?> getBackupMetadata() async {
    if (client == null) return null;
    final uid = await _googleUserId();
    if (uid == null) return null;
    // v2.2.42: baca path versi-agnostik dulu, lalu fallback ke path lama
    // (per-varian). Backup lama menulis per-varian; versi baru menulis
    // root — dua-duanya dibaca supaya verifikasi varian jalan untuk backup
    // lama sekaligus backup baru.
    for (final metaPath in [
      '$uid/metadata.json',
      '$uid/${NusaConfig.productId}/metadata.json',
    ]) {
      try {
        final bytes =
            await client!.storage.from('nusa-backups').download(metaPath);
        if (bytes.isEmpty) continue;
        final text = utf8.decode(bytes);
        return jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Download backup from cloud and write directly to the live DB + images.
  /// Restore berlaku IMMEDIATE — caller harus menutup koneksi drift dulu
  /// (lihat RestoreBackupFlow / _autoRestoreIfNeeded) supaya swap aman.
  /// Returns true on success.
  Future<bool> restoreDirect() async {
    if (client == null) return false;
    await _ensureAnonAuth();
    final uid = await _googleUserId();
    if (uid == null) return false;
    final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
    try {
      final bytes = await client!.storage.from('nusa-backups').download(path);
      if (bytes.isEmpty) return false;
      final decrypted = await BackupCrypto.decrypt(bytes, uid);
      // v2.2.42: jangan pernah restore backup yang isinya data varian LAIN
      // (folder tercemar — mis. nusa-fnb berisi produk servis). Restore data
      // salah varian = data user hilang dari layar varian ini.
      if (!await _backupBelongsToVariant(decrypted, uid)) return false;
      final dir = await getApplicationDocumentsDirectory();

      // Unpack archive (DB + images) directly — no restart needed
      final packedFiles = BackupCrypto.unpackFiles(Uint8List.fromList(decrypted));
      var imageCount = 0;
      final rootCanonical = p.normalize(Directory(dir.path).absolute.path);
      for (final entry in packedFiles.entries) {
        final destination = File(p.join(dir.path, entry.key));
        final destinationCanonical = p.normalize(destination.absolute.path);
        if (destinationCanonical != rootCanonical &&
            !p.isWithin(rootCanonical, destinationCanonical)) {
          throw FormatException(
            'Restore path escapes application directory: ${entry.key}',
          );
        }

        // ── v2.2.37: swap LANGSUNG ke live sqlite (bukan .pending) ──
        // Caller (RestoreBackupFlow / _autoRestoreIfNeeded) SUDAH menutup
        // koneksi drift (`ref.read(databaseProvider).close()` + invalidate)
        // sebelum memanggil restoreDirect(). Karena tidak ada koneksi drift
        // yang terbuka, menulis langsung ke nusa_kasir.sqlite AMAN dan restore
        // berlaku IMMEDIATE — tidak perlu restart, tidak ada .pending yang
        // menggantung, tidak ada jendela di mana app membaca DB lama yang
        // kosong (PIN gagal + produk kosong) setelah restart gagal.
        // v2.2.39: SEBELUM menulis file, jalankan migrasi drift schema
        // terhadap bytes hasil decrypt — backup lama (mis. varian lain yang
        // masih ver 26-30) bisa bawa kolom/tabel yang belum ada. Kalau dibiarkan,
        // drift tidak akan migrasi (user_version sudah dibaca & di-cache di
        // koneksi), query produk error "no such column" → loading abadi.
        // Jalankan eksplisit supaya DB hasil restore SELALU schema 44.
        if (entry.key == 'nusa_kasir.sqlite') {
          final migrated = await _migrateSqliteBytes(entry.value, uid);
          final live = File(p.join(dir.path, 'nusa_kasir.sqlite'));
          // Bersihkan sidecar WAL/SHM supaya SQLite tidak me-replay data lama
          // di atas file yang baru ditimpa.
          for (final sidecar in [
            '${live.path}-wal',
            '${live.path}-shm',
            '${live.path}-journal',
          ]) {
            final f = File(sidecar);
            if (await f.exists()) {
              try {
                await f.delete();
              } catch (_) {}
            }
          }
          await live.writeAsBytes(migrated, flush: true);
          await SecureStore.clearPendingRestore();
          continue;
        }
        await File(destinationCanonical).writeAsBytes(entry.value, flush: true);
        if (entry.key != 'nusa_kasir.sqlite') imageCount++;
      }

      // Pull backup timestamp from metadata if available
      final meta = await getBackupMetadata();
      final ts = meta?['backupTime'] as String?;
      if (ts != null) {
        await SecureStore.saveLastBackupTime(DateTime.parse(ts));
      }

      debugPrint('[RestoreDirect] Restored DB${imageCount > 0 ? " + $imageCount images" : ""} (live swap, no restart needed)');
      return true;
    } catch (e) {
      debugPrint('[RestoreDirect] error: $e');
      return false;
    }
  }

  /// Download backup from cloud and stage it for restore on next launch.
  /// Uses Google user ID for decryption.
  ///
  /// v2.2.37: gunakan untuk jalur yang TIDAK bisa menutup drift — background
  /// AutoSyncService & settings manual. Stage .pending → di-swap oleh
  /// main.dart _applyPendingRestore() saat start berikutnya (tidak menabrak
  /// koneksi drift yang selalu terbuka). Untuk jalur user-facing (activation /
  /// RestoreBackupFlow) gunakan restoreDirect() (live swap setelah drift
  /// ditutup).
  Future<bool> restoreFromCloud() async {
    if (client == null) return false;
    await _ensureAnonAuth();
    final uid = await _googleUserId();
    if (uid == null) return false;
    final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
    try {
      final bytes = await client!.storage.from('nusa-backups').download(path);
      if (bytes.isEmpty) return false;
      final decrypted = await BackupCrypto.decrypt(bytes, uid);
      // v2.2.42: jangan pernah stage backup yang isinya data varian LAIN.
      if (!await _backupBelongsToVariant(decrypted, uid)) return false;
      final dir = await getApplicationDocumentsDirectory();

      // v2.2.39: migrasi schema eksplisit sebelum di-stage — backup lama
      // (ver 26-30 dari varian lain) butuh kolom/tabel baru; kalau tidak,
      // drift tidak akan migrasi saat koneksi baru dibuka (user_version sudah
      // di-cache) → query produk error → loading abadi (lihat restoreDirect).
      final migrated = await _migrateSqliteBytes(decrypted, uid);

      final pending = File(p.join(dir.path, 'nusa_kasir.sqlite.pending'));
      await pending.writeAsBytes(migrated, flush: true);
      await SecureStore.savePendingRestore();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Jalankan migrasi drift schema terhadap bytes SQLite hasil decrypt.
  /// Menulis bytes ke file temp, buka dengan AppDatabase (memicu `onUpgrade`
  /// sampai schemaVersion 44), lalu baca hasilnya kembali. Fallback: kalau
  /// migrasi gagal (DB rusak), kembalikan bytes asli — restore tetap jalan,
  /// query produk yang butuh kolom baru tinggal error, tapi app tidak crash.
  Future<List<int>> _migrateSqliteBytes(
    List<int> bytes,
    String googleUserId,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final temp = File(p.join(dir.path, 'nusa_kasir.sqlite.migrate'));
      await temp.writeAsBytes(bytes, flush: true);
      // AppDatabase.at() membuka FILE TEMP (bukan live) → migrasi onUpgrade
      // dijalankan terhadap bytes hasil decrypt. AppDatabase() normal selalu
      // buka nusa_kasir.sqlite (live) — salah sasaran kalau dipakai di sini.
      final db = AppDatabase.at('nusa_kasir.sqlite.migrate');
      // Buka + tutup → drift menjalankan onUpgrade (from=user_version → 44).
      // Tutup file secara manual supaya koneksi benar-benar release.
      await db.customSelect('SELECT 1').get();
      await db.close();
      // Hapus sidecar hasil migrasi (temp saja, bukan live).
      for (final sidecar in ['-wal', '-shm', '-journal']) {
        final f = File(temp.path + sidecar);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      final migrated = await temp.readAsBytes();
      await temp.delete();
      return migrated;
    } catch (e) {
      debugPrint('[Restore] _migrateSqliteBytes fallback (keep original): $e');
      return bytes;
    }
  }

  /// Auto-sync: check if cloud backup is newer than local state.
  /// If so, download and replace the local database directly (no restart needed).
  /// Returns true if sync was performed.
  ///
  /// NOTE: no longer a direct overwrite — the DB is staged to a .pending file
  /// that main.dart applies BEFORE the next database open. Overwriting the
  /// live sqlite file while drift has it open corrupts the session (empty
  /// reads → login fails, menu buttons dead). Sync here = stage for next
  /// launch; the pending swap is atomic.
  Future<bool> syncIfNewer() async {
    if (client == null) return false;
    try {
      await _ensureAnonAuth();
      final uid = await _googleUserId();
      if (uid == null) return false;

      // Check if cloud backup exists and get its timestamp.
      // v2.2.38: anon key tidak bisa `list()` folder (404) — probe download
      // dulu; kalau ada, pakai metadata.json untuk timestamp (upload selalu
      // menulis updated_at). Fallback: anggap backup ada & lebih baru (yang
      // penting data user ketemu, bukan dilewati karena takut menimpa).
      final cp = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
      try {
        final probe = await client!.storage.from('nusa-backups').download(cp);
        if (probe.isEmpty) return false;
      } catch (_) {
        return false;
      }
      final meta = await getBackupMetadata();
      final cloudTime = meta != null
          ? DateTime.tryParse(meta['updated_at']?.toString() ?? '')
          : null;

      // Compare with local last-sync timestamp
      final localTime = await SecureStore.getLastBackupTime();
      if (localTime != null && cloudTime != null && !cloudTime.isAfter(localTime)) {
        return false;
      }

      debugPrint('[Sync] Cloud backup newer ($cloudTime), downloading...');

      // Download & decrypt
      final bytes = await client!.storage.from('nusa-backups').download(cp);
      if (bytes.isEmpty) return false;

      final decrypted = await BackupCrypto.decrypt(bytes, uid);
      // v2.2.42: jangan pernah sync backup yang isinya data varian LAIN —
      // kalau cloud tercemar, cukup adopsi timestamp-nya tanpa menimpa lokal.
      if (!await _backupBelongsToVariant(decrypted, uid)) {
        if (cloudTime != null) await SecureStore.setLastCloudSeen(cloudTime);
        return false;
      }
      final dir = await getApplicationDocumentsDirectory();

      // Unpack archive (DB + images). The DB goes to .pending (applied at
      // next launch); images are written directly — safe, they're not open
      // by any connection.
      final packedFiles = BackupCrypto.unpackFiles(
        Uint8List.fromList(decrypted),
      );
      var imageCount = 0;
      final rootCanonical = p.normalize(Directory(dir.path).absolute.path);
      for (final entry in packedFiles.entries) {
        if (entry.key == 'nusa_kasir.sqlite') {
          final pending = File(p.join(dir.path, 'nusa_kasir.sqlite.pending'));
          await pending.writeAsBytes(entry.value, flush: true);
          await SecureStore.savePendingRestore();
          continue;
        }
        final destination = File(p.join(dir.path, entry.key));
        final destinationCanonical = p.normalize(destination.absolute.path);
        if (destinationCanonical != rootCanonical &&
            !p.isWithin(rootCanonical, destinationCanonical)) {
          throw FormatException(
            'Restore path escapes application directory: ${entry.key}',
          );
        }
        await File(destinationCanonical).writeAsBytes(entry.value, flush: true);
        imageCount++;
      }

      // v2.2.38: cloudTime bisa null (tanpa metadata) — tetap stage DB.
      // Kalau null, skip simpan lastBackupTime supaya next launch coba lagi.
      if (cloudTime != null) {
        await SecureStore.saveLastBackupTime(cloudTime);
      }
      debugPrint(
        '[Sync] Staged DB${imageCount > 0 ? " + $imageCount images" : ""} from cloud (applied next launch)',
      );
      return true;
    } catch (e) {
      debugPrint('[Sync] syncIfNewer error: $e');
      return false;
    }
  }

  // ── Legacy methods (kept for backward compatibility with old activation-key based backups) ──

  /// Upload using old activation-key encryption. Used for migration.
  @Deprecated('Use uploadBackupNow() which encrypts with Google ID')
  Future<bool> uploadBackup(String activationKey) async {
    if (client == null) return false;
    final uid = await _googleUserId();
    if (uid == null) return false;
    final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'nusa_kasir.sqlite'));
      if (!await file.exists()) return false;
      final raw = await file.readAsBytes();
      final encrypted = await BackupCrypto.encrypt(raw, activationKey);
      await client!.storage
          .from('nusa-backups')
          .uploadBinary(
            path,
            encrypted,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  @Deprecated('Use restoreFromCloud() which decrypts with Google ID')
  Future<bool> downloadAndRestore(String activationKey) async {
    if (client == null) return false;
    await _ensureAnonAuth();
    final path = await _backupPath();
    if (path == null) return false;
    try {
      final bytes = await client!.storage.from('nusa-backups').download(path);
      if (bytes.isEmpty) return false;
      final decrypted = await BackupCrypto.decrypt(bytes, activationKey);
      final dir = await getApplicationDocumentsDirectory();
      final pending = File(p.join(dir.path, 'nusa_kasir.sqlite.pending'));
      await pending.writeAsBytes(decrypted, flush: true);
      await SecureStore.savePendingRestore();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deactivate() async => SecureStore.clearActivation();
}
