import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/sound_service.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/pin_dialog.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';
import 'package:nusa_kasir/shared/services/auth_methods.dart';
import 'package:nusa_kasir/core/utils/wa_phone.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

const _avatarColors = [
  Color(0xFFE63946), Color(0xFF3B82F6), Color(0xFF10B981),
  Color(0xFF8B5CF6), Color(0xFFF59E0B), Color(0xFFEC4899),
  Color(0xFF14B8A6), Color(0xFFF97316),
];
Color _avatarCol(String name) =>
    _avatarColors[name.runes.fold(0, (a, b) => a + b) % _avatarColors.length];

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  int _tab = 0; // 0 = Hari Ini, 1 = Riwayat
  List<Employee> _employees = [];
  Map<int, AttendanceData?> _today = {};
  Map<String, int> _summary = {};
  bool _loading = true;

  // Filter
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _roleFilter = 'Semua';
  final _roleOptions = ['Semua', 'Owner', 'Manager', 'Kasir', 'Gudang', 'Finance'];

  // History state
  int _histYear = DateTime.now().year;
  int _histMonth = DateTime.now().month;
  Map<int, Map<String, dynamic>> _monthlySummary = {};
  Map<String, List<AttendanceData>> _historyGrouped = {};
  bool _histLoading = false;
  int? _selectedEmployeeIdForCalendar;
  DateTime? _selectedCalendarDay;

  bool _showMyEarnings = false;

  final List<String> _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    _load();
    _checkMyEarnings();
  }

  Future<void> _checkMyEarnings() async {
    try {
      if (!NusaConfig.isSalonVariant) return;
      final session = ref.read(employeeSessionProvider);
      if (session == null) return;
      final emps = await AttendanceRepository(ref.read(databaseProvider)).getEmployees();
      Employee? me;
      for (final e in emps) {
        if (e.id == session.employeeId) me = e;
      }
      if (!mounted) return;
      setState(() => _showMyEarnings = me?.isServiceStaff ?? false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = AttendanceRepository(ref.read(databaseProvider));
    final emps = await repo.getEmployees();
    final today = await repo.getAllToday();
    final sum = await repo.getTodaySummary();
    if (!mounted) return;
    setState(() {
      _employees = emps;
      _today = today;
      _summary = sum;
      _loading = false;
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _histLoading = true);
    final repo = AttendanceRepository(ref.read(databaseProvider));
    final list = await repo.getMonthly(month: _histMonth, year: _histYear);

    final grouped = <String, List<AttendanceData>>{};
    for (final a in list) {
      final emp = _employees.cast<Employee?>().firstWhere(
        (e) => e!.id == a.employeeId,
        orElse: () => null,
      );
      final key = emp?.name ?? 'Staf #${a.employeeId}';
      grouped.putIfAbsent(key, () => []).add(a);
    }

    final monthly = await repo.getMonthlySummary(month: _histMonth, year: _histYear);

    if (!mounted) return;
    setState(() {
      _historyGrouped = grouped;
      _monthlySummary = monthly;
      if (_selectedEmployeeIdForCalendar == null && _employees.isNotEmpty) {
        _selectedEmployeeIdForCalendar = _employees.first.id;
      }
      _histLoading = false;
    });
  }

  List<Employee> get _filtered {
    return _employees.where((e) {
      if (_query.isNotEmpty && !e.name.toLowerCase().contains(_query)) return false;
      if (_roleFilter != 'Semua' && e.role != _roleFilter) return false;
      return true;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  UNIFIED BOTTOM SHEET: ABSENSI, CASH & PIN DI DALAM 1 FLOW
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _openAbsenFlow(Employee e, {required bool isCheckIn}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final att = _today[e.id];
    final isCashier = e.role == 'Kasir' || e.requiresCashOpen || e.requiresCashClose;
    final cashCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool obscurePin = true;
    String? errorText;

    final title = isCheckIn ? 'Absen Masuk' : 'Absen Pulang';
    final actionLabel = isCheckIn ? 'Konfirmasi Masuk' : 'Konfirmasi Pulang';
    final cashLabel = isCheckIn ? 'Kas Awal (Modal Laci)' : 'Kas Akhir (Hitung Fisik)';

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Staf Info
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: _avatarCol(e.name).withValues(alpha: 0.15),
                          image: e.photoPath != null && e.photoPath!.isNotEmpty
                              ? DecorationImage(
                                  image: FileImage(File(e.photoPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: (e.photoPath == null || e.photoPath!.isEmpty)
                            ? Text(
                                e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _avatarCol(e.name),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${e.role} • ${e.workStart ?? "08:00"} - ${e.workEnd ?? "17:00"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isCheckIn ? NusaConfig.accentGreen : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCheckIn ? NusaConfig.accentGreen : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Cash input for Cashier
                  if (isCashier) ...[
                    Text(
                      cashLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cashCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 100000',
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                        ),
                        filled: true,
                        fillColor: isDark ? NusaConfig.darkInputFill : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Integrated PIN Input
                  Text(
                    'PIN Karyawan (${e.name})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: obscurePin,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? NusaConfig.darkInputFill : const Color(0xFFF1F5F9),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                        ),
                        onPressed: () => setSheetState(() => obscurePin = !obscurePin),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(
                              color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final pin = pinCtrl.text.trim();
                            if (pin != e.pin) {
                              setSheetState(() => errorText = 'PIN yang dimasukkan salah');
                              HapticFeedback.heavyImpact();
                              return;
                            }

                            final cash = int.tryParse(cashCtrl.text.trim()) ?? 0;
                            final repo = AttendanceRepository(ref.read(databaseProvider));

                            if (isCheckIn) {
                              if (isCashier && cash > 0) {
                                await repo.checkInWithCash(e.id, cash);
                              } else {
                                await repo.checkIn(e.id);
                              }
                            } else {
                              if (isCashier && cash > 0) {
                                await repo.checkOutWithCash(e.id, cash);
                              } else {
                                await repo.checkOut(e.id);
                              }
                            }

                            HapticFeedback.mediumImpact();
                            SoundService.I.play(NusaSound.success);
                            if (mounted) {
                              Navigator.pop(sheetCtx, true);
                              TopToast.success(context, '$actionLabel berhasil!');
                              _load();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCheckIn ? NusaConfig.accentGreen : const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showIzinDialog(Employee e) {
    String selectedReason = 'Izin';
    final noteCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setModal) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catat Izin / Sakit — ${e.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Row(
                children: ['Izin', 'Sakit', 'Cuti'].map((t) {
                  final sel = selectedReason == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: sel,
                      onSelected: (_) => setModal(() => selectedReason = t),
                      selectedColor: NusaConfig.activePrimary.withValues(alpha: 0.15),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  hintText: 'Keterangan opsional...',
                  filled: true,
                  fillColor: isDark ? NusaConfig.darkInputFill : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    final repo = AttendanceRepository(ref.read(databaseProvider));
                    await repo.markTodayStatus(e.id, selectedReason);
                    if (mounted) {
                      TopToast.success(context, 'Status $selectedReason tercatat');
                      _load();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Status', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD SCREEN
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(employeeSessionProvider);
    final isOwner = session?.role == 'Owner' || session?.role == 'Manager';

    return ScreenScaffold(
      'Presensi & Staf',
      Column(
        children: [
          // Segment Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _tabBtn('Hari Ini', 0, isDark),
                  _tabBtn('Riwayat Bulanan', 1, isDark),
                ],
              ),
            ),
          ),

          if (_showMyEarnings)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/pendapatan-saya'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NusaConfig.activePrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payments_rounded, color: NusaConfig.activePrimary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Lihat Rekap Komisi & Pendapatan Saya',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: NusaConfig.activePrimary),
                    ],
                  ),
                ),
              ),
            ),

          Expanded(
            child: _tab == 0 ? _buildTodayTab(isDark, isOwner) : _buildHistoryTab(isDark),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _tab == 0 ? _load() : _loadHistory(),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, int index, bool isDark) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          if (index == 1) _loadHistory();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? (isDark ? NusaConfig.darkSurface2 : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel && !isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel
                  ? (isDark ? NusaConfig.darkTextPrimary : const Color(0xFF0F172A))
                  : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TAB 1: HARI INI (HERO STATS + REDESIGNED STAFF CARD)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTodayTab(bool isDark, bool isOwner) {
    final hadir = _summary['hadir'] ?? 0;
    final total = _employees.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // Hero Today Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _statPill('Hadir Hari Ini', '$hadir / $total', NusaConfig.accentGreen, Icons.how_to_reg_rounded, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statPill('Belum Hadir', '${total - hadir}', const Color(0xFFF59E0B), Icons.schedule_rounded, isDark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _roleOptions.map((r) {
                final sel = _roleFilter == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r),
                    selected: sel,
                    onSelected: (_) => setState(() => _roleFilter = r),
                    selectedColor: NusaConfig.activePrimary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NusaSearchBar(
              controller: _searchCtrl,
              hint: 'Cari nama staf...',
            ),
          ),

          const SizedBox(height: 8),

          // Employee List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(icon: Icons.person_off_outlined, message: 'Tidak ada staf')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildStaffHeroCard(_filtered[i], isDark, isOwner),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String val, Color col, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: col, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? NusaConfig.darkTextPrimary : const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffHeroCard(Employee e, bool isDark, bool isOwner) {
    final att = _today[e.id];
    final isCheckedIn = att?.checkIn != null;
    final isCheckedOut = att?.checkOut != null;
    final isIzin = att?.status == 'Izin' || att?.status == 'Sakit' || att?.status == 'Cuti';

    String statusText;
    Color statusColor;
    if (isIzin) {
      statusText = att?.status ?? 'Izin';
      statusColor = const Color(0xFF3B82F6);
    } else if (isCheckedOut) {
      statusText = 'Selesai (${att?.checkOut})';
      statusColor = const Color(0xFF64748B);
    } else if (isCheckedIn) {
      statusText = 'Bekerja (${att?.checkIn})';
      statusColor = NusaConfig.accentGreen;
    } else {
      statusText = 'Belum Hadir';
      statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _avatarCol(e.name).withValues(alpha: 0.15),
                  image: e.photoPath != null && e.photoPath!.isNotEmpty
                      ? DecorationImage(
                          image: FileImage(File(e.photoPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: (e.photoPath == null || e.photoPath!.isEmpty)
                    ? Text(
                        e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _avatarCol(e.name),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? NusaConfig.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.role,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: NusaConfig.activePrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${e.workStart ?? "08:00"} - ${e.workEnd ?? "17:00"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isIzin
                        ? null
                        : (!isCheckedIn
                            ? () => _openAbsenFlow(e, isCheckIn: true)
                            : (!isCheckedOut
                                ? () => _openAbsenFlow(e, isCheckIn: false)
                                : null)),
                    icon: Icon(
                      !isCheckedIn
                          ? Icons.login_rounded
                          : (!isCheckedOut ? Icons.logout_rounded : Icons.check_circle_rounded),
                      size: 18,
                    ),
                    label: Text(
                      !isCheckedIn
                          ? 'Absen Masuk'
                          : (!isCheckedOut ? 'Absen Pulang' : 'Hadir Lengkap'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isCheckedIn
                          ? NusaConfig.accentGreen
                          : (!isCheckedOut ? const Color(0xFFEF4444) : (isDark ? NusaConfig.darkSurface2 : const Color(0xFFE2E8F0))),
                      foregroundColor: (!isCheckedIn || !isCheckedOut)
                          ? Colors.white
                          : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              if (isOwner && !isCheckedIn && !isIzin) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.event_busy_rounded, size: 18),
                  tooltip: 'Catat Izin/Sakit',
                  onPressed: () => _showIzinDialog(e),
                ),
              ],
              if (isOwner && e.phone != null && e.phone!.isNotEmpty && !isCheckedIn && !isIzin) ...[
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF10B981)),
                  tooltip: 'Chat WA',
                  onPressed: () {
                    final uri = waLink(e.phone!, text: 'Halo ${e.name}, jangan lupa presensi kehadiran hari ini.');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TAB 2: RIWAYAT INTERACTIVE CALENDAR VIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab(bool isDark) {
    if (_histLoading) return const Center(child: CircularProgressIndicator());

    final currentEmp = _employees.cast<Employee?>().firstWhere(
      (e) => e!.id == _selectedEmployeeIdForCalendar,
      orElse: () => _employees.isNotEmpty ? _employees.first : null,
    );

    final attList = currentEmp != null ? (_historyGrouped[currentEmp.name] ?? []) : <AttendanceData>[];
    final dayMap = <int, AttendanceData>{};
    for (final a in attList) {
      dayMap[a.date.day] = a;
    }

    final daysInMonth = DateUtils.getDaysInMonth(_histYear, _histMonth);
    final firstDayWeekday = DateTime(_histYear, _histMonth, 1).weekday; // 1 = Mon, 7 = Sun

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () {
                    if (_histMonth == 1) {
                      setState(() { _histMonth = 12; _histYear--; });
                    } else {
                      setState(() => _histMonth--);
                    }
                    _loadHistory();
                  },
                ),
                Text(
                  '${_monthNames[_histMonth]} $_histYear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? NusaConfig.darkTextPrimary : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    if (_histMonth == 12) {
                      setState(() { _histMonth = 1; _histYear++; });
                    } else {
                      setState(() => _histMonth++);
                    }
                    _loadHistory();
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Employee Horizontal Picker
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _employees.map((e) {
                  final sel = e.id == _selectedEmployeeIdForCalendar;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: _avatarCol(e.name),
                        radius: 10,
                        child: Text(
                          e.name.isNotEmpty ? e.name[0] : '?',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      label: Text(e.name),
                      selected: sel,
                      onSelected: (_) => setState(() => _selectedEmployeeIdForCalendar = e.id),
                      selectedColor: NusaConfig.activePrimary.withValues(alpha: 0.15),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Calendar Card Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? NusaConfig.darkBorder.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  // Weekday Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((w) {
                      return SizedBox(
                        width: 38,
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Calendar Days Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: (firstDayWeekday - 1) + daysInMonth,
                    itemBuilder: (ctx, index) {
                      if (index < firstDayWeekday - 1) {
                        return const SizedBox.shrink();
                      }
                      final day = index - (firstDayWeekday - 2);
                      final att = dayMap[day];

                      Color cellBg = isDark ? NusaConfig.darkSurface2 : const Color(0xFFF8FAFC);
                      Color textColor = isDark ? NusaConfig.darkTextPrimary : const Color(0xFF0F172A);
                      Border? cellBorder;

                      if (att != null) {
                        if (att.status == 'Izin' || att.status == 'Sakit' || att.status == 'Cuti') {
                          cellBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
                          textColor = const Color(0xFF3B82F6);
                        } else if (att.checkIn != null) {
                          cellBg = NusaConfig.accentGreen.withValues(alpha: 0.15);
                          textColor = NusaConfig.accentGreen;
                        }
                      }

                      return InkWell(
                        onTap: att != null
                            ? () {
                                _showDayDetailDialog(currentEmp?.name ?? 'Staf', day, att);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cellBg,
                            borderRadius: BorderRadius.circular(10),
                            border: cellBorder,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              if (att?.checkIn != null)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: textColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayDetailDialog(String empName, int day, AttendanceData att) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Presensi $day ${_monthNames[_histMonth]} — $empName', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Status', att.status ?? 'Hadir'),
            _detailRow('Jam Masuk', att.checkIn ?? '—'),
            _detailRow('Jam Pulang', att.checkOut ?? '—'),
            if (att.pettyCash != null) _detailRow('Kas Awal', formatRupiah(att.pettyCash!)),
            if (att.finalCash != null) _detailRow('Kas Akhir', formatRupiah(att.finalCash!)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
