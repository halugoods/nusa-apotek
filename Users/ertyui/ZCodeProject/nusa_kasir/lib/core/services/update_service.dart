import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

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
  factory UpdateInfo.error(String msg) => UpdateInfo(hasUpdate: false, error: msg);
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
    // If we recently hit GitHub's rate limit, don't hammer it again
    // immediately — return the cached (error) result instead.
    if (_rateLimitedUntil != null && DateTime.now().isBefore(_rateLimitedUntil!)) {
      return _cached ?? UpdateInfo.error('Terlalu banyak permintaan. Coba lagi nanti.');
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
        final err = UpdateInfo.error('Terlalu banyak permintaan. Coba lagi nanti.');
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
      return UpdateInfo.error('Tidak dapat memeriksa update. Periksa koneksi internet.');
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

  /// Formats file size for display.
  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
