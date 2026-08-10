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
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';

/// Full-screen PIN login — card-with-depth style (v1.7.17 design).
/// Shows the keypad with FP icon; fingerprint does NOT auto-skip the pinpad.
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
      });
      // Dots + shake handled by PinKeypad: passing a fresh error triggers
      // didUpdateWidget → haptic + shake + reset dots to 0.
      _keypadKey.currentState?.clear();
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
    await _doLogin(owner, remember: _remember);
  }

  void _clearError() {
    if (mounted) setState(() => _error = null);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ── Lock icon (gradient circle, depth) ──
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [NusaConfig.activePrimary, NusaConfig.activeDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.lock_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 32),

                // ── Card container (depth) ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Title
                      Text('Masuk',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : Color(0xFF151717),
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

                      // ── Keypad ──
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

                      // ── Remember checkbox (rounded) ──
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GestureDetector(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _remember
                                        ? NusaConfig.activePrimary
                                        : (isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor),
                                    width: 2,
                                  ),
                                  color: _remember
                                      ? NusaConfig.activePrimary
                                      : Colors.transparent,
                                ),
                                child: _remember
                                    ? Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
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
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                // Version text
                Text('v${NusaConfig.appVersion}+${NusaConfig.appBuildNumber}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
