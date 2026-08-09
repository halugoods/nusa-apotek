import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/cashier_session_repository.dart';
import 'package:nusa_kasir/data/repositories/report_repository.dart';
import 'package:nusa_kasir/data/repositories/branch_repository.dart';
import 'package:nusa_kasir/data/repositories/online_order_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/finance_repository.dart';
import 'package:nusa_kasir/data/repositories/laundry_order_repository.dart';
import 'package:nusa_kasir/data/repositories/role_repository.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/features/auth/rbac.dart';
import 'package:nusa_kasir/shared/widgets/dashboard_header.dart';
import 'package:nusa_kasir/shared/widgets/pin_dialog.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/profile_stats_card.dart';
import 'package:nusa_kasir/core/utils/icon_loader.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore_for_file: use_build_context_synchronously

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _storeName = 'NUSA';
  String _omzet = 'Rp 0';
  String _trxCount = '0';
  String _avg = 'Rp 0';
  final String _topProduct = '—';
  List<Branche> _branches = [];
  Branche? _activeBranch;

  // Current session info
  String _currentName = '';
  String _currentRole = '';
  int? _currentEmployeeId;
  String? _currentPhotoPath;

  // Attendance tracking
  bool _hasCheckedIn = false;
  String _checkInTime = '';

  // Last cashier session
  String? _lastCashierName;
  String _lastCashierRole = '';
  String _lastCashierTime = '';
  String? _lastCashierPhoto;
  List<Employee> _employees = [];
  int _onlinePending = 0;
  int _lowStockCount = 0;

  // Keuangan summary
  int _financeExpense = 0;
  int _financeIncome = 0;

  // Laundry stats
  int _laundryToday = 0;
  int _laundryPending = 0;
  int _laundryReady = 0;
  int _laundryDelivered = 0;

  // Flip card data
  EmployeeCardData? _cardData;
  int? _cardEmployeeId;

  final List<Map<String, dynamic>> _items = const [
    {'id': 'produk', 'label': 'Produk', 'icon': 'product'},
    {'id': 'stok', 'label': 'Stok', 'icon': 'inventory'},
    {'id': 'transaksi', 'label': 'Transaksi', 'icon': 'transaction'},
    {'id': 'pelanggan', 'label': 'Pelanggan', 'icon': 'customer'},
    {'id': 'piutang', 'label': 'Piutang', 'icon': 'debt'},
    {'id': 'promo', 'label': 'Promo', 'icon': 'promotion'},
    {'id': 'pesanan_online', 'label': 'Online', 'icon': 'online'},
    {'id': 'laporan', 'label': 'Laporan', 'icon': 'report'},
    {'id': 'presensi', 'label': 'Presensi', 'icon': 'notification'},
    {'id': 'karyawan', 'label': 'Karyawan', 'icon': 'employee'},
    {'id': 'keuangan', 'label': 'Keuangan', 'icon': 'finance'},
    {'id': 'spreadsheet', 'label': 'Spreadsheet', 'icon': 'table'},
    {'id': 'supplier', 'label': 'Supplier', 'icon': 'supplier'},
    {'id': 'cabang', 'label': 'Cabang', 'icon': 'branch'},
    {'id': 'ai_chat', 'label': 'AI Chat', 'icon': 'ai'},
    {'id': 'pengaturan', 'label': 'Pengaturan', 'icon': 'settings'},
    // ── Domain-specific menus (hidden by default in irrelevant variants) ──
    {'id': 'meja', 'label': 'Meja', 'icon': 'table_bar'},
    {'id': 'laundry_status', 'label': 'Status Laundry', 'icon': 'laundry'},
    {'id': 'servis', 'label': 'Tiket Servis', 'icon': 'repair'},
    {'id': 'booking', 'label': 'Booking', 'icon': 'booking'},
    {'id': 'resep', 'label': 'Resep', 'icon': 'prescription'},
    {'id': 'print_order', 'label': 'Order Cetak', 'icon': 'print_order'},
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Restore session
    await ref.read(employeeSessionProvider.notifier).restore();
    final session = ref.read(employeeSessionProvider);
    if (session != null) {
      ref.read(authProvider.notifier).state = session.role;
      _currentName = session.name;
      _currentRole = session.role;
      _currentEmployeeId = session.employeeId;
      // Check attendance for today
      await _checkAttendance(session.employeeId);
    }

    // ═══ Init providers from persisted storage (fixes BUG #5 + #11) ═══
    // These providers start empty by default — we must seed them from
    // SecureStore before the first Dashboard build so menu ordering,
    // feature toggles, and per-role access lists work on fresh launch.
    try {
      // Feature toggles
      final togglesRaw = await SecureStore.getFeatureToggles();
      if (togglesRaw != null) {
        final toggles = (jsonDecode(togglesRaw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as bool));
        ref.read(featureTogglesProvider.notifier).state = toggles;
      }
      // Menu order
      final orderRaw = await SecureStore.getMenuOrder();
      if (orderRaw != null) {
        final order = (jsonDecode(orderRaw) as List<dynamic>)
            .map((e) => e as String)
            .toList();
        ref.read(menuOrderProvider.notifier).state = order;
      }
      // RBAC dynamic role access — load custom roles so Owner-defined
      // per-role access lists are applied without needing to open Karyawan.
      final roleRepo = RoleRepository();
      final roles = await roleRepo.getRoles();
      final dynamicAccess = <String, List<String>>{};
      for (final r in roles) {
        dynamicAccess[r['name'] as String] =
            List<String>.from(r['access'] as List? ?? []);
      }
      setDynamicRoleAccess(dynamicAccess);
    } catch (_) {
      // Non-critical — defaults are safe fallbacks
    }

    await _load();

    // Fix: reload photoPath from DB (not stale session data)
    if (session != null && mounted) {
      try {
        final attRepo = AttendanceRepository(ref.read(databaseProvider));
        final emp = await attRepo.getEmployee(session.employeeId);
        if (emp != null && mounted) {
          setState(() => _currentPhotoPath = emp.photoPath);
        }
      } catch (_) {}
    }

    // Biometric auto-unlock for Owner is handled by the GoRouter redirect guard
    // in app.dart — NOT here. The redirect guard invalidates remembered sessions
    // when fingerprint is disabled. If we reach here, the session is valid.

    // Auto-scope branch from session
    if (session?.branchId != null && mounted) {
      final branchRepo = BranchRepository(ref.read(databaseProvider));
      final branch = await branchRepo.byId(session!.branchId!);
      if (branch != null && mounted) {
        setState(() => _activeBranch = branch);
        ref.read(activeBranchProvider.notifier).state = branch;
        await _load();
      }
    }
  }

  Future<void> _checkAttendance(int employeeId) async {
    try {
      final attRepo = AttendanceRepository(ref.read(databaseProvider));
      final today = await attRepo.getToday(employeeId);
      if (mounted) {
        setState(() {
          _hasCheckedIn = today != null && today.checkIn != null;
          _checkInTime = today?.checkIn ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final name = await ref.read(settingsRepoProvider).getStoreName();
    final db = ref.read(databaseProvider);
    final attRepo = AttendanceRepository(db);
    final emps = await attRepo.getEmployees();
    final branches =
        await BranchRepository(ref.read(databaseProvider)).getAll();
    final session = ref.read(employeeSessionProvider);
    // A null branch keeps owner/global dashboards scoped to all branches.
    final branchId = _activeBranch?.id ?? session?.branchId;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reportRepo = ReportRepository(ref.read(databaseProvider));
    final sum = await reportRepo.summary(
      from: today,
      to: now,
      branchId: branchId,
    );

    final cashierRepo =
        CashierSessionRepository(ref.read(databaseProvider));
    final lastSession = await cashierRepo.getLast();

    String? lastCashierName;
    String lastCashierRole = '';
    String lastCashierTime = '';
    String? lastCashierPhoto;
    if (lastSession != null) {
      final emp = emps.cast<Employee?>().firstWhere(
            (e) => e!.id == lastSession.employeeId,
            orElse: () => null,
          );
      if (emp != null) {
        lastCashierName = emp.name;
        lastCashierRole = emp.role;
        lastCashierPhoto = emp.photoPath;
        final t = lastSession.openedAt;
        lastCashierTime =
            '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';
      }
    }

    // Check attendance for each employee — who hasn't checked in today?
    // (we'll use this to show badge on employee picker)
    // For now just reload the list

    // Load online pending count
    final onlineRepo = OnlineOrderRepository(ref.read(databaseProvider));
    final onlinePending = await onlineRepo.countPending();

    // Load low stock count (stok menipis: stock < minStock && minStock > 0)
    int lowStockCount = 0;
    try {
      final allProducts = await ProductRepository(ref.read(databaseProvider)).getProducts();
      lowStockCount = allProducts.where((p) => p.stock < p.minStock && p.minStock > 0).length;
    } catch (_) {}

    // Load keuangan summary
    final financeRepo = FinanceRepository(ref.read(databaseProvider));
    final finSummary = await financeRepo.getDashboardSummary(branchId: branchId);

    // Load laundry stats
    int laundryToday = 0, laundryPending = 0, laundryReady = 0, laundryDelivered = 0;
    if (NusaConfig.isLaundryVariant) {
      final laundryRepo = LaundryOrderRepository(db);
      laundryToday = await laundryRepo.countToday();
      laundryPending = await laundryRepo.countPending();
      laundryReady = await laundryRepo.countByStatus('Siap');
      laundryDelivered = await laundryRepo.countByStatus('Diambil');
    }

    // Load flip card data
    await _fetchCardData(ref.read(employeeSessionProvider)?.employeeId);

    if (mounted) {
      setState(() {
        _storeName = name.isNotEmpty ? name : 'NUSA';
        _branches = branches;
        // Only auto-set first branch if session didn't already scope
        if (branches.isNotEmpty && _activeBranch == null && ref.read(employeeSessionProvider)?.branchId == null) {
          _activeBranch = branches.first;
          ref.read(activeBranchProvider.notifier).state = branches.first;
        }
        _omzet = formatRupiah(sum['omzet'] as int);
        _trxCount = '${sum['count']}';
        _avg = formatRupiah(sum['avg'] as int);
        _employees = emps;
        _onlinePending = onlinePending;
        _lowStockCount = lowStockCount;
        _lastCashierName = lastCashierName;
        _lastCashierRole = lastCashierRole;
        _lastCashierTime = lastCashierTime;
        _lastCashierPhoto = lastCashierPhoto;
        _financeExpense = finSummary['totalExpense'] ?? 0;
        _financeIncome = finSummary['totalIncome'] ?? 0;
        _laundryToday = laundryToday;
        _laundryPending = laundryPending;
        _laundryReady = laundryReady;
        _laundryDelivered = laundryDelivered;
      });
    }
  }

  /// Pre-fetch flip card data for the profile card back side.
  Future<void> _fetchCardData(int? employeeId) async {
    if (employeeId == null) return;
    _cardEmployeeId = employeeId;
    try {
      final db = ref.read(databaseProvider);
      final reportRepo = ReportRepository(db);
      final attRepo = AttendanceRepository(db);
      final onlineRepo = OnlineOrderRepository(db);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final branchId = _activeBranch?.id ??
          ref.read(employeeSessionProvider)?.branchId;

      // Today's sales summary
      final sum = await reportRepo.summary(
        from: today,
        to: now,
        branchId: branchId,
      );
      final penjualan = sum['omzet'] as int;
      final trxCount = sum['count'] as int;

      // Profit estimate
      final laba = (penjualan * 0.9).round();

      // Cash drawer — from today's attendance record
      final todayAtt = await attRepo.getToday(employeeId);
      final modalAwal = todayAtt?.pettyCash ?? 0;
      final totalLaci = todayAtt?.finalCash ?? modalAwal;
      final selisihLaci = totalLaci - modalAwal - penjualan;
      String? shiftHours;
      // Shift hours from today's attendance
      if (todayAtt?.checkIn != null) {
        final parts = todayAtt!.checkIn!.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final diff = now.difference(
              DateTime(now.year, now.month, now.day, h, m));
          if (diff.inMinutes > 0) {
            shiftHours = '${diff.inHours}j ${diff.inMinutes.remainder(60)}m';
          }
        }
      }

      // Monthly data
      final monthStart = DateTime(now.year, now.month, 1);
      final monthSum = await reportRepo.summary(
        from: monthStart,
        to: now,
        branchId: branchId,
      );
      final omzet = monthSum['omzet'] as int;
      final transaksiBulan = monthSum['count'] as int;

      // Attendance — count records this month
      final history = await attRepo.history(employeeId: employeeId);
      final hadirDays = history
          .where((a) => a.date.isAfter(monthStart.subtract(const Duration(days: 1))) && a.checkIn != null)
          .length;
      final totalDays = now.day;

      // Pending online orders
      final pendingItems = await onlineRepo.countPending();

      if (mounted) {
        setState(() {
          _cardData = EmployeeCardData(
            penjualan: penjualan,
            laba: laba,
            trxCount: trxCount,
            modalAwal: modalAwal,
            totalLaci: totalLaci,
            selisihLaci: selisihLaci,
            shiftHours: shiftHours,
            omzet: omzet,
            transaksiBulan: transaksiBulan,
            hadirDays: hadirDays,
            totalDays: totalDays,
            pendingItems: pendingItems,
          );
        });
      }
    } catch (_) {}
  }

  // ── Branch Picker ──────────────────────────────────────────────

  void _showBranchPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: NusaConfig.accentPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store, color: NusaConfig.accentPurple, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Pilih Cabang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          // "Semua Cabang" option
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.layers, color: NusaConfig.accentGreen, size: 20),
            ),
            title: const Text('Semua Cabang',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: const Text('Lihat data dari seluruh cabang',
                style: TextStyle(fontSize: 12)),
            trailing: _activeBranch == null
                ? const Icon(Icons.check_circle, color: NusaConfig.accentGreen, size: 22)
                : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                setState(() => _activeBranch = null);
                ref.read(activeBranchProvider.notifier).state = null;
                Navigator.pop(ctx);
                await _load();
              },
          ),
          const SizedBox(height: 4),
          // Branch list
          ..._branches.map((b) {
            final active = _activeBranch?.id == b.id;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (active ? NusaConfig.accentPurple : const Color(0xFF9CA3AF)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.storefront,
                    color: active ? NusaConfig.accentPurple : const Color(0xFF9CA3AF), size: 20),
              ),
              title: Text(b.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                      color: active ? NusaConfig.accentPurple : null)),
              subtitle: b.address != null && b.address!.isNotEmpty
                  ? Text(b.address!, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: active
                  ? const Icon(Icons.check_circle, color: NusaConfig.accentPurple, size: 22)
                  : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                setState(() => _activeBranch = b);
                ref.read(activeBranchProvider.notifier).state = b;
                Navigator.pop(ctx);
                await _load();
              },
            );
          }),
          const SizedBox(height: 8),
          // Kelola Cabang button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/cabang');
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Kelola Cabang',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: NusaConfig.accentPurple,
                side: const BorderSide(color: NusaConfig.accentPurple),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Menu navigation with RBAC guard ────────────────────────────────

  Future<void> _handleMenuTap(String route) async {
    final session = ref.read(employeeSessionProvider);

    // 1. Session must exist (GoRouter guard ensures this)
    if (session == null) return;

    final currentRole = ref.read(employeeSessionProvider)?.role ?? 'Kasir';

    // 2. Owner-only guard
    if (isOwnerOnly(route) && currentRole != 'Owner' && currentRole != 'Manager') {
      _showOwnerOnlyDialog(route);
      return;
    }

    // 3. RBAC access guard — block navigation for screens not in role's access list
    if (!hasAccess(currentRole, route)) {
      _showOwnerOnlyDialog(route);
      return;
    }

    // 4. PIN guard for sensitive menus (kasir)
    if (needsPinGuard(route)) {
      final pinOk = await _requirePinReentry();
      if (!pinOk) return;
    }

    // 5. Attendance check: if not checked in, check in now
    if (!_hasCheckedIn && session != null) {
      final attRepo = AttendanceRepository(ref.read(databaseProvider));
      await attRepo.checkIn(session.employeeId);
      if (mounted) setState(() => _hasCheckedIn = true);
    }

    // Navigate
    if (route == 'presensi') {
      await context.push('/$route');
      if (mounted) await _load();
    } else if (route == 'stok' && _lowStockCount > 0) {
      context.push('/stok?lowStock=true');
    } else {
      context.push('/$route');
    }
  }

  /// Show "Hanya owner" dialog with lock icon.
  void _showOwnerOnlyDialog(String route) {
    final label = _items.firstWhere(
      (i) => i['id'] == route,
      orElse: () => {'label': route},
    )['label'] as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: NusaConfig.activePrimary, size: 28),
            const SizedBox(width: 10),
            const Text('Akses Terbatas', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(
          'Menu "$label" hanya bisa diakses oleh Owner/Manager. '
          'Silakan minta Owner untuk login jika perlu mengakses menu ini.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NusaConfig.activePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Force PIN re-entry for sensitive operations.
  Future<bool> _requirePinReentry() async {
    final session = ref.read(employeeSessionProvider);
    if (session == null) return false;

    final emp = _employees.cast<Employee?>().firstWhere(
          (e) => e!.id == session.employeeId,
          orElse: () => null,
        );
    if (emp == null) return false;

    final result = await PinDialog.show(
      context: context,
      employeeName: emp.name,
      employeeRole: emp.role,
      correctPin: emp.pin,
      showRemember: false,
      showFingerprint: true,
      showNfc: true,
      onFingerprint: () async => await _authFingerprint(),
      onNfc: () async {
        final id = await NfcTagService.readEmployeeTag();
        return id?.toString();
      },
      pinLength: 6,
    );

    if (result == null || !result.success) {
      return false;
    }

    // Touch session on successful PIN
    ref.read(employeeSessionProvider.notifier).touch();
    return true;
  }

  Future<bool> _authFingerprint() async {
    return BiometricService.authenticate(
      reason: 'Verifikasi sidik jari untuk melanjutkan',
    );
  }

  // ── Employee Picker + Login ────────────────────────────────────────

  Future<void> _pickAndLogin() async {
    if (_employees.isEmpty) {
      TopToast.info(context, 'Belum ada karyawan. Tambah di menu Karyawan.');
      return;
    }

    // Show employee picker with attendance badges
    final emp = await _showEmployeePicker();
    if (emp == null || !mounted) return;

    // Show PIN dialog
    final result = await PinDialog.show(
      context: context,
      employeeName: emp.name,
      employeeRole: emp.role,
      correctPin: emp.pin,
      showFingerprint: true,
      showNfc: true,
      onFingerprint: () async => await _authFingerprint(),
      onNfc: () async {
        final id = await NfcTagService.readEmployeeTag();
        return id?.toString();
      },
      pinLength: 6,
    );

    if (result == null || !result.success || !mounted) return;

    // Login
    final session = EmployeeSession(
      employeeId: emp.id,
      name: emp.name,
      role: emp.role,
      branchId: emp.branchId,
      remember: result.remember,
    );
    ref.read(employeeSessionProvider.notifier).login(session, remember: result.remember);
    ref.read(authProvider.notifier).state = emp.role;

    // Touch session
    ref.read(employeeSessionProvider.notifier).touch();

    // Auto-scope to employee's assigned branch
    if (emp.branchId != null) {
      final branchRepo = BranchRepository(ref.read(databaseProvider));
      final branch = await branchRepo.byId(emp.branchId!);
      if (branch != null && mounted) {
        setState(() => _activeBranch = branch);
        ref.read(activeBranchProvider.notifier).state = branch;
      }
    }

    // Auto check-in if not yet checked in today
    try {
      final attRepo = AttendanceRepository(ref.read(databaseProvider));
      await attRepo.checkIn(emp.id);
      await _checkAttendance(emp.id);
    } catch (_) {}

    if (mounted) {
      _currentName = emp.name;
      _currentRole = emp.role;
      _currentEmployeeId = emp.id;
      _currentPhotoPath = emp.photoPath;
      TopToast.success(context, 'Halo, ${emp.name}! 👋');
    }
  }

  // ── Buka Kasir ─────────────────────────────────────────────────────

  Future<void> _bukaKasir() async {
    // Session must exist (GoRouter guard ensures this)
    final s = ref.read(employeeSessionProvider);
    if (s == null) return;

    // PIN re-entry for security
    final pinOk = await _requirePinReentry();
    if (!pinOk) return;
    if (!mounted) return;

    // Check if there's already an active cashier session
    final cashierRepo = CashierSessionRepository(ref.read(databaseProvider));
    final active = await cashierRepo.getActive();
    if (active != null) {
      if (mounted) {
        TopToast.info(context, 'Kasir masih terbuka. Melanjutkan sesi sebelumnya.');
        context.push('/kasir?sessionId=${active.id}');
      }
      return;
    }

    // Auto check-in if not yet
    if (!_hasCheckedIn) {
      try {
        final attRepo = AttendanceRepository(ref.read(databaseProvider));
        await attRepo.checkIn(s.employeeId);
        setState(() => _hasCheckedIn = true);
      } catch (_) {}
    }

    // Create cashier session with saldo = 0
    try {
      final sessionId = await cashierRepo.open(
        employeeId: s.employeeId,
        startingCash: 0,
      );
      if (mounted) {
        TopToast.success(context, 'Kasir dibuka — Halo, ${s.name}! 👋');
        context.push('/kasir?sessionId=$sessionId');
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Gagal membuka kasir: $e');
      }
    }
  }

  Future<void> _handlePresensiTap() async {
    await context.push('/presensi');
    if (mounted) {
      await _load();
    }
  }

  /// Show employee list with WhatsApp chat buttons (Owner quick access).
  void _showEmployeeWaList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Hubungi Karyawan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._employees.where((e) => e.phone != null && e.phone!.isNotEmpty).map((e) {
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(e.name[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: NusaConfig.activePrimary)),
              ),
              title: Text(e.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(e.role,
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chat, color: NusaConfig.accentGreen),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _launchWa(e.phone!);
              },
            );
          }),
          if (_employees.where((e) => e.phone != null && e.phone!.isNotEmpty).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Tidak ada karyawan dengan nomor WA',
                  style: TextStyle(fontSize: 13, color: NusaConfig.textSecondary)),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _launchWa(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
        'https://wa.me/${clean.startsWith('0') ? '62${clean.substring(1)}' : clean}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        TopToast.error(context, 'Gagal membuka WhatsApp');
      }
    }
  }

  // ── Employee Picker with Attendance Badge ─────────────────────────

  Future<Employee?> _showEmployeePicker() async {
    // Build attendance status map for today
    final attRepo = AttendanceRepository(ref.read(databaseProvider));
    final Map<int, bool> checkedInMap = {};
    for (final e in _employees) {
      final att = await attRepo.getToday(e.id);
      checkedInMap[e.id] = att != null && att.checkIn != null;
    }

    if (!mounted) return null;

    return showDialog<Employee>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Karyawan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Siapa yang mau login?',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _employees.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final e = _employees[i];
                      final checkedIn = checkedInMap[e.id] ?? false;
                      final hasPhoto = e.photoPath != null && e.photoPath!.isNotEmpty && File(e.photoPath!).existsSync();
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                            image: hasPhoto
                                ? DecorationImage(image: FileImage(File(e.photoPath!)), fit: BoxFit.cover)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: !hasPhoto
                              ? Text(e.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: NusaConfig.activePrimary))
                              : Stack(children: [
                                  // Attendance badge
                                  if (!checkedIn)
                                    Positioned(right: 0, bottom: 0,
                                      child: Container(
                                        width: 14, height: 14,
                                        decoration: BoxDecoration(color: NusaConfig.accentGold, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                        child: const Icon(Icons.warning_amber_rounded, size: 8, color: Colors.white),
                                      ),
                                    ),
                                ]),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                e.name,
                                style: TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!checkedIn) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: NusaConfig.accentGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Belum absen',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: NusaConfig.accentGold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(e.role,
                            style: const TextStyle(fontSize: 12)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onTap: () => Navigator.of(ctx).pop(e),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(employeeSessionProvider);
    final role = session?.role ?? 'Owner';

    // Build menu items — only show menus this variant + role can access
    final featureToggles = ref.watch(featureTogglesProvider);
    final menuOrder = ref.watch(menuOrderProvider);
    final filteredItems = _items
        .where((item) {
          final id = item['id'] as String;
          // User override from Kelola Fitur takes priority
          if (featureToggles.containsKey(id)) return featureToggles[id]!;
          // Hide domain-inappropriate menus for this variant
          if (NusaConfig.hiddenMenus.contains(id)) return false;
          // Hide menus the employee's role cannot access (no lock gimmick)
          if (isOwnerOnly(id) && role != 'Owner' && role != 'Manager') return false;
          if (!hasAccess(role, id)) return false;
          return true;
        })
        .map((item) {
      final id = item['id'] as String;
      final label = item['label'] as String;
      final icon = item['icon'] as String;

      // Only PIN-guarded menus need an indicator; everything else is accessible
      String accessType = '';
      if (needsPinGuard(id)) {
        accessType = '🔐';
      }

      return {
        'id': id,
        'label': label,
        'icon': icon,
        'access': accessType,
      };
    }).toList();

    // Apply user-defined menu order from Kelola Fitur drag-reorder
    if (menuOrder.isNotEmpty) {
      final orderMap = <String, int>{};
      for (var i = 0; i < menuOrder.length; i++) {
        orderMap[menuOrder[i]] = i;
      }
      filteredItems.sort((a, b) {
        final ai = orderMap[a['id'] as String] ?? 999;
        final bi = orderMap[b['id'] as String] ?? 999;
        return ai.compareTo(bi);
      });
    }
    final menuItems = filteredItems;

    // Build card props
    String initials, userName, roleText, attendanceText;
    String? cardPhoto;
    if (_currentName.isNotEmpty) {
      initials = _currentName[0].toUpperCase();
      userName = _currentName;
      roleText = _currentRole;
      cardPhoto = _currentPhotoPath;
      attendanceText = _hasCheckedIn
          ? 'Hadir • $_checkInTime'
          : '⚠️  Belum absen hari ini — buka kasir untuk absen otomatis';
    } else if (_lastCashierName != null) {
      initials = _lastCashierName!.isNotEmpty
          ? _lastCashierName![0].toUpperCase()
          : '?';
      userName = _lastCashierName!;
      roleText = _lastCashierRole;
      cardPhoto = _lastCashierPhoto;
      attendanceText = 'Kasir terakhir • $_lastCashierTime';
    } else {
      initials = '?';
      userName = 'Belum ada sesi kasir';
      roleText = '';
      cardPhoto = null;
      attendanceText = 'Buka Kasir untuk memulai';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header (static)
            DashboardHeader(
              userName: userName,
              role: roleText,
              branch: _storeName,
              hasNotification: !_hasCheckedIn && _currentName.isNotEmpty,
              onBellTap: () {},
            ),

            // Branch selector — bottom sheet picker
            if (_branches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: () => _showBranchPicker(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.store, size: 18, color: NusaConfig.accentPurple.withValues(alpha: 0.8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _activeBranch?.name ?? 'Semua Cabang',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: NusaConfig.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${_branches.length} cabang',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: NusaConfig.accentPurple)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.expand_more, size: 20,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                    ]),
                  ),
                ),
              ),

            // Scrollable content: Profile card + Menu grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async { await _load(); },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Profile card (now interactive — tap to flip)
                      ProfileStatsCard(
                        photoPath: cardPhoto,
                        initials: initials,
                        userName: userName,
                        role: roleText,
                        branch: _storeName,
                        attendanceStatus: attendanceText,
                        salesValue: _omzet,
                        transactionCount: _trxCount,
                        avgValue: _avg,
                        topProduct: _topProduct,
                        // Flip card params
                        viewerRole: role,
                        viewerEmployeeId: session?.employeeId,
                        employeeId: _cardEmployeeId ?? session?.employeeId,
                        cardData: _cardData,
                        onAuthOwner: session?.role != 'Owner'
                            ? () async {
                                // Owner authenticating from non-Owner session
                                final attRepo = AttendanceRepository(
                                    ref.read(databaseProvider));
                                final emps = await attRepo.getEmployees();
                                final owner =
                                    emps.cast<Employee?>().firstWhere(
                                          (e) =>
                                              e!.role == 'Owner' &&
                                              e.status != 'Nonaktif',
                                          orElse: () => null,
                                        );
                                if (owner == null) return false;
                                final result = await PinDialog.show(
                                  context: context,
                                  employeeName: owner.name,
                                  employeeRole: 'Owner',
                                  correctPin: owner.pin,
                                  showRemember: false,
                                  showFingerprint: true,
                                  showNfc: true,
                                  onFingerprint: () async => await _authFingerprint(),
                                  onNfc: () async {
                                    final id = await NfcTagService.readEmployeeTag();
                                    return id?.toString();
                                  },
                                  pinLength: 6,
                                );
                                return result?.success ?? false;
                              }
                            : null,
                        onAbsenMasuk: () {
                          _handlePresensiTap();
                        },
                        onAbsenKeluar: () {
                          _handlePresensiTap();
                        },
                        onKontakWa: () {
                          // Show employee WA list for Owner
                          _showEmployeeWaList();
                        },
                      ),

                      // Keuangan summary card
                      if (_financeExpense > 0 || _financeIncome > 0) ...[
                        const SizedBox(height: 12),
                        _KeuanganSummary(
                          expense: _financeExpense,
                          income: _financeIncome,
                        ),
                      ],

                      // Laundry stats
                      if (NusaConfig.isLaundryVariant && (_laundryToday > 0 || _laundryPending > 0)) ...[
                        const SizedBox(height: 12),
                        _LaundryStats(
                          today: _laundryToday,
                          pending: _laundryPending,
                          ready: _laundryReady,
                          delivered: _laundryDelivered,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Menu grid with lock indicators (responsive columns)
                      LayoutBuilder(builder: (_, constraints) {
                        final w = constraints.maxWidth;
                        final cols = w > 900 ? 5 : (w > 600 ? 4 : 3);
                        final spacing = w > 900 ? 24.0 : 20.0;
                        final pad = w > 900 ? 32.0 : 24.0;
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: 0.72,
                          children: menuItems.map((item) {
                            return _MenuItem(
                              label: item['label'] as String,
                              icon: item['icon'] as String,
                              access: item['access'] as String,
                              onTap: () => _handleMenuTap(item['id'] as String),
                              badgeCount: item['id'] == 'pesanan_online' ? _onlinePending : (item['id'] == 'stok' ? _lowStockCount : null),
                              badgeColor: item['id'] == 'stok' ? NusaConfig.warning : null,
                            );
                          }).toList(),
                        );
                      }),

                      const SizedBox(height: 76), // space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Big prominent floating Kasir button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FloatingActionButton.extended(
            backgroundColor: NusaConfig.activePrimary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.point_of_sale_rounded, size: 24),
            label: const Text('Kasir',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _bukaKasir(),
          ),
        ),
      ),
    );
  }
}

