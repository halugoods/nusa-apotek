import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/pin_keypad.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';
import 'package:nusa_kasir/shared/widgets/restore_backup_flow.dart';
import 'package:nusa_kasir/core/services/google_auth_service.dart';
import 'package:nusa_kasir/core/utils/permission_helper.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Full-screen PIN login — card-with-depth style (v1.7.17 design).
/// Shows the keypad with FP icon; fingerprint does NOT auto-skip the pinpad.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _nfcAvailable = false;
  bool _remember = false;
  String? _error;
  // v2.2.43: panjang PIN dari settings (4/6) — jangan hardcode 6, supaya user
  // yang PIN-nya 4 digit tidak stuck selamanya.
  int _pinLength = 6;
  final _keypadKey = GlobalKey<PinKeypadState>();

  @override
  void initState() {
    super.initState();
    // v2.2.57+116: izin pertama kali juga diminta di layar PIN login — menutup
    // jalur user yang sudah aktivasi tapi flag `nusa_permissions_asked` belum
    // pernah diset (update dari versi lama). Helper ini aman: sekali jalan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestFirstInstallPermissions();
    });
    NfcTagService.isAvailable().then((ok) {
      if (mounted) setState(() => _nfcAvailable = ok);
    });
    ref.read(settingsRepoProvider).getPinLength().then((len) {
      if (mounted && len != _pinLength) setState(() => _pinLength = len);
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
    // v2.2.47: pulihkan file foto produk dari BASE64 (kolom DB) setelah login.
    // hydrateImages() di main() hanya jalan sekali saat cold start; kalau user
    // logout→login lagi (app tidak restart) atau restore cloud baru selesai,
    // path file lokal bisa hilang walau base64 masih ada — sini menulis ulang
    // supaya foto produk tampil di list/grid/POS.
    try {
      final db = ref.read(databaseProvider);
      await ProductRepository(db).hydrateImages();
    } catch (_) {}
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted) context.go(name.isEmpty ? '/onboarding' : '/home');
  }

  Future<void> _verifyPin(String pin) async {
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final List<Employee> emps;
    try {
      emps = await repo.getEmployees();
    } catch (e) {
      // DB rusak / query gagal — jangan bilang "PIN salah", jangan stuck.
      // Coba pulihkan data dari cloud DULU; kalau tidak ada backup, setup
      // baru jadi pilihan terakhir.
      debugPrint('[Login] getEmployees error: $e');
      if (mounted) {
        setState(() => _error = 'Data karyawan gagal dibaca. Mencoba memulihkan dari cloud...');
        _keypadKey.currentState?.clear();
        await _tryRestoreOrSetup();
      }
      return;
    }
    if (emps.isEmpty) {
      // Tidak ada karyawan/owner → kemungkinan besar varian ini belum pernah
      // dipakai. User punya data di cloud (akun Google) → TANYAKAN restore,
      // bukan langsung suruh setup dari nol.
      debugPrint('[Login] No employees found — trying cloud restore first');
      final restored = await RestoreBackupFlow.runIfNeeded(ref, context);
      if (restored) return; // app restart
      if (mounted && context.mounted) context.go('/setup');
      return;
    }
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
    final List<Employee> emps;
    try {
      emps = await repo.getEmployees();
    } catch (e) {
      debugPrint('[Login] fingerprint getEmployees error: $e');
      if (mounted) await _tryRestoreOrSetup();
      return;
    }
    if (emps.isEmpty) {
      final restored = await RestoreBackupFlow.runIfNeeded(ref, context);
      if (restored) return; // app restart
      if (mounted && context.mounted) context.go('/setup');
      return;
    }
    final owner = emps.cast<Employee?>().firstWhere(
          (e) => e!.role == 'Owner', orElse: () => null);
    if (owner == null || !mounted) return;
    await _doLogin(owner, remember: _remember);
  }

  /// Login via barcode id-card (B8) — jalur auth ke-4 setelah PIN/FP/NFC.
  /// Resolver dipanggil dengan code hasil scan HID; jika barcode cocok dengan
  /// karyawan aktif → langsung _doLogin.
  Future<void> _barcodeLogin(String code) async {
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final norm = ProductRepository.normalizeBarcode(code);
    if (norm.isEmpty) return;
    final emp = await repo.getByBarcode(norm, status: 'Aktif');
    if (emp == null) {
      if (mounted) setState(() => _error = 'Barcode tidak terdaftar');
      _keypadKey.currentState?.clear();
      return;
    }
    await _doLogin(emp, remember: _remember);
  }

  /// DB karyawan tidak terbaca / kosong: pulihkan dari cloud dulu.
  /// Setup hanya dijalankan kalau memang TIDAK ADA backup cloud.
  Future<void> _tryRestoreOrSetup() async {
    final restored = await RestoreBackupFlow.runIfNeeded(ref, context);
    if (restored) return; // app restart
    if (!mounted || !context.mounted) return;
    // Tidak ada backup cloud — baru saatnya setup dari nol.
    context.go('/setup');
  }

  void _clearError() {
    if (mounted) setState(() => _error = null);
  }

  /// "Lupa PIN?" — v2.2.43. User yang ter-restore data dengan PIN beda / lupa
  /// PIN tidak boleh stuck selamanya. Alur:
  /// 1. Dialog konfirmasi.
  /// 2. Google re-auth (sign-in interaktif) — harus akun yang SAMA dengan
  ///    `nusa_google_user_id` (pemilik akun → Owner).
  /// 3. Set PIN baru (min 4 digit) untuk karyawan Owner → auto login.
  Future<void> _forgotPin() async {
    // 1. Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Lupa PIN?'),
        content: const Text(
          'Untuk mengganti PIN, Anda harus login ulang dengan akun Google '
          'yang sama dengan akun toko (Owner). Lanjutkan?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NusaConfig.activePrimary,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // 2. Google re-auth — harus SAMA dengan stored user id (pemilik akun).
    setState(() => _error = 'Verifikasi akun Google…');
    final currentUid = await GoogleAuthService.getStoredUserId();
    final newUid = await GoogleAuthService().signIn();
    if (!mounted) return;
    if (newUid == null) {
      setState(() {
        _error = 'Verifikasi dibatalkan. PIN tidak diubah.';
        _keypadKey.currentState?.clear();
      });
      return;
    }
    if (currentUid != null && newUid != currentUid) {
      setState(() {
        _error = 'Akun Google berbeda. Gunakan akun pemilik toko.';
        _keypadKey.currentState?.clear();
      });
      return;
    }
    // Pastikan UID tersimpan (fresh install di atas data lama).
    await GoogleAuthService.ensureStored(newUid);

    // 3. Ambil karyawan Owner/Manager lalu set PIN baru.
    final db = ref.read(databaseProvider);
    final repo = AttendanceRepository(db);
    final emps = await repo.getEmployees();
    if (!mounted) return;
    final owner = emps.cast<Employee?>().firstWhere(
          (e) => e!.role == 'Owner' || e!.role == 'Manager',
          orElse: () => null,
        );
    if (owner == null) {
      setState(() => _error = 'Tidak ada akun Owner. Hubungi dukungan.');
      _keypadKey.currentState?.clear();
      return;
    }
    final newPin = await _promptNewPin();
    if (!mounted || newPin == null) return;
    await repo.updateEmployee(
      id: owner.id,
      name: owner.name,
      pin: newPin,
      role: owner.role,
      branchId: owner.branchId,
      phone: owner.phone,
      photoPath: owner.photoPath,
      baseSalary: owner.baseSalary,
      startDate: owner.startDate,
      status: owner.status,
      workStart: owner.workStart,
      workEnd: owner.workEnd,
      requiresCashOpen: owner.requiresCashOpen,
      requiresCashClose: owner.requiresCashClose,
    );
    if (!mounted) return;
    TopToast.success(context, 'PIN berhasil diganti');
    await _doLogin(owner, remember: false);
  }

  /// Dialog input PIN baru (min 4 digit, numeric). Return null bila batal.
  Future<String?> _promptNewPin() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('PIN Baru'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan PIN baru (4–6 digit)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NusaConfig.activePrimary,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.length < 4 || !RegExp(r'^\d+$').hasMatch(v)) {
                return; // invalid — keep dialog open
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
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
                      Text('Masukkan PIN, gunakan biometrik, atau tap NFC',
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
                        length: _pinLength,
                        error: _error,
                        showFingerprint: true,
                        showNfc: _nfcAvailable,
                        showBarcode: true,
                        showCancel: false,
                        onFingerprint: () => BiometricService.authenticate(
                          reason: 'Verifikasi biometrik untuk melanjutkan',
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
                        onBarcode: (code) async {
                          await _barcodeLogin(code);
                          return null;
                        },
                        onComplete: (pin) async {
                          await _verifyPin(pin);
                        },
                        onChanged: (_) {
                          if (_error != null) _clearError();
                        },
                      ),

                      // ── Lupa PIN? (v2.2.43) ──
                      // User yang data cloud-nya ter-restore dengan PIN beda
                      // (atau lupa PIN) TIDAK boleh stuck selamanya. Verifikasi
                      // Google re-auth → pemilik akun → set PIN baru.
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton(
                          onPressed: _forgotPin,
                          style: TextButton.styleFrom(
                            foregroundColor: NusaConfig.activePrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Lupa PIN?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
