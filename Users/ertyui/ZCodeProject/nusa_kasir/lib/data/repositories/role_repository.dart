import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Simple file-based CRUD for custom roles/jabatan.
///
/// Default roles: Owner, Manager, Kasir, Gudang, Finance.
/// Custom roles are persisted as JSON in app documents.
class RoleRepository {
  static const _filename = 'nusa_roles.json';
  static const _defaultRoles = ['Owner', 'Manager', 'Kasir', 'Gudang', 'Finance'];

  /// Public list of default role names (used by UI to check deletability).
  static const defaultRoleNames = ['Owner', 'Manager', 'Kasir', 'Gudang', 'Finance'];

  static const _defaultRoleColors = {
    'Owner': 0xFF8B5CF6,
    'Manager': 0xFF3B82F6,
    'Kasir': 0xFF10B981,
    'Gudang': 0xFFF59E0B,
    'Finance': 0xFFEC4899,
  };

  static const _defaultRoleAccess = {
    'Owner': ["home","kasir","produk","stok","transaksi","pelanggan","promo","laporan","presensi","karyawan","keuangan","pengaturan","supplier","spreadsheet","pesanan_online","ai_chat","piutang","cabang",
               "meja","laundry_status","servis","booking","resep","print_order"],
    'Manager': ["home","kasir","produk","stok","transaksi","pelanggan","promo","laporan","presensi","karyawan","keuangan","pengaturan","supplier","spreadsheet","pesanan_online","ai_chat","piutang","cabang",
                "meja","laundry_status","servis","booking","resep","print_order"],
    'Kasir': ["home","kasir","produk","stok","transaksi","pelanggan","ai_chat"],
    'Gudang': ["home","produk","stok","laporan","supplier"],
    'Finance': ["home","transaksi","keuangan","laporan","presensi","karyawan","supplier"],
  };

  /// Load all roles from file, falling back to defaults.
  Future<List<Map<String, dynamic>>> getRoles() async {
    final file = await _file();
    if (!await file.exists()) {
      return _defaultRoles.map((r) => _defaultEntry(r)).toList();
    }
    try {
      final raw = await file.readAsString();
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      // Ensure defaults always present
      final names = list.map((r) => r['name'] as String).toSet();
      for (final d in _defaultRoles) {
        if (!names.contains(d)) {
          list.add(_defaultEntry(d));
        }
      }
      return list;
    } catch (_) {
      return _defaultRoles.map((r) => _defaultEntry(r)).toList();
    }
  }

  Map<String, dynamic> _defaultEntry(String name) => {
    'name': name,
    'color': _defaultRoleColors[name] ?? 0xFF3B82F6,
    'access': _defaultRoleAccess[name] ?? ['home'],
  };

  /// Save roles list to file.
  Future<void> _saveRoles(List<Map<String, dynamic>> roles) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(roles), flush: true);
  }

  /// Add a new custom role.
  Future<void> addRole(String name, int color, List<String> access) async {
    final roles = await getRoles();
    // Remove existing with same name
    roles.removeWhere((r) => r['name'] == name);
    roles.add({'name': name, 'color': color, 'access': access});
    await _saveRoles(roles);
  }

  /// Update an existing role.
  Future<void> updateRole(String oldName, String newName, int color, List<String> access) async {
    final roles = await getRoles();
    final idx = roles.indexWhere((r) => r['name'] == oldName);
    if (idx == -1) return;
    roles[idx] = {'name': newName, 'color': color, 'access': access};
    // If name changed, update employees table
    if (oldName != newName) {
      roles.removeWhere((r) => r['name'] == oldName);
    }
    await _saveRoles(roles);
  }

  /// Delete a custom role. Default roles cannot be deleted.
  Future<bool> deleteRole(String name) async {
    if (_defaultRoles.contains(name)) return false;
    final roles = await getRoles();
    roles.removeWhere((r) => r['name'] == name);
    await _saveRoles(roles);
    return true;
  }

  /// Get access list for a role, with fallback to defaults.
  Future<List<String>> getAccess(String roleName) async {
    final roles = await getRoles();
    for (final r in roles) {
      if (r['name'] == roleName) {
        return (r['access'] as List).cast<String>();
      }
    }
    return _defaultRoleAccess[roleName] ?? ['home'];
  }

  /// Get role color, with fallback.
  Future<int> getColor(String roleName) async {
    final roles = await getRoles();
    for (final r in roles) {
      if (r['name'] == roleName) {
        return r['color'] as int;
      }
    }
    return _defaultRoleColors[roleName] ?? 0xFF3B82F6;
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }
}
