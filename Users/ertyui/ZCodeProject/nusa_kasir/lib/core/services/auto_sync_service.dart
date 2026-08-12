import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';

/// Auto cloud sync (file-based, two-way, silent).
///
/// - Upload: listens to drift table updates → debounce 6s (coalesce 30s) →
///   upload full backup archive (+ images) when local changed and cloud
///   is not newer. Offline failures are silent; next change retries.
/// - Receive: happens at app launch (main.dart) — this service only handles
///   the upload side + conflict snapshots.
/// - Conflict (cloud newer AND local changed): newest-wins — the loser is
///   saved as `conflict_<ts>.sqlite` snapshot next to the DB and the
///   `nusa_conflict_count` badge bumps. No dialogs, no reminders.
class AutoSyncService {
  final AppDatabase db;
  final ActivationRepository repo;
  final SupabaseClient? client;

  static const _debounce = Duration(seconds: 6);
  static const _coalesce = Duration(seconds: 30);

  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  Timer? _coalesceTimer;
  DateTime? _lastLocalChange;
  bool _inFlight = false;
  bool _disposed = false;

  AutoSyncService({required this.db, required this.repo, required this.client});

  /// Watch every table write and schedule a debounced upload.
  void start() {
    if (_sub != null) return;
    try {
      _sub = db.tableUpdates().listen((_) {
        _markLocalChange();
      });
    } catch (e) {
      debugPrint('[AutoSync] watch start error: $e');
    }
  }

  void _markLocalChange() {
    _lastLocalChange = DateTime.now().toUtc();
    // Persist immediately so app restart/receive-at-launch knows there is
    // un-uploaded local work.
    SecureStore.setLastLocalChange(_lastLocalChange!);
    _schedule();
  }

  void _schedule() {
    // Coalesce: keep pushing the debounce as long as writes keep coming.
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesce, () => flushNow());
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => flushNow());
  }

  /// Flush pending upload immediately (also called on app pause).
  Future<void> flushNow() async {
    _debounceTimer?.cancel();
    _coalesceTimer?.cancel();
    if (_inFlight || _disposed) return;
    if (_lastLocalChange == null) return;

    // Guards: activated + linked Google ID + DB file exists.
    if (!await repo.isActivated) return;
    final uid = await SecureStore.read(key: 'nusa_google_user_id');
    if (uid == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'nusa_kasir.sqlite'));
    if (!await dbFile.exists()) return;

    _inFlight = true;
    try {
      await _pushOnce();
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _pushOnce() async {
    if (client == null) return;
    final cloudTime = await repo.getBackupTimestamp();
    final lastSeen = await SecureStore.getLastCloudSeen();

    // 1. No cloud backup yet → just upload.
    if (cloudTime == null) {
      await _upload();
      return;
    }

    // 2. Cloud older or equal than what we've already seen AND we have local
    //    changes → safe upload (we're the newest).
    if (lastSeen != null && !cloudTime.isAfter(lastSeen)) {
      await _upload();
      return;
    }

    // 3. Cloud newer than what we've seen.
    if (cloudTime.isAfter(lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0))) {
      // 3a. No local changes → adopt cloud time, never overwrite cloud.
      if (_lastLocalChange == null || !_lastLocalChange!.isAfter(lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0))) {
        await SecureStore.setLastCloudSeen(cloudTime);
        return;
      }
      // 3b. Local changes AND cloud newer → conflict: newest-wins.
      //     The local DB is the loser only when cloud is strictly newer.
      //     Save a snapshot of the local file first (zero data loss).
      if (cloudTime.isAfter(_lastLocalChange!)) {
        await _snapshotLoser();
        // Replace local with cloud winner.
        final ok = await repo.restoreDirect();
        if (ok) {
          await SecureStore.setLastCloudSeen(cloudTime);
        } else {
          // Restore failed — don't lose local: keep it, adopt seen time.
          await SecureStore.setLastCloudSeen(cloudTime);
        }
      } else {
        // Local is newest — safe upload.
        await _upload();
      }
    }
  }

  Future<void> _upload() async {
    final now = DateTime.now().toUtc();
    // Reuse the service's DB for metadata (no extra connection per upload).
    final meta = SettingsRepository(db);
    final ok = await repo.uploadBackupNow(
      storeName: await meta.getStoreName(),
      ownerName: await meta.getOwnerName(),
    );
    if (ok) {
      await SecureStore.setLastCloudSeen(now);
      _lastLocalChange = null;
      await SecureStore.setLastLocalChange(now);
    }
  }

  /// Snapshot the local DB file so a conflict never destroys data.
  Future<void> _snapshotLoser() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final src = File(p.join(dir.path, 'nusa_kasir.sqlite'));
      if (!await src.exists()) return;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dest = File(p.join(dir.path, 'conflict_$ts.sqlite'));
      await src.copy(dest.path);
      await SecureStore.bumpConflictCount();
      debugPrint('[AutoSync] Conflict snapshot saved: ${dest.path}');
    } catch (e) {
      debugPrint('[AutoSync] snapshot error: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _coalesceTimer?.cancel();
    _sub?.cancel();
    _sub = null;
  }
}
