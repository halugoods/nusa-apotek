import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
/// Push side kini debounced 5 menit (coalesce 30s) — v2.2.57+130. Dulu 1.2s
/// (coalesce 10s): tiap transaksi/ubah produk = upload backup FULL di
/// belakang layar (bomb egress: 2-3 user aktif sudah makan kuota Cached
/// Egress Supabase sampai HTTP 402, project restricted). Data lama belum
/// hilang — masih ada flush-on-pause (throttled) + pull realtime (WS/
/// broadcast) + restore manual. Sekarang arsip backup DB-only (tanpa
/// gambar) + crypto di isolate, jadi tiap upload ringan; 5 menit tetap
/// menjaga RPO wajar untuk kasir offline-first.
enum AutoSyncPhase { idle, uploading, ok, failed }

class AutoSyncStatus {
  final AutoSyncPhase phase;
  final DateTime? lastOkAt;
  const AutoSyncStatus(this.phase, {this.lastOkAt});
}

class AutoSyncService {
  final AppDatabase db;
  final ActivationRepository repo;

  /// v2.2.57+130: debounce 5 MENIT (dulu 1.2s). Root cause bom egress:
  /// backup full di-upload setiap kali ada DB write. Backup arsip baru
  /// DB-only + isolate, tapi tetap jangan upload tiap transaksi — bisnis
  /// lifetime Rp249rb tidak sanggup biaya egress per-user.
  static const _debounce = Duration(minutes: 5);

  /// Safety net: paksa flush tiap 30 menit supaya perubahan yang tidak
  /// berhenti (burst panjang) tetap terkirim walau debounce belum lewat.
  static const _coalesce = Duration(minutes: 30);

  /// v2.2.57: hard cap per upload cycle. Tanpa ini, satu hang request bikin
  /// `_inFlight` stuck forever → autosync mati total (insiden utama).
  static const _flushWatchdog = Duration(seconds: 60);
  static const _networkTimeout = Duration(seconds: 8);

  /// v2.2.57+130 (A1.4): flush-on-pause hanya kalau ada perubahan yang
  /// belum terupload ≥2 menit sejak upload terakhir. App pause setiap kali
  /// user ganti app/lock screen — tanpa gate ini tiap pause = upload penuh
  /// (perangkat kasir sering lock/unlock puluhan kali sehari).
  static const _pauseFlushGate = Duration(minutes: 2);

  /// Periodic pull — cek cloud tiap 5 menit untuk device yang sama-sama
  /// terbuka (owner + kasir realtime lihat data satu sama lain tanpa
  /// restart). v2.2.57+122 (Cached Egress fix): sebelumnya 30 detik →
  /// 8.640 request HEAD/device/hari. Perubahan data tetap tersiar hampir
  /// seketika lewat [RealtimeBackupNotifier.broadcastUpdated] (push side
  /// announce ke device lain → mereka pullNow() segera). Jadi 5 menit cukup
  /// untuk recovery, tanpa membebani Storage.
  static const _pullInterval = Duration(minutes: 5);

  /// Waktu upload sukses terakhir (local) — untuk gate flush-on-pause.
  DateTime? _lastUploadAt;

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

  AutoSyncService({required this.db, required this.repo});

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
  ///
  /// v2.2.57+130 (A1.4): [force] = false (default) menerapkan gate
  /// [_pauseFlushGate] — skip kalau belum ada ≥2 menit sejak upload sukses
  /// terakhir. Panggilan internal (debounce/coalesce timer) TIDAK dipaksa;
  /// panggilan app-pause pakai default (gated). Semua caller yang benar-
  /// benar butuh upload sekarang (tombol manual, sebelum restore) pakai
  /// `force: true`.
  Future<void> flushNow({bool force = false}) async {
    _debounceTimer?.cancel();
    _coalesceTimer?.cancel();
    if (_inFlight || _disposed) return;
    if (_lastLocalChange == null) return;

    // Gate anti-bom egress: pause tanpa perubahan berarti → jangan upload.
    // (Debounce 5 menit sudah melewatkan sebagian besar pause biasa; gate
    // ini menahan kasus "edit lalu langsung lock screen".)
    if (!force &&
        _lastUploadAt != null &&
        DateTime.now().difference(_lastUploadAt!) < _pauseFlushGate) {
      return;
    }

    if (!await repo.isActivated) return;
    // v2.2.57+115 (Area I): satu canonical UID untuk backup — prefer UID akun
    // email/password (UUID), lalu Google 21-digit. Sebelumnya guard hanya baca
    // `nusa_google_user_id` → user yang login email/password SAJA (tanpa
    // Google) uid null → autosync mati total ("login sama tapi ga sinkron").
    final uid = await SecureStore.resolveCanonicalUid();
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
        // Reschedule TANPA force — debounce penuh 5 menit berlaku lagi
        // (kalau gagal upload, retry tetap di-throttle, bukan loop cepat).
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
      // Area I: canonical UID (lihat flushNow).
      final uid = await SecureStore.resolveCanonicalUid();
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
      _lastUploadAt = DateTime.now();
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