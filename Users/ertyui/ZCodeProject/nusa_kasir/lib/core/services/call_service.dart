import 'dart:async';
import 'dart:convert';

import 'package:nusa_kasir/core/cloud/cloud_gateway.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Panggil Karyawan (v2.2.54) — realtime broadcast via WebSocket gateway.
///
/// Semua device toko yang login subscribe ke channel `ring:{uid}`
/// (satu toko = satu akun, jadi channel-nya sama; uid = canonical backup
/// identity — lihat SecureStore.resolveCanonicalUid, v2.2.57+115 Area I).
/// Owner tap "Panggil"
/// pada karyawan X → broadcast event `ring` → device yang sedang login
/// SEBAGAI karyawan X memainkan ringtone + overlay sampai di-dismiss.
///
/// Tanpa tabel baru; broadcast tidak persist (panggilan = real-time saja).
class CallEvent {
  final int employeeId;
  final String employeeName;
  final String by;
  CallEvent({required this.employeeId, required this.employeeName, required this.by});

  factory CallEvent.fromPayload(dynamic payload) {
    final p = payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
    return CallEvent(
      employeeId: int.tryParse('${p['employeeId']}') ?? -1,
      employeeName: '${p['employeeName'] ?? ''}',
      by: '${p['by'] ?? 'Owner'}',
    );
  }
}

class CallService {
  CallService._();
  static final CallService I = CallService._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  String? _joinedChannel;
  bool _sending = false;

  final _controller = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get stream => _controller.stream;

  /// Nama channel per-toko — diturunkan dari UID tersimpan.
  Future<String?> _channelName() async {
    // v2.2.57+115 (Area I): canonical UID — channel panggilan ikut identitas
    // backup yang sama supaya device di akun yang sama tetap bertemu.
    final uid = await SecureStore.resolveCanonicalUid();
    if (uid == null || uid.isEmpty) return null;
    return 'ring:$uid';
  }

  /// Subscribe channel panggilan untuk device ini. Idempoten — dipanggil saat
  /// sesi karyawan aktif (dashboard) dan saat logout di-stop.
  Future<void> start() async {
    if (_channel != null) return;
    if (!await SecureStore.getCallFeatureEnabled()) return;
    final name = await _channelName();
    if (name == null) return;
    try {
      final ws = CloudGateway.shared.wsChannel(name);
      if (ws == null) return;
      // Tunggu handshake selesai sebelum listen (ws.ready).
      await ws.ready.timeout(const Duration(seconds: 8));
      _sub = ws.stream.listen((message) {
        try {
          // Pesan gateway: JSON string {"event": ..., "payload": {...}}.
          final dynamic decoded = message is String
              ? jsonDecode(message)
              : message;
          if (decoded is! Map) return;
          if ('${decoded['event'] ?? ''}' != 'ring') return;
          _controller.add(CallEvent.fromPayload(decoded['payload']));
        } catch (_) {}
      }, onError: (_) {}, cancelOnError: false);
      _channel = ws;
      _joinedChannel = name;
    } catch (_) {
      _channel = null;
      _joinedChannel = null;
    }
  }

  Future<void> stop() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
    _joinedChannel = null;
  }

  /// Kirim panggilan ke karyawan [employeeId]. Return true kalau terkirim.
  Future<bool> call({
    required int employeeId,
    required String employeeName,
    required String by,
  }) async {
    if (_sending) return false;
    var name = _joinedChannel ?? await _channelName();
    if (name == null) return false;
    // Channel belum ter-join (mis. sheet dibuka sebelum start()) → join dulu.
    if (_channel == null) {
      await start();
      if (_channel == null) return false;
    }
    _sending = true;
    try {
      _channel!.sink.add(jsonEncode({
        'event': 'ring',
        'payload': {
          'employeeId': employeeId,
          'employeeName': employeeName,
          'by': by,
        },
      }));
      return true;
    } catch (_) {
      return false;
    } finally {
      _sending = false;
    }
  }
}
