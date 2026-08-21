import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nusa_kasir/core/services/online_order_service.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auto-sync produk online (v2.2.43) — pemicu ringan di samping backup.
///
/// Mendengarkan `tableUpdates()` (produk berubah) → debounce 8 dtk →
/// `OnlineOrderService.syncOnlineProducts` (hanya produk isOnline, UPSERT ke
/// edge fn — produk non-online di web TIDAK terhapus). Gagal = senyap (log),
/// tidak ada dialog/toast — sinkron manual tetap tersedia di Pengaturan Toko.
class OnlineProductSyncService {
  final AppDatabase db;
  final SupabaseClient client;

  static const _debounce = Duration(seconds: 8);

  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  bool _inFlight = false;
  bool _disposed = false;

  OnlineProductSyncService({required this.db, required this.client});

  void start() {
    if (_sub != null) return;
    try {
      _sub = db.tableUpdates().listen((_) {
        _schedule();
      });
    } catch (e) {
      debugPrint('[OnlineSync] watch start error: $e');
    }
  }

  void _schedule() {
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
    try {
      final svc = OnlineOrderService(client);
      final result = await svc.syncOnlineProducts(db);
      if (result.error != null) {
        debugPrint('[OnlineSync] ⚠ ${result.error}');
      } else {
        debugPrint(
          '[OnlineSync] ✓ ${result.count} produk, '
          '${result.imgSuccess} gambar ok, ${result.imgFailed} gagal',
        );
      }
    } catch (e) {
      debugPrint('[OnlineSync] error: $e');
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
