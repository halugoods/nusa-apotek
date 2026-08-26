import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an update check.
@immutable
class UpdateInfo {
  final bool hasUpdate;
  final String? latestVersion;
  final int? latestBuildNumber;
  final String? downloadUrl;
  final String? changelog;
  final int? fileSizeBytes;
  final String? error; // non-null means check failed

  const UpdateInfo({
    required this.hasUpdate,
    this.latestVersion,
    this.latestBuildNumber,
    this.downloadUrl,
    this.changelog,
    this.fileSizeBytes,
    this.error,
  });

  factory UpdateInfo.noUpdate() => const UpdateInfo(hasUpdate: false);
  factory UpdateInfo.error(String msg) =>
      UpdateInfo(hasUpdate: false, error: msg);
}

/// Satu entri riwayat rilis — versi + isi changelog dari GitHub Releases.
@immutable
class ReleaseHistoryItem {
  final String version;
  final int buildNumber;
  final String body;
  final DateTime? publishedAt;

  const ReleaseHistoryItem({
    required this.version,
    required this.buildNumber,
    required this.body,
    this.publishedAt,
  });

  factory ReleaseHistoryItem.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?) ?? '';
    final parsed = UpdateService._parseTag(
      tag,
      fallbackBuildNumber: (json['id'] as int?) ?? 0,
    );
    return ReleaseHistoryItem(
      version: parsed?.$1 ?? tag.replaceAll(RegExp(r'^v'), ''),
      buildNumber: parsed?.$2 ?? 0,
      body: ((json['body'] as String?) ?? '').trim(),
      publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
    );
  }
}

/// Checks GitHub Releases for newer versions.
///
/// Release tags should follow the format `v1.0.0+2` where the suffix
/// after `+` is the build number.
///
/// Falls back to plain semver (`v1.0.0` → build number from release ID)
/// and also tries `v1.0.0+2` without `v` prefix.
class UpdateService {
  static const _apiBase = 'https://api.github.com';
  static const _userAgent = 'nusa-kasir-updater';
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _cacheTtl = Duration(minutes: 10);

  static UpdateInfo? _cached;
  static DateTime? _cacheTime;
  // While set, we back off from hitting GitHub to avoid hammering the
  // unauthenticated rate limit (60 requests/hour/IP).
  static DateTime? _rateLimitedUntil;

  /// Fetches the latest release from GitHub and compares against the
  /// current build number defined in [NusaConfig].
  ///
  /// Results are cached for 30 minutes to avoid hitting GitHub rate limits.
  static Future<UpdateInfo> checkForUpdate({bool force = false}) async {
    // Dev builds always stay on the installed build — updates are pushed to
    // the per-variant production repos, never to the dev app.
    if (NusaConfig.isDevBuild) return UpdateInfo.noUpdate();
    // If we recently hit GitHub's rate limit, don't hammer it again
    // immediately — return the cached (error) result instead.
    if (_rateLimitedUntil != null &&
        DateTime.now().isBefore(_rateLimitedUntil!)) {
      return _cached ??
          UpdateInfo.error('Terlalu banyak permintaan. Coba lagi nanti.');
    }
    if (!force && _cacheTime != null && _cached != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheTtl) {
        return _cached!;
      }
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(
        Uri.parse('$_apiBase/repos/${NusaConfig.githubRepo}/releases/latest'),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final res = await req.close().timeout(_timeout);

      if (res.statusCode == 403 || res.statusCode == 429) {
        final err = UpdateInfo.error(
          'Terlalu banyak permintaan. Coba lagi nanti.',
        );
        _cached = err;
        _cacheTime = DateTime.now();
        _rateLimitedUntil = DateTime.now().add(const Duration(minutes: 2));
        return err;
      }
      if (res.statusCode == 404) {
        return UpdateInfo.error('Repository tidak ditemukan.');
      }
      if (res.statusCode != 200) {
        return UpdateInfo.error('Gagal memeriksa update (${res.statusCode}).');
      }

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tag = (json['tag_name'] as String?) ?? '';
      final releaseId = (json['id'] as int?) ?? 0;
      final parsed = _parseTag(tag, fallbackBuildNumber: releaseId);
      if (parsed == null) {
        return UpdateInfo.error('Format versi tidak dikenal: $tag');
      }

      final (version, buildNumber) = parsed;

      if (buildNumber <= NusaConfig.appBuildNumber) {
        final result = UpdateInfo.noUpdate();
        _cached = result;
        _cacheTime = DateTime.now();
        _rateLimitedUntil = null;
        return result;
      }

      // Find the APK asset
      String? downloadUrl;
      int? fileSizeBytes;
      final assets = (json['assets'] as List<dynamic>?) ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = (asset['browser_download_url'] as String?) ?? '';
          fileSizeBytes = (asset['size'] as int?) ?? 0;
          break;
        }
      }

