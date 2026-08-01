/// Global Riverpod providers — extracted from app.dart to break circular imports.
/// All screens can import this file without pulling in the full router.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/online_order_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:nusa_kasir/core/activation/activation_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final authProvider = StateProvider<String?>((ref) => null);

final themeModeProvider = StateProvider<String>((ref) => 'system');

final activeBranchProvider = StateProvider<Branche?>((ref) => null);

final settingsRepoProvider =
    Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

final transactionRepoProvider =
    Provider((ref) => TransactionRepository(ref.watch(databaseProvider)));

final customerRepoProvider =
    Provider((ref) => CustomerRepository(ref.watch(databaseProvider)));

final productRepoProvider =
    Provider((ref) => ProductRepository(ref.watch(databaseProvider)));

final activationRepoProvider = Provider<ActivationRepository>((ref) {
  try {
    return ActivationRepository(Supabase.instance.client);
  } catch (_) {
    return ActivationRepository(null);
  }
});

final onlineOrderRepoProvider =
    Provider((ref) => OnlineOrderRepository(ref.watch(databaseProvider)));

/// Feature toggles — which menu items show on Home Screen.
final featureTogglesProvider = StateProvider<Map<String, bool>>((ref) => {});

/// PIN length preference (4 or 6 digits). Default 6.
/// Loaded from settings DB on app init, mutated by settings screen.
final pinLengthProvider = StateProvider<int>((ref) => 6);
