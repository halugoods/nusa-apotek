import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';

/// Holds the currently authenticated employee session (null = not logged in).
final employeeSessionProvider =
    StateNotifierProvider<EmployeeSessionNotifier, EmployeeSession?>(
        (ref) => EmployeeSessionNotifier());

class EmployeeSessionNotifier extends StateNotifier<EmployeeSession?> {
  EmployeeSessionNotifier() : super(null);

  /// Try to restore a remembered session from secure storage.
  Future<void> restore() async {
    final session = await EmployeeSession.restore();
    if (session != null && !session.isExpired) {
      state = session;
    }
  }

  void login(EmployeeSession session, {bool remember = false}) {
    final s = EmployeeSession(
      employeeId: session.employeeId,
      name: session.name,
      role: session.role,
      branchId: session.branchId,
      remember: remember,
      savedAt: DateTime.now(),
    );
    state = s;
    if (remember) {
      EmployeeSession.save(s);
    }
  }

  /// Refresh the persisted session timestamp so the 8h window stays alive.
  Future<void> touch() => EmployeeSession.touch();

  void logout() {
    state = null;
    EmployeeSession.clear();
  }
}
