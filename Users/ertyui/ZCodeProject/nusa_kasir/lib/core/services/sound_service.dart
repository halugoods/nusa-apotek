import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// NUSA Sound — SFX pendek + ringtone looping (v2.2.55).
///
/// - SFX pendek (transaksi sukses, scan, dsb) via [AudioPool] — low latency,
///   beberapa instance supaya bunyi beruntun tidak terpotong.
/// - Ringtone "Panggil Karyawan" via [AudioPlayer] ReleaseMode.loop sampai
///   di-dismiss.
/// - Semua pemutaran di-gate toggle "Suara Aplikasi" (SecureStore, default
///   AKTIF). Semua call best-effort: kegagalan audio TIDAK pernah melempar.
/// - v2.2.55 custom sounds: owner bisa upload file audio per slot dari
///   dashboard web (bucket publik `nusa-sounds` + manifest.json). App cek
///   cache lokal `{docs}/custom_sounds/` dulu — kalau ada file untuk slot
///   tsb pakai itu (DeviceFileSource), kalau tidak fallback ke asset bawaan.
///   Manifest dicek di background sekali per sesi; versi lebih baru → file
///   diunduh lalu pool dibangun ulang.
enum NusaSound {
  success, // transaksi sukses
  error, // transaksi gagal / PIN salah
  scan, // barcode ketemu
  pop, // item masuk keranjang
  ding, // order online masuk
  presence, // presensi berhasil
  lowStock, // stok menipis
}

class SoundService {
  SoundService._();
  static final SoundService I = SoundService._();

  static const _files = {
    NusaSound.success: 'audio/success.wav',
    NusaSound.error: 'audio/error.wav',
    NusaSound.scan: 'audio/scan.wav',
    NusaSound.pop: 'audio/pop.wav',
    NusaSound.ding: 'audio/ding.wav',
    NusaSound.presence: 'audio/presence.wav',
    NusaSound.lowStock: 'audio/lowstock.wav',
  };

  /// Key slot di manifest cloud (harus sama dengan dashboard /notifikasi).
  static const _keys = {
    NusaSound.success: 'success',
    NusaSound.error: 'error',
    NusaSound.scan: 'scan',
    NusaSound.pop: 'pop',
    NusaSound.ding: 'ding',
    NusaSound.presence: 'presence',
    NusaSound.lowStock: 'lowstock',
  };
  static const _ringKey = 'ring';
  static const _bucket = 'nusa-sounds';
  static const _versionStoreKey = 'nusa_sounds_version';

  final Map<NusaSound, AudioPool?> _pools = {};
  bool _loaded = false;
  bool _cloudSynced = false;
  AudioPlayer? _ringPlayer;

  /// Key → path file custom lokal (kosong = semua slot masih asset bawaan).
  final Map<String, String> _customPaths = {};

  /// Toggle "Suara Aplikasi". Cache in-memory supaya play() tidak membaca
  /// secure storage tiap kali; invalidasi lewat setEnabled().
  bool? _enabledCache;

  Future<bool> get enabled async =>
      _enabledCache ??= await SecureStore.getSoundEnabled();

  Future<void> setEnabled(bool v) async {
    await SecureStore.setSoundEnabled(v);
    _enabledCache = v;
    if (!v) await stopRing();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true; // set duluan — jangan retry storm kalau gagal
    await _loadCustomPaths();
    await _buildPools();
    unawaited(_syncFromCloud());
  }

  /// Scan folder cache custom_sounds → isi [_customPaths].
  Future<void> _loadCustomPaths() async {
    _customPaths.clear();
    try {
      final dir = await _cacheDir();
      for (final f in dir.listSync()) {
        if (f is! File) continue;
        final name = f.uri.pathSegments.last;
        final dot = name.indexOf('.');
        if (dot <= 0) continue;
        _customPaths[name.substring(0, dot)] = f.path;
      }
    } catch (_) {}
  }

  Future<void> _buildPools() async {
    for (final entry in _files.entries) {
      try {
        await _pools[entry.key]?.dispose();
      } catch (_) {}
      _pools.remove(entry.key);
      final customPath = _customPaths[_keys[entry.key]];
      try {
        _pools[entry.key] = await AudioPool.create(
          source: customPath != null
              ? DeviceFileSource(customPath)
              : AssetSource(entry.value),
          maxPlayers: 2,
        );
      } catch (_) {
        _pools[entry.key] = null;
      }
    }
  }

  /// Mainkan SFX pendek. Best-effort + gated toggle.
  Future<void> play(NusaSound s) async {
    try {
      if (!await enabled) return;
      await _ensureLoaded();
      await _pools[s]?.start();
    } catch (_) {}
  }

  /// Ringtone panggilan — loop terus sampai [stopRing].
  Future<void> startRing() async {
    try {
      if (!await enabled) return;
      await stopRing();
      final player = AudioPlayer(playerId: 'nusa-call-ring');
      _ringPlayer = player;
      await player.setReleaseMode(ReleaseMode.loop);
      final ringPath = _customPaths[_ringKey];
      await player.play(ringPath != null
          ? DeviceFileSource(ringPath)
          : AssetSource('audio/ring.wav'));
    } catch (_) {}
  }

  Future<void> stopRing() async {
    try {
      await _ringPlayer?.stop();
      await _ringPlayer?.dispose();
    } catch (_) {}
    _ringPlayer = null;
  }

  // ── Custom sounds dari cloud (v2.2.55) ────────────────────────────────

  Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/custom_sounds');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Uri _publicUrl(String filename) =>
      Uri.parse('${NusaConfig.supabaseUrl}/storage/v1/object/public/'
          '$_bucket/$filename');

  /// Cek manifest cloud sekali per sesi. Kalau version > versi tersimpan:
  /// unduh file yang belum ada di cache, hapus file yang sudah di-reset dari
  /// web, simpan version baru, lalu rebuild pool.
  Future<void> _syncFromCloud() async {
    if (_cloudSynced) return;
    _cloudSynced = true;
    try {
      final res = await http
          .get(_publicUrl('manifest.json'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteVersion = (m['version'] as num?)?.toInt() ?? 0;
      final sounds =
          ((m['sounds'] as Map<String, dynamic>?) ?? const {}).cast<String, String>();
      if (remoteVersion <= 0) return;

      final localVersion =
          int.tryParse(await SecureStore.read(key: _versionStoreKey) ?? '') ?? -1;
      if (remoteVersion == localVersion) return;

      final dir = await _cacheDir();

      // Versi berubah → unduh ulang SEMUA file manifest (bisa jadi isi file
      // dengan nama sama sudah diganti owner).
      for (final filename in sounds.values.toSet()) {
        try {
          final fr = await http.get(_publicUrl(filename)).timeout(
                const Duration(seconds: 15),
              );
          if (fr.statusCode == 200 && fr.bodyBytes.isNotEmpty) {
            await File('${dir.path}/$filename')
                .writeAsBytes(fr.bodyBytes, flush: true);
          }
        } catch (_) {}
      }

      // Hapus file lokal yang sudah tidak ada di manifest (reset dari web).
      final valid = sounds.values.toSet();
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (!valid.contains(name)) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }

      await SecureStore.write(key: _versionStoreKey, value: '$remoteVersion');
      await _loadCustomPaths();
      await _buildPools();
    } catch (_) {
      // Offline / bucket belum dibuat — pakai suara bawaan saja.
    }
  }
}
