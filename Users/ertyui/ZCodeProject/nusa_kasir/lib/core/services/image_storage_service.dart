import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

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

  // ── Public API ────────────────────────────────────────────────────

  /// Upload a local file to Supabase Storage.
  /// Returns true on success. Does NOT throw — errors are logged.
  Future<bool> uploadImage(String category, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return false;
      final filename = p.basename(localPath);
      final remotePath = _remotePath(category, filename);
      final bytes = await file.readAsBytes();
      await _client.storage
          .from('nusa-images')
          .uploadBinary(
            remotePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return true;
    } catch (e) {
      debugPrint('[ImageStorage] Upload failed ($category): $e');
      return false;
    }
  }

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
  Future<int> syncAll() async {
    int count = 0;
    final categories = ['products', 'employees', 'settings'];
    final dir = await getApplicationDocumentsDirectory();

    for (final cat in categories) {
      try {
        final files = await _client.storage
            .from('nusa-images')
            .list(path: _remoteDir(cat));

        for (final f in files) {
          final localFile = File(
            p.join(dir.path, '${NusaConfig.productId}_${f.name}'),
          );

          // Skip if already cached locally
          if (await localFile.exists()) continue;

          final remotePath = _remotePath(cat, f.name);
          try {
            final bytes = await _client.storage
                .from('nusa-images')
                .download(remotePath);
            await localFile.writeAsBytes(bytes, flush: true);
            count++;
          } catch (_) {
            // Skip individual failures
          }
        }
      } catch (_) {
        // Category might not exist yet — that's fine
      }
    }
    if (count > 0) {
      debugPrint('[ImageStorage] Synced $count images from cloud');
    }
    return count;
  }

  /// First-time migration: upload all local images to Supabase.
  /// Only uploads images that don't already exist on the server.
  /// Returns number of images uploaded.
  Future<int> uploadAllLocal() async {
    int count = 0;
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

        // Check if already on server
        try {
          final remotePath = _remotePath(category, name);
          await _client.storage.from('nusa-images').download(remotePath);
          // File exists on server — skip
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
