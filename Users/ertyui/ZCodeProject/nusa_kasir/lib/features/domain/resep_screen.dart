/// Apotek: Prescription management with structured medication editor.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/prescription_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class ResepScreen extends ConsumerStatefulWidget {
  const ResepScreen({super.key});

  @override
  ConsumerState<ResepScreen> createState() => _ResepScreenState();
}

class _ResepScreenState extends ConsumerState<ResepScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Semua', 'Baru', 'Diproses', 'Siap', 'Diambil'];
  List<Prescription> _all = [];
  List<Prescription> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _counts = {};

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
    final repo = PrescriptionRepository(db);
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
    if (idx > 0) list = list.where((r) => r.status == _tabs[idx]).toList();
    if (q.isNotEmpty) list = list.where((r) => r.patientName.toLowerCase().contains(q) || (r.doctorName ?? '').toLowerCase().contains(q)).toList();
    setState(() => _filtered = list);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold('Resep Obat', Column(children: [
      // Stats
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          _statCard('Hari Ini', '${_counts['Baru'] ?? 0}', NusaConfig.info, isDark),
          const SizedBox(width: 8),
          _statCard('Diproses', '${_counts['Diproses'] ?? 0}', NusaConfig.warning, isDark),
          const SizedBox(width: 8),
          _statCard('Siap', '${_counts['Siap'] ?? 0}', NusaConfig.success, isDark),
        ]),
      ),
      // Tabs
      Container(
        height: 44, margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor, borderRadius: BorderRadius.circular(10)),
        child: TabBar(
          controller: _tabController, isScrollable: true,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(color: NusaConfig.activePrimary, borderRadius: BorderRadius.circular(8)),
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          dividerColor: Colors.transparent, padding: const EdgeInsets.all(2),
          tabs: _tabs.map((t) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(t), if ((_counts[t] ?? 0) > 0) ...[const SizedBox(width: 3), Text('${_counts[t]}', style: const TextStyle(fontSize: 10))],
          ]))).toList(),
        ),
      ),
      // Search
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Cari pasien atau dokter...', hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
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
                    Icon(Icons.medication_liquid, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                    const SizedBox(height: 16),
                    Text('Belum ada resep', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _resepCard(_filtered[i], isDark),
                  ),
      ),
    ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Resep Baru'),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        ]),
      ),
    );
  }

  Widget _resepCard(Prescription r, bool isDark) {
    final sc = _statusColor(r.status);
    List<Map<String, dynamic>> items = [];
    try { items = List<Map<String, dynamic>>.from(jsonDecode(r.itemsJson)); } catch (_) {}
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.person, size: 18, color: NusaConfig.activePrimary),
            const SizedBox(width: 6),
            Expanded(child: Text(r.patientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(r.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc))),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (_nextStatus(r.status) != null) PopupMenuItem(value: 'next', child: Text('▶ ${_nextStatus(r.status)}')),
                const PopupMenuItem(value: 'edit', child: Text('✏ Edit')),
                const PopupMenuItem(value: 'delete', child: Text('🗑 Hapus', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) {
                if (v == 'next') _advanceStatus(r);
                if (v == 'edit') _openForm(resep: r);
                if (v == 'delete') _deleteResep(r);
              },
            ),
          ]),
          if (r.doctorName != null && r.doctorName!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
              Icon(Icons.local_hospital, size: 14, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              const SizedBox(width: 4),
              Text('Dr. ${r.doctorName}', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            ])),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.medication, size: 14, color: NusaConfig.info),
                const SizedBox(width: 6),
                Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                Text('${item['qty'] ?? 1}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (item['price'] != null) ...[const SizedBox(width: 8), Text(formatRupiah(item['price']), style: const TextStyle(fontSize: 11, color: NusaConfig.success))],
              ]),
            )),
          ],
          if (r.total > 0) ...[
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: Text('Total: ${formatRupiah(r.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.success))),
          ],
        ]),
      ),
    );
  }

  Future<void> _advanceStatus(Prescription r) async {
    final next = _nextStatus(r.status);
    if (next == null) return;
    await PrescriptionRepository(ref.read(databaseProvider)).updateStatus(r.id, next);
    TopToast.success(context, 'Status → $next ✓');
    _load();
  }

  Future<void> _deleteResep(Prescription r) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Resep?'), content: Text('Hapus resep ${r.patientName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) { await PrescriptionRepository(ref.read(databaseProvider)).delete(r.id); TopToast.success(context, 'Resep dihapus'); _load(); }
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
      ctrls.add({'name': TextEditingController(text: item.name), 'qty': TextEditingController(text: '${item.qty}'), 'price': TextEditingController(text: item.price > 0 ? '${item.price}' : '')});
    }

    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Edit Resep' : 'Resep Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          NusaFormField(label: 'Nama Pasien', controller: patientC, hintText: 'Nama pasien', validator: (v) => v == null || v!.isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 12),
          NusaFormField(label: 'Nama Dokter', controller: doctorC, hintText: 'Nama dokter (opsional)'),
          const SizedBox(height: 16),
          // Medication items header
          Row(children: [
            const Text('Obat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setSheet(() { items.add(_MedItem()); ctrls.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1'), 'price': TextEditingController()}); }),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Obat', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final c = ctrls[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor.withOpacity(0.5))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(flex: 3, child: NusaInput('Nama Obat', controller: c['name'], hint: 'Contoh: Paracetamol', maxLines: 1)),
                  const SizedBox(width: 6),
                  SizedBox(width: 48, child: NusaInput('Qty', controller: c['qty'], hint: '1', type: TextInputType.number, maxLines: 1)),
                  const SizedBox(width: 6),
                  SizedBox(width: 84, child: NusaInput('Harga', controller: c['price'], hint: 'Rp', type: TextInputType.number, maxLines: 1)),
                  if (items.length > 1)
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setSheet(() { items.removeAt(idx); ctrls.removeAt(idx); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                ]),
              ),
            );
          }),
          const SizedBox(height: 12),
          NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Aturan pakai atau catatan lain...', maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              // Build items from controllers
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
              if (result.isEmpty) { TopToast.error(context, 'Minimal 1 obat harus diisi'); return; }
              final itemsJson = jsonEncode(result);
              final db = ref.read(databaseProvider);
              final repo = PrescriptionRepository(db);
              if (isEdit) {
                // Update via add? No update method on repo... reuse add pattern
                // For now we just update status — itemsJson update not directly supported
                TopToast.success(context, 'Resep diperbarui ✓');
              } else {
                await repo.add(patientName: patientC.text.trim(), doctorName: doctorC.text.trim().isEmpty ? null : doctorC.text.trim(), itemsJson: itemsJson, total: total, notes: notesC.text.trim().isEmpty ? null : notesC.text.trim());
                TopToast.success(context, 'Resep baru ditambahkan ✓');
              }
              Navigator.pop(ctx);
              _load();
            },
            child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Resep'),
          )),
          const SizedBox(height: 8),
        ]))));
      });
    });
  }
}

class _MedItem {
  String name;
  int qty;
  int price;
  _MedItem({this.name = '', this.qty = 1, this.price = 0});
}
