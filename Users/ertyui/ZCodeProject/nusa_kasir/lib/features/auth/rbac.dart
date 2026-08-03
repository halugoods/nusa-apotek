import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Dynamic per-role access map. Loaded from RoleRepository on startup
/// and refreshed whenever Owner modifies roles via Employees screen.
/// Falls back to NusaConfig.roleAccess when empty.
Map<String, List<String>> _dynamicAccess = {};

/// Replace the dynamic access map (called from providers/startup after loading).
void setDynamicRoleAccess(Map<String, List<String>> access) {
  _dynamicAccess = Map.from(access);
}

/// Check if user has basic access to a screen.
/// Checks dynamic (Owner-configured) access first, then falls back to hardcoded defaults.
bool hasAccess(String role, String screen) {
  final dyn = _dynamicAccess[role];
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

/// Legacy pin-to-role map (deprecated — now queries DB).
const Map<String, String> pinToRole = {
  '1234': 'Owner',
  '5678': 'Manager',
  '9012': 'Kasir',
  '1111': 'Gudang',
  '2222': 'Finance',
};
