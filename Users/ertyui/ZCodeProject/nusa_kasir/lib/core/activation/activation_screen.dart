import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/google_auth_service.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/activation/activation_key.dart';
import 'package:nusa_kasir/core/activation/activation_public_key.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/pin_keypad.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Activation & auth screen with 4 branches:
///
///   1. Welcome Screen — user memilih "Masuk dengan Google" secara manual
///   2. Setelah Google ID didapat:
///      a. Belum aktivasi key → minta input key aktivasi
///         → ada tombol "Belum punya key?" → buka landing page
///      b. Sudah aktivasi key → minta PIN untuk sign in
///   3. PIN → cek role → auto check-in attendance → dashboard
///   4. Restore prompt for cloud backup
///
/// Tidak ada auto-trigger Google sign-in — user memilih sendiri.
class ActivationScreen extends ConsumerStatefulWidget {
  ActivationScreen({super.key});
  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  // Google Sign-In state
  bool _googleLoading = false;
  String? _googleError;
  String? _googleId;

  // Activation key input (new user)
  final _keyCtrl = TextEditingController();
  bool _keyLoading = false;
  String? _keyError;

  // PIN input (returning user)
  bool _pinLoading = false;
  String? _pinError;

  // Screen state: 'welcome' | 'google_loading' | 'pin' | 'key'
  String _screen = 'welcome';

  @override
  void initState() {
    super.initState();
    _initAutoSignIn();
  }

  /// Auto-launch Google Sign-In silently if already activated.
  /// Skips welcome screen — user goes directly to PIN input.
  Future<void> _initAutoSignIn() async {
    final activated = (await SecureStore.getActivation()) != null;
    if (!activated) return;
    final linked = await GoogleAuthService.isLinked();
    if (!linked) return;
    if (!mounted) return;
    _startGoogleSignIn();
  }