/// Individual menu item with optional PIN-guard indicator.
class _MenuItem extends StatelessWidget {
  final String label;
  final String icon;
  final String access;
  final VoidCallback? onTap;
  final int? badgeCount;
  final Color? badgeColor;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.access,
    this.onTap,
    this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Only PIN-guarded menus (kasir) show a 🔐 indicator; locked menus
    // are now hidden by the caller, so they never reach here.
    final isPinGuarded = access == '🔐';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: MenuIcon(
                  name: icon,
                  size: 72,
                ),
              ),
              // PIN guard badge (kasir only)
              if (isPinGuarded)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: NusaConfig.warning,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark ? NusaConfig.darkBackground : Colors.white,
                          width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child:
                        const Text('🔐', style: TextStyle(fontSize: 8)),
                  ),
                ),
              // Badge (count)
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: badgeColor ?? NusaConfig.activePrimary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isPinGuarded
                  ? (isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary)
                  : (isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _KeuanganSummary extends StatelessWidget {
  final int expense;
  final int income;
  const _KeuanganSummary({required this.expense, required this.income});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final net = income - expense;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: NusaConfig.accentPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 16, color: NusaConfig.accentPurple),
            ),
            const SizedBox(width: 10),
            Text('Keuangan Bulan Ini',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _finStat('Pengeluaran', expense, NusaConfig.activePrimary, isDark),
            const SizedBox(width: 12),
            _finStat('Pemasukan', income, NusaConfig.accentGreen, isDark),
            const SizedBox(width: 12),
            _finStat('Selisih', net, net >= 0 ? NusaConfig.accentGreen : NusaConfig.activePrimary, isDark),
          ]),
        ]),
      ),
    );
  }

  Widget _finStat(String label, int amount, Color color, bool isDark) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formatRupiah(amount > 0 ? amount : 0),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
      ]),
    );
  }
}

