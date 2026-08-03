import 'dart:convert';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

class EmployeeSession {
  final int employeeId;
  final String name;
  final String role;
  final int? branchId;
  final DateTime savedAt;
  final bool remember;

  EmployeeSession({
    required this.employeeId,
    required this.name,
    required this.role,
    this.branchId,
    this.remember = false,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  bool get isExpired {
    if (!remember) return true;
    return DateTime.now().difference(savedAt).inHours >= 8;
  }

  /// Refresh the session timestamp to extend the 8-hour window.
  static Future<void> touch() async {
    final raw = await SecureStore.read(key: _key);
    if (raw == null) return;
    try {
      final session = EmployeeSession.fromJson(jsonDecode(raw));
      final refreshed = EmployeeSession(
        employeeId: session.employeeId,
        name: session.name,
        role: session.role,
        branchId: session.branchId,
        remember: true,
        savedAt: DateTime.now(),
      );
      await save(refreshed);
    } catch (e) {
      // Session refresh failed — user will re-login when current session expires.
      // ignore: avoid_print
      print('[EmployeeSession] Gagal refresh sesi: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'name': name,
        'role': role,
        'branchId': branchId,
        'savedAt': savedAt.toIso8601String(),
        'remember': remember,
      };

  factory EmployeeSession.fromJson(Map<String, dynamic> json) {
    return EmployeeSession(
      employeeId: json['employeeId'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      branchId: json['branchId'] as int?,
      remember: json['remember'] == true,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  static const _key = 'nusa_employee_session';

  static Future<EmployeeSession?> restore() async {
    final raw = await SecureStore.read(key: _key);
    if (raw == null) return null;
    try {
      final session = EmployeeSession.fromJson(jsonDecode(raw));
      if (session.isExpired) {
        await clear();
        return null;
      }
      return session;
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(EmployeeSession session) async {
    await SecureStore.write(
        key: _key, value: jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    await SecureStore.delete(key: _key);
  }
}