  Future<void> _startGoogleSignIn() async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _googleError = null;
      _screen = 'google_loading';
    });
    try {
      final googleAuth = GoogleAuthService();
      final googleId = await googleAuth.signIn();
      if (googleId == null) {
        setState(() {
          _googleLoading = false;
          _googleError = 'Login Google diperlukan untuk menggunakan NUSA Kasir';
          _screen = 'welcome';
        });
        return;
      }
      _googleId = googleId;
      await GoogleAuthService.ensureStored(googleId);

      // Show "checking license" state — keep spinner active during cloud call
      setState(() => _googleLoading = false);
      if (mounted) await _checkLicenseStatus(googleId);
    } catch (e) {
      setState(() {
        _googleLoading = false;
        _googleError = 'Gagal login Google: $e';
        _screen = 'welcome';
      });
    }
  }

  Future<void> _openLandingPage() async {
    final uri = Uri.parse(NusaConfig.landingPageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Check if employees exist. If not, try cloud restore first, then redirect to /setup.
  /// If employees exist, directly show PIN dialog.
  Future<void> _goToPinOrSetup() async {
    try {
      final db = ref.read(databaseProvider);
      final repo = AttendanceRepository(db);
      final emps = await repo.getEmployees();
      if (emps.isEmpty) {
        // No employees — try cloud auto-restore first
        final restored = await _autoRestoreIfNeeded();
        if (restored) return; // app will restart
        // No backup or restore failed — setup from scratch
        if (mounted) context.go('/setup');
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _screen = 'pin');
  }

  /// Auto-restore cloud backup if cloud is newer than local AND belongs to this product variant.
  /// Uses Google user ID for decryption — no activation key needed.
  Future<bool> _autoRestoreIfNeeded() async {
    final repo = ref.read(activationRepoProvider);
    final hasBak = await repo.hasBackup();
    if (!hasBak) return false;

    // Compare timestamps — only restore if cloud is newer
    final localTime = await SecureStore.getLastBackupTime();
    final cloudTime = await repo.getBackupTimestamp();
    if (cloudTime != null && localTime != null && !cloudTime.isAfter(localTime)) {
      return false; // local is same or newer
    }

    // Only restore if local is truly fresh (no local backup timestamp at all)
    // AND no employees exist. This prevents cross-variant data leakage:
    // a fresh install of a different variant should NOT pull the old variant's backup.
    // The backup path is already namespaced per productId, but for safety we also
    // guard against restoring when employees already exist locally.
    if (localTime != null) {
      return false; // local has its own backup history, don't auto-restore
    }

    final ok = await repo.restoreFromCloud();
    if (ok) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.cloud_download_outlined, color: NusaConfig.activePrimary, size: 28),
                SizedBox(width: 10),
                Text('Menyinkronkan Data', style: TextStyle(fontSize: 17)),
              ],
            ),
            content: Text(
              'Data toko ditemukan di cloud.\nSedang dipulihkan...',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => SystemNavigator.pop(),
                child: Text('Buka Ulang'),
              ),
            ],
          ),
        );
      }
      return true;
    }
    return false;
  }

  /// Check if this Google account already has an activated license.
  Future<void> _checkLicenseStatus(String googleUserId) async {
    // First check local storage
    final isActivated = await ref.read(activationRepoProvider).isActivated;

    if (isActivated) {
      _goToPinOrSetup();
      return;
    }

    // Try cloud check to recover license key on fresh installs
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'register_activation',
        body: {'googleUserId': googleUserId, 'product': NusaConfig.productId},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data?['has_license'] == true) {
        // Check if trial expired
        final isExpired = data!['is_expired'] == true;
        
        if (isExpired) {
          setState(() {
            _googleLoading = false;
            _googleError = 'Masa trial Anda telah habis.\nBeli lisensi seumur hidup untuk melanjutkan.';
            _screen = 'trial_expired';
          });
          return;
        }

        // Verify the returned key is valid locally before accepting it.
        // This guards against cross-variant license leaks where the edge
        // function returns a key meant for a different product variant.
        final key = data['key'] as String;
        final keyValid = await ActivationKey.verify(
          key, nusaActivationPublicKey,
        );
        if (!keyValid) {
          if (mounted) {
            setState(() {
              _googleLoading = false;
              _googleError = 'Lisensi tidak valid untuk aplikasi ini.';
              _screen = 'key';
            });
          }
          return;
        }

        await SecureStore.saveActivation(key);
        _goToPinOrSetup();
        return;
      }
    } catch (_) {
      // Offline / Supabase error — show key input so user can enter manually.
      // Never bypass activation — user must have a valid key.
      if (mounted) setState(() => _screen = 'key');
      return;
    }

    setState(() => _screen = 'key');
  }


  // ── Key Activation Submit ──────────────────────────────────────────

  Future<void> _submitKey() async {
    final key = _keyCtrl.text.trim().toUpperCase();
    if (key.isEmpty) {
      setState(() => _keyError = 'Masukkan key aktivasi');
      return;
    }

    setState(() {
      _keyLoading = true;
      _keyError = null;
    });

    final googleId = _googleId ?? await GoogleAuthService.getStoredUserId();
    if (googleId == null) {
      setState(() {
        _keyLoading = false;
        _keyError = 'Login Google dulu';
      });
      return;
    }

    final repo = ref.read(activationRepoProvider);
    final r = await repo.activate(key, googleId);
    setState(() => _keyLoading = false);

    if (!r.ok) {
      setState(() => _keyError = r.error);
      return;
    }

    // Activation success → go to setup
    if (mounted) {
      TopToast.success(context, 'Aktivasi berhasil! 🎉');
      context.go('/setup');
    }
  }

  // ── Scan / NFC ─────────────────────────────────────────────────────

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Scan Key Aktivasi')),
        body: MobileScanner(
          onDetect: (c) {
            final raw = c.barcodes.firstOrNull?.rawValue;
            if (raw != null) Navigator.pop(context, raw);
          },
        ),
      ),
    ));
    if (code != null) {
      _keyCtrl.text = code;
      await _submitKey();
    }
  }

  Future<void> _tapNfc() async {
    if (!await NfcManager.instance.isAvailable()) {
      setState(() => _keyError = 'NFC tidak tersedia');
      return;
    }
    await NfcManager.instance.startSession(onDiscovered: (tag) async {
      final ndef = Ndef.from(tag);
      final msg = ndef?.cachedMessage;
      String? key;
      if (msg != null) {
        for (final record in msg.records) {
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.type.isNotEmpty &&
              record.type.first == 0x54) {
            final payload = record.payload;
            if (payload.isNotEmpty) {
              final langLen = payload.first & 0x3F;
              key = String.fromCharCodes(payload.sublist(1 + langLen));
            }
          }
        }
      }
      await NfcManager.instance.stopSession();
      if (key != null) {
        _keyCtrl.text = key;
        await _submitKey();
      }
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (_screen) {
      case 'welcome':
        return _buildWelcomeScreen(isDark);
      case 'google_loading':
        return _buildGoogleLoadingScreen(isDark);
      case 'trial_expired':
        return _buildTrialExpiredScreen(isDark);
      case 'pin':
        return _buildPinScreen(isDark);
      case 'key':
        return _buildKeyScreen(isDark);
      default:
        return _buildWelcomeScreen(isDark);
    }
  }

  // ── Welcome Screen ──────────────────────────────────────────────────

  Widget _buildWelcomeScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                // Logo + Brand
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [NusaConfig.activePrimary, NusaConfig.activeDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.store_rounded, color: Colors.white, size: 36),
                ),
                SizedBox(height: 20),
                Text('NUSA', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: NusaConfig.activePrimary, fontWeight: FontWeight.w800, letterSpacing: -1)),
                SizedBox(height: 4),
                Text(NusaConfig.appSubtitle,
                  style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                SizedBox(height: 36),

                // ── Card ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(28),
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
                      Text('Masuk ke NUSA',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: isDark ? NusaConfig.darkTextPrimary : Color(0xFF151717),
                        )),
                      SizedBox(height: 4),
                      Text('Gunakan akun Google untuk melanjutkan',
                        style: TextStyle(fontSize: 13,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                      SizedBox(height: 24),

                      // Google Sign-In button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _startGoogleSignIn,
                          icon: Image.asset(
                            'assets/icons/google_logo.png',
                            width: 20, height: 20,
                            errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, size: 24, color: Color(0xFF4285F4)),
                          ),
                          label: Text('Masuk dengan Google',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? NusaConfig.darkTextPrimary : Color(0xFF151717),
                            side: BorderSide(color: isDark ? NusaConfig.darkBorder : Color(0xFFEDEDEF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),

                      // Error message
                      if (_googleError != null) ...[
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, size: 18,
                                color: NusaConfig.activePrimary.withValues(alpha: 0.7)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(_googleError!,
                                  style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 32),
                Text('v${NusaConfig.appVersion}+${NusaConfig.appBuildNumber}',
                  style: TextStyle(fontSize: 11,
                    color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Google Sign-In Loading Screen ─────────────────────────────────────

  Widget _buildGoogleLoadingScreen(bool isDark) {
    final statusText = _googleLoading
        ? 'Menghubungkan ke Google...'
        : _googleError != null
            ? null
            : 'Memeriksa lisensi...';

    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(height: 60),
              if (_googleError != null) ...[
                // Card error state
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 40,
                        color: NusaConfig.activePrimary.withValues(alpha: 0.7)),
                      SizedBox(height: 12),
                      Text(_googleError!, textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, fontSize: 14)),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startGoogleSignIn,
                          icon: Icon(Icons.login, size: 20),
                          label: Text('Login Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF151717),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BouncingDots(),
                    SizedBox(height: 16),
                    Text(
                      statusText!,
                      style: TextStyle(
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Trial Expired Screen ─────────────────────────────────────────────

  Widget _buildTrialExpiredScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                SizedBox(height: 40),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.shade100,
                  ),
                  child: Icon(Icons.timer_off_rounded, size: 36, color: Colors.amber.shade700),
                ),
                SizedBox(height: 20),
                Text('Masa Trial Habis', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                SizedBox(height: 28),
                // Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _googleError ?? 'Masa trial 30 hari Anda telah berakhir.\nBeli lisensi seumur hidup untuk melanjutkan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.6,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openLandingPage,
                          icon: Icon(Icons.shopping_bag_outlined, size: 18),
                          label: Text('Beli Lisensi (Rp 249K)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NusaConfig.activePrimary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _startGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                            side: BorderSide(color: Color(0xFFEDEDEF)),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Ganti Akun Google'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── PIN Screen (returning user) ────────────────────────────────────

  Widget _buildPinScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              SizedBox(height: 40),
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
              SizedBox(height: 32),
              // Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text('Masuk', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: isDark ? NusaConfig.darkTextPrimary : Color(0xFF151717))),
                    SizedBox(height: 4),
                    Text('Masukkan PIN untuk melanjutkan',
                      style: TextStyle(fontSize: 13,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    SizedBox(height: 16),
                    PinKeypad(
                      length: 6,
                      showFingerprint: true,
                      showNfc: true,
                      showCancel: false,
                      onFingerprint: () async => await _authFingerprint(),
                      onFingerprintSuccess: () => _fingerprintLogin(),
                      onNfc: () async {
                        final id = await NfcTagService.readEmployeeTag();
                        if (id == null || !mounted) return null;
                        // NFC login: lookup employee, create session, navigate
                        final db = ref.read(databaseProvider);
                        final repo = AttendanceRepository(db);
                        final emp = await repo.getEmployee(id);
                        if (emp == null || !mounted) return null;
                        final session = EmployeeSession(
                          employeeId: emp.id, name: emp.name, role: emp.role, remember: false,
                        );
                        ref.read(employeeSessionProvider.notifier).login(session, remember: false);
                        ref.read(authProvider.notifier).state = emp.role;
                        try { await AttendanceRepository(ref.read(databaseProvider)).checkIn(emp.id); } catch (_) {}
                        final storeName = await SettingsRepository(ref.read(databaseProvider)).getStoreName();
                        if (mounted) context.go(storeName.isEmpty ? '/setup' : '/home');
                        return null; // already handled
                      },
                      onComplete: (pin) async {
                        setState(() => _pinLoading = true);
                        final db = ref.read(databaseProvider);
                        final repo = AttendanceRepository(db);
                        final emps = await repo.getEmployees();
                        final emp = emps.cast<Employee?>().firstWhere(
                              (e) => e!.pin == pin,
                              orElse: () => null,
                            );
                        if (emp != null) {
                          if (mounted) setState(() => _pinLoading = false);
                          // Create session
                          final session = EmployeeSession(
                            employeeId: emp.id,
                            name: emp.name,
                            role: emp.role,
                            remember: false,
                          );
                          ref.read(employeeSessionProvider.notifier).login(session, remember: false);
                          ref.read(authProvider.notifier).state = emp.role;

                          // Auto check-in
                          try {
                            final db = ref.read(databaseProvider);
                            final repo = AttendanceRepository(db);
                            await repo.checkIn(emp.id);
                          } catch (_) {}

                          final settingsRepo = SettingsRepository(ref.read(databaseProvider));
                          final storeName = await settingsRepo.getStoreName();
                          if (mounted) context.go(storeName.isEmpty ? '/setup' : '/home');
                        } else {
                          if (mounted) setState(() {
                            _pinLoading = false;
                            _pinError = 'PIN salah';
                          });
                        }
                      },
                    ),
                    if (_pinError != null) ...[
                      SizedBox(height: 8),
                      Text(_pinError!,
                          style:  TextStyle(color: NusaConfig.activePrimary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: _startGoogleSignIn,
                child: Text('Ganti akun Google', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _authFingerprint() async {
    return BiometricService.authenticate(
      reason: 'Verifikasi sidik jari untuk melanjutkan',
    );
  }

  /// Login as Owner via fingerprint — bypass PIN.
  Future<void> _fingerprintLogin() async {
    try {
      final db = ref.read(databaseProvider);
      final repo = AttendanceRepository(db);
      final emps = await repo.getEmployees();
      final owner = emps.cast<Employee?>().firstWhere(
            (e) => e!.role == 'Owner',
            orElse: () => null,
          );
      if (owner == null || !mounted) return;

      final session = EmployeeSession(
        employeeId: owner.id,
        name: owner.name,
        role: owner.role,
        remember: false,
      );
      ref.read(employeeSessionProvider.notifier).login(session, remember: false);
      ref.read(authProvider.notifier).state = owner.role;

      try { await AttendanceRepository(db).checkIn(owner.id); } catch (_) {}

      final storeName = await SettingsRepository(db).getStoreName();
      if (mounted) context.go(storeName.isEmpty ? '/setup' : '/home');
    } catch (_) {
      // Fingerprint succeeded but employee lookup failed — fall through
    }
  }

  // ── Key Activation Screen (new user) ───────────────────────────────

  Widget _buildKeyScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              SizedBox(height: 40),
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
                child: Icon(Icons.vpn_key_rounded, color: Colors.white, size: 34),
              ),
              SizedBox(height: 32),
              // Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text('Aktivasi NUSA', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: isDark ? NusaConfig.darkTextPrimary : Color(0xFF151717))),
                    SizedBox(height: 4),
                    Text('Masukkan key aktivasi dari seller',
                      style: TextStyle(fontSize: 13,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    SizedBox(height: 24),
                    // Key input
                    TextField(
                      controller: _keyCtrl,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontFamily: 'monospace', letterSpacing: 0.5),
                      decoration: InputDecoration(
                        hintText: 'NUSA-XXXX-XXXX-...',
                        hintStyle: TextStyle(fontSize: 13,
                          color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                        filled: true,
                        fillColor: isDark ? NusaConfig.darkBackground : Color(0xFFF9FAFB),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFFECEDEC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFFECEDEC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFF2D79F3), width: 1.5),
                        ),
                      ),
                    ),
                    if (_keyError != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(_keyError!,
                          style:  TextStyle(color: NusaConfig.activePrimary, fontSize: 13)),
                      ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _keyLoading ? null : _submitKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF151717),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _keyLoading ? 'Memproses...' : 'Aktivasi',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              // Scan / NFC
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _scan,
                    icon: Icon(Icons.qr_code_scanner, size: 18),
                    label: Text('Scan', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: _tapNfc,
                    icon: Icon(Icons.nfc, size: 18),
                    label: Text('NFC', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  ),
                ],
              ),
              SizedBox(height: 4),
              TextButton(
                onPressed: _openLandingPage,
                child: Text('Belum punya key aktivasi?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF2D79F3), fontWeight: FontWeight.w500)),
              ),
              TextButton(
                onPressed: _startGoogleSignIn,
                child: Text('Ganti akun Google', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouncing 3-dot loading indicator — matches splash screen rhythm.
class _BouncingDots extends StatefulWidget {
  final double size;
  final double spacing;
  _BouncingDots({this.size = 10, this.spacing = 5});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (_) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600),
      );
    });
    _anims = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(
          parent: _ctrls[i],
          curve: Interval(0, 0.5, curve: Curves.easeOut),
        ),
      );
    });
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () => _loop(i));
    }
  }

  void _loop(int i) {
    if (!mounted) return;
    _ctrls[i].forward().then((_) => _ctrls[i].reverse()).then((_) => _loop(i));
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return _AnimatedBuilder(
          animation: _anims[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _anims[i].value),
              child: child,
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            margin: EdgeInsets.symmetric(horizontal: widget.spacing),
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

// Reuse AnimatedBuilder from splash screen
class _AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  _AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => builder(context, child);
}
