import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nusa_kasir/core/cloud/cloud_gateway.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Pushes realtime "backup_updated" events so other devices on the same
/// account get notified within ~1s instead of waiting for the next
/// poll tick. Complements the file-based pull in [AutoSyncService].
///
/// v2.2.57: this is the "hybrid B" delta push. We don't ship a full CRDT or
/// WebSocket-driven SQLite sync — too heavy for a small POS. We just shout
/// "hey, I just uploaded" and let subscribers do the regular pull.
class RealtimeBackupNotifier {
  RealtimeBackupNotifier._();
  static final RealtimeBackupNotifier I = RealtimeBackupNotifier._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _shouldRun = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongTimer;

  // v2.2.57+142: heartbeat ping 10 dtk (dulu 20s) menjaga socket selalu hangat
  // dari timeout agresif operator seluler & WiFi gateway.
  static const _pingInterval = Duration(seconds: 10);

  // v2.2.57+130 (A3): exponential backoff untuk reconnect — hindari hammer
  // server saat worker restart / network flap. Delay tumbuh 1s → 2s → 4s → …
  // sampai max 30s, reset ke awal saat koneksi berhasil.
  static const _initialDelay = Duration(seconds: 1);
  static const _maxDelay = Duration(seconds: 30);
  static const _multiplier = 2;
  int _attempt = 0;

  /// Channel name shared by all devices signed into the same account.
  /// Mirrors CallService pattern.
  Future<String?> _channelName() async {
    // v2.2.57+115 (Area I): channel memakai canonical UID (sama dengan path
    // backup) supaya semua device di akun yang sama bertemu di satu channel —
    // sebelum ini device Google UID vs email UUID tidak pernah saling lihat.
    final uid = await SecureStore.resolveCanonicalUid();
    if (uid == null || uid.isEmpty) return null;
    return 'backup_updated:$uid';
  }

  Future<void> start() async {
    if (_shouldRun) return;
    _shouldRun = true;
    final devId = await SecureStore.getDeviceId();
    if (devId != null && devId.isNotEmpty) {
      _deviceId = devId;
    }
    _connect();
  }

  /// v2.2.57+130 (A3): auto-reconnect saat koneksi WS terputus (network flap,
  /// worker restart). Pola: retry dengan delay tetap; berhenti saat stop().
  Future<void> _connect() async {
    if (!_shouldRun) return;
    final name = await _channelName();
    if (name == null) {
      // v2.2.57+141: Jangan return diam-diam saat UID belum siap — jadwalkan
      // reconnect agar WebSocket tersambung begitu user login / UID terbaca.
      _scheduleReconnect();
      return;
    }
    try {
      final ws = CloudGateway.shared.wsChannel(name);
      if (ws == null) {
        _scheduleReconnect();
        return;
      }
      // Tunggu handshake selesai sebelum listen (ws.ready).
      await ws.ready.timeout(const Duration(seconds: 8));
      // Koneksi berhasil — reset backoff counter supaya retry berikutnya
      // mulai dari delay awal lagi.
      _attempt = 0;
      _channel = ws;
      _startPing();
      // v2.2.57+142: segera trigger pull saat WS terhubung atau reconnect
      RealtimeSyncService.I.onRemoteBackupUpdated();
      _sub = ws.stream.listen((message) {
        // v2.2.57+142: server RoomDO auto-responds 'pong' to 'ping'. Watchdog reset!
        if (message == 'pong') {
          _pongTimer?.cancel();
          _pongTimer = null;
          return;
        }
        try {
          // Pesan gateway: JSON string {"event": ..., "payload": {...}}.
          final dynamic decoded = message is String
              ? jsonDecode(message)
              : message;
          if (decoded is! Map) return;
          final event = '${decoded['event'] ?? ''}';

          // v2.2.57+143: Pure Realtime direct delta_broadcast (<50ms).
          if (event == 'delta_broadcast') {
            final payload = decoded['payload'];
            final p = payload is Map
                ? Map<String, dynamic>.from(payload)
                : <String, dynamic>{};
            final deviceId = '${p['deviceId'] ?? ''}';
            if (deviceId == _myDeviceId()) return;
            final deltasRaw = p['deltas'];
            if (deltasRaw is List && deltasRaw.isNotEmpty) {
              final deltas = deltasRaw
                  .whereType<Map>()
                  .map((d) => Map<String, dynamic>.from(d))
                  .toList();
              if (deltas.isNotEmpty) {
                debugPrint(
                    '[RealtimeSync] direct delta_broadcast (${deltas.length} deltas) from $deviceId');
                RealtimeSyncService.I.onRemoteDeltas(deltas);
                return;
              }
            }
          }

          if (event != 'backup_updated' && event != 'sync') return;
          final payload = decoded['payload'];
          final p = payload is Map
              ? Map<String, dynamic>.from(payload)
              : <String, dynamic>{};
          final deviceId = '${p['deviceId'] ?? ''}';
          // Ignore our own broadcast (the originator doesn't need to pull
          // from itself).
          if (deviceId == _myDeviceId()) return;
          debugPrint('[RealtimeSync] backup_updated from $deviceId');
          // Trigger immediate pull on the receiving device.
          RealtimeSyncService.I.onRemoteBackupUpdated();
        } catch (_) {}
      }, onError: (_) {
        // Koneksi error — reconnect otomatis.
        _scheduleReconnect();
      }, onDone: () {
        // Channel ditutup (server restart / network) — reconnect.
        _scheduleReconnect();
      }, cancelOnError: false);
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    }
  }

