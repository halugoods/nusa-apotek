import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/online_order_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fase sinkronisasi produk online — dipakai chip status cloud di header
/// Toko Online (v2.2.57+120). Beda dari AutoSyncPhase (backup DB): ini
/// khusus produk `isOnline` → edge fn online-store.
enum OnlineSyncPhase { idle, uploading, ok, failed }

class OnlineSyncStatus {
  final OnlineSyncPhase phase;
  final DateTime? lastOkAt;
  final int? lastCount;
  const OnlineSyncStatus(this.phase, {this.lastOkAt, this.lastCount});
}

/// Auto-sync produk online (v2.2.43) — pemicu ringan di samping backup.
///
/// Mendengarkan `tableUpdates()` (produk berubah) → debounce 8 dtk →
/// `OnlineOrderService.syncOnlineProducts` (hanya produk isOnline, UPSERT ke
/// edge fn — produk non-online di web TIDAK terhapus). Gagal = senyap (log),
/// tidak ada dialog/toast — sinkron manual tetap tersedia di Pengaturan Toko.
///
/// v2.2.57+120: status sinkron di-expose global ([status]) supaya header
/// Toko Online bisa menampilkan chip cloud (hijau = sukses, amber = sedang
/// mengunggah, merah = gagal, abu = belum pernah).
class OnlineProductSyncService {
  final AppDatabase db;
  final SupabaseClient client;

  static const _debounce = Duration(seconds: 8);

  /// Status sinkronisasi produk online global — dipakai chip header.
  static final ValueNotifier<OnlineSyncStatus> status =
      ValueNotifier(const OnlineSyncStatus(OnlineSyncPhase.idle));

  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  bool _inFlight = false;
  bool _disposed = false;

  OnlineProductSyncService({required this.db, required this.client});

  void start() {
    if (_sub != null) return;
    _restoreStatusFromDisk();
    try {
      _sub = db.tableUpdates().listen((_) {
        _schedule();
      });
    } catch (e) {
      debugPrint('[OnlineSync] watch start error: $e');
    }
  }

  /// v2.2.57+120: pulihkan status "sukses terakhir" dari disk supaya chip
  /// header tidak selalu abu-abu setelah app restart.
  Future<void> _restoreStatusFromDisk() async {
    try {
      final raw = await SecureStore.read(
        key: 'nusa_online_sync_status_${NusaConfig.productId}',
      );
      if (raw != null && raw.isNotEmpty) {
        final ms = int.tryParse(raw);
        if (ms != null) {
          final t = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
          if (status.value.phase == OnlineSyncPhase.idle) {
            status.value = OnlineSyncStatus(OnlineSyncPhase.ok, lastOkAt: t);
          }
        }
      }
    } catch (_) {}
  }

  void _schedule() {
    // Ada perubahan lokal yang belum ter-sinkron → status "menunggu"
    // (chip abu-abu lagi, tombol sinkron manual aktif kembali).
    status.value = OnlineSyncStatus(OnlineSyncPhase.idle,
        lastOkAt: status.value.lastOkAt, lastCount: status.value.lastCount);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => flushNow());
  }

  /// Sinkron sekarang (juga dipanggil saat app pause).
  Future<void> flushNow() async {
    _debounceTimer?.cancel();
    if (_inFlight || _disposed) return;
    try {
      // Toko online aktif? (setting store_name tidak kosong → sudah setup).
      final meta = SettingsRepository(db);
      final storeName = await meta.getStoreName();
      if (storeName.isEmpty) return;
    } catch (_) {
      return;
    }
    _inFlight = true;
    status.value = OnlineSyncStatus(OnlineSyncPhase.uploading,
        lastOkAt: status.value.lastOkAt, lastCount: status.value.lastCount);
    try {
      final svc = OnlineOrderService(client);
      final result = await svc.syncOnlineProducts(db);
      if (result.error != null) {
        debugPrint('[OnlineSync] ⚠ ${result.error}');
        status.value = OnlineSyncStatus(OnlineSyncPhase.failed,
            lastOkAt: status.value.lastOkAt,
            lastCount: status.value.lastCount);
      } else {
        debugPrint(
          '[OnlineSync] ✓ ${result.count} produk, '
          '${result.imgSuccess} gambar ok, ${result.imgFailed} gagal',
        );
        status.value = OnlineSyncStatus(OnlineSyncPhase.ok,
            lastOkAt: DateTime.now(), lastCount: result.count);
        try {
          await SecureStore.write(
            key: 'nusa_online_sync_status_${NusaConfig.productId}',
            value: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[OnlineSync] error: $e');
      status.value = OnlineSyncStatus(OnlineSyncPhase.failed,
          lastOkAt: status.value.lastOkAt,
          lastCount: status.value.lastCount);
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _sub?.cancel();
    _sub = null;
  }
}

