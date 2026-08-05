import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';

/// Post-activation setup: store name, owner name, owner PIN.
///
/// Polished onboarding UI — not a plain form.
class SetupScreen extends ConsumerStatefulWidget {
  SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _storeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _storeCtrl.dispose();
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = _storeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (store.isEmpty || name.isEmpty || pin.isEmpty) {
      setState(() => _error = 'Semua field harus diisi');
      return;
    }
    if (pin.length < 4 || pin.length > 6) {
      setState(() => _error = 'PIN harus 4–6 digit angka');
      return;
    }
    if (int.tryParse(pin) == null) {
      setState(() => _error = 'PIN hanya boleh angka');
      return;
    }

    setState(() => _loading = true);

    try {
      final db = ref.read(databaseProvider);
      // Save store name
      await ref.read(settingsRepoProvider).setStoreName(store);
      // Create Owner employee
      final employeeId = await AttendanceRepository(db).addEmployee(
        name: name,
        pin: pin,
        role: 'Owner',
      );
      // Create session so Owner is already logged in on dashboard
      final session = EmployeeSession(
        employeeId: employeeId,
        name: name,
        role: 'Owner',
        remember: true,
      );
      ref.read(employeeSessionProvider.notifier).login(session, remember: true);
      ref.read(authProvider.notifier).state = 'Owner';

      // Auto check-in so Owner arrives at dashboard ready to use all features
      await AttendanceRepository(db).checkIn(employeeId);

      // Auto-upload backup ke cloud setelah setup selesai (background)
      try {
        final activationRepo = ref.read(activationRepoProvider);
        await activationRepo.uploadBackupNow(
          storeName: store,
          ownerName: name,
        );
      } catch (_) {}

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              NusaConfig.activePrimary,
              NusaConfig.activeDark,
              isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor,
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 32),

                  // Hero icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Brand + welcome
                  Text(
                    'NUSA',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Atur tokomu dulu, yuk!',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 40),

                  // Form card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? NusaConfig.darkSurface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama Usaha
                        _sectionLabel('Nama Usaha', isDark),
                        SizedBox(height: 8),
                        _buildInput(
                          controller: _storeCtrl,
                          hint: 'contoh: Toko Berkah Jaya',
                          icon: Icons.store_outlined,
                          isDark: isDark,
                        ),
                        SizedBox(height: 20),

                        // Nama Pemilik
                        _sectionLabel('Nama Pemilik', isDark),
                        SizedBox(height: 8),
                        _buildInput(
                          controller: _nameCtrl,
                          hint: 'Nama lengkap kamu',
                          icon: Icons.person_outline,
                          isDark: isDark,
                        ),
                        SizedBox(height: 20),

                        // PIN Owner
                        _sectionLabel('PIN Owner (4–6 digit)', isDark),
                        SizedBox(height: 8),
                        _buildInput(
                          controller: _pinCtrl,
                          hint: 'PIN rahasia',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          obscure: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),

                        if (_error != null) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: NusaConfig.activePrimary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: NusaConfig.activePrimary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: NusaConfig.activePrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 24),
                        NusaButton(
                          _loading ? 'Menyimpan...' : 'Mulai Buka Toko 🚀',
                          onPressed: _loading ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          letterSpacing: 0.3,
        ),
      );

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLengthEnforcement: maxLength != null
          ? MaxLengthEnforcement.enforced
          : MaxLengthEnforcement.none,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark
              ? NusaConfig.darkTextTertiary
              : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, size: 20, color: NusaConfig.activePrimary),
        filled: true,
        fillColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor,
        counterText: '',
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: NusaConfig.activePrimary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
