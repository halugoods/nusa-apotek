import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/image_storage_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/pin_dialog.dart';
import 'package:nusa_kasir/features/settings/backup_sheet.dart';
import 'package:nusa_kasir/features/settings/printer_settings_sheet.dart';
import 'package:nusa_kasir/core/services/update_service.dart';
import 'package:nusa_kasir/data/repositories/role_repository.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storeCtrl = TextEditingController();
  String? _activationKey;
  String _themeMode = 'system';
  String? _printerName;
  bool _checkingUpdate = false;
  UpdateInfo? _updateInfo;
  bool _backingUp = false;

  // Manual cloud sync
  bool _syncing = false;
  String? _cloudTimeStr;
  String? _localTimeStr;

  // Fingerprint
  bool _fingerprintEnabled = false;

  // FnB: alur pembayaran
  bool _fnbPayFirst = false;

  // Salon: estimasi & notifikasi
  int _salonDefaultDuration = 60;
  bool _salonNotifyBooking = true;

  // Theme preset
  String _themePreset = NusaConfig.productId.replaceFirst('nusa-', '');

  // Feature toggles — all true by default
  Map<String, bool> _featureToggles = {};
  static const _featureToggleKey = 'nusa_feature_toggles';
  List<String> _menuOrder = []; // persistable menu order (drag-reorder)

  static const _allFeatures = [
    'produk', 'stok', 'transaksi', 'pelanggan', 'piutang', 'promo',
    'pesanan_online', 'laporan', 'presensi', 'karyawan',
    'keuangan', 'spreadsheet', 'supplier', 'cabang', 'ai_chat', 'pengaturan',
    // Domain features — hidden by default per variant via NusaConfig.hiddenMenus
    'meja', 'laundry_status', 'servis', 'booking', 'resep', 'print_order',
  ];

  static const _featureLabels = {
    'produk': 'Produk',
    'stok': 'Stok',
    'transaksi': 'Transaksi',
    'pelanggan': 'Pelanggan',
    'piutang': 'Piutang',
    'promo': 'Promo',
    'pesanan_online': 'Pesanan Online',
    'laporan': 'Laporan',
    'presensi': 'Presensi',
    'karyawan': 'Karyawan',
    'keuangan': 'Keuangan',
    'spreadsheet': 'Spreadsheet',
    'supplier': 'Supplier',
    'cabang': 'Cabang',
    'ai_chat': 'AI Chat',
    'pengaturan': 'Pengaturan',
    'meja': 'Meja',
    'laundry_status': 'Status Laundry',
    'servis': 'Tiket Servis',
    'booking': 'Booking',
    'resep': 'Resep',
    'print_order': 'Order Cetak',
  };

  static const _featureIcons = {
    'produk': Icons.inventory_2_outlined,
    'stok': Icons.view_module_outlined,
    'transaksi': Icons.receipt_long_outlined,
    'pelanggan': Icons.person_outline,
    'piutang': Icons.money_off_outlined,
    'promo': Icons.discount_outlined,
    'pesanan_online': Icons.shopping_cart_outlined,
    'laporan': Icons.paid_outlined,
    'presensi': Icons.fingerprint,
    'karyawan': Icons.people_outline,
    'keuangan': Icons.account_balance_wallet_outlined,
    'spreadsheet': Icons.table_chart_outlined,
    'supplier': Icons.local_shipping_outlined,
    'cabang': Icons.storefront_outlined,
    'ai_chat': Icons.smart_toy_outlined,
    'pengaturan': Icons.settings_outlined,
    'meja': Icons.table_bar_outlined,
    'laundry_status': Icons.local_laundry_service_outlined,
    'servis': Icons.build_outlined,
    'booking': Icons.calendar_month_outlined,
    'resep': Icons.medication_outlined,
    'print_order': Icons.print_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepoProvider);
    final name = await repo.getStoreName();
    final key = await SecureStore.getActivation();
    final theme = await repo.getThemeMode();
    final printer = await repo.getPrinterAddress();

    // Load theme preset
    final savedTheme = await SecureStore.getThemePreset();
    if (savedTheme != null && NusaConfig.themePresets.containsKey(savedTheme)) {
      _themePreset = savedTheme;
      NusaConfig.applyTheme(savedTheme);
    }

    // Load feature toggles
    final raw = await SecureStore.getFeatureToggles();
    Map<String, bool> toggles = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          toggles[e.key] = e.value == true;
        }
      } catch (_) {}
    }
    // Fill in missing features conservatively: domain-specific menus stay hidden
    // unless explicitly enabled for this variant by the user.
    for (final f in _allFeatures) {
      toggles.putIfAbsent(f, () => !NusaConfig.hiddenMenus.contains(f));
    }

    // Load menu order
    final orderRaw = await SecureStore.getMenuOrder();
    List<String> order = [];
    if (orderRaw != null && orderRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(orderRaw) as List<dynamic>;
        order = decoded.cast<String>();
        // Filter to only valid feature IDs, add any new features at end
        final existing = order
            .where((id) => _allFeatures.contains(id))
            .toList();
        for (final f in _allFeatures) {
          if (!existing.contains(f)) existing.add(f);
        }
        order = existing;
      } catch (_) {
        order = List.from(_allFeatures);
      }
    } else {
      order = List.from(_allFeatures);
    }

    if (mounted) {
      _storeCtrl.text = name;
      _activationKey = key;
      _themeMode = theme ?? 'system';
      _printerName = printer;
      _featureToggles = toggles;
      _menuOrder = order;
      ref.read(themeModeProvider.notifier).state = _themeMode;
      // Sync feature toggles to provider (used by dashboard)
      ref.read(featureTogglesProvider.notifier).state = Map.from(toggles);
      // Sync menu order to provider (used by dashboard sort)
      ref.read(menuOrderProvider.notifier).state = List.from(order);

      // Load fingerprint state
      _fingerprintEnabled = await BiometricService.isEnabled();

      // Load FnB payment flow
      if (NusaConfig.isFnbVariant) {
        _fnbPayFirst = await SecureStore.getFnbPaymentFirst();
      }

      // Load Salon settings
      if (NusaConfig.isSalonVariant) {
        _salonDefaultDuration = await SecureStore.getSalonDefaultDuration();
        _salonNotifyBooking = await SecureStore.getSalonNotifyBooking();
      }

      // (Laundry global settings removed — now per-product)

      setState(() {});
    }
  }

  Future<void> _saveFeatureToggles() async {
    final json = jsonEncode(_featureToggles);
    await SecureStore.saveFeatureToggles(json);
    ref.read(featureTogglesProvider.notifier).state = Map.from(_featureToggles);
  }

  Future<void> _saveMenuOrder() async {
    final json = jsonEncode(_menuOrder);
    await SecureStore.saveMenuOrder(json);
    ref.read(menuOrderProvider.notifier).state = List.from(_menuOrder);
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    super.dispose();
  }

  // ── PIN Gate ──────────────────────────────────────────────

  Future<bool> _checkPin() async {
    final session = ref.read(employeeSessionProvider);
    String name;
    String correctPin;
    bool needOwner = false;

    if (session != null) {
      // Current session employee
      final repo = AttendanceRepository(ref.read(databaseProvider));
      final emp = await repo.getEmployee(session.employeeId);
      if (emp != null) {
        name = emp.name;
        correctPin = emp.pin;
      } else {
        // Stale session — employee was deleted or DB was replaced.
        // Clear the session and fall through to owner PIN below
        // instead of silently returning false (which shows misleading "PIN salah" toast).
        ref.read(employeeSessionProvider.notifier).logout();
        needOwner = true;
        name = '';
        correctPin = ''; // will be overwritten below
      }
    } else {
      needOwner = true;
      name = '';
      correctPin = ''; // will be overwritten below
    }

    if (needOwner) {
      // No valid session — ask for Owner PIN
      final repo = AttendanceRepository(ref.read(databaseProvider));
      final all = await repo.getEmployees();
      final ownerList = all.where((e) => e.role == 'Owner').toList();
      if (ownerList.isEmpty) return true;
      final owner = ownerList.first;
      name = owner.name;
      correctPin = owner.pin;
    }

    final result = await PinDialog.show(
      context: context,
      title: 'Verifikasi PIN',
      subtitle: 'Masukkan PIN $name untuk mengakses pengaturan keamanan',
      employeeName: name,
      correctPin: correctPin,
      pinLength: 6,
      showRemember: false,
      showFingerprint: true,
      showNfc: true,
      onFingerprint: () async => await _authFingerprint(),
      onNfc: () async {
        final id = await NfcTagService.readEmployeeTag();
        return id?.toString();
      },
    );

    return result?.success == true;
  }

  Future<bool> _authFingerprint() async {
    return BiometricService.authenticate(
      reason: 'Verifikasi sidik jari untuk melanjutkan',
    );
  }

  Future<void> _pinGate(VoidCallback action) async {
    if (await _checkPin()) {
      action();
    } else {
      TopToast.error(context, 'PIN salah — akses ditolak');
    }
  }

  /// Toggle fingerprint login for Owner — direct, no PIN gate.
  /// ON → langsung muncul dialog biometric OS, sukses = enable, gagal = balik OFF.
  /// OFF → langsung disable.
  Future<void> _toggleFingerprint(EmployeeSession session) async {
    if (session.role != 'Owner') {
      TopToast.info(context, 'Hanya Owner yang bisa mengatur fingerprint');
      return;
    }

    final enable = !_fingerprintEnabled;

    if (enable) {
      // Check hardware capabilities first — don't allow enable on devices
      // without biometric sensors (otherwise OS falls back to device PIN).
      final caps = await BiometricService.checkCapabilities();
      if (!caps.ok) {
        if (mounted) TopToast.error(context, caps.message);
        return;
      }

      // Validate via system biometric dialog directly
      final scanned = await BiometricService.authenticate(
        reason: 'Pindai sidik jari untuk mengaktifkan Login Fingerprint',
      );
      if (!scanned) {
        if (mounted) {
          final msg =
              BiometricService.lastResult.message ??
              'Pemindaian sidik jari gagal atau dibatalkan';
          TopToast.error(context, msg);
        }
        return;
      }

      await BiometricService.enable();
    } else {
      await BiometricService.disable();
    }

    if (mounted) {
      setState(() => _fingerprintEnabled = enable);
      TopToast.success(
        context,
        enable ? 'Fingerprint diaktifkan' : 'Fingerprint dinonaktifkan',
      );
    }
  }

  // ── FnB: Alur Pembayaran ──────────────────────────────────

  Future<void> _loadFnbPayFirst() async {
    final v = await SecureStore.getFnbPaymentFirst();
    if (mounted) setState(() => _fnbPayFirst = v);
  }

  Future<void> _toggleFnbPayFirst() async {
    final next = !_fnbPayFirst;
    await SecureStore.setFnbPaymentFirst(next);
    if (mounted) setState(() => _fnbPayFirst = next);
    if (mounted) {
      TopToast.success(
        context,
        next ? 'Alur: Bayar dulu di kasir' : 'Alur: Pesan dulu, bayar nanti',
      );
    }
  }

  // ── Backups ───────────────────────────────────────────────

  Future<void> _backupNow() async {
    setState(() => _backingUp = true);
    final ok = await ref.read(activationRepoProvider).uploadBackupNow();
    if (mounted) {
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Backup berhasil disimpan ke cloud'
                : 'Gagal backup. Periksa koneksi internet.',
          ),
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ── Cloud Sync (manual) ──────────────────────────────────

  Future<void> _showCloudSync() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fetch timestamps
    final repo = ref.read(activationRepoProvider);
    final cloudTime = await repo.getBackupTimestamp();
    final localTime = await SecureStore.getLastBackupTime();

    if (mounted) {
      setState(() {
        _cloudTimeStr = cloudTime != null
            ? '${cloudTime.day}/${cloudTime.month}/${cloudTime.year} ${cloudTime.hour.toString().padLeft(2, '0')}:${cloudTime.minute.toString().padLeft(2, '0')}'
            : null;
        _localTimeStr = localTime != null
            ? '${localTime.day}/${localTime.month}/${localTime.year} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}'
            : null;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkDivider
                    : NusaConfig.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.cloud_sync,
              size: 40,
              color: NusaConfig.activePrimary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sinkronisasi Cloud',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload / Download data antar perangkat',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Timestamp comparison
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkSurface2
                    : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _syncInfoRow(
                    'Cloud (Supabase)',
                    _cloudTimeStr,
                    Icons.cloud,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _syncInfoRow(
                    'Lokal (Perangkat ini)',
                    _localTimeStr,
                    Icons.phone_android,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Upload
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncing
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _doUpload();
                      },
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload ke Cloud (Simpan data lokal)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Download
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _syncing
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _confirmDownload();
                      },
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Download dari Cloud (Timpa data lokal)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NusaConfig.error,
                  side: const BorderSide(color: NusaConfig.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '⚠ Download akan menimpa SEMUA data lokal dengan data dari cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncInfoRow(
    String label,
    String? time,
    IconData icon,
    bool isDark,
  ) => Row(
    children: [
      Icon(
        icon,
        size: 16,
        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
        ),
      ),
      Text(
        time ?? 'Belum pernah',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: time != null
              ? (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)
              : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)
                    .withValues(alpha: 0.8),
        ),
      ),
    ],
  );

  Future<void> _doUpload() async {
    setState(() => _syncing = true);
    final repo = ref.read(activationRepoProvider);
    final ok = await repo.uploadBackupNow();
    if (mounted) {
      setState(() => _syncing = false);
      // Refresh timestamps so the next cloud sync dialog shows up-to-date values.
      if (ok) {
        final cloudTime = await repo.getBackupTimestamp();
        final localTime = await SecureStore.getLastBackupTime();
        setState(() {
          _cloudTimeStr = cloudTime != null
              ? '${cloudTime.day}/${cloudTime.month}/${cloudTime.year} ${cloudTime.hour.toString().padLeft(2, '0')}:${cloudTime.minute.toString().padLeft(2, '0')}'
              : null;
          _localTimeStr = localTime != null
              ? '${localTime.day}/${localTime.month}/${localTime.year} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}'
              : null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Data berhasil diupload ke cloud ☁️'
                : 'Gagal upload. Periksa koneksi internet.',
          ),
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _confirmDownload() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: NusaConfig.error,
              size: 28,
            ),
            SizedBox(width: 10),
            Text('Konfirmasi Download', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          'Data lokal akan DITIMPA dengan data dari cloud.\n\n'
          'Pastikan tidak ada transaksi yang belum diupload.\n'
          'Disarankan upload dulu sebelum download.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NusaConfig.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _doDownload();
            },
            child: const Text(
              'Ya, Timpa Data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doDownload() async {
    setState(() => _syncing = true);
    final repo = ref.read(activationRepoProvider);
    final ok = await repo.restoreFromCloud();
    if (mounted) {
      setState(() => _syncing = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Data dari cloud siap dipulihkan. Aplikasi akan restart...',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // Restart the app to apply restored DB
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) GoRouter.of(context).go('/home');
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Gagal download. Pastikan koneksi internet dan cloud backup tersedia.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── Section Header ────────────────────────────────────────

  Widget _sectionHeader(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
        letterSpacing: 1.2,
      ),
    ),
  );

  // ── Menu Row (reusable) ───────────────────────────────────

  Widget _menuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
    bool isDark = false,
    Widget? trailing,
  }) => NusaCard(
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? NusaConfig.activePrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
          ],
        ),
      ),
    ),
  );

  // ── Theme Chip ────────────────────────────────────────────

  Widget _themeChip(String label, String mode, IconData icon, bool isDark) {
    final selected = _themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await ref.read(settingsRepoProvider).setThemeMode(mode);
          ref.read(themeModeProvider.notifier).state = mode;
          setState(() => _themeMode = mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? NusaConfig.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? NusaConfig.activePrimary
                  : NusaConfig.dividerColor,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? NusaConfig.activePrimary
                    : isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? NusaConfig.activePrimary
                      : isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Theme Picker ──────────────────────────────────────────

  String _currentThemeLabel() {
    return NusaConfig.themeNames[_themePreset] ?? _themePreset;
  }

  void _showThemePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkDivider
                      : NusaConfig.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
                        color: NusaConfig.activePrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Tema Warna',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih palet warna untuk aplikasi. Beberapa menu akan '
                'menyesuaikan warna tema yang dipilih.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: NusaConfig.themePresets.entries.map((entry) {
                    final id = entry.key;
                    final preset = entry.value;
                    final selected = _themePreset == id;
                    return GestureDetector(
                      onTap: () async {
                        setSt(() {
                          _themePreset = id;
                          setState(() {});
                        });
                        NusaConfig.applyTheme(id);
                        ref.read(themePresetProvider.notifier).state = id;
                        await SecureStore.saveThemePreset(id);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset['primary'],
                          border: Border.all(
                            color: selected
                                ? (isDark ? Colors.white : NusaConfig.textPrimary)
                                : Colors.transparent,
                            width: selected ? 3 : 0,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: (preset['primary']!).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.white, size: 28)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feature Toggles Bottom Sheet ──────────────────────────

  void _showFeatureToggles() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Build ordered list respecting user's drag-reorder preference
    final hidden = NusaConfig.hiddenMenus;
    final ordered = List<String>.from(
      (_menuOrder.isNotEmpty ? _menuOrder : _allFeatures)
          .where((id) => !hidden.contains(id)),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkDivider
                      : NusaConfig.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.toggle_on_outlined,
                        color: NusaConfig.activePrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kelola Fitur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Geser ikon ⠿ untuk atur ulang urutan menu di Home Screen.\n'
                'Matikan fitur yang tidak ingin ditampilkan.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: ordered.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setSt(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = ordered.removeAt(oldIndex);
                      ordered.insert(newIndex, item);
                      _menuOrder = List.from(ordered);
                      setState(() {});
                    });
                    _saveMenuOrder();
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      shadowColor: NusaConfig.activePrimary.withValues(
                        alpha: 0.2,
                      ),
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final id = ordered[index];
                    final enabled = _featureToggles[id] ?? true;
                    return Container(
                      key: ValueKey(id),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? NusaConfig.darkBackground
                            : NusaConfig.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drag handle
                            Icon(
                              Icons.drag_indicator,
                              size: 20,
                              color: isDark
                                  ? NusaConfig.darkTextTertiary
                                  : NusaConfig.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: enabled
                                    ? NusaConfig.activePrimary.withValues(
                                        alpha: 0.12,
                                      )
                                    : (isDark
                                          ? NusaConfig.darkSurface2
                                          : NusaConfig.backgroundColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                (_featureIcons[id] ?? Icons.circle),
                                size: 18,
                                color: enabled
                                    ? NusaConfig.activePrimary
                                    : isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          _featureLabels[id] ?? id,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? (isDark
                                      ? NusaConfig.darkTextPrimary
                                      : NusaConfig.textPrimary)
                                : (isDark
                                      ? NusaConfig.darkTextTertiary
                                      : NusaConfig.textTertiary),
                          ),
                        ),
                        value: enabled,
                        activeColor: NusaConfig.activePrimary,
                        onChanged: (v) {
                          setSt(() {
                            _featureToggles[id] = v;
                            setState(() {}); // sync parent
                          });
                          _saveFeatureToggles();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── License Detail Bottom Sheet ───────────────────────────

  void _showLicense() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkDivider
                    : NusaConfig.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.key,
                    color: NusaConfig.accentGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Lisensi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Activation key
            const Text(
              'Kode Aktivasi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkSurface2
                    : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.borderColor,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _activationKey ?? '-',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_activationKey != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _activationKey!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kode aktivasi disalin'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 18,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: NusaConfig.accentGreen,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Status: Aktif',
                  style: TextStyle(
                    fontSize: 13,
                    color: NusaConfig.accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Backup button
            OutlinedButton.icon(
              onPressed: _backingUp
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _backupNow();
                    },
              icon: _backingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(_backingUp ? 'Menyimpan...' : 'Backup ke Cloud'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NusaConfig.activePrimary,
                side: BorderSide(color: NusaConfig.activePrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Backup cloud tersimpan di akun Google Anda. Gunakan Sinkronisasi Cloud untuk upload/download manual.',
              style: TextStyle(
                fontSize: 11,
                color:
                    (isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)
                        .withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Update Check ──────────────────────────────────────────

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final info = await UpdateService.checkForUpdate();
    if (mounted) {
      setState(() {
        _checkingUpdate = false;
        _updateInfo = info;
      });
      if (info.hasUpdate) {
        _showUpdateDialog();
      } else if (info.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(info.error!),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aplikasi sudah versi terbaru ✨'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showUpdateDialog() {
    final info = _updateInfo;
    if (info == null || !info.hasUpdate) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.system_update,
                color: Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Tersedia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versi ${info.latestVersion} (build ${info.latestBuildNumber})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Saat ini: v${NusaConfig.appVersion}+${NusaConfig.appBuildNumber}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
            if (info.fileSizeBytes != null && info.fileSizeBytes! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Ukuran: ${UpdateService.formatSize(info.fileSizeBytes)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
            ],
            if (info.changelog != null && info.changelog!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkSurface2
                      : NusaConfig.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  info.changelog!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (info.downloadUrl != null) ...[
              const SizedBox(height: 16),
              Text(
                'Klik Download untuk mengunduh APK terbaru dari GitHub.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti'),
          ),
          if (info.downloadUrl != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openDownloadUrl(info.downloadUrl!);
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openDownloadUrl(String url) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Settings] Gagal buka URL: $e');
    }
  }

  // ── Receipt Settings ──────────────────────────────────────

  Future<void> _showReceiptSettings() async {
    final repo = ref.read(settingsRepoProvider);
    final headerCtrl = TextEditingController(
      text: await repo.getReceiptHeader() ?? '',
    );
    final footerCtrl = TextEditingController(
      text: await repo.getReceiptFooter() ?? '',
    );
    final currentLogo = await repo.getStoreLogoPath()
        ?? await SecureStore.getPrinterLogoPath();
    String paperSize = await repo.getReceiptPaperSize();
    final toggles = await repo.getReceiptToggles();
    final storeName = await repo.getStoreName();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final setDark = Theme.of(ctx).brightness == Brightness.dark;
        // State variables declared OUTSIDE StatefulBuilder so they persist across rebuilds
        String? logoPath = currentLogo;
        String headerText = headerCtrl.text;
        String paper = paperSize;
        Map<String, bool> togs = Map.from(toggles);
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return Container(
              decoration: BoxDecoration(
                color: setDark
                    ? NusaConfig.darkSurface
                    : NusaConfig.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: setDark
                            ? NusaConfig.darkDivider
                            : NusaConfig.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Pengaturan Struk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: setDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Ukuran Kertas ──
                    Text(
                      'Ukuran Kertas',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: setDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _paperChip(
                          '58mm',
                          paper,
                          setDark,
                          onTap: () => setSt(() => paper = '58mm'),
                        ),
                        const SizedBox(width: 10),
                        _paperChip(
                          '80mm',
                          paper,
                          setDark,
                          onTap: () => setSt(() => paper = '80mm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Info: logo diatur di Pengaturan Printer ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NusaConfig.primarySoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: NusaConfig.activePrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: NusaConfig.activePrimary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Logo struk diatur di menu Pengaturan Printer',
                              style: TextStyle(
                                fontSize: 12,
                                color: setDark
                                    ? NusaConfig.darkTextSecondary
                                    : NusaConfig.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Header Struk ──
                    Text(
                      'Header Struk',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: setDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NusaInput(
                      'Header',
                      controller: headerCtrl,
                      hint: 'Cth: NUSA MART - Cabang Pusat',
                    ),
                    const SizedBox(height: 20),

                    // ── Footer Struk ──
                    Text(
                      'Footer Struk',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: setDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: setDark
                            ? NusaConfig.darkInputFill
                            : NusaConfig.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: setDark
                              ? NusaConfig.darkInputBorder
                              : NusaConfig.inputBorder,
                        ),
                      ),
                      child: TextField(
                        controller: footerCtrl,
                        maxLines: 3,
                        style: TextStyle(
                          color: setDark
                              ? NusaConfig.darkTextPrimary
                              : NusaConfig.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Terima kasih, ditunggu pesanan selanjutnya!',
                          hintStyle: TextStyle(
                            color: setDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Footer templates
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _footerChip(
                          '🙏 Terima kasih, ditunggu pesanan selanjutnya!',
                          footerCtrl,
                          setSt,
                        ),
                        _footerChip(
                          '🔄 Barang yang sudah dibeli tidak dapat ditukar.',
                          footerCtrl,
                          setSt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Tampilkan di Struk ──
                    Text(
                      'Tampilkan di Struk',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: setDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _toggleRow(
                      'Logo toko',
                      togs['showLogo'] ?? true,
                      setDark,
                      (v) => setSt(() => togs['showLogo'] = v),
                    ),
                    _toggleRow(
                      'Nama kasir',
                      togs['showCashier'] ?? true,
                      setDark,
                      (v) => setSt(() => togs['showCashier'] = v),
                    ),
                    _toggleRow(
                      'Nomor invoice',
                      togs['showInvoice'] ?? true,
                      setDark,
                      (v) => setSt(() => togs['showInvoice'] = v),
                    ),
                    _toggleRow(
                      'Tanggal & jam',
                      togs['showDate'] ?? true,
                      setDark,
                      (v) => setSt(() => togs['showDate'] = v),
                    ),
                    _toggleRow(
                      'Barcode',
                      togs['showBarcode'] ?? false,
                      setDark,
                      (v) => setSt(() => togs['showBarcode'] = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Mini Preview ──
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: setDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Logo ──
                          if (togs['showLogo'] == true &&
                              logoPath != null &&
                              logoPath!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Image.file(
                                File(logoPath!),
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                            ),

                          // ── Store header ──
                          Text(
                            headerCtrl.text.isNotEmpty
                                ? headerCtrl.text
                                : (storeName.isNotEmpty
                                      ? storeName
                                      : 'NUSA MART'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Jl. Merdeka No. 123, Jakarta',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Dashed line ──
                          _dashedLine(false),
                          const SizedBox(height: 4),

                          // ── Invoice + Kasir ──
                          if (togs['showInvoice'] == true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Text(
                                    'INV-001',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Kasir: ${togs['showCashier'] == true ? 'Budi' : '—'}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (togs['showDate'] == true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Text(
                                    '25 Jul 2026  14:30 WIB',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _dashedLine(false),
                          const SizedBox(height: 4),

                          // ── Dummy items ──
                          _receiptItem('Indomie Goreng', 4, 3500, false),
                          _receiptItem('Beras 5kg', 1, 72000, false),
                          _receiptItem('Minyak Goreng 2L', 2, 38000, false),
                          _receiptItem('Telur Ayam 10 butir', 1, 28000, false),
                          _receiptItem('Gula Pasir 1kg', 1, 16000, false),
                          const SizedBox(height: 2),
                          _dashedLine(false),
                          const SizedBox(height: 4),

                          // ── Totals ──
                          Row(
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Rp  173.000',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Text(
                                'Diskon',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Rp   -5.000',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFE63946),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Rp  168.000',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _dashedLine(true),
                          const SizedBox(height: 4),

                          // ── Payment info ──
                          Row(
                            children: [
                              const Text(
                                'Tunai',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Rp  200.000',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Text(
                                'Kembalian',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Rp   32.000',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _dashedLine(false),
                          const SizedBox(height: 4),

                          // ── Barcode ──
                          if (togs['showBarcode'] == true) ...[
                            Container(
                              width: double.infinity,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: List.generate(
                                    20,
                                    (i) => i.isEven
                                        ? const Color(0xFF111827)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'INV-001',
                              style: TextStyle(
                                fontSize: 8,
                                color: Color(0xFF9CA3AF),
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            _dashedLine(false),
                            const SizedBox(height: 4),
                          ],

                          // ── Footer ──
                          Text(
                            footerCtrl.text.isNotEmpty
                                ? footerCtrl.text
                                : '🙏 Terima kasih, ditunggu pesanan selanjutnya!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '•••',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save button
                    NusaButton(
                      'Simpan',
                      onPressed: () async {
                        await repo.setReceiptHeader(headerCtrl.text.trim());
                        await repo.setReceiptFooter(footerCtrl.text.trim());
                        await repo.setReceiptPaperSize(paper);
                        await repo.setReceiptToggles(togs);
                        if (mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Receipt helpers ──────────────────────────────────────

  Widget _paperChip(
    String label,
    String current,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    final selected = current == label;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? NusaConfig.primarySoft
                : (isDark ? NusaConfig.darkSurface2 : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? NusaConfig.activePrimary
                  : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            ),
          ),
          child: Column(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.print,
                size: 20,
                color: selected
                    ? NusaConfig.activePrimary
                    : (isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? NusaConfig.activePrimary
                      : (isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(
    String label,
    bool value,
    bool isDark,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: NusaConfig.activePrimary,
      onChanged: onChanged,
    );
  }

  Widget _footerChip(
    String text,
    TextEditingController ctrl,
    StateSetter setSt,
  ) {
    return GestureDetector(
      onTap: () {
        ctrl.text = text;
        setSt(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NusaConfig.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: NusaConfig.activePrimary),
        ),
      ),
    );
  }

  /// Dashed line separator for receipt preview.
  Widget _dashedLine(bool thick) {
    return CustomPaint(
      painter: _DashPainter(thick ? 2.0 : 1.0),
      size: const Size(double.infinity, 2),
    );
  }

  /// Single receipt item row for preview.
  Widget _receiptItem(String name, int qty, int price, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${qty}x',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 9, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Rp  ${(qty * price).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }

  // ── Role Management ───────────────────────────────────────

  Future<void> _showManageRoles() async {
    final roleRepo = RoleRepository();
    final roles = await roleRepo.getRoles();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text(
            'Kelola Role & Jabatan',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...roles.map((r) {
                  final name = r['name'] as String;
                  final color = Color(r['color'] as int);
                  final isDefault = RoleRepository.defaultRoleNames.contains(
                    name,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? NusaConfig.darkSurface2
                            : NusaConfig.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? NusaConfig.darkBorder
                              : NusaConfig.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.badge, size: 18, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!isDefault)
                            GestureDetector(
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                await _showRoleForm(roleRepo, existing: r);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: isDark
                                      ? NusaConfig.darkTextSecondary
                                      : NusaConfig.textSecondary,
                                ),
                              ),
                            ),
                          if (!isDefault)
                            GestureDetector(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Hapus Role'),
                                    content: Text(
                                      'Hapus role "$name"? Karyawan dg role ini akan perlu diubah manual.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: Text(
                                          'Hapus',
                                          style: TextStyle(
                                            color: NusaConfig.activePrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await roleRepo.deleteRole(name);
                                  if (mounted) Navigator.of(ctx).pop();
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: NusaConfig.activePrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _showRoleForm(roleRepo);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Role'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoleForm(
    RoleRepository roleRepo, {
    Map<String, dynamic>? existing,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] as String?);
    var selectedColor = existing != null
        ? (existing['color'] as int)
        : 0xFF3B82F6;
    final accessList = <String>[];
    if (existing != null)
      accessList.addAll((existing['access'] as List).cast<String>());

    const allScreens = [
      'home',
      'kasir',
      'produk',
      'stok',
      'transaksi',
      'pelanggan',
      'promo',
      'laporan',
      'presensi',
      'karyawan',
      'keuangan',
      'pengaturan',
      'supplier',
      'spreadsheet',
      'pesanan_online',
      'ai_chat',
    ];

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            isEdit ? 'Edit Role' : 'Tambah Role Baru',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NusaInput('Nama Role', controller: nameCtrl),
                const SizedBox(height: 12),
                const Text(
                  'Warna',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      const [
                            0xFFE63946,
                            0xFF3B82F6,
                            0xFF10B981,
                            0xFF8B5CF6,
                            0xFFF59E0B,
                            0xFFEC4899,
                            0xFF6366F1,
                            0xFF14B8A6,
                          ]
                          .map(
                            (c) => GestureDetector(
                              onTap: () => setSt(() => selectedColor = c),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  borderRadius: BorderRadius.circular(10),
                                  border: selectedColor == c
                                      ? Border.all(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Akses Menu',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...allScreens.map(
                  (s) => CheckboxListTile(
                    title: Text(s, style: const TextStyle(fontSize: 13)),
                    value: accessList.contains(s),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => setSt(() {
                      v == true ? accessList.add(s) : accessList.remove(s);
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                if (isEdit) {
                  await roleRepo.updateRole(
                    existing['name'] as String,
                    name,
                    selectedColor,
                    accessList,
                  );
                } else {
                  await roleRepo.addRole(name, selectedColor, accessList);
                }
                if (mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── About Link ────────────────────────────────────────────

  Widget _aboutLink(String label, String url) {
    return GestureDetector(
      onTap: () {
        try {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: NusaConfig.activePrimary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(employeeSessionProvider);

    return ScreenScaffold(
      'Pengaturan',
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ════════════════════════════════════════
            //  TOKO
            // ════════════════════════════════════════
            _sectionHeader('TOKO', isDark),
            // Nama Toko
            NusaCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Informasi Toko',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  NusaInput('Nama toko', controller: _storeCtrl),
                  const SizedBox(height: 12),
                  NusaButton(
                    'Simpan',
                    onPressed: () async {
                      await ref
                          .read(settingsRepoProvider)
                          .setStoreName(_storeCtrl.text.trim());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Toko Online
            _menuRow(
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFFE63946),
              title: 'Toko Online',
              subtitle: 'Aktifkan & atur toko online (Vercel)',
              isDark: isDark,
              onTap: () => context.push('/toko_online_setup'),
            ),
            const SizedBox(height: 12),
            // Pembayaran
            _menuRow(
              icon: Icons.payment,
              iconColor: const Color(0xFF6366F1),
              title: 'Pembayaran',
              subtitle: 'Atur QRIS & rekening bank untuk transfer',
              isDark: isDark,
              onTap: () => context.push('/pengaturan_pembayaran'),
            ),
            // Alur Pembayaran — FnB only
            if (NusaConfig.isFnbVariant) ...[
              const SizedBox(height: 12),
              _menuRow(
                icon: Icons.swap_horiz,
                iconColor: const Color(0xFFF59E0B),
                title: 'Alur Pembayaran',
                subtitle: _fnbPayFirst
                    ? 'Bayar dulu di kasir, baru pilih meja'
                    : 'Pesan dulu, duduk di meja, bayar setelah selesai',
                isDark: isDark,
                onTap: null, // toggle handled by trailing switch
                trailing: Switch(
                  value: _fnbPayFirst,
                  activeColor: NusaConfig.warning,
                  onChanged: (_) => _toggleFnbPayFirst(),
                ),
              ),
            ],
            // Laundry settings removed — now per-product via priceType toggle on product cards.

            // Salon settings
            if (NusaConfig.isSalonVariant) ...[
              const SizedBox(height: 12),
              _menuRow(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Estimasi Default',
                subtitle: '$_salonDefaultDuration menit — durasi estimasi standar per booking',
                isDark: isDark,
                onTap: () async {
                  final opts = [30, 45, 60, 90, 120];
                  final current = _salonDefaultDuration;
                  final sel = await showModalBottomSheet<String>(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Estimasi Default', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ...opts.map((o) => ListTile(
                          title: Text('$o menit'),
                          trailing: o == current ? Icon(Icons.check, color: NusaConfig.activePrimary) : null,
                          onTap: () => Navigator.pop(ctx, '$o'),
                        )),
                      ]),
                    ),
                  );
                  if (sel != null && mounted) {
                    final v = int.parse(sel);
                    await SecureStore.setSalonDefaultDuration(v);
                    setState(() => _salonDefaultDuration = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              _menuRow(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Notifikasi Booking',
                subtitle: _salonNotifyBooking ? 'Notif H-30 menit sebelum booking' : 'Notifikasi dimatikan',
                isDark: isDark,
                onTap: null,
                trailing: Switch(
                  value: _salonNotifyBooking,
                  activeColor: NusaConfig.info,
                  onChanged: (v) async {
                    await SecureStore.setSalonNotifyBooking(v);
                    setState(() => _salonNotifyBooking = v);
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Pengaturan Struk
            _menuRow(
              icon: Icons.receipt_long,
              iconColor: const Color(0xFF10B981),
              title: 'Pengaturan Struk',
              subtitle: 'Atur footer struk & upload logo toko',
              isDark: isDark,
              onTap: _showReceiptSettings,
            ),

            // Fingerprint — Owner only, no PIN gate, direct toggle
            if (session?.role == 'Owner') ...[
              const SizedBox(height: 12),
              _menuRow(
                icon: Icons.fingerprint,
                iconColor: NusaConfig.accentPurple,
                title: 'Login Fingerprint',
                subtitle: _fingerprintEnabled
                    ? 'Aktif — akses cepat pakai sidik jari'
                    : 'Aktifkan akses cepat Owner',
                isDark: isDark,
                onTap: () => _toggleFingerprint(session!),
                trailing: Switch(
                  value: _fingerprintEnabled,
                  activeColor: NusaConfig.accentPurple,
                  onChanged: (v) => _toggleFingerprint(session!),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ════════════════════════════════════════
            //  TAMPILAN
            // ════════════════════════════════════════
            _sectionHeader('TAMPILAN', isDark),
            NusaCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tema',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _themeChip('Terang', 'light', Icons.light_mode, isDark),
                      const SizedBox(width: 8),
                      _themeChip('Gelap', 'dark', Icons.dark_mode, isDark),
                      const SizedBox(width: 8),
                      _themeChip(
                        'Sistem',
                        'system',
                        Icons.phone_android,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tema Warna
            _menuRow(
              icon: Icons.palette_outlined,
              iconColor: NusaConfig.activePrimary,
              title: 'Tema Warna',
              subtitle: _currentThemeLabel(),
              isDark: isDark,
              onTap: _showThemePicker,
            ),

            const SizedBox(height: 24),

            // ════════════════════════════════════════
            //  KEAMANAN
            // ════════════════════════════════════════
            Row(
              children: [
                _sectionHeader('KEAMANAN', isDark),
                const SizedBox(width: 6),
                Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ],
            ),
            // Kelola Fitur
            _menuRow(
              icon: Icons.toggle_on_outlined,
              iconColor: NusaConfig.accentPurple,
              title: 'Kelola Fitur',
              subtitle: 'Atur fitur yang tampil di Home Screen',
              isDark: isDark,
              onTap: () => _pinGate(_showFeatureToggles),
              trailing: Icon(
                Icons.lock_outline,
                size: 16,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
            // Dev: Pilih Varian (only in dev build)
            if (NusaConfig.isDevBuild) ...[
              const SizedBox(height: 12),
              _menuRow(
                icon: Icons.apps_rounded,
                iconColor: NusaConfig.accentGold,
                title: 'Pilih Varian',
                subtitle: 'Switch ke variant lain (${NusaConfig.productId.replaceFirst('nusa-', '')})',
                isDark: isDark,
                onTap: () => _pinGate(() => context.go('/variant-picker')),
                trailing: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Lisensi
            _menuRow(
              icon: Icons.key,
              iconColor: NusaConfig.accentGreen,
              title: 'Lisensi',
              subtitle: _activationKey != null
                  ? 'Terverifikasi'
                  : 'Belum diaktivasi',
              isDark: isDark,
              onTap: () => _pinGate(_showLicense),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activationKey != null)
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: NusaConfig.accentGreen,
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                ],
              ),
            ),

            // PIN length — fixed at 6 digits, not user-changeable
            const SizedBox(height: 24),

            // ════════════════════════════════════════
            //  DATA
            // ════════════════════════════════════════
            _sectionHeader('DATA', isDark),
            _menuRow(
              icon: Icons.backup,
              iconColor: NusaConfig.activePrimary,
              title: 'Backup & Restore',
              subtitle: 'Simpan atau muat file database',
              isDark: isDark,
              onTap: () => showBackupSheet(context, ref),
            ),
            const SizedBox(height: 12),
            _menuRow(
              icon: Icons.cloud_sync,
              iconColor: NusaConfig.info,
              title: 'Sinkronisasi Cloud',
              subtitle: 'Upload / Download antar perangkat via Google',
              isDark: isDark,
              onTap: () => _showCloudSync(),
            ),

            const SizedBox(height: 24),

            // ════════════════════════════════════════
            //  PERANGKAT
            // ════════════════════════════════════════
            _sectionHeader('PERANGKAT', isDark),
            // Printer
            _menuRow(
              icon: Icons.print,
              iconColor: const Color(0xFFE63946),
              title: 'Printer',
              subtitle: _printerName != null
                  ? _printerName!.split('|').first
                  : 'Atur printer thermal',
              isDark: isDark,
              onTap: () => PrinterSettingsSheet.show(
                context: context,
                currentAddress: _printerName,
                onPrinterSelected: (d) async {
                  await ref
                      .read(settingsRepoProvider)
                      .setPrinterAddress('${d.name}|${d.address}');
                  setState(() => _printerName = '${d.name}|${d.address}');
                },
              ),
            ),
            const SizedBox(height: 12),
            // Update
            _menuRow(
              icon: _updateInfo?.hasUpdate == true
                  ? Icons.system_update
                  : Icons.update,
              iconColor: _updateInfo?.hasUpdate == true
                  ? Colors.orange
                  : NusaConfig.activePrimary,
              title: _updateInfo?.hasUpdate == true
                  ? 'Update Tersedia!'
                  : 'Cek Update',
              subtitle: _updateInfo?.hasUpdate == true
                  ? 'Versi ${_updateInfo!.latestVersion} (build ${_updateInfo!.latestBuildNumber})'
                  : _checkingUpdate
                  ? 'Memeriksa...'
                  : 'v${NusaConfig.appVersion}+${NusaConfig.appBuildNumber}',
              isDark: isDark,
              onTap: _updateInfo?.hasUpdate == true
                  ? _showUpdateDialog
                  : _checkUpdate,
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _updateInfo?.hasUpdate == true
                          ? Icons.download
                          : Icons.refresh,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
            ),

            const SizedBox(height: 32),

            // ════════════════════════════════════════
            //  TENTANG APLIKASI
            // ════════════════════════════════════════
            _sectionHeader('TENTANG APLIKASI', isDark),
            NusaCard(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nusa Kasir',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Versi ${NusaConfig.appVersion} (build ${NusaConfig.appBuildNumber})',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? NusaConfig.darkTextSecondary
                                      : NusaConfig.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Dibuat oleh Halu Goods',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _aboutLink(
                          'Syarat & Ketentuan',
                          'https://halugoods.com/terms',
                        ),
                        const SizedBox(width: 16),
                        _aboutLink(
                          'Kebijakan Privasi',
                          'https://halugoods.com/privacy',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Custom dash painter for receipt preview ──
class _DashPainter extends CustomPainter {
  final double strokeWidth;
  _DashPainter(this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 1),
        Offset((startX + dashWidth).clamp(0, size.width), 1),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      strokeWidth != oldDelegate.strokeWidth;
}
