import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Central service for storing images in Supabase Storage.
///
/// All images (product photos, employee photos, QRIS, logos) are uploaded
/// to the `nusa-images` bucket and cached locally for offline access.
///
/// Local cache is namespaced by product/account to prevent basename collisions.
/// Remote path:  `{user_id}/{productId}/{category}/{filename}`
class ImageStorageService {
  final SupabaseClient _client;
  final String _uid;

  ImageStorageService(this._client, this._uid);

  /// Build remote path with product namespace to prevent cross-variant leakage.
  String _remotePath(String category, String filename) =>
      '$_uid/${NusaConfig.productId}/$category/$filename';

  /// Build remote directory prefix for listing.
  String _remoteDir(String category) =>
      '$_uid/${NusaConfig.productId}/$category';

  /// Map nama file lokal (product_*, photo_*, qris_*) → kategori remote.
  static String _categoryOf(String filename) {
    if (filename.startsWith('product_')) return 'products';
    if (filename.startsWith('photo_')) return 'employees';
    return 'settings'; // qris_*, printer_logo_*
  }

  // ── Public API ────────────────────────────────────────────────────

  /// Upload a local file to Supabase Storage.
  /// Returns true on success. Does NOT throw — errors are logged.
  Future<bool> uploadImage(String category, String localPath) async {
    final r = await uploadImageDetailed(category, localPath);
    return r.ok;
  }

