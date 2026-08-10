/// Salon: Appointment booking with stylist slot view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/appointment_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/stage_slider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

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

  // Month/date navigation
  DateTime _selectedDate = DateTime.now();

  String _bulan(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][m];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
            // ── Date strip ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
              ),
              child: Row(children: [
                Text('${_bulan(_selectedDate.month)} ${_selectedDate.year}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1)), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (_, i) {
                      final d = _selectedDate.add(Duration(days: i));
                      final sel = d.day == _selectedDate.day && d.month == _selectedDate.month && d.year == _selectedDate.year;
                      final isNow = d.day == now.day && d.month == now.month && d.year == now.year;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDate = d),
                        child: Container(
                          width: 40, height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: sel ? NusaConfig.activePrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isNow && !sel ? Border.all(color: NusaConfig.activePrimary.withOpacity(0.3), width: 1.5) : null,
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${d.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
                            Text(const ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][d.weekday], style: TextStyle(fontSize: 8, color: sel ? Colors.white70 : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1)), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
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
            // ── Search ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                Text(a.customerPhone!, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
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
    final serviceC = TextEditingController(text: appointment?.service ?? '');
    final stylistC = TextEditingController(text: appointment?.stylist ?? '');
    final notesC = TextEditingController(text: appointment?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime date = appointment?.date ?? DateTime.now();
    final timeSlotCtrl = TextEditingController(text: appointment?.timeSlot ?? '09:00');
    int selectedDuration = appointment?.estimatedDuration ?? 60;

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
            Expanded(child: Text(isEdit ? 'Edit Booking' : 'Booking Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            if (bookingNumber != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: NusaConfig.activePrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(bookingNumber!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
              ),
          ]),
          const SizedBox(height: 16),
          NusaFormField(label: 'Nama Pelanggan', controller: nameC, hintText: 'Nama pelanggan', validator: (v) => v == null || v!.isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 12),
          NusaFormField(label: 'No. Telepon', controller: phoneC, hintText: 'Contoh: 0812-3456-7890', keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          NusaFormField(label: 'Layanan', controller: serviceC, hintText: 'Contoh: Haircut, Coloring, Creambath', validator: (v) => v == null || v!.isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 12),
          NusaFormField(label: 'Stylist', controller: stylistC, hintText: 'Nama stylist (opsional)'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async { final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) { setModalState(() => date = d); } },
                child: NusaFormField(label: 'Tanggal', controller: TextEditingController(text: '${date.day}/${date.month}/${date.year}'), hintText: 'Pilih tanggal', readOnly: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NusaFormField(
                label: 'Jam',
                controller: timeSlotCtrl,
                hintText: 'HH:mm',
                keyboardType: TextInputType.datetime,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Estimated duration dropdown
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Estimasi Durasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textPrimary)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
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
          ]),
          const SizedBox(height: 12),
          NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final db = ref.read(databaseProvider);
              final repo = AppointmentRepository(db);
              final nextCounter = isEdit ? (appointment?.counterId) : await repo.getNextCounter(date);
              if (isEdit && appointment != null) {
                await db.update(db.appointments).replace(appointment.copyWith(
                  customerName: nameC.text.trim(),
                  customerPhone: Value(phoneC.text.trim().isEmpty ? null : phoneC.text.trim()),
                  service: serviceC.text.trim(),
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
                  service: serviceC.text.trim(),
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
