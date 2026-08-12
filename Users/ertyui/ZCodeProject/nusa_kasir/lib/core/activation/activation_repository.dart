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
  static Future<String?> _googleUserId() async =>
      SecureStore.read(key: 'nusa_google_user_id');

  /// Ensure an anonymous Supabase session exists so background storage calls
  /// (auto-sync upload/download) work without forcing interactive auth.
  /// Non-blocking: failure just leaves the caller to use the existing session.
  Future<void> _ensureAnonAuth() async {
    try {
      final auth = client?.auth;
      if (auth == null) return;
      if (auth.currentSession != null) return;
      await auth.signInAnonymously();
    } catch (e) {
      debugPrint('[Auth] signInAnonymously skip: $e');
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
  Future<bool> hasBackup() async {
    if (client == null) return false;
    final uid = await _googleUserId();
    if (uid == null) return false;
    try {
      final productPath = '$uid/${NusaConfig.productId}';
      final res = await client!.storage
          .from('nusa-backups')
          .list(path: productPath);
      return res.any((f) => f.name == 'backup.sqlite.enc');
    } catch (_) {
      return false;
    }
  }

  /// Get the cloud backup's last-modified timestamp.
  Future<DateTime?> getBackupTimestamp() async {
    if (client == null) return null;
    final uid = await _googleUserId();
    if (uid == null) return null;
    try {
      final productPath = '$uid/${NusaConfig.productId}';
      final res = await client!.storage
          .from('nusa-backups')
          .list(path: productPath);
      for (final f in res) {
        if (f.name == 'backup.sqlite.enc') {
          return f.updatedAt != null ? DateTime.tryParse(f.updatedAt!) : null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
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
  /// Does NOT require a restart — the restored DB is ready immediately.
  /// Returns true on success.
  Future<bool> restoreDirect() async {
    if (client == null) return false;
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
        await File(destinationCanonical).writeAsBytes(entry.value, flush: true);
        if (entry.key != 'nusa_kasir.sqlite') imageCount++;
      }

      // Pull backup timestamp from metadata if available
      final meta = await getBackupMetadata();
      final ts = meta?['backupTime'] as String?;
      if (ts != null) {
        await SecureStore.saveLastBackupTime(DateTime.parse(ts));
      }

      debugPrint('[RestoreDirect] Restored DB${imageCount > 0 ? " + $imageCount images" : ""}');
      return true;
    } catch (e) {
      debugPrint('[RestoreDirect] error: $e');
      return false;
    }
  }

  /// Download backup from cloud and stage it for restore on next launch.
  /// Uses Google user ID for decryption.
  Future<bool> restoreFromCloud() async {
    if (client == null) return false;
    final uid = await _googleUserId();
    if (uid == null) return false;
    final path = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
    try {
      final bytes = await client!.storage.from('nusa-backups').download(path);
      if (bytes.isEmpty) return false;
      final decrypted = await BackupCrypto.decrypt(bytes, uid);
      final dir = await getApplicationDocumentsDirectory();
      final pending = File(p.join(dir.path, 'nusa_kasir.sqlite.pending'));
      await pending.writeAsBytes(decrypted, flush: true);
      await SecureStore.savePendingRestore();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Auto-sync: check if cloud backup is newer than local state.
  /// If so, download and replace the local database directly (no restart needed).
  /// Returns true if sync was performed.
  Future<bool> syncIfNewer() async {
    if (client == null) return false;
    try {
      final uid = await _googleUserId();
      if (uid == null) return false;

      // Check if cloud backup exists and get its timestamp
      final cp = '$uid/${NusaConfig.productId}/backup.sqlite.enc';
      final files = await client!.storage
          .from('nusa-backups')
          .list(path: '$uid/${NusaConfig.productId}');
      final backup = files.cast<FileObject?>().firstWhere(
        (f) => f?.name == 'backup.sqlite.enc',
        orElse: () => null,
      );
      if (backup?.updatedAt == null) return false;

      final cloudTime = DateTime.tryParse(backup!.updatedAt!);
      if (cloudTime == null) return false;

      // Compare with local last-sync timestamp
      final localTime = await SecureStore.getLastBackupTime();
      if (localTime != null && !cloudTime.isAfter(localTime)) return false;

      debugPrint('[Sync] Cloud backup newer ($cloudTime), downloading...');

      // Download & decrypt
      final bytes = await client!.storage.from('nusa-backups').download(cp);
      if (bytes.isEmpty) return false;

      final decrypted = await BackupCrypto.decrypt(bytes, uid);
      final dir = await getApplicationDocumentsDirectory();

      // Unpack archive (DB + images) directly — no restart needed
      final packedFiles = BackupCrypto.unpackFiles(
        Uint8List.fromList(decrypted),
      );
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
        await File(destinationCanonical).writeAsBytes(entry.value, flush: true);
        if (entry.key != 'nusa_kasir.sqlite') imageCount++;
      }

      await SecureStore.saveLastBackupTime(cloudTime);
      debugPrint(
        '[Sync] Restored DB${imageCount > 0 ? " + $imageCount images" : ""} from cloud',
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
