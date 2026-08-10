/// Salon: Appointment booking calendar with stylist slot view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/appointment_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Semua', 'Dikonfirmasi', 'Datang', 'Menunggu', 'Selesai', 'Batal'];
  List<Appointment> _all = [];
  List<Appointment> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _counts = {};
  DateTime _selectedDate = DateTime.now();

  // Bulk selection
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  String _bulan(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][m];
  String _hari(int w) => const ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][w];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) _applyFilter(); });
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final repo = AppointmentRepository(db);
    final data = await repo.getAll();
    final counts = <String, int>{};
    for (final s in _tabs) {
      if (s == 'Semua') { counts[s] = data.length; } else { counts[s] = await repo.countByStatus(s); }
    }
    if (!mounted) return;
    setState(() { _all = data; _counts = counts; _loading = false; });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    final idx = _tabController.index;
    var list = _all;
    if (idx > 0) list = list.where((a) => a.status == _tabs[idx]).toList();
    if (q.isNotEmpty) list = list.where((a) => a.customerName.toLowerCase().contains(q) || (a.customerPhone ?? '').contains(q) || a.service.toLowerCase().contains(q)).toList();
    setState(() => _filtered = list);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Dikonfirmasi': return NusaConfig.info;
      case 'Datang': return NusaConfig.accentGreen;
      case 'Menunggu': return NusaConfig.warning;
      case 'Selesai': return NusaConfig.success;
      case 'Batal': return Colors.red;
      default: return NusaConfig.activePrimary;
    }
  }

  String? _nextStatus(String s) {
    const flow = {'Dikonfirmasi': 'Datang', 'Datang': 'Menunggu', 'Menunggu': 'Selesai'};
    return flow[s];
  }

  Future<void> _advanceStatus(Appointment a) async {
    final next = _nextStatus(a.status);
    if (next == null) return;
    await AppointmentRepository(ref.read(databaseProvider)).updateStatus(a.id, next);
    TopToast.success(context, 'Status → $next ✓');
    _load();
  }

  Future<void> _advanceSelected() async {
    if (_selectedIds.isEmpty) return;
    final db = ref.read(databaseProvider);
    final repo = AppointmentRepository(db);
    int updated = 0;
    for (final id in _selectedIds) {
      final a = _all.firstWhere((x) => x.id == id);
      final next = _nextStatus(a.status);
      if (next != null) {
        await repo.updateStatus(id, next);
        updated++;
      }
    }
    if (mounted) {
      TopToast.success(context, '$updated booking dilanjutkan ✓');
      setState(() { _selectionMode = false; _selectedIds.clear(); });
      _load();
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

  void _cetakAntrian(Appointment a) {
    // Compact receipt-style print for salon queue ticket
    TopToast.success(context, 'Cetak antrian #BKG-${a.counterId?.toString().padLeft(3, '0') ?? a.id.toString().padLeft(3, '0')}');
    // TODO: integrate with ReceiptPrinter.printBookingTicket() when thermal printer is connected
  }

  void _quickPos(Appointment a) {
    context.push('/kasir', extra: {'bookingCustomer': a.customerName, 'bookingPhone': a.customerPhone});
    TopToast.success(context, 'Buka kasir untuk ${a.customerName}');
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

  // ── Bulk selection toolbar ──

  Widget? _selectionToolbar(bool isDark) {
    if (!_selectionMode) return null;
    final canAdvance = _selectedIds.any((id) {
      final a = _all.firstWhere((x) => x.id == id);
      return _nextStatus(a.status) != null;
    });
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NusaConfig.activePrimary.withOpacity(0.1),
      child: Row(children: [
        Text('${_selectedIds.length} dipilih', style: TextStyle(fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
        const Spacer(),
        if (canAdvance)
          TextButton.icon(
            onPressed: _advanceSelected,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Lanjutkan'),
            style: TextButton.styleFrom(foregroundColor: NusaConfig.success),
          ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => setState(() { _selectionMode = false; _selectedIds.clear(); }),
          child: const Text('Batal'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold('Booking', Column(children: [
      // Selection toolbar
      if (_selectionToolbar(isDark) != null) _selectionToolbar(isDark)!,
      // Month + nav
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text('${_bulan(_selectedDate.month)} ${_selectedDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () { setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1)); }),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1)); }),
        ]),
      ),
      // Date strip
      SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 14,
          itemBuilder: (_, i) {
            final d = _selectedDate.add(Duration(days: i));
            final sel = d.day == DateTime.now().day && d.month == DateTime.now().month && d.year == DateTime.now().year;
            return GestureDetector(
              onTap: () { setState(() { _selectedDate = d; }); _applyFilter(); },
              child: Container(
                width: 52, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: sel ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_hari(d.weekday), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
                  Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
                ]),
              ),
            );
          },
        ),
      ),
      // Tab bar
      Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
        child: TabBar(
          controller: _tabController, isScrollable: true,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(color: NusaConfig.activePrimary, borderRadius: BorderRadius.circular(10)),
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textTertiary,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.all(4),
          tabs: _tabs.map((t) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(t),
            if ((_counts[t] ?? 0) > 0) ...[const SizedBox(width: 3), Text('${_counts[t]}', style: const TextStyle(fontSize: 10))],
          ]))).toList(),
        ),
      ),
      // Search
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_available, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                    const SizedBox(height: 16),
                    Text('Belum ada booking', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
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

  Widget _bookingCard(Appointment a, bool isDark) {
    final sc = _statusColor(a.status);
    final isSel = _selectedIds.contains(a.id);
    final finishTime = a.estimatedDuration != null ? _formatFinishTime(a.timeSlot, a.estimatedDuration) : null;
    final bookingNum = a.counterId != null ? '#BKG-${a.counterId.toString().padLeft(3, '0')}' : '#${a.id}';

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selectedIds.add(a.id);
        });
      },
      onTap: _selectionMode
          ? () {
              setState(() {
                if (isSel) {
                  _selectedIds.remove(a.id);
                  if (_selectedIds.isEmpty) _selectionMode = false;
                } else {
                  _selectedIds.add(a.id);
                }
              });
            }
          : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isSel ? BorderSide(color: NusaConfig.activePrimary, width: 2) : BorderSide.none,
        ),
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Checkbox (selection mode)
            if (_selectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(isSel ? Icons.check_circle : Icons.circle_outlined, color: isSel ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ),
            // Date box
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: NusaConfig.activePrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${a.date.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
                Text('${a.timeSlot}', style: TextStyle(fontSize: 11, color: NusaConfig.activePrimary)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(a.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(bookingNum, style: TextStyle(fontSize: 10, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                ]),
                if (a.customerPhone != null && a.customerPhone!.isNotEmpty)
                  Text(a.customerPhone!, style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: NusaConfig.info.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(a.service, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: NusaConfig.info))),
                  if (a.stylist != null) ...[const SizedBox(width: 6), Text('👤 ${a.stylist}', style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))],
                ]),
                if (finishTime != null) ...[
                  const SizedBox(height: 2),
                  Text(finishTime, style: TextStyle(fontSize: 10, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                ],
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(a.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
            ),
            if (!_selectionMode)
              PopupMenuButton(
                itemBuilder: (_) => [
                  if (a.status != 'Selesai' && a.status != 'Batal') const PopupMenuItem(value: 'next', child: Text('▶ Lanjutkan')),
                  const PopupMenuItem(value: 'pos', child: Text('🛒 Buat Pesanan')),
                  const PopupMenuItem(value: 'print', child: Text('🖨 Cetak Antrian')),
                  const PopupMenuItem(value: 'edit', child: Text('✏ Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('🗑 Hapus', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (v) {
                  if (v == 'next') _advanceStatus(a);
                  if (v == 'pos') _quickPos(a);
                  if (v == 'print') _cetakAntrian(a);
                  if (v == 'edit') _openForm(appointment: a);
                  if (v == 'delete') _deleteBooking(a);
                },
              ),
          ]),
        ),
      ),
    );
  }

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
                // Edit: update existing
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
