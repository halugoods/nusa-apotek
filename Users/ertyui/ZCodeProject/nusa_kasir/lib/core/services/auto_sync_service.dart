import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/core/services/realtime_sync_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';

/// Auto cloud sync (file-based, near-realtime, two-way).
///
/// v2.2.57 (paska-insiden percetakanrks@gmail.com 2026-08-26):
/// - **Timeout watchdog** di setiap step yang bisa hang (network). Tanpa
///   ini, satu request yang menggantung bikin `_inFlight = true` selamanya →
///   autosync mati total, hanya manual upload dari settings yang jalan.
/// - **Status terminal** di SETIAP exit path `_pushOnce`. Sebelumnya hanya
///   path "upload sukses" yang update `status` ke `ok` → path "adopsi cloud"
///   dan "konflik dengan guard" return tanpa update → chip stuck amber
///   selamanya.
/// - **Pull periodik + pull-on-resume**: device yang baru dibuka / di-resume
///   otomatis sinkron dari cloud (sebelumnya hanya saat app launch di
///   main.dart → 2 device bersamaan tidak pernah konvergen sampai restart).
/// - **Tidak fallback ke `DateTime.now()`**: `getBackupTimestamp` kini
///   return `null` kalau tidak bisa baca metadata (sebelumnya fallback ke
///   sekarang → cloud SELALU lebih baru → konflik terdeteksi terus → upload
///   mati). Null = "tidak terbukti lebih baru" = aman upload.
/// - **Conflict policy dilunakkan**: snapshot + counter hanya jika benar-
///   benar ada local-unsynced-work DAN cloud is proven newer; adopsi normal
///   diam.
///
/// Push side tetap debounced 1.2s (coalesce 10s) — sama dengan v2.2.55,
/// terbukti cukup menggabungkan burst edit tanpa terasa lambat.
enum AutoSyncPhase { idle, uploading, ok, failed }

class AutoSyncStatus {
  final AutoSyncPhase phase;
  final DateTime? lastOkAt;
  const AutoSyncStatus(this.phase, {this.lastOkAt});
}

class AutoSyncService {
  final AppDatabase db;
  final ActivationRepository repo;
  final SupabaseClient? client;

  /// Near-realtime — debounce 1.2s menggabungkan burst edit (import, form
  /// multi-step) tapi backup keluar hampir seketika.
  static const _debounce = Duration(milliseconds: 1200);

  /// Safety net: paksa flush tiap 10s supaya data tetap mengalir walau
  /// ada burst panjang.
  static const _coalesce = Duration(seconds: 10);

  /// v2.2.57: hard cap per upload cycle. Tanpa ini, satu hang request bikin
  /// `_inFlight` stuck forever → autosync mati total (insiden utama).
  static const _flushWatchdog = Duration(seconds: 60);
  static const _networkTimeout = Duration(seconds: 8);

  /// Periodic pull — cek cloud tiap 30s untuk device yang sama-sama terbuka
  /// (owner + kasir realtime lihat data satu sama lain tanpa restart).
  static const _pullInterval = Duration(seconds: 30);

  /// Status sinkronisasi global — chip awan di DashboardHeader.
  static final ValueNotifier<AutoSyncStatus> status =
      ValueNotifier(const AutoSyncStatus(AutoSyncPhase.idle));

  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  Timer? _coalesceTimer;
  Timer? _pullTimer;
  DateTime? _lastLocalChange;
  bool _inFlight = false;
  bool _disposed = false;

  AutoSyncService({required this.db, required this.repo, required this.client});