      final result = UpdateInfo(
        hasUpdate: true,
        latestVersion: version,
        latestBuildNumber: buildNumber,
        downloadUrl: downloadUrl,
        changelog: (json['body'] as String?) ?? '',
        fileSizeBytes: fileSizeBytes,
      );
      _cached = result;
      _cacheTime = DateTime.now();
      _rateLimitedUntil = null;
      return result;
    } on TimeoutException {
      return UpdateInfo.error('Waktu koneksi habis. Periksa koneksi internet.');
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate error: $e');
      return UpdateInfo.error(
        'Tidak dapat memeriksa update. Periksa koneksi internet.',
      );
    }
  }

  /// Parses a tag like "v1.2.3+5" → (version, buildNumber).
  ///
  /// Tries multiple formats in order:
  ///   1. `v1.2.3+5` — version + explicit build number
  ///   2. `1.2.3+5` — same without 'v' prefix
  ///   3. `v1.2.3`  — plain semver, uses [fallbackBuildNumber] as build
  ///   4. `1.2.3`   — same without 'v' prefix
  ///
  /// Returns null if no format matches.
  static (String, int)? _parseTag(String tag, {int fallbackBuildNumber = 0}) {
    final t = tag.trim();

    // Try vX.Y.Z+N or X.Y.Z+N
    var m = RegExp(r'^v?(\d+\.\d+\.\d+)\+(\d+)$').firstMatch(t);
    if (m != null) return (m.group(1)!, int.parse(m.group(2)!));

    // Try plain vX.Y.Z or X.Y.Z — use release ID as build number
    m = RegExp(r'^v?(\d+\.\d+\.\d+)$').firstMatch(t);
    if (m != null && fallbackBuildNumber > 0) {
      return (m.group(1)!, fallbackBuildNumber);
    }

    return null;
  }

  /// Mengambil riwayat rilis (changelog) untuk menu "Riwayat Update".
  ///
  /// Ambil maks 20 rilis terbaru dari GitHub (tag + body). Gagal/jaringan
  /// mati → kembalikan daftar kosong; pemanggil menampilkan versi lokal.
  /// Tidak ada guard isDevBuild — di build dev sekalipun riwayat rilis tetap
  /// berguna (user bisa lihat changelog versi yang pernah dirilis).
  static Future<List<ReleaseHistoryItem>> getReleaseHistory() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(
        Uri.parse(
          '$_apiBase/repos/${NusaConfig.githubRepo}/releases?per_page=20',
        ),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return [];
      final body = await res.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ReleaseHistoryItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[UpdateService] getReleaseHistory error: $e');
      return [];
    }
  }

  /// Formats file size for display.
  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Downloads the APK to app-private external storage (visible to
  /// FileProvider via `external_files`) and returns its absolute path.
  ///
  /// Streams to disk with progress reported through [onProgress]
  /// (0.0 → 1.0). On failure the partial file is deleted so a corrupted
  /// APK never gets installed. Does NOT touch the UI.
  static Future<String?> downloadApk({
    required String url,
    required String variantId,
    required String version,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;
    final downloads = Directory(p.join(dir.path, 'downloads'));
    try {
      if (await downloads.exists()) {
        // Remove stale APKs for this variant so we never install an old build.
        await for (final f in downloads.list()) {
          if (f is File && p.extension(f.path).toLowerCase() == '.apk') {
            try {
              await f.delete();
            } catch (_) {}
          }
        }
      } else {
        await downloads.create(recursive: true);
      }
    } catch (_) {}

    final filePath = p.join(
      downloads.path,
      'nusa-${variantId.replaceFirst('nusa-', '')}-v$version.apk',
    );
    final sink = File(filePath).openWrite();
    HttpClient client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        throw HttpException('Download failed: HTTP ${res.statusCode}');
      }
      final total = res.contentLength;
      var received = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      return filePath;
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        client.close();
      } catch (_) {}
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      debugPrint('[UpdateService] downloadApk error: $e');
      rethrow;
    }
  }

  /// Installs a downloaded APK via the system package installer.
  ///
  /// Bridges to `com.nusa_kasir/installer` in MainActivity.kt which fires
  /// ACTION_VIEW + FileProvider. Throws on failure.
  static Future<void> installApk(String filePath) async {
    const channel = MethodChannel('com.nusa_kasir/installer');
    try {
      final ok = await channel.invokeMethod<bool>('installApk', {
        'path': filePath,
      });
      if (ok != true) {
        throw Exception('Installer tidak membuka (ok=$ok)');
      }
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Installer error');
    }
  }

  /// Hapus APK sisa unduhan (folder downloads app-private). Dipanggil saat
  /// app start berikutnya — menutup celah "APK sampah" untuk user gaptek
  /// (file tidak bisa dihapus seketika saat installer masih memakainya).
  static Future<void> cleanupApk() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final downloads = Directory(p.join(dir.path, 'downloads'));
      if (!await downloads.exists()) return;
      await for (final f in downloads.list()) {
        if (f is File && p.extension(f.path).toLowerCase() == '.apk') {
          try {
            await f.delete();
            debugPrint('[UpdateService] cleanupApk: hapus ${f.path}');
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ── v2.2.57: ping server (version tracking + force-update) ────────

  /// Hasil ping terakhir — dipakai notif lonceng untuk tombol download
  /// via browser tanpa panggil ulang server.
  static ForceUpdateInfo? lastForceCheck;

  /// Ping edge fn `app_ping`: catat versi perangkat ke cloud (dashboard
  /// admin bisa lihat user di versi berapa) + ambil versi minimum produk.
  /// Return [ForceUpdateInfo.required]=true → app HARUS diupdate (blocking).
  ///
  /// Gagal jaringan TIDAK pernah memblokir app — balik no-update.
  static Future<ForceUpdateInfo> pingAndCheck() async {
    try {
      final client = Supabase.instance.client;
      final key = await SecureStore.getActivation();
      final res = await client.functions.invoke(
        'app_ping',
        body: {
          if (key != null && key.isNotEmpty) 'key': key,
          'product': NusaConfig.productId,
          'version': NusaConfig.appVersion,
          'build': NusaConfig.appBuildNumber,
        },
      );
      final data = res.data as Map<String, dynamic>? ?? const {};
      final info = ForceUpdateInfo(
        required: data['update_required'] == true,
        minVersion: data['min_version'] as String? ?? '',
        minBuild: (data['min_build'] as num?)?.toInt() ?? 0,
        downloadUrl: data['download_url'] as String?,
      );
      lastForceCheck = info;
      return info;
    } catch (_) {
      final info = const ForceUpdateInfo(required: false);
      return info;
    }
  }
}

/// Hasil cek force-update dari server (v2.2.57).
class ForceUpdateInfo {
  final bool required;
  final String minVersion;
  final int minBuild;
  final String? downloadUrl;

  const ForceUpdateInfo({
    required this.required,
    this.minVersion = '',
    this.minBuild = 0,
    this.downloadUrl,
  });
}
