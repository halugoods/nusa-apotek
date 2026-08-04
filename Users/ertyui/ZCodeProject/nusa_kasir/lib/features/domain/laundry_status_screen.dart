/// Laundry: Status pesanan pipeline — New, Wash, Dry, Iron, Ready, Delivered.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/laundry_order_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class LaundryStatusScreen extends ConsumerStatefulWidget {
  const LaundryStatusScreen({super.key});

  @override
  ConsumerState<LaundryStatusScreen> createState() => _LaundryStatusScreenState();
}

class _LaundryStatusScreenState extends ConsumerState<LaundryStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _stages = [
    {'label': 'Baru', 'icon': Icons.receipt_long, 'color': NusaConfig.accentPurple},
    {'label': 'Cuci', 'icon': Icons.local_laundry_service, 'color': NusaConfig.info},
    {'label': 'Kering', 'icon': Icons.air, 'color': NusaConfig.accentGreen},
    {'label': 'Setrika', 'icon': Icons.iron, 'color': NusaConfig.warning},
    {'label': 'Siap', 'icon': Icons.check_circle, 'color': NusaConfig.success},
    {'label': 'Diambil', 'icon': Icons.delivery_dining, 'color': NusaConfig.activePrimary},
  ];
  List<LaundryOrder> _all = [];
  List<LaundryOrder> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _counts = {};
  String? _selectedStage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stages.length, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) _selectStage(_stages[_tabController.index]['label']); });
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
    final repo = LaundryOrderRepository(db);
    final data = await repo.getAll();
    final counts = <String, int>{};
    for (final stage in _stages) {
      counts[stage['label']] = await repo.countByStatus(stage['label']);
    }
    if (!mounted) return;
    setState(() { _all = data; _counts = counts; _loading = false; });
    _selectStage(_stages[_tabController.index]['label']);
  }

  void _selectStage(String stage) {
    _selectedStage = stage;
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    var list = _all.where((o) => o.status == _selectedStage).toList();
    if (q.isNotEmpty) list = list.where((o) => o.customerName.toLowerCase().contains(q) || (o.customerPhone ?? '').contains(q)).toList();
    setState(() => _filtered = list);
  }

  String? _nextStatus(String s) {
    const flow = {'Baru': 'Cuci', 'Cuci': 'Kering', 'Kering': 'Setrika', 'Setrika': 'Siap', 'Siap': 'Diambil'};
    return flow[s];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold('Status Laundry', _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // Pipeline tabs
            Container(
              height: 48, margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor, borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController, isScrollable: true,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: NusaConfig.activePrimary, borderRadius: BorderRadius.circular(10)),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                dividerColor: Colors.transparent, padding: const EdgeInsets.all(3),
                tabs: _stages.map((s) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s['label']),
                  if ((_counts[s['label']] ?? 0) > 0) ...[const SizedBox(width: 3), Text('${_counts[s['label']]}', style: const TextStyle(fontSize: 10))],
                ]))).toList(),
              ),
            ),
            // Counts summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: _stages.map((s) {
                final c = _counts[s['label']] ?? 0;
                final color = s['color'] as Color;
                return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text('$c', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                    Text(s['label'], style: TextStyle(fontSize: 9, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  ]),
                )));
              }).toList()),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Cari pelanggan...', hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
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
                Text('$_selectedStage', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${_filtered.length} pesanan', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              ]),
            ),
            // List
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_laundry_service, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      const SizedBox(height: 16),
                      Text('Tidak ada pesanan $_selectedStage', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _orderCard(_filtered[i], isDark),
                    ),
            ),
          ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Cucian Baru'),
      ),
    );
  }

  Widget _orderCard(LaundryOrder o, bool isDark) {
    List<Map<String, dynamic>> items = [];
    try { items = List<Map<String, dynamic>>.from(jsonDecode(o.itemsJson)); } catch (_) {}
    final stage = _stages.firstWhere((s) => s['label'] == o.status, orElse: () => _stages[0]);
    final color = stage['color'] as Color;
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
              Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (o.customerPhone != null && o.customerPhone!.isNotEmpty)
                Text(o.customerPhone!, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            ])),
            if (o.total > 0) Text(formatRupiah(o.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NusaConfig.success)),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (_nextStatus(o.status) != null) PopupMenuItem(value: 'next', child: Text('▶ ${_nextStatus(o.status)}')),
                const PopupMenuItem(value: 'edit', child: Text('✏ Edit')),
                const PopupMenuItem(value: 'delete', child: Text('🗑 Hapus', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) {
                if (v == 'next') _advanceStatus(o);
                if (v == 'edit') _openForm(order: o);
                if (v == 'delete') _deleteOrder(o);
              },
            ),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill, borderRadius: BorderRadius.circular(6)),
                child: Text('${item['name']} ${item['qty']}x', style: const TextStyle(fontSize: 11)),
              )).toList(),
            ),
          ],
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(o.notes!, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
          ],
        ]),
      ),
    );
  }

  Future<void> _advanceStatus(LaundryOrder o) async {
    final next = _nextStatus(o.status);
    if (next == null) return;
    await LaundryOrderRepository(ref.read(databaseProvider)).updateStatus(o.id, next);
    TopToast.success(context, 'Status → $next ✓');
    _load();
  }

  Future<void> _deleteOrder(LaundryOrder o) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Cucian?'), content: Text('Hapus cucian ${o.customerName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) { await LaundryOrderRepository(ref.read(databaseProvider)).delete(o.id); TopToast.success(context, 'Cucian dihapus'); _load(); }
  }

  void _openForm({LaundryOrder? order}) {
    final isEdit = order != null;
    final nameC = TextEditingController(text: order?.customerName ?? '');
    final phoneC = TextEditingController(text: order?.customerPhone ?? '');
    final notesC = TextEditingController(text: order?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    // Parse existing items or start with one empty row
    List<_LaundryItem> items = [];
    if (order != null) {
      try {
        final parsed = List<Map<String, dynamic>>.from(jsonDecode(order.itemsJson));
        items = parsed.map((m) => _LaundryItem(name: m['name'] ?? '', qty: m['qty'] ?? 1, price: m['price'] ?? 0)).toList();
      } catch (_) {}
    }
    if (items.isEmpty) items.add(_LaundryItem());

    // Controllers for each item row — created fresh on each open
    final itemControllers = <Map<String, TextEditingController>>[];
    for (final item in items) {
      itemControllers.add({
        'name': TextEditingController(text: item.name),
        'qty': TextEditingController(text: '${item.qty}'),
        'price': TextEditingController(text: item.price > 0 ? '${item.price}' : ''),
      });
    }

    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Edit Cucian' : 'Cucian Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          NusaFormField(label: 'Nama Pelanggan', controller: nameC, hintText: 'Nama pelanggan', validator: (v) => v == null || v!.isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 12),
          NusaFormField(label: 'No. Telepon', controller: phoneC, hintText: 'Contoh: 0812-3456-7890', keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          // Items editor
          Row(children: [
            const Text('Item Cucian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setSheet(() { items.add(_LaundryItem()); itemControllers.add({'name': TextEditingController(), 'qty': TextEditingController(text: '1'), 'price': TextEditingController()}); }),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Item', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final ctrls = itemControllers[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(flex: 3, child: NusaInput('Item', controller: ctrls['name'], hint: 'Nama item', maxLines: 1)),
                const SizedBox(width: 6),
                SizedBox(width: 50, child: NusaInput('Qty', controller: ctrls['qty'], hint: '1', type: TextInputType.number, maxLines: 1)),
                const SizedBox(width: 6),
                SizedBox(width: 80, child: NusaInput('Harga', controller: ctrls['price'], hint: 'Rp', type: TextInputType.number, maxLines: 1)),
                if (items.length > 1)
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setSheet(() { items.removeAt(idx); itemControllers.removeAt(idx); }), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              ]),
            );
          }),
          const SizedBox(height: 4),
          Divider(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
          const SizedBox(height: 12),
          NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              // Read items from controllers
              final validItems = <Map<String, dynamic>>[];
              var total = 0;
              for (var i = 0; i < items.length; i++) {
                final name = itemControllers[i]['name']!.text.trim();
                if (name.isEmpty) continue;
                final qty = int.tryParse(itemControllers[i]['qty']!.text) ?? 1;
                final price = int.tryParse(itemControllers[i]['price']!.text) ?? 0;
                validItems.add({'name': name, 'qty': qty, 'price': price});
                total += qty * price;
              }
              if (validItems.isEmpty) { TopToast.error(context, 'Minimal 1 item cucian'); return; }
              final itemsJson = jsonEncode(validItems);
              final db = ref.read(databaseProvider);
              final repo = LaundryOrderRepository(db);
              if (isEdit) {
                await repo.update(order!.id, customerName: nameC.text.trim(), customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(), itemsJson: itemsJson, total: total, notes: notesC.text.trim().isEmpty ? null : notesC.text.trim());
                TopToast.success(context, 'Cucian diperbarui ✓');
              } else {
                await repo.add(customerName: nameC.text.trim(), customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(), itemsJson: itemsJson, total: total, notes: notesC.text.trim().isEmpty ? null : notesC.text.trim());
                TopToast.success(context, 'Cucian baru ditambahkan ✓');
              }
              Navigator.pop(ctx);
              _load();
            },
            child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Cucian'),
          )),
          const SizedBox(height: 8),
        ]))));
      });
    });
  }
}

class _LaundryItem {
  String name;
  int qty;
  int price;
  _LaundryItem({this.name = '', this.qty = 1, this.price = 0});
}