  /// v2.2.57+142: kirim 'ping' periodik + pong watchdog 4 detik.
  /// Di Android/jaringan seluler, koneksi TCP sering mati diam-diam (half-open)
  /// tanpa melempar onError/onDone dan sink.add('ping') tidak melempar error.
  /// Pong watchdog memastikan socket mati langsung terdeteksi & di-reconnect!
  void _startPing() {
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _pongTimer = null;
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      final ws = _channel;
      if (ws == null) return;
      try {
        ws.sink.add('ping');
        _pongTimer?.cancel();
        _pongTimer = Timer(const Duration(seconds: 4), () {
          debugPrint('[RealtimeSync] pong timeout — connection dropped, reconnecting...');
          forceReconnect();
        });
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    if (!_shouldRun) return;
    _reconnectTimer?.cancel();

    // Exponential backoff: delay = min(initial * multiplier^attempt, max).
    final delayMs = math.min(
      _initialDelay.inMilliseconds * math.pow(_multiplier, _attempt).toInt(),
      _maxDelay.inMilliseconds,
    );
    final delay = Duration(milliseconds: delayMs);
    _attempt++;

    debugPrint('[RealtimeSync] reconnect in ${delay.inSeconds}s (attempt $_attempt)');
    _reconnectTimer = Timer(delay, () {
      if (!_shouldRun) return;
      _sub = null;
      _channel = null;
      _connect();
    });
  }

  /// v2.2.57+137: paksa reconnect SEKARANG (dipanggil saat app resume dari
  /// background — selama pause, OS boleh membunuh koneksi WS tanpa callback
  /// onDone, sehingga tanpa ini device menunggu tick ping/poll berikutnya).
  void forceReconnect() {
    if (!_shouldRun) return;
    _reconnectTimer?.cancel();
    _sub?.cancel().catchError((_) {});
    _sub = null;
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
    _connect();
  }

  Future<void> stop() async {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
  }

  /// Broadcast after a successful upload. Includes our deviceId so listeners
  /// can ignore their own echoes.
  Future<void> broadcastUpdated() async {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({
        'event': 'backup_updated',
        'payload': {
          'deviceId': _myDeviceId(),
          'at': DateTime.now().toUtc().toIso8601String(),
        },
      }));
    } catch (e) {
      debugPrint('[RealtimeSync] broadcast failed: $e');
    }
  }

  /// v2.2.57+143: Pure Realtime 1-Jalur WS Delta Broadcast.
  /// Kirim payload delta langsung ke semua peer aktif di channel backup_updated:{uid}.
  Future<void> broadcastDeltas(List<Map<String, dynamic>> deltas) async {
    if (_channel == null || deltas.isEmpty) return;
    try {
      _channel!.sink.add(jsonEncode({
        'event': 'delta_broadcast',
        'payload': {
          'deviceId': _myDeviceId(),
          'deltas': deltas,
          'at': DateTime.now().toUtc().toIso8601String(),
        },
      }));
      debugPrint('[RealtimeSync] broadcast ${deltas.length} deltas directly via WS');
    } catch (e) {
      debugPrint('[RealtimeSync] broadcast deltas failed: $e');
    }
  }

  String _myDeviceId() => _deviceId ??= () {
        try {
          return 'dart-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${identityHashCode(this).toRadixString(36)}';
        } catch (_) {
          return 'dart-${DateTime.now().microsecondsSinceEpoch}';
        }
      }();
  static String? _deviceId;
}

/// Handles "another device just uploaded" notifications. Calls into the
/// existing pull logic in [AutoSyncService] so the receiving device picks
/// up the change within ~1s of the originator's push.
class RealtimeSyncService {
  RealtimeSyncService._();
  static final RealtimeSyncService I = RealtimeSyncService._();

  final _controller = StreamController<DateTime>.broadcast();
  Stream<DateTime> get stream => _controller.stream;

  final _deltaController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get deltaStream => _deltaController.stream;

  /// Called by [RealtimeBackupNotifier] callback when another device
  /// announces a backup. Triggers immediate pull on this device.
  void onRemoteBackupUpdated() {
    if (!_controller.isClosed) _controller.add(DateTime.now());
  }

  /// v2.2.57+143: Menerima deltas langsung dari WebSocket broadcast peer.
  void onRemoteDeltas(List<Map<String, dynamic>> deltas) {
    if (!_deltaController.isClosed) _deltaController.add(deltas);
  }
}

/// Helper that runs the actual pull + optional hot-apply. Lives next to
/// RealtimeBackupNotifier so the channel logic stays simple. Caller wires
/// the listener once at app startup.
///
/// Hot-apply on remote update is conservative — only fires when the app is
/// currently at the root route (no pushed sheets / forms), so we don't
/// disrupt a user mid-edit. Otherwise we just pull (record the cloud time)
/// and the next launch will see the fresh data.
Future<void> applyRemoteBackup({
  required ActivationRepository repo,
  required bool canHotApply,
  required Future<void> Function() closeAndRestore,
}) async {
  try {
    if (canHotApply) {
      await closeAndRestore();
      return;
    }
    // Soft pull: just adopt the cloud timestamp — next launch will pick up
    // the fresh data via the existing _applyPendingRestore flow.
    // Area I: canonical UID (lihat _channelName).
    final uid = await SecureStore.resolveCanonicalUid();
    if (uid == null) return;
    final cloudTime = await repo.getBackupTimestamp().timeout(
          const Duration(seconds: 8),
        );
    if (cloudTime != null) {
      await SecureStore.setLastCloudSeen(cloudTime);
    }
  } catch (_) {
    // Non-fatal — periodic pull will retry.
  }
}