  /// Upload dengan detail hasil — `ok=false` disertai [message] alasan
  /// (mis. "file tidak ada", "MIME ditolak 415", "RLS 403", "jaringan").
  /// Dipakai sinkronisasi toko online untuk menampilkan ALASAN kegagalan
  /// upload gambar (bukan sekadar "gagal").
  Future<({bool ok, String message})> uploadImageDetailed(
    String category,
    String localPath,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return (ok: false, message: 'file tidak ada: $localPath');
      }
      final filename = p.basename(localPath);
      final remotePath = _remotePath(category, filename);
      final bytes = await file.readAsBytes();
      final ext = p.extension(filename).toLowerCase();
      // Pastikan contentType eksplisit — bucket nusa-images cuma menerima
      // jpeg/png/webp/gif; storage_client menebak MIME dari ekstensi path,
      // tapi eksplisit lebih andal (hindari 415 invalid_mime_type).
      final contentType = _mimeFor(ext);
      // v2.2.57+122 (Cached Egress): set Cache-Control eksplisit per upload.
      // Default Supabase = max-age=3600 (1 jam). Aset JELAS statis (QRIS,
      // logo toko) bisa 1 minggu + immutable → browser/CDN cache hit, hemat
      // egress berulang. Foto produk/karyawan = 1 jam (sesuai default) →
      // cache bust dengan `?v={epoch}` di URL kalau perlu paksa refresh.
      final isStatic = category == 'settings'; // qris_*, store_logo_*
      final cacheControl = isStatic
          ? 'public, max-age=604800, immutable'
          : 'public, max-age=3600';
      await _client.storage.from('nusa-images').uploadBinary(
            remotePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: cacheControl,
            ),
          );
      // v2.2.57+122: upload = file baru di server. Reset sync gate supaya
      // syncAll berikutnya (di device ini atau sibling) menarik fresh copy.
      await SecureStore.setLastImageSyncMs(0);
      return (ok: true, message: '');
    } catch (e) {
      debugPrint('[ImageStorage] Upload failed ($category): $e');
      final msg = '$e';
      String reason = msg;
      if (msg.contains('415') || msg.toLowerCase().contains('mime')) {
        reason = 'MIME ditolak (415) — ekstensi file tidak didukung';
      } else if (msg.contains('404') || msg.contains('bucket')) {
        reason = 'Bucket/objek tidak ditemukan (404)';
      } else if (msg.contains('403') || msg.toLowerCase().contains('rls') ||
          msg.toLowerCase().contains('policy')) {
        // Upload memakai anon key (app tidak buat sesi Supabase Auth) —
        // 403 di sini berarti policy bucket, bukan "belum login Google".
        reason = 'Upload ditolak server (403) — cek koneksi & coba lagi';
      } else if (msg.contains('network') || msg.contains('socket') ||
          msg.contains('timeout') || msg.contains('internet')) {
        reason = 'Jaringan bermasalah';
      }
      return (ok: false, message: reason);
    }
  }

  /// MIME dari ekstensi file (fallback tebakan aman).
  String _mimeFor(String ext) => switch (ext) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        _ => 'application/octet-stream',
      };

  /// Download an image from Supabase to local cache.
  /// Saves to root of app dir with the original filename.
  /// Returns the local cache path, or null on failure.
  Future<String?> downloadImage(String category, String filename) async {
    try {
      final remotePath = _remotePath(category, filename);
      final bytes = await _client.storage
          .from('nusa-images')
          .download(remotePath);

      final dir = await getApplicationDocumentsDirectory();
      final localFile = File(
        p.join(dir.path, '${NusaConfig.productId}_$filename'),
      );
      await localFile.writeAsBytes(bytes, flush: true);
      return localFile.path;
    } catch (e) {
      debugPrint('[ImageStorage] Download failed ($filename): $e');
      return null;
    }
  }

  /// v2.2.57+130 (A2 relink): download gambar DENGAN NAMA FILE ASLI (tanpa
  /// prefix `{productId}_`) — dipakai _relinkImagesFromCloud() setelah restore
  /// untuk memulihkan file yang ditunjuk `imagePath` di DB. Backup baru
  /// (+130) tidak lagi mengemas file gambar di arsip NUS1, jadi device baru /
  /// setelah clear-data perlu menarik gambar langsung dari bucket dengan nama
  /// yang SAMA seperti yang tersimpan di DB (`product_{id}_{ts}.jpg`).
  /// Remote path tetap tanpa prefix (nama upload = nama asli, lihat
  /// uploadImageDetailed + syncOnlineProducts yang pakai p.basename).
  Future<String?> downloadOriginal(
    String category,
    String filename,
  ) async {
    try {
      final remotePath = _remotePath(category, filename);
      final bytes = await _client.storage
          .from('nusa-images')
          .download(remotePath);
      if (bytes.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File(p.join(dir.path, filename));
      await localFile.writeAsBytes(bytes, flush: true);
      return localFile.path;
    } catch (e) {
      debugPrint('[ImageStorage] DownloadOriginal failed ($filename): $e');
      return null;
    }
  }

  /// Delete an image from Supabase and optionally from local disk.
  Future<void> deleteImage(String category, String localPath) async {
    try {
      final filename = p.basename(localPath);
      final remotePath = _remotePath(category, filename);
      await _client.storage.from('nusa-images').remove([remotePath]);
    } catch (_) {}

    try {
      final file = File(localPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Sync: download all cloud images that don't exist locally.
  /// Returns number of images downloaded.
  ///
  /// v2.2.38: anon key TIDAK bisa `list()` folder nusa-images (404) — list
  /// hanya jalan untuk role dengan izin list. Ganti strategi: probe download
  /// per nama yang mungkin (dari kandidat nama lokal yang terdaftar di DB:
  /// produk, karyawan, QRIS/logo). Nama yang tidak ada di server → 404 → di-
  /// skip; yang ada → ter-download. Ini bikin sync gambar jalan untuk SEMUA
  /// user (bukan cuma yang kebetulan punya izin list).
  ///
  /// v2.2.57+122 (Cached Egress throttle): kalau dipanggil terlalu sering
  /// (default <6 jam dari sync sebelumnya) langsung return 0 tanpa probe —
  /// `nusa-images` CDN cache sudah 1 jam, sync berulang sebelum TTL = sia-sia
  /// + boros Cached Egress. Caller paksa sync dengan clear flag lewat
  /// `clearSyncGate()` (mis. setelah upload gambar baru).
  Future<int> syncAll({bool force = false}) async {
    if (!force) {
      final last = await SecureStore.getLastImageSyncMs();
      if (last > 0 &&
          DateTime.now().millisecondsSinceEpoch - last <
              SecureStore.imageSyncIntervalMs) {
        return 0; // skip — baru sync belum lama
      }
    }
    int count = 0;
    final categories = ['products', 'employees', 'settings'];
    final dir = await getApplicationDocumentsDirectory();

    // Kumpulkan nama file yang mungkin ada di cloud dari DB lokal (via
    // file cache: produk_*, photo_*, qris_* yang sudah pernah terlihat).
    final candidates = <String>{};
    try {
      final entries = await dir.list().toList();
      for (final e in entries) {
        if (e is! File) continue;
        final n = p.basename(e.path);
        if (n.startsWith('product_') ||
            n.startsWith('photo_') ||
            n.startsWith('qris_') ||
            n.startsWith('printer_logo_')) {
          candidates.add(n);
        }
      }
    } catch (_) {}

    for (final cat in categories) {
      try {
        final remoteDir = _remoteDir(cat);
        // Coba list dulu (kalau izinnya ada — varian/role tertentu).
        // Kalau 404, lanjut ke probe download per kandidat.
        List<dynamic> files = [];
        try {
          files = await _client.storage
              .from('nusa-images')
              .list(path: remoteDir);
        } catch (_) {
          files = [];
        }

        // Kalau LIST berhasil, jangan probe nama lokal yang jelas tidak ada
        // di daftar server (kalau tidak, tiap start probe 404 per kandidat).
        // Kalau list gagal (anon tanpa izin list), lanjut jalur probe lama.
        final listed = <String>{
          for (final f in files)
            if (f is Map && f['name'] is String) f['name'] as String,
        };

        final names = <String>{
          ...listed,
          if (files.isEmpty)
            for (final c in candidates)
              if (_categoryOf(c) == cat) p.basename(c),
        };

        for (final name in names) {
          final localFile = File(
            p.join(dir.path, '${NusaConfig.productId}_$name'),
          );
          // Skip if already cached locally
          if (await localFile.exists()) continue;

          final remotePath = _remotePath(cat, name);
          try {
            final bytes = await _client.storage
                .from('nusa-images')
                .download(remotePath);
            if (bytes.isEmpty) continue;
            await localFile.writeAsBytes(bytes, flush: true);
            count++;
          } catch (_) {
            // File tidak ada di cloud (404) atau gagal — skip individual
          }
        }
      } catch (_) {
        // Category might not exist yet — that's fine
      }
    }
    if (count > 0) {
      debugPrint('[ImageStorage] Synced $count images from cloud');
    }
    // v2.2.57+122: catat timestamp sync terakhir — dipakai gate berikutnya.
    await SecureStore.setLastImageSyncMs(DateTime.now().millisecondsSinceEpoch);
    return count;
  }

  /// v2.2.57+122: hapus gate sync (paksa syncAll berikutnya tidak skip).
  /// Dipanggil setelah upload gambar baru / restore selesai — file baru di
  /// server harus di-fetch ke local cache.
  Future<void> clearSyncGate() => SecureStore.setLastImageSyncMs(0);

  /// First-time migration: upload all local images to Supabase.
  /// Only uploads images that don't already exist on the server.
  /// Returns number of images uploaded.
  Future<int> uploadAllLocal() async {
    int count = 0;
    // Nama file yang sudah dipastikan ADA di server (sesi ini) — hindari
    // download probe ulang tiap start (migrasi dulu selalu nge-probe).
    final knownRemote = <String>{};
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entries = await dir.list().toList();
      final imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

      for (final entry in entries) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        final ext = p.extension(entry.path).toLowerCase();
        if (!imageExtensions.contains(ext)) continue;

        String? category;
        if (name.startsWith('product_')) {
          category = 'products';
        } else if (name.startsWith('photo_')) {
          category = 'employees';
        } else if (name.startsWith('qris_') ||
            name.startsWith('printer_logo_') ||
            name.startsWith('store_logo_')) {
          category = 'settings';
        } else {
          continue; // unknown prefix, skip
        }

        final remotePath = _remotePath(category, name);
        if (knownRemote.contains(remotePath)) continue;

        // Check if already on server
        try {
          await _client.storage.from('nusa-images').download(remotePath);
          // File exists on server — skip
          knownRemote.add(remotePath);
          continue;
        } catch (_) {
          // File doesn't exist — upload it
        }

        final ok = await uploadImage(category, entry.path);
        if (ok) {
          count++;
          debugPrint('[ImageStorage] Migrated: $category/$name');
        }
      }
    } catch (e) {
      debugPrint('[ImageStorage] Migration error: $e');
    }
    return count;
  }

  /// Get the local path for an image, downloading from cloud if missing.
  /// Use this to ensure an image is available before displaying.
  Future<String?> ensureLocal(String category, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File(
      p.join(dir.path, '${NusaConfig.productId}_$filename'),
    );
    if (await localFile.exists()) return localFile.path;

    // Try to download from cloud
    return downloadImage(category, filename);
  }

  // ── Category helpers ──────────────────────────────────────────────

  /// Detect category from filename prefix.
  static String? categoryFromFilename(String filename) {
    if (filename.startsWith('product_')) return 'products';
    if (filename.startsWith('photo_')) return 'employees';
    if (filename.startsWith('qris_') ||
        filename.startsWith('printer_logo_') ||
        filename.startsWith('store_logo_')) {
      return 'settings';
    }
    return null;
  }
}