/// Laundry mini stats card — shows order pipeline counts.
class _LaundryStats extends StatelessWidget {
  final int today, pending, ready, delivered;
  const _LaundryStats({required this.today, required this.pending, required this.ready, required this.delivered});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFFEC4899).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.local_laundry_service_outlined, color: Color(0xFFEC4899), size: 16),
          ),
          const SizedBox(width: 8),
          const Text('Laundry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _laundryStat('Hari Ini', today, NusaConfig.accentPurple),
          _laundryStat('Diproses', pending, NusaConfig.info),
          _laundryStat('Siap', ready, NusaConfig.success),
          _laundryStat('Diambil', delivered, NusaConfig.activePrimary),
        ]),
      ]),
    );
  }

  Widget _laundryStat(String label, int count, Color color) {
    return Expanded(
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: NusaConfig.textTertiary)),
      ]),
    );
  }
}

/// Menu icon — PNG icons from assets/icons/ (225px), resolved by [iconAssetPath].
class MenuIcon extends StatelessWidget {
  final String name;
  final double size;
  const MenuIcon({super.key, required this.name, this.size = 26});

  @override
  Widget build(BuildContext context) => Image.asset(
        iconAssetPath(name),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.grid_view_rounded, size: size, color: NusaConfig.activePrimary),
      );
}

