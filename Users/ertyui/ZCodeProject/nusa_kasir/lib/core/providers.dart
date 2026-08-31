/// Global Riverpod providers — extracted from app.dart to break circular imports.
/// All screens can import this file without pulling in the full router.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/online_order_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/recipe_repository.dart';
import 'package:nusa_kasir/data/repositories/refund_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/core/services/auto_sync_service.dart';
import 'package:nusa_kasir/core/services/online_product_sync_service.dart';
import 'package:nusa_kasir/core/services/sheets_live_sync.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final authProvider = StateProvider<String?>((ref) => null);

final themeModeProvider = StateProvider<String>((ref) => 'system');

final activeBranchProvider = StateProvider<Branche?>((ref) => null);

final settingsRepoProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final transactionRepoProvider = Provider(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final refundRepoProvider = Provider(
  (ref) => RefundRepository(ref.watch(databaseProvider)),
);

final customerRepoProvider = Provider(
  (ref) => CustomerRepository(ref.watch(databaseProvider)),
);

final productRepoProvider = Provider(
  (ref) => ProductRepository(ref.watch(databaseProvider)),
);

/// F&B: bahan baku + resep + HPP. Hanya dipakai varian F&B.
final recipeRepoProvider = Provider(
  (ref) => RecipeRepository(ref.watch(databaseProvider)),
);

final activationRepoProvider = Provider<ActivationRepository>((ref) {
  try {
    return ActivationRepository(Supabase.instance.client);
  } catch (_) {
    return ActivationRepository(null);
  }
});

/// Auto cloud sync — starts on app init, flushed on app pause.
/// Kept alive for the whole app lifetime (autoDispose would kill the watcher).
final autoSyncProvider = Provider<AutoSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(activationRepoProvider);
  final svc = AutoSyncService(db: db, repo: repo, client: repo.client);
  ref.onDispose(svc.dispose);
  svc.start();
  return svc;
});

final onlineOrderRepoProvider = Provider(
  (ref) => OnlineOrderRepository(ref.watch(databaseProvider)),
);

/// Live sync harian → Google Sheets (v2.2.57+122, cloud panas). Listen
/// tableUpdates → debounce 2 dtk → append Transaksi (dedup by invoice di
/// server). Kept alive for the whole app lifetime like [autoSyncProvider].
final sheetsLiveSyncProvider = Provider<SheetsLiveSyncService>((ref) {
  final svc = SheetsLiveSyncService(db: ref.watch(databaseProvider));
  ref.onDispose(svc.dispose);
  svc.start();
  return svc;
});

/// Auto-sync produk online (v2.2.43) — debounce tableUpdates → syncOnlineProducts.
/// Kept alive for the whole app lifetime (autoDispose would kill the watcher).
final onlineProductSyncProvider = Provider<OnlineProductSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final svc = OnlineProductSyncService(
    db: db,
    client: Supabase.instance.client,
  );
  ref.onDispose(svc.dispose);
  svc.start();
  return svc;
});

/// Role permissions (RBAC) — per-role menu access map.
/// Loaded from the SQLite Roles table on startup and refreshed whenever an
/// Owner edits roles, so the dashboard menu rebuilds reactively.
final roleAccessProvider = StateProvider<Map<String, List<String>>>((ref) => {});

/// Feature toggles — which menu items show on Home Screen.
final featureTogglesProvider = StateProvider<Map<String, bool>>((ref) => {});

/// Menu ordering — user-defined order from Kelola Fitur drag-reorder.
final menuOrderProvider = StateProvider<List<String>>((ref) => []);

/// Active theme preset ID (maps to NusaConfig.themePresets keys).
/// Loaded from SecureStore on app init, default = productId.
final themePresetProvider = StateProvider<String>((ref) => 'kelontong');

/// PIN length preference (4 or 6 digits). Default 6.
/// Loaded from settings DB on app init, mutated by settings screen.
final pinLengthProvider = StateProvider<int>((ref) => 6);
