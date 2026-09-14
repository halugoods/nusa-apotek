/// Apotek: Prescription management with structured medication editor & StageSlider workflow.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/prescription_repository.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/stage_slider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class ResepScreen extends ConsumerStatefulWidget {
  const ResepScreen({super.key});

  @override
  ConsumerState<ResepScreen> createState() => _ResepScreenState();
}

class _ResepScreenState extends ConsumerState<ResepScreen> {
  final List<Map<String, dynamic>> _stages = [
    {'label': 'Baru', 'icon': Icons.fiber_new_rounded, 'color': NusaConfig.info},
    {'label': 'Diproses', 'icon': Icons.hourglass_bottom_rounded, 'color': NusaConfig.warning},
    {'label': 'Siap', 'icon': Icons.check_circle_outline_rounded, 'color': NusaConfig.success},
    {'label': 'Diambil', 'icon': Icons.done_all_rounded, 'color': NusaConfig.textTertiary},
  ];

  List<Prescription> _all = [];
  List<Prescription> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _counts = {};
  int _selectedIdx = 0;

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
    final repo = PrescriptionRepository(db);
    final data = await repo.getAll();
    final counts = <String, int>{};
    for (final s in _stages) {
      final label = s['label'] as String;
      counts[label] = await repo.countByStatus(label);
    }
    if (!mounted) return;
    setState(() {
      _all = data;
      _counts = counts;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase().trim();
    final currentLabel = _stages[_selectedIdx]['label'] as String;
    var list = _all.where((r) => r.status == currentLabel).toList();
    if (q.isNotEmpty) {
      list = list.where((r) =>
        r.patientName.toLowerCase().contains(q) ||
        (r.doctorName ?? '').toLowerCase().contains(q)
      ).toList();
    }
    setState(() => _filtered = list);
  }

  void _selectStage(int idx) {
    if (_selectedIdx == idx) return;
    setState(() => _selectedIdx = idx);
    _applyFilter();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Baru': return NusaConfig.info;
      case 'Diproses': return NusaConfig.warning;
      case 'Siap': return NusaConfig.success;
      case 'Diambil': return NusaConfig.textTertiary;
      default: return NusaConfig.activePrimary;
    }
  }

  String? _nextStatus(String s) {
    const flow = {'Baru': 'Diproses', 'Diproses': 'Siap', 'Siap': 'Diambil'};
    return flow[s];
  }

  List<Map<String, dynamic>> _nextStages(String currentStatus) {
    final next = _nextStatus(currentStatus);
    if (next == null) return [];
    return _stages.where((s) => s['label'] == next).toList();
  }

  Future<void> _advanceStatus(Prescription r) async {
    final next = _nextStatus(r.status);
    if (next == null) return;
    await PrescriptionRepository(ref.read(databaseProvider)).updateStatus(r.id, next);
    if (!mounted) return;
    TopToast.success(context, 'Status → $next ✓');
    _load();
  }

  Future<void> _jumpToStatus(Prescription r, String targetStatus) async {
    await PrescriptionRepository(ref.read(databaseProvider)).updateStatus(r.id, targetStatus);
    if (!mounted) return;
    TopToast.success(context, 'Status → $targetStatus ✓');
    _load();
  }

  void _quickPos(Prescription r) {
    context.push('/kasir', extra: {'bookingCustomer': r.patientName, 'bookingPhone': ''});
    TopToast.success(context, 'Buka kasir untuk ${r.patientName}');
  }

