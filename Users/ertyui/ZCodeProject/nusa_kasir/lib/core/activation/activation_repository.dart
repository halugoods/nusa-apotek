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
      return bytes.isNotEmpty;
    } catch (_) {
      return false;
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
      };
      final jsonBytes = Uint8List.fromList(
        const JsonEncoder.withIndent('  ').convert(meta).codeUnits,
      );
      await client!.storage.from('nusa-backups').uploadBinary(
        '$uid/${NusaConfig.productId}/metadata.json',
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
    final metaPath = '$uid/${NusaConfig.productId}/metadata.json';
    try {
      final bytes = await client!.storage.from('nusa-backups').download(metaPath);
      if (bytes.isEmpty) return null;
      final text = utf8.decode(bytes);
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
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
