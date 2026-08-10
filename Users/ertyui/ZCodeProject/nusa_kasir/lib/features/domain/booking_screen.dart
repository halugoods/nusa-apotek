/// Salon: Appointment booking with stylist slot view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/appointment_repository.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/shared/widgets/customer_picker_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/stage_slider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final List<Map<String, dynamic>> _stages = [
    {'label': 'Dikonfirmasi', 'icon': Icons.event_available, 'color': NusaConfig.info},
    {'label': 'Datang', 'icon': Icons.login_rounded, 'color': NusaConfig.accentGreen},
    {'label': 'Menunggu', 'icon': Icons.hourglass_bottom, 'color': NusaConfig.warning},
    {'label': 'Selesai', 'icon': Icons.check_circle, 'color': NusaConfig.success},
    {'label': 'Batal', 'icon': Icons.cancel, 'color': Colors.red},
  ];
  List<Appointment> _all = [];
  List<Appointment> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _counts = {};
  int _selectedIdx = 0;
  List<String> _stylists = [];
  bool _stylistsLoading = true;

  // Month/date navigation
  DateTime _selectedDate = DateTime.now();

  String _bulan(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][m];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
    _loadStylists();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Stylist options come from the Karyawan system — all active staff,
  /// filtered by the salon's default working roles (Owner, Manager,
  /// Kasir, Finance) + any custom roles the user added.
  Future<void> _loadStylists() async {
    final emps = await AttendanceRepository(ref.read(databaseProvider)).getEmployees();
    const excluded = {'Gudang'};
    final names = emps.where((e) => !excluded.contains(e.role)).map((e) => e.name.trim()).where((n) => n.isNotEmpty).toSet();
    if (!mounted) return;
    setState(() {
      _stylists = names.toList()..sort();
      _stylistsLoading = false;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final repo = AppointmentRepository(db);
    final data = await repo.getAll();
    final counts = <String, int>{};
    for (final stage in _stages) {
      counts[stage['label']] = await repo.countByStatus(stage['label']);
    }
    if (!mounted) return;
    setState(() { _all = data; _counts = counts; _loading = false; });
    _applyFilter();
  }

  void _selectStage(int idx) {
    setState(() => _selectedIdx = idx);
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    final stageLabel = _stages[_selectedIdx]['label'] as String;
    var list = _all.where((a) => a.status == stageLabel).toList();
    if (q.isNotEmpty) list = list.where((a) => a.customerName.toLowerCase().contains(q) || (a.customerPhone ?? '').contains(q) || a.service.toLowerCase().contains(q)).toList();
    setState(() => _filtered = list);
  }

  // ── Stage flow helpers ──────────────────────────────────────────────

  String? _nextStatus(String s) {
    const flow = {'Dikonfirmasi': 'Datang', 'Datang': 'Menunggu', 'Menunggu': 'Selesai'};
    return flow[s];
  }

  List<Map<String, dynamic>> _nextStages(Appointment a) {
    final result = <Map<String, dynamic>>[];
    var current = a.status;
    for (int i = 0; i < 3; i++) {
      final next = _nextStatus(current);
      if (next == null) break;
      final stage = _stages.firstWhere((s) => s['label'] == next, orElse: () => _stages[0]);
      result.add(stage);
      current = next;
    }
    return result;
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _jumpToStatus(Appointment a, String targetStatus) async {
    await AppointmentRepository(ref.read(databaseProvider)).updateStatus(a.id, targetStatus);
    TopToast.success(context, 'Status → $targetStatus');
    _load();
  }

  Future<void> _advanceStatus(Appointment a) async {
    final next = _nextStatus(a.status);
    if (next == null) return;
    await AppointmentRepository(ref.read(databaseProvider)).updateStatus(a.id, next);
    TopToast.success(context, 'Status → $next');
    _load();
  }

  void _quickPos(Appointment a) {
    context.push('/kasir', extra: {'bookingCustomer': a.customerName, 'bookingPhone': a.customerPhone});
    TopToast.success(context, 'Buka kasir untuk ${a.customerName}');
  }

  /// Tap-to-call pelanggan (pola suppliers_screen).
  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      TopToast.error(context, 'Tidak bisa membuka dialer');
    }
  }

  Future<void> _deleteBooking(Appointment a) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Booking?'), content: Text('Booking ${a.customerName} — ${a.service}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) { await AppointmentRepository(ref.read(databaseProvider)).delete(a.id); TopToast.success(context, 'Booking dihapus'); _load(); }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = _selectedDate.day == now.day && _selectedDate.month == now.month && _selectedDate.year == now.year;

    final stageDatas = _stages.map((s) => StageData(
      label: s['label'] as String,
      color: s['color'] as Color,
      count: _counts[s['label']] ?? 0,
    )).toList();

    return ScreenScaffold('Booking', _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // ── Date strip: scrollable full month + month dropdown ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
              ),
              child: Column(children: [
                // Month/Year dropdown row
                Row(children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDialog<DateTime>(context: context, builder: (ctx) {
                        final months = List.generate(12, (i) => DateTime(_selectedDate.year, i + 1, 1));
                        return SimpleDialog(
                          title: Text('${_selectedDate.year}', textAlign: TextAlign.center),
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                                Navigator.pop(ctx);
                                showDialog(context: context, builder: (_) {
                                  final prevMonths = List.generate(12, (i) => DateTime(_selectedDate.year - 1, i + 1, 1));
                                  return _MonthYearPicker(months: prevMonths, onPick: (d) => Navigator.pop(context, d));
                                });
                              }),
                              Text('${_selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                                Navigator.pop(ctx);
                                showDialog(context: context, builder: (_) {
                                  final nextMonths = List.generate(12, (i) => DateTime(_selectedDate.year + 1, i + 1, 1));
                                  return _MonthYearPicker(months: nextMonths, onPick: (d) => Navigator.pop(context, d));
                                });
                              }),
                            ]),
                            ...List.generate(3, (row) => Row(children: List.generate(4, (col) {
                              final idx = row * 4 + col;
                              if (idx >= 12) return const Spacer();
                              final m = months[idx];
                              final isSel = m.month == _selectedDate.month && m.year == _selectedDate.year;
                              return Expanded(child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Material(
                                  color: isSel ? NusaConfig.activePrimary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => Navigator.pop(ctx, m),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(_bulan(m.month), textAlign: TextAlign.center, style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: isSel ? Colors.white : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                                      )),
                                    ),
                                  ),
                                ),
                              ));
                            }))),
                          ],
                        );
                      });
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${_bulan(_selectedDate.month)} ${_selectedDate.year}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                    ]),
                  ),
                  const Spacer(),
                  // Quick jump to today
                  if (!isToday)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = now),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: NusaConfig.activePrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Hari ini', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
                      ),
                    ),
                ]),
                // Scrollable date strip — all dates in selected month
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day,
                    itemBuilder: (_, i) {
                      final day = i + 1;
                      final d = DateTime(_selectedDate.year, _selectedDate.month, day);
                      final sel = d.day == _selectedDate.day && d.month == _selectedDate.month && d.year == _selectedDate.year;
                      final isNow = d.day == now.day && d.month == now.month && d.year == now.year;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDate = d),
                        child: Container(
                          width: 40, height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: sel ? NusaConfig.activePrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isNow && !sel ? Border.all(color: NusaConfig.activePrimary.withOpacity(0.4), width: 1.5) : null,
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
                            Text(const ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][d.weekday], style: TextStyle(fontSize: 7, color: sel ? Colors.white70 : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            // ── Stage Slider ──
            StageSlider(
              stages: stageDatas,
              selectedIndex: _selectedIdx,
              onChanged: _selectStage,
              isDark: isDark,
            ),
            // ── Counts summary ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: _stages.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final c = _counts[s['label']] ?? 0;
                final color = s['color'] as Color;
                final selected = i == _selectedIdx;
                return Expanded(child: GestureDetector(
                  onTap: () => _selectStage(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? color.withOpacity(0.18) : color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: selected ? Border.all(color: color.withOpacity(0.4), width: 1.2) : null,
                      ),
                      child: Column(children: [
                        Text('$c', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                        Text(s['label'], style: TextStyle(fontSize: 9, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                      ]),
                    ),
                  ),
                ));
              }).toList()),
            ),
            // ── Search with contact picker ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau layanan...', hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true, fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CustomerPickerButton(
                  onPick: (r) {
                    if (!mounted) return;
                    final q = r.phone.isNotEmpty ? r.phone : r.name;
                    if (q.isNotEmpty) {
                      _search.text = q;
                      _applyFilter();
                      setState(() {});
                    }
                  },
                ),
              ]),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(_stages[_selectedIdx]['label'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${_filtered.length} booking', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              ]),
            ),
            // List
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.content_cut_rounded, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      const SizedBox(height: 16),
                      Text('Tidak ada booking ${_stages[_selectedIdx]['label']}', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _bookingCard(_filtered[i], isDark),
                    ),
            ),
          ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Booking Baru'),
      ),
    );
  }

  String _formatFinishTime(String timeSlot, int? estDuration) {
    if (estDuration == null) return '';
    try {
      final parts = timeSlot.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final finish = DateTime(2024, 1, 1, h, m).add(Duration(minutes: estDuration));
      return 'Selesai ~${finish.hour.toString().padLeft(2, '0')}:${finish.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _bookingCard(Appointment a, bool isDark) {
    final stage = _stages.firstWhere((s) => s['label'] == a.status, orElse: () => _stages[0]);
    final color = stage['color'] as Color;
    final bookingLabel = a.counterId != null ? '#BKG-${a.counterId.toString().padLeft(3, '0')}' : '#${a.id}';
    final nextStages = _nextStages(a);
    final finishTime = a.estimatedDuration != null ? _formatFinishTime(a.timeSlot, a.estimatedDuration) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(stage['icon'] as IconData, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(a.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                Text(bookingLabel, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ]),
              if (a.customerPhone != null && a.customerPhone!.isNotEmpty)
                GestureDetector(
                  onTap: () => _callCustomer(a.customerPhone!),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.phone_outlined, size: 11, color: NusaConfig.activePrimary),
                    const SizedBox(width: 4),
                    Text(a.customerPhone!, style: TextStyle(fontSize: 11, color: NusaConfig.activePrimary)),
                  ]),
                ),
            ])),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (_nextStatus(a.status) != null) PopupMenuItem(value: 'next', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_forward_rounded, size: 18), const SizedBox(width: 8), Text(_nextStatus(a.status)!),
                ])),
                const PopupMenuItem(value: 'pos', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_cart_rounded, size: 18), SizedBox(width: 8), Text('Buat Pesanan'),
                ])),
                const PopupMenuItem(value: 'edit', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red)),
                ])),
              ],
              onSelected: (v) {
                if (v == 'next') _advanceStatus(a);
                if (v == 'pos') _quickPos(a);
                if (v == 'edit') _openForm(appointment: a);
                if (v == 'delete') _deleteBooking(a);
              },
            ),
          ]),
          // ── Service chips ──
          if (a.service.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(a.service, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ),
                if (a.stylist != null && a.stylist!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill, borderRadius: BorderRadius.circular(6)),
                    child: Text('👤 ${a.stylist}', style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
          // ── Estimate + time slot ──
          if (finishTime != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule, size: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              const SizedBox(width: 4),
              Text('${a.timeSlot} → $finishTime', style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              if (a.estimatedDuration != null) ...[
                const SizedBox(width: 6),
                Text('${a.estimatedDuration} mnt', style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              ],
            ]),
          ] else if (a.timeSlot.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.schedule, size: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              const SizedBox(width: 4),
              Text(a.timeSlot, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            ]),
          ] else ...[
            const SizedBox(height: 4),
            Text('${a.date.day}/${a.date.month}/${a.date.year}', style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
          ],
          if (a.notes != null && a.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(a.notes!, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
          ],
          // ── Quick status update chips ──
          if (nextStages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.rocket_launch_rounded, size: 13, color: NusaConfig.info),
              const SizedBox(width: 6),
              Text('Update:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              const SizedBox(width: 6),
              ...nextStages.map((ns) {
                final nsColor = ns['color'] as Color;
                return GestureDetector(
                  onTap: () => _jumpToStatus(a, ns['label']),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: nsColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: nsColor.withOpacity(0.3)),
                    ),
                    child: Text(ns['label'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: nsColor)),
                  ),
                );
              }),
            ]),
          ],
        ]),
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────

  Future<void> _openForm({Appointment? appointment}) async {
    final isEdit = appointment != null;
    final nameC = TextEditingController(text: appointment?.customerName ?? '');
    final phoneC = TextEditingController(text: appointment?.customerPhone ?? '');
    final stylistC = TextEditingController(text: appointment?.stylist ?? '');
    final notesC = TextEditingController(text: appointment?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime date = appointment?.date ?? DateTime.now();
    final timeSlotCtrl = TextEditingController(text: appointment?.timeSlot ?? '09:00');
    int selectedDuration = appointment?.estimatedDuration ?? 60;

    // Services items (like laundry items editor)
    List<_ServiceItem> items = [];
    if (appointment != null && appointment.service.isNotEmpty) {
      final parts = appointment.service.split(', ');
      items = parts.map((p) => _ServiceItem(name: p.trim())).toList();
    }
    if (items.isEmpty) items.add(_ServiceItem());

    final itemControllers = <Map<String, TextEditingController>>[];
    for (final item in items) {
      itemControllers.add({'name': TextEditingController(text: item.name)});
    }

    // Generate booking number for new bookings
    String? bookingNumber;
    if (!isEdit) {
      final db = ref.read(databaseProvider);
      final repo = AppointmentRepository(db);
      final nextId = await repo.getNextCounter(date);
      bookingNumber = '#BKG-${nextId.toString().padLeft(3, '0')}';
    }

    if (!mounted) return;

    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return StatefulBuilder(builder: (ctx, setModalState) {
        return Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: NusaConfig.info.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.event_available, color: NusaConfig.info, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'Edit Booking' : 'Booking Baru', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (bookingNumber != null)
                Text(bookingNumber!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
            ])),
          ]),
          const SizedBox(height: 18),
          NusaInput('Nama Pelanggan', controller: nameC, hint: 'Nama pelanggan'),
          const SizedBox(height: 12),
          NusaInput('No. Telepon', controller: phoneC, type: TextInputType.phone, hint: 'Contoh: 0812-3456-7890'),
          const SizedBox(height: 16),
          // ── Services editor ──
          Row(children: [
            const Text('Layanan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setModalState(() { items.add(_ServiceItem()); itemControllers.add({'name': TextEditingController()}); }),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Layanan', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final ctrls = itemControllers[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: NusaInput('Layanan ${idx + 1}', controller: ctrls['name'], hint: 'Contoh: Haircut, Coloring')),
                if (items.length > 1)
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setModalState(() { items.removeAt(idx); itemControllers.removeAt(idx); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              ]),
            );
          }),
          const SizedBox(height: 4),
          Divider(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
          const SizedBox(height: 12),
          // ── Stylist (from Karyawan) ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: NusaConfig.accentGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.person, color: NusaConfig.accentGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stylistsLoading
                  ? Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('Memuat stylist...', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _stylists.contains(stylistC.text) ? stylistC.text : null,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                          style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                          hint: Text('Pilih stylist (opsional)', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Pilih stylist (opsional)')),
                            ..._stylists.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                          ],
                          onChanged: (v) => setModalState(() => stylistC.text = v ?? ''),
                        ),
                      ),
                    ),
            ),
          ]),
          if (_stylists.isNotEmpty == false && !_stylistsLoading) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.info_outline, size: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              const SizedBox(width: 4),
              Expanded(child: Text('Belum ada karyawan. Tambah di menu Karyawan agar bisa jadi stylist.',
                style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary))),
            ]),
          ],
          const SizedBox(height: 12),
          // ── Date + Time ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: NusaConfig.info.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.calendar_today, color: NusaConfig.info, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async { final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) { setModalState(() => date = d); } },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                ),
                child: TextField(
                  controller: timeSlotCtrl,
                  keyboardType: TextInputType.datetime,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                  decoration: const InputDecoration.collapsed(hintText: 'HH:mm'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // ── Duration ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: NusaConfig.warningSoft, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.timer, color: NusaConfig.warning, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedDuration,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                    style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30 menit')),
                      DropdownMenuItem(value: 45, child: Text('45 menit')),
                      DropdownMenuItem(value: 60, child: Text('60 menit (1 jam)')),
                      DropdownMenuItem(value: 90, child: Text('90 menit')),
                      DropdownMenuItem(value: 120, child: Text('120 menit (2 jam)')),
                    ],
                    onChanged: (v) { if (v != null) setModalState(() => selectedDuration = v); },
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              // Collect services from items
              final validItems = <String>[];
              for (var i = 0; i < items.length; i++) {
                final name = itemControllers[i]['name']!.text.trim();
                if (name.isNotEmpty) validItems.add(name);
              }
              if (validItems.isEmpty) { TopToast.error(context, 'Minimal 1 layanan'); return; }
              final serviceText = validItems.join(', ');

              final db = ref.read(databaseProvider);
              final repo = AppointmentRepository(db);
              final nextCounter = isEdit ? (appointment?.counterId) : await repo.getNextCounter(date);
              if (isEdit && appointment != null) {
                await db.update(db.appointments).replace(appointment.copyWith(
                  customerName: nameC.text.trim(),
                  customerPhone: Value(phoneC.text.trim().isEmpty ? null : phoneC.text.trim()),
                  service: serviceText,
                  stylist: Value(stylistC.text.trim().isEmpty ? null : stylistC.text.trim()),
                  date: date,
                  timeSlot: timeSlotCtrl.text,
                  notes: Value(notesC.text.trim().isEmpty ? null : notesC.text.trim()),
                  estimatedDuration: Value(selectedDuration),
                ));
                TopToast.success(context, 'Booking diperbarui ✓');
              } else {
                await repo.add(
                  customerName: nameC.text.trim(),
                  customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                  service: serviceText,
                  stylist: stylistC.text.trim().isEmpty ? null : stylistC.text.trim(),
                  date: date,
                  timeSlot: timeSlotCtrl.text,
                  notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                  estimatedDuration: selectedDuration,
                  counterId: nextCounter,
                );
                TopToast.success(context, 'Booking baru ditambahkan ✓');
              }
              Navigator.pop(ctx);
              _load();
            },
            child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Booking'),
          )),
          const SizedBox(height: 8),
        ]))));
      });
    });
  }
}

class _ServiceItem { String name; _ServiceItem({this.name = ''}); }

/// Simple month/year grid picker dialog content.
class _MonthYearPicker extends StatelessWidget {
  final List<DateTime> months;
  final void Function(DateTime) onPick;
  const _MonthYearPicker({required this.months, required this.onPick});

  String _bulan(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][m];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SimpleDialog(
      title: Text('${months.first.year}', textAlign: TextAlign.center),
      children: List.generate(3, (row) => Row(children: List.generate(4, (col) {
        final idx = row * 4 + col;
        if (idx >= 12) return const Spacer();
        final m = months[idx];
        return Expanded(child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPick(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_bulan(m.month), textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                )),
              ),
            ),
          ),
        ));
      }))),
    );
  }
}
