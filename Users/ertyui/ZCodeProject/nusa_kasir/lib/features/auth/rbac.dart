import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/repositories/role_repository.dart';

/// Check if user has basic access to a screen.
/// Checks the reactive [roleAccessProvider] map (loaded from the SQLite Roles
/// table) first, then falls back to hardcoded defaults.
bool hasAccess(WidgetRef ref, String role, String screen) {
  final dyn = ref.read(roleAccessProvider)[role];
  if (dyn != null) return dyn.contains(screen);
  // Fallback to hardcoded defaults
  final access = NusaConfig.roleAccess[role];
  return access?.contains(screen) ?? false;
}

/// True if this screen requires PIN re-entry (for security).
bool needsPinGuard(String screen) {
  return NusaConfig.pinGuardScreens.contains(screen);
}

/// True if this screen is owner-only (block non-owners).
bool isOwnerOnly(String screen) {
  return NusaConfig.ownerOnlyScreens.contains(screen);
}

/// Load roles from the SQLite Roles table into the reactive provider.
/// Called at startup and after every role save so the dashboard rebuilds.
Future<void> loadRoleAccess(WidgetRef ref) async {
  final roles = await RoleRepository(ref.read(databaseProvider)).getRoles();
  final map = <String, List<String>>{};
  for (final r in roles) {
    map[r['name'] as String] = (r['access'] as List).cast<String>();
  }
  ref.read(roleAccessProvider.notifier).state = map;
}