  void start() {
    if (_sub != null) return;
    _restoreStatusFromDisk();
    try {
      _sub = db.tableUpdates().listen((_) => _markLocalChange());
    } catch (e) {
      debugPrint('[AutoSync] watch start error: $e');
    }
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_pullInterval, (_) {
      // Pull-only — does NOT touch _inFlight (upload side) and does not
      // update status; if pull finds newer cloud, it stages a pending
      // restore which the caller (lifecycle or resume) will apply.
      _pullOnly();
    });
  }

  Future<void> _restoreStatusFromDisk() async {
    try {
      final last = await SecureStore.getLastBackupTime();
      if (last != null &&
          status.value.phase == AutoSyncPhase.idle &&
          status.value.lastOkAt == null) {
        status.value = AutoSyncStatus(AutoSyncPhase.ok, lastOkAt: last);
      }
    } catch (_) {}
  }

  void _markLocalChange() {
    _lastLocalChange = DateTime.now().toUtc();
    SecureStore.setLastLocalChange(_lastLocalChange!);
    _schedule();
  }

  void _schedule() {
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesce, () => flushNow());
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => flushNow());
  }

  /// Flush pending upload immediately. Also called on app pause.
  /// Hard-wrapped with [_flushWatchdog] so a hung request cannot wedge
  /// the service (the v2.2.55 bug: `_inFlight` stuck true forever).
  Future<void> flushNow() async {
    _debounceTimer?.cancel();
    _coalesceTimer?.cancel();
    if (_inFlight || _disposed) return;
    if (_lastLocalChange == null) return;

    if (!await repo.isActivated) return;
    final uid = await SecureStore.read(key: 'nusa_google_user_id');
    if (uid == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'nusa_kasir.sqlite'));
    if (!await dbFile.exists()) return;

    _inFlight = true;
    status.value = AutoSyncStatus(AutoSyncPhase.uploading,
        lastOkAt: status.value.lastOkAt);
    try {
      await _pushOnce().timeout(_flushWatchdog);
    } on TimeoutException {
      debugPrint('[AutoSync] flushNow watchdog timeout — releasing');
      status.value = AutoSyncStatus(AutoSyncPhase.failed,
          lastOkAt: status.value.lastOkAt);
    } catch (_) {
      status.value = AutoSyncStatus(AutoSyncPhase.failed,
          lastOkAt: status.value.lastOkAt);
    } finally {
      _inFlight = false;
      if (_lastLocalChange != null && !_disposed) {
        _schedule();
      }
    }
  }

  /// Pull-only — checks if cloud is newer than our last seen AND we have no
  /// unsynced local work. If so, records the cloud timestamp so the next
  /// push cycle knows it's safe; hot-apply is the caller's responsibility
  /// (we never swap the DB mid-write from here).
  Future<void> _pullOnly() async {
    if (_disposed) return;
    try {
      if (!await repo.isActivated) return;
      final uid = await SecureStore.read(key: 'nusa_google_user_id');
      if (uid == null) return;

      final cloudTime =
          await repo.getBackupTimestamp().timeout(_networkTimeout);
      if (cloudTime == null) return;

      final lastSeen = await SecureStore.getLastCloudSeen();

      // Cloud not proven newer than what we've already adopted → nothing.
      if (lastSeen != null && !cloudTime.isAfter(lastSeen)) return;

      // Cloud newer AND we have unsynced local work → defer to push side
      // (push will resolve; pulling now would clobber unsynced edits).
      if (_lastLocalChange != null &&
          _lastLocalChange!.isAfter(lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0))) {
        return;
      }

      // Adopt cloud time. Callers (lifecycle / hot-apply) decide whether
      // to actually swap the DB based on app state.
      await SecureStore.setLastCloudSeen(cloudTime);
    } catch (_) {
      // Pull failure is non-fatal — next tick will retry.
    }
  }

  /// Periodic pull — exposed publicly so app lifecycle hooks can fire it
  /// immediately on resume instead of waiting up to 30s for the next tick.
  Future<void> pullNow() => _pullOnly();

  Future<void> _pushOnce() async {
    if (client == null) {
      status.value = AutoSyncStatus(AutoSyncPhase.failed,
          lastOkAt: status.value.lastOkAt);
      return;
    }
    final cloudTime =
        await repo.getBackupTimestamp().timeout(_networkTimeout);
    final lastSeen = await SecureStore.getLastCloudSeen();

    // 1. Unknown / first run → just upload.
    if (cloudTime == null) {
      await _upload();
      return;
    }

    // 2. Cloud not proven newer than our last seen AND we have local
    //    changes → safe upload.
    if (lastSeen != null && !cloudTime.isAfter(lastSeen)) {
      await _upload();
      return;
    }

    // 3. Cloud proven newer than our last seen.
    final localChangedSinceSeen =
        _lastLocalChange != null &&
            _lastLocalChange!.isAfter(
              lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0),
            );

    if (!localChangedSinceSeen) {
      // 3a. No unsynced local work → adopt cloud time (no snapshot needed).
      await SecureStore.setLastCloudSeen(cloudTime);
      status.value = AutoSyncStatus(AutoSyncPhase.ok,
          lastOkAt: status.value.lastOkAt);
      return;
    }

    // 3b. Local has unsynced work AND cloud is newer.
    if (cloudTime.isAfter(_lastLocalChange!)) {
      // Cloud is strictly newer than our local change. Could be a real
      // conflict (other device wrote) OR stale cloud (other device
      // uploaded an older backup). Snap-shot local (zero data loss) but
      // keep local active (it's newer from this user's perspective) and
      // let our next push overwrite cloud. Avoid clobbering variants by
      // requiring employees to exist locally first (sanity guard).
      try {
        final empCount =
            await db.select(db.employees).get().then((r) => r.length);
        if (empCount == 0) {
          // Truly empty device — safe to adopt cloud (likely first-time
          // restore on a fresh install). Stage restore; user-initiated
          // restore at launch handles the swap.
          await SecureStore.setLastCloudSeen(cloudTime);
          status.value = AutoSyncStatus(AutoSyncPhase.ok,
              lastOkAt: status.value.lastOkAt);
          return;
        }
      } catch (_) {}
      await _snapshotLoser();
      // Adopt seen time so subsequent push uploads correctly; we keep
      // local DB active (newest from this user's POV wins).
      await SecureStore.setLastCloudSeen(cloudTime);
      // Local work is still pending — next push will run.
      status.value = AutoSyncStatus(AutoSyncPhase.ok,
          lastOkAt: status.value.lastOkAt);
    } else {
      // Local is newest — safe upload.
      await _upload();
    }
  }

  Future<void> _upload() async {
    final now = DateTime.now().toUtc();
    final meta = SettingsRepository(db);
    final ok = await repo.uploadBackupNow(
      storeName: await meta.getStoreName(),
      ownerName: await meta.getOwnerName(),
    );
    if (ok) {
      await SecureStore.setLastCloudSeen(now);
      _lastLocalChange = null;
      await SecureStore.setLastLocalChange(now);
      status.value = AutoSyncStatus(AutoSyncPhase.ok, lastOkAt: now.toLocal());
      // v2.2.57: announce to other devices on the same Google account so
      // they can pull within ~1s instead of waiting for the next tick.
      unawaited(RealtimeBackupNotifier.I.broadcastUpdated());
    } else {
      status.value = AutoSyncStatus(AutoSyncPhase.failed,
          lastOkAt: status.value.lastOkAt);
    }
  }

  /// Snapshot local DB so a conflict never destroys data.
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
    _pullTimer?.cancel();
    _sub?.cancel();
    _sub = null;
  }
}