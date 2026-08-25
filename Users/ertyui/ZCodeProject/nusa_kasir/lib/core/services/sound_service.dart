import 'package:audioplayers/audioplayers.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// NUSA Sound — SFX pendek + ringtone looping (v2.2.54).
///
/// - SFX pendek (transaksi sukses, scan, dsb) via [AudioPool] — low latency,
///   beberapa instance supaya bunyi beruntun tidak terpotong.
/// - Ringtone "Panggil Karyawan" via [AudioPlayer] ReleaseMode.loop sampai
///   di-dismiss.
/// - Semua pemutaran di-gate toggle "Suara Aplikasi" (SecureStore, default
///   AKTIF). Semua call best-effort: kegagalan audio TIDAK pernah melempar.
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

  final Map<NusaSound, AudioPool?> _pools = {};
  bool _loaded = false;
  AudioPlayer? _ringPlayer;

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
    for (final entry in _files.entries) {
      try {
        _pools[entry.key] = await AudioPool.create(
          source: AssetSource(entry.value),
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
      await player.play(AssetSource('audio/ring.wav'));
    } catch (_) {}
  }

  Future<void> stopRing() async {
    try {
      await _ringPlayer?.stop();
      await _ringPlayer?.dispose();
    } catch (_) {}
    _ringPlayer = null;
  }
}
