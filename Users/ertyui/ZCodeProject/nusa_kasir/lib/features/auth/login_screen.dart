import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/pin_keypad.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';

/// POST-SETUP login: user taps NFC or enters PIN via popup.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _nfcAvailable = false;

  @override
  void initState() {
    super.initState();
    NfcTagService.isAvailable().then((ok) { if (mounted) setState(() => _nfcAvailable = ok); });
  }

  @override
  void dispose() {
    NfcTagService.stopSession();
    super.dispose();
  }

  Future<void> _loginWithEmployeeId(int employeeId) async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final repo = AttendanceRepository(db);
      final emp = await repo.getEmployee(employeeId);
      if (emp == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _doLogin(emp);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doLogin(Employee emp) async {
    final session = EmployeeSession(
      employeeId: emp.id,
      name: emp.name,
      role: emp.role,
    );
    ref.read(employeeSessionProvider.notifier).login(session, remember: false);
    ref.read(authProvider.notifier).state = emp.role;
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted) context.go(name.isEmpty ? '/onboarding' : '/home');
  }

  Future<bool> _authFingerprint() async {
    return BiometricService.authenticate(
      reason: 'Verifikasi sidik jari untuk melanjutkan',
    );
  }

  /// Login as Owner via fingerprint — called when fingerprint auth succeeds.
  Future<void> _fingerprintLogin() async {
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final emps = await repo.getEmployees();
    final owner = emps.cast<Employee?>().firstWhere(
          (e) => e!.role == 'Owner',
          orElse: () => null,
        );
    if (owner == null || !mounted) return;

    final session = EmployeeSession(
      employeeId: owner.id, name: owner.name, role: owner.role, remember: false,
    );
    ref.read(employeeSessionProvider.notifier).login(session, remember: false);
    ref.read(authProvider.notifier).state = owner.role;
    if (mounted) context.go('/home');
  }

  /// Verify PIN directly (used by PinKeypad on login screen).
  Future<void> _verifyPin(String pin) async {
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final emps = await repo.getEmployees();
    final emp = emps.cast<Employee?>().firstWhere(
          (e) => e!.pin == pin,
          orElse: () => null,
        );
    if (emp == null) {
      if (mounted) TopToast.error(context, 'PIN salah');
      return;
    }

    final session = EmployeeSession(
      employeeId: emp.id,
      name: emp.name,
      role: emp.role,
      remember: false,
    );
    ref.read(employeeSessionProvider.notifier).login(session, remember: false);
    ref.read(authProvider.notifier).state = emp.role;
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted) context.go(name.isEmpty ? '/onboarding' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Masuk',
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 32),
            Text(
              'Masuk sebagai',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Masuk dengan PIN, fingerprint, atau NFC',
              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            ),

            // ── PIN Keypad ──────────────────────────────────────
            SizedBox(height: 24),
            PinKeypad(
              length: 6,
              showFingerprint: true,
              showNfc: _nfcAvailable,
              showCancel: false,
              onFingerprint: () async => await _authFingerprint(),
              onFingerprintSuccess: () => _fingerprintLogin(),
              onNfc: () async {
                final id = await NfcTagService.readEmployeeTag();
                if (id == null || !mounted) return null;
                await _loginWithEmployeeId(id);
                return null; // already handled, don't trigger onComplete
              },
              onComplete: (pin) async {
                setState(() => _loading = true);
                await _verifyPin(pin);
                if (mounted) setState(() => _loading = false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
