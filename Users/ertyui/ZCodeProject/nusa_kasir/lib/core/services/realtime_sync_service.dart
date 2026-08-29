import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/core/services/realtime_sync_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Pushes realtime "backup_updated" events so other devices on the same
/// Google account get notified within ~1s instead of waiting for the next
/// poll tick. Complements the file-based pull in [AutoSyncService].
///
/// v2.2.57: this is the "hybrid B" delta push. We don't ship a full CRDT or
/// WebSocket-driven SQLite sync — too heavy for a small POS. We just shout
/// "hey, I just uploaded" and let subscribers do the regular pull.
class RealtimeBackupNotifier {
  RealtimeBackupNotifier._();
  static final RealtimeBackupNotifier I = RealtimeBackupNotifier._();

  RealtimeChannel? _channel;
  String? _joinedName;

  /// Channel name shared by all devices signed into the same Google account.
  /// Mirrors CallService pattern.
  Future<String?> _channelName() async {
    try {
      if (!Supabase.instance.isInitialized) return null;
    } catch (_) {
      return null;
    }
    // v2.2.57+115 (Area I): channel memakai canonical UID (sama dengan path
    // backup) supaya semua device di akun yang sama bertemu di satu channel —
    // sebelum ini device Google UID vs email UUID tidak pernah saling lihat.
    final uid = await SecureStore.resolveCanonicalUid();
    if (uid == null || uid.isEmpty) return null;
    return 'nusa-sync-$uid';
  }

  Future<void> start() async {
    if (_channel != null) return;
    final name = await _channelName();
    if (name == null) return;
    try {
      _channel = Supabase.instance.client.channel(name).onBroadcast(
        event: 'backup_updated',
        callback: (payload) {
          try {
            final p = Map<String, dynamic>.from(payload as Map);
            final deviceId = '${p['deviceId'] ?? ''}';
            // Ignore our own broadcast (the originator doesn't need to pull
            // from itself).
            if (deviceId == _myDeviceId()) return;
            debugPrint('[RealtimeSync] backup_updated from $deviceId');
            // Trigger immediate pull on the receiving device.
            RealtimeSyncService.I.onRemoteBackupUpdated();
          } catch (_) {}
        },
      ).subscribe();
      _joinedName = name;
    } catch (_) {
      _channel = null;
    }
  }

  Future<void> stop() async {
    try {
      await _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _joinedName = null;
  }

  /// Broadcast after a successful upload. Includes our deviceId so listeners
  /// can ignore their own echoes.
  Future<void> broadcastUpdated() async {
    if (_channel == null) return;
    try {
      await _channel!.sendBroadcastMessage(
        event: 'backup_updated',
        payload: {
          'deviceId': _myDeviceId(),
          'at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[RealtimeSync] broadcast failed: $e');
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

  /// Called by [RealtimeBackupNotifier] callback when another device
  /// announces a backup. Triggers immediate pull on this device.
  void onRemoteBackupUpdated() {
    if (!_controller.isClosed) _controller.add(DateTime.now());
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
