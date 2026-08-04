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
import 'package:nusa_kasir/shared/widgets/pin_dialog.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';

/// POST-SETUP login screen.
///
/// Uses the **same** [PinDialog] as every PIN-protected action
/// (menus, attendance, settings) — lock icon, keypad, FP icon,
/// NFC hint card, and "Ingat PIN selama 8 jam" checkbox.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  Employee? _foundEmp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPin());
  }

  @override
  void dispose() {
    NfcTagService.stopSession();
    super.dispose();
  }

  Future<void> _doLogin(Employee emp, bool remember) async {
    final s = EmployeeSession(
      employeeId: emp.id, name: emp.name, role: emp.role,
    );
    ref.read(employeeSessionProvider.notifier).login(s, remember: remember);
    ref.read(authProvider.notifier).state = emp.role;
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted) context.go(name.isEmpty ? '/onboarding' : '/home');
  }

  /// Shows the unified PIN dialog. Re-shows on cancel.
  Future<void> _showPin() async {
    final result = await PinDialog.show(
      context: context,
      title: 'Masuk',
      subtitle: 'Masukkan PIN, gunakan fingerprint, atau tap NFC',
      showRemember: true,
      pinLength: 6,
      showFingerprint: true,
      showNfc: true,
      onFingerprint: () => BiometricService.authenticate(
        reason: 'Verifikasi sidik jari untuk melanjutkan',
      ),
      onNfc: () async {
        final id = await NfcTagService.readEmployeeTag();
        return id?.toString();
      },
      onVerify: (pin) async {
        final db = ref.read(databaseProvider);
        final repo = AttendanceRepository(db);
        final emps = await repo.getEmployees();
        _foundEmp = emps.cast<Employee?>().firstWhere(
              (e) => e!.pin == pin, orElse: () => null);
        return _foundEmp != null;
      },
    );

    if (result == null) {
      // User dismissed — re-show
      _showPin();
      return;
    }
    if (!result.success) {
      _showPin();
      return;
    }

    // NFC login
    if (result.nfcEmployeeId != null) {
      final db = ref.read(databaseProvider);
      final repo = AttendanceRepository(db);
      final emp = await repo.getEmployee(result.nfcEmployeeId!);
      if (emp != null) { await _doLogin(emp, result.remember); return; }
      _showPin();
      return;
    }

    // PIN login
    if (_foundEmp != null) {
      await _doLogin(_foundEmp!, result.remember);
      return;
    }

    // Fingerprint → login as Owner
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final emps = await repo.getEmployees();
    final owner = emps.cast<Employee?>().firstWhere(
          (e) => e!.role == 'Owner', orElse: () => null);
    if (owner != null) {
      await _doLogin(owner, result.remember);
      return;
    }

    _showPin();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Masuk',
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.store_rounded,
                    color: NusaConfig.activePrimary, size: 36),
              ),
              const SizedBox(height: 20),
              Text('NUSA Kasir',
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                  )),
              const SizedBox(height: 6),
              Text(NusaConfig.appSubtitle,
                  textAlign: TextAlign.center,
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
    );
  }
}
