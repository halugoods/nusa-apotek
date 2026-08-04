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
import 'package:nusa_kasir/shared/widgets/pin_keypad.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';

/// Full-screen PIN login — same visual style as [PinDialog] but embedded
/// directly in the screen body (not a popup).  Lock icon, keypad, FP icon,
/// NFC hint card, and "Ingat PIN selama 8 jam" checkbox.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _nfcAvailable = false;
  bool _remember = false;
  String? _error;
  final _keypadKey = GlobalKey<PinKeypadState>();

  @override
  void initState() {
    super.initState();
    NfcTagService.isAvailable().then((ok) {
      if (mounted) setState(() => _nfcAvailable = ok);
    });
  }

  @override
  void dispose() {
    NfcTagService.stopSession();
    super.dispose();
  }

  // ── Login helpers ────────────────────────────────────────────

  Future<void> _doLogin(Employee emp, {bool remember = false}) async {
    final s = EmployeeSession(
      employeeId: emp.id, name: emp.name, role: emp.role);
    ref.read(employeeSessionProvider.notifier).login(s, remember: remember);
    ref.read(authProvider.notifier).state = emp.role;
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted) context.go(name.isEmpty ? '/onboarding' : '/home');
  }

  Future<void> _verifyPin(String pin) async {
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final emps = await repo.getEmployees();
    final emp = emps.cast<Employee?>().firstWhere(
          (e) => e!.pin == pin, orElse: () => null);
    if (emp == null) {
      setState(() {
        _error = 'PIN salah';
        _keypadKey.currentState?.clear();
      });
      return;
    }
    await _doLogin(emp, remember: _remember);
  }

  /// Called AFTER biometric already passed (onFingerprint returned true).
  Future<void> _fingerprintLogin() async {
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final emps = await repo.getEmployees();
    final owner = emps.cast<Employee?>().firstWhere(
          (e) => e!.role == 'Owner', orElse: () => null);
    if (owner == null || !mounted) return;
    // remember=false so dashboard doesn't re-prompt biometric
    await _doLogin(owner, remember: false);
  }

  /// Clean the PIN input after an error dismiss timeout.
  void _clearError() {
    if (mounted) setState(() => _error = null);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Masuk',
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),

            // ── Lock icon ──
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline,
                  color: NusaConfig.activePrimary, size: 26),
            ),
            const SizedBox(height: 14),

            // ── Title ──
            Text('Masuk',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                )),
            const SizedBox(height: 4),
            Text('Masukkan PIN, gunakan fingerprint, atau tap NFC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                )),
            const SizedBox(height: 20),

            // ── Keypad (same PinKeypad widget used in PinDialog) ──
            PinKeypad(
              key: _keypadKey,
              length: 6,
              error: _error,
              showFingerprint: true,
              showNfc: _nfcAvailable,
              showCancel: false,
              onFingerprint: () => BiometricService.authenticate(
                reason: 'Verifikasi sidik jari untuk melanjutkan',
              ),
              onFingerprintSuccess: _fingerprintLogin,
              onNfc: () async {
                final id = await NfcTagService.readEmployeeTag();
                if (id == null || !mounted) return null;
                final db = ref.read(databaseProvider);
                final repo = AttendanceRepository(db);
                final emp = await repo.getEmployee(id);
                if (emp != null && mounted) {
                  await _doLogin(emp, remember: _remember);
                }
                return null;
              },
              onComplete: (pin) async {
                setState(() => _loading = true);
                await _verifyPin(pin);
                if (mounted) setState(() => _loading = false);
              },
              onChanged: (_) {
                if (_error != null) _clearError();
              },
            ),

            // ── Remember checkbox ──
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: GestureDetector(
                onTap: () => setState(() => _remember = !_remember),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22, height: 22,
                      child: Checkbox(
                        value: _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? false),
                        activeColor: NusaConfig.activePrimary,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Ingat PIN selama 8 jam',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