  Future<void> _deleteResep(Prescription r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusLG)),
        title: const Text('Hapus Resep?'),
        content: Text('Hapus resep untuk pasien ${r.patientName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NusaConfig.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PrescriptionRepository(ref.read(databaseProvider)).delete(r.id);
      if (!mounted) return;
      TopToast.success(context, 'Resep dihapus');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageDatas = _stages.map((s) => StageData(
      label: s['label'] as String,
      color: s['color'] as Color,
      count: _counts[s['label']] ?? 0,
    )).toList();

    return ScreenScaffold(
      'Resep Obat',
      _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8),
                // ── Stage Slider ──
                StageSlider(
                  stages: stageDatas,
                  selectedIndex: _selectedIdx,
                  onChanged: _selectStage,
                  isDark: isDark,
                ),
                // ── Counts summary row ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: _stages.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final c = _counts[s['label']] ?? 0;
                      final color = s['color'] as Color;
                      final selected = i == _selectedIdx;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _selectStage(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.18)
                                    : color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: selected
                                    ? Border.all(color: color.withValues(alpha: 0.4), width: 1.2)
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Text('$c', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                                  Text(
                                    s['label'],
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // ── Search bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: NusaSearchBar(
                    controller: _search,
                    hint: 'Cari pasien atau dokter...',
                  ),
                ),
                // ── Header count ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        _stages[_selectedIdx]['label'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_filtered.length} resep',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── List ──
                Expanded(
                  child: _filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.medication_liquid_rounded,
                          message: 'Tidak ada resep ${_stages[_selectedIdx]['label']}.\nTambah resep baru atau pilih tahapan lain.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _resepCard(_filtered[i], isDark),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Resep Baru'),
      ),
    );
  }

  Widget _resepCard(Prescription r, bool isDark) {
    final sc = _statusColor(r.status);
    final nextStages = _nextStages(r.status);
    final initial = r.patientName.isNotEmpty ? r.patientName[0].toUpperCase() : 'P';
    final resepNumber = '#RSP-${r.id.toString().padLeft(3, '0')}';

    List<Map<String, dynamic>> items = [];
    try {
      items = List<Map<String, dynamic>>.from(jsonDecode(r.itemsJson));
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NusaCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: sc),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.patientName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              resepNumber,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (r.doctorName != null && r.doctorName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.local_hospital_rounded, size: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Dr. ${r.doctorName!}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(r.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sc)),
                    ],
                  ),
                ),
                PopupMenuButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  itemBuilder: (_) => [
                    if (_nextStatus(r.status) != null)
                      PopupMenuItem(
                        value: 'next',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(_nextStatus(r.status)!),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'pos',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Buka Kasir'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'next') _advanceStatus(r);
                    if (v == 'pos') _quickPos(r);
                    if (v == 'edit') _openForm(resep: r);
                    if (v == 'delete') _deleteResep(r);
                  },
                ),
              ],
            ),
            // Medication item pills
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_rounded, size: 13, color: NusaConfig.info),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['name'] ?? '',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${item['qty'] ?? 1}x',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                          ),
                        ),
                        if (item['price'] != null && (item['price'] as num) > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatRupiah(item['price']),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: NusaConfig.success),
                          ),
                        ],
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
            // Total cost
            if (r.total > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Biaya Obat',
                    style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  ),
                  Text(
                    formatRupiah(r.total),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.success),
                  ),
                ],
              ),
            ],
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.notes!,
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              ),
            ],
            // Quick advance chips & POS button
            const SizedBox(height: 8),
            Row(
              children: [
                if (nextStages.isNotEmpty) ...[
                  const Icon(Icons.rocket_launch_rounded, size: 13, color: NusaConfig.info),
                  const SizedBox(width: 4),
                  ...nextStages.map((ns) {
                    final nsColor = ns['color'] as Color;
                    return GestureDetector(
                      onTap: () => _jumpToStatus(r, ns['label']),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: nsColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: nsColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          ns['label'],
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: nsColor),
                        ),
                      ),
                    );
                  }),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                    side: BorderSide(color: NusaConfig.activePrimary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _quickPos(r),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                  label: const Text('Kasir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
      ),
    );
  }

  void _openForm({Prescription? resep}) {
    final isEdit = resep != null;
    final patientC = TextEditingController(text: resep?.patientName ?? '');
    final doctorC = TextEditingController(text: resep?.doctorName ?? '');
    final notesC = TextEditingController(text: resep?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    // Parse existing items or start with one empty row
    List<_MedItem> items = [];
    if (resep != null) {
      try {
        final parsed = List<Map<String, dynamic>>.from(jsonDecode(resep.itemsJson));
        items = parsed.map((m) => _MedItem(name: m['name'] ?? '', qty: m['qty'] ?? 1, price: m['price'] ?? 0)).toList();
      } catch (_) {}
    }
    if (items.isEmpty) items.add(_MedItem());

    // Controllers per row
    final ctrls = <Map<String, TextEditingController>>[];
    for (final item in items) {
      ctrls.add({
        'name': TextEditingController(text: item.name),
        'qty': TextEditingController(text: '${item.qty}'),
        'price': TextEditingController(text: item.price > 0 ? '${item.price}' : ''),
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: NusaConfig.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medication_liquid_rounded, color: NusaConfig.info, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isEdit ? 'Edit Resep' : 'Resep Obat Baru', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                Text('Informasi resep dokter dan daftar obat', style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      NusaFormField(
                        label: 'Nama Pasien',
                        controller: patientC,
                        hintText: 'Nama pasien',
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      NusaFormField(
                        label: 'Nama Dokter',
                        controller: doctorC,
                        hintText: 'Contoh: Dr. Budi Santoso (opsional)',
                      ),
                      const SizedBox(height: 16),
                      // Medication items header
                      Row(
                        children: [
                          const Text('Daftar Obat Resep', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setSheet(() {
                              items.add(_MedItem());
                              ctrls.add({
                                'name': TextEditingController(),
                                'qty': TextEditingController(text: '1'),
                                'price': TextEditingController(),
                              });
                            }),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Tambah Obat', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final c = ctrls[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(flex: 3, child: NusaInput('Nama Obat', controller: c['name'], hint: 'Contoh: Amoxicillin', maxLines: 1)),
                                const SizedBox(width: 6),
                                SizedBox(width: 54, child: NusaInput('Qty', controller: c['qty'], hint: '1', type: TextInputType.number, maxLines: 1)),
                                const SizedBox(width: 6),
                                SizedBox(width: 90, child: NusaInput('Harga', controller: c['price'], hint: 'Rp', type: TextInputType.number, maxLines: 1)),
                                if (items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () => setSheet(() {
                                      items.removeAt(idx);
                                      ctrls.removeAt(idx);
                                    }),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      NusaFormField(label: 'Aturan Pakai / Catatan', controller: notesC, hintText: 'Contoh: 3x sehari sesudah makan...', maxLines: 2),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NusaConfig.activePrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final result = <Map<String, dynamic>>[];
                            var total = 0;
                            for (var i = 0; i < items.length; i++) {
                              final name = ctrls[i]['name']!.text.trim();
                              if (name.isEmpty) continue;
                              final qty = int.tryParse(ctrls[i]['qty']!.text) ?? 1;
                              final price = int.tryParse(ctrls[i]['price']!.text) ?? 0;
                              result.add({'name': name, 'qty': qty, 'price': price});
                              total += qty * price;
                            }
                            if (result.isEmpty) {
                              TopToast.error(context, 'Minimal 1 obat harus diisi');
                              return;
                            }
                            final itemsJson = jsonEncode(result);
                            final db = ref.read(databaseProvider);
                            final repo = PrescriptionRepository(db);
                            if (isEdit) {
                              TopToast.success(context, 'Resep diperbarui ✓');
                            } else {
                              await repo.add(
                                patientName: patientC.text.trim(),
                                doctorName: doctorC.text.trim().isEmpty ? null : doctorC.text.trim(),
                                itemsJson: itemsJson,
                                total: total,
                                notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                              );
                              if (mounted) {
                                TopToast.success(context, 'Resep baru ditambahkan ✓');
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          },
                          child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Resep'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MedItem {
  String name;
  int qty;
  int price;
  _MedItem({this.name = '', this.qty = 1, this.price = 0});
}
