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
///
/// v2.2.55: status upload kini TERLIHAT — [AutoSyncService.status] di-update
/// setiap fase (idle/uploading/ok/failed) dan ditampilkan sebagai ikon awan
/// di DashboardHeader, supaya user tahu kapan data SUDAH aman di cloud
/// sebelum menghapus data aplikasi (kasus nyata: produk hilang karena device
/// dihapus saat upload masih berjalan — silent failure).
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

  /// v2.2.55: near-realtime — debounce 6s terasa lama (user bisa hapus data
  /// sebelum upload mulai). 1.2s masih menggabungkan burst tulisan (import,
  /// form multi-step) tapi backup keluar hampir seketika.
  static const _debounce = Duration(milliseconds: 1200);

  /// Safety net: walau tulisan terus-menerus (debounce terus tertunda),
  /// paksa flush tiap 10s supaya data tetap mengalir ke cloud.
  static const _coalesce = Duration(seconds: 10);

  /// Status sinkronisasi global — didengarkan ikon awan di DashboardHeader.
  /// Static supaya manual upload di Pengaturan bisa meng-update chip yang sama.
  static final ValueNotifier<AutoSyncStatus> status =
      ValueNotifier(const AutoSyncStatus(AutoSyncPhase.idle));

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
    _restoreStatusFromDisk();
    try {
      _sub = db.tableUpdates().listen((_) {
        _markLocalChange();
      });
    } catch (e) {
      debugPrint('[AutoSync] watch start error: $e');
    }
  }

  /// Tampilkan waktu backup sukses terakhir (dari sesi sebelumnya) di chip.
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
    status.value = AutoSyncStatus(AutoSyncPhase.uploading,
        lastOkAt: status.value.lastOkAt);
    try {
      await _pushOnce();
    } catch (_) {
      status.value = AutoSyncStatus(AutoSyncPhase.failed,
          lastOkAt: status.value.lastOkAt);
    } finally {
      _inFlight = false;
      // v2.2.55: perubahan yang terjadi SAAT upload berjalan tidak boleh
      // nunggu tulisan berikutnya — langsung antre siklus lagi. Kalau tidak
      // ada perubahan baru, _lastLocalChange == null (dikosongkan setelah
      // sukses) → tidak ada loop.
      if (_lastLocalChange != null && !_disposed) {
        _schedule();
      }
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
        // ── PENTING: jangan timpa DB lokal yang sudah punya karyawan ──
        // Backup cloud bisa milik varian lain (UID anon vs Google tidak
        // konsisten) → menimpa DB varian ini menghilangkan owner/PIN →
        // "PIN salah" selamanya. Jika lokal sudah punya data, jangan restore.
        try {
          final empCount =
              await db.select(db.employees).get().then((r) => r.length);
          if (empCount > 0) {
            await SecureStore.setLastCloudSeen(cloudTime);
            return;
          }
        } catch (_) {
          await SecureStore.setLastCloudSeen(cloudTime);
          return;
        }
        await _snapshotLoser();
        // Replace local with cloud winner.
        // v2.2.37: pakai restoreFromCloud() (stage .pending) BUKAN
        // restoreDirect() (live swap) — service ini memegang koneksi drift
        // `db` yang selalu terbuka; menulis live sqlite saat drift terbuka =
        // korupsi. Stage .pending → di-swap oleh main.dart _applyPendingRestore
        // saat start berikutnya, aman. Restore langsung hanya untuk jalur
        // user-facing (activation/RestoreBackupFlow) yang menutup drift dulu.
        final ok = await repo.restoreFromCloud();
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
      status.value = AutoSyncStatus(AutoSyncPhase.ok, lastOkAt: now.toLocal());
    } else {
      status.value = AutoSyncStatus(AutoSyncPhase.failed,
          lastOkAt: status.value.lastOkAt);
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
