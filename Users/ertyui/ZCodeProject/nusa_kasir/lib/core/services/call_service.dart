import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/services/google_auth_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Panggil Karyawan (v2.2.54) — Supabase Realtime Broadcast.
///
/// Semua device toko yang login subscribe ke channel `nusa-call-{googleUid}`
/// (satu toko = satu akun Google, jadi channel-nya sama). Owner tap "Panggil"
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
    final p = Map<String, dynamic>.from(payload as Map);
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

  RealtimeChannel? _channel;
  String? _joinedChannel;
  bool _sending = false;

  final _controller = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get stream => _controller.stream;

  /// Nama channel per-toko — diturunkan dari Google UID tersimpan.
  Future<String?> _channelName() async {
    try {
      if (!Supabase.instance.isInitialized) return null;
    } catch (_) {
      return null;
    }
    final uid = await GoogleAuthService.getStoredUserId();
    if (uid == null || uid.isEmpty) return null;
    return 'nusa-call-$uid';
  }

  /// Subscribe channel panggilan untuk device ini. Idempoten — dipanggil saat
  /// sesi karyawan aktif (dashboard) dan saat logout di-stop.
  Future<void> start() async {
    if (_channel != null) return;
    if (!await SecureStore.getCallFeatureEnabled()) return;
    final name = await _channelName();
    if (name == null) return;
    try {
      _channel = Supabase.instance.client.channel(name).onBroadcast(
        event: 'ring',
        callback: (payload) {
          try {
            _controller.add(CallEvent.fromPayload(payload));
          } catch (_) {}
        },
      ).subscribe();
      _joinedChannel = name;
    } catch (_) {
      _channel = null;
    }
  }

  Future<void> stop() async {
    try {
      await _channel?.unsubscribe();
    } catch (_) {}
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
      await _channel!.sendBroadcastMessage(event: 'ring', payload: {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'by': by,
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      _sending = false;
    }
  }
}
