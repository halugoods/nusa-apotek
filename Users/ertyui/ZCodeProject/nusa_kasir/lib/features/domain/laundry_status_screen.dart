/// Laundry: Status pesanan pipeline — Baru, Cuci, Kering, Setrika, Siap, Diantar, Diambil.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/contact_picker.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/laundry_order_repository.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/stage_slider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class LaundryStatusScreen extends ConsumerStatefulWidget {
  const LaundryStatusScreen({super.key});

  @override
  ConsumerState<LaundryStatusScreen> createState() => _LaundryStatusScreenState();
}

class _LaundryStatusScreenState extends ConsumerState<LaundryStatusScreen> {
  final List<Map<String, dynamic>> _stages = [
    {'label': 'Baru', 'icon': Icons.receipt_long, 'color': NusaConfig.accentPurple},
    {'label': 'Cuci', 'icon': Icons.local_laundry_service, 'color': NusaConfig.info},
    {'label': 'Kering', 'icon': Icons.air, 'color': NusaConfig.accentGreen},
    {'label': 'Setrika', 'icon': Icons.iron, 'color': NusaConfig.warning},
    {'label': 'Siap', 'icon': Icons.check_circle, 'color': NusaConfig.success},
    {'label': 'Diantar', 'icon': Icons.local_shipping, 'color': NusaConfig.accentGold},
    {'label': 'Diambil', 'icon': Icons.delivery_dining, 'color': NusaConfig.activePrimary},
  ];
  List<LaundryOrder> _all = [];
  List<LaundryOrder> _filtered = [];
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
    final repo = LaundryOrderRepository(db);
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
    var list = _all.where((o) => o.status == stageLabel).toList();
    if (q.isNotEmpty) list = list.where((o) => o.customerName.toLowerCase().contains(q) || (o.customerPhone ?? '').contains(q)).toList();
    setState(() => _filtered = list);
  }

  // ── Stage flow helpers ──────────────────────────────────────────────

  String? _nextStatus(String s) {
    const flow = {'Baru': 'Cuci', 'Cuci': 'Kering', 'Kering': 'Setrika', 'Setrika': 'Siap', 'Siap': 'Diantar', 'Diantar': 'Diambil'};
    return flow[s];
  }

  /// Get the next 2-3 stages from current status for quick-update chips.
  List<Map<String, dynamic>> _nextStages(LaundryOrder o) {
    final result = <Map<String, dynamic>>[];
    var current = o.status;
    for (int i = 0; i < 3; i++) {
      final next = _nextStatus(current);
      if (next == null) break;
      final stage = _stages.firstWhere((s) => s['label'] == next, orElse: () => _stages[0]);
      result.add(stage);
      current = next;
    }
    return result;
  }

  // ── Customer picker ─────────────────────────────────────────────────

  Future<void> _showCustomerPicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.read(databaseProvider);
    final customers = await CustomerRepository(db).getCustomers();

    if (!mounted) return;

    String pickerQuery = '';
    List<Customer> filtered = List.from(customers);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(children: [
              // Drag handle
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Pilih Pelanggan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              // Search
              TextField(
                autofocus: true,
                onChanged: (v) => setSheet(() {
                  pickerQuery = v.toLowerCase();
                  filtered = customers.where((c) => c.name.toLowerCase().contains(pickerQuery) || (c.phone ?? '').contains(pickerQuery)).toList();
                }),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau telepon...', hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true, fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('Tidak ada pelanggan', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: NusaConfig.activePrimary.withOpacity(0.1),
                              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: TextStyle(fontWeight: FontWeight.w700, color: NusaConfig.activePrimary, fontSize: 14)),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: c.phone != null && c.phone!.isNotEmpty ? Text(c.phone!, style: const TextStyle(fontSize: 12)) : null,
                            onTap: () {
                              _search.text = c.name;
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ]),
          );
        });
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stageDatas = _stages.map((s) => StageData(
      label: s['label'] as String,
      color: s['color'] as Color,
      count: _counts[s['label']] ?? 0,
    )).toList();

    return ScreenScaffold('Status Laundry', _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // ── Stage Slider (replacing TabBar) ──
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
            // ── Search with customer picker ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Cari pelanggan...', hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: GestureDetector(
                        onTap: _showCustomerPicker,
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: NusaConfig.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person_search_rounded, size: 20, color: NusaConfig.primaryColor),
                        ),
                      ),
                      filled: true, fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final contact = await pickContact();
                    if (contact != null) {
                      final phone = contact['phone'] ?? '';
                      if (phone.isNotEmpty) {
                        _search.text = phone;
                        _applyFilter();
                        setState(() {});
                      }
                    }
                  },
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: NusaConfig.activePrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.contacts_outlined, color: NusaConfig.activePrimary, size: 20),
                  ),
                ),
              ]),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(_stages[_selectedIdx]['label'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                      Text('Tidak ada pesanan ${_stages[_selectedIdx]['label']}', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
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
    final orderLabel = '#LND-${o.id.toString().padLeft(3, '0')}';
    final nextStages = _nextStages(o);

    String? estString;
    if (o.estimatedReady != null) {
      final diff = o.estimatedReady!.difference(DateTime.now());
      if (diff.isNegative) {
        estString = 'Sudah lewat estimasi';
      } else {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        estString = 'Estimasi ${days > 0 ? '$days hari ' : ''}${hours > 0 ? '$hours jam' : 'sebentar lagi'}';
      }
    }

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
                Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                Text(orderLabel, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ]),
              if (o.customerPhone != null && o.customerPhone!.isNotEmpty)
                Text(o.customerPhone!, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            ])),
            if (o.total > 0) Text(formatRupiah(o.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NusaConfig.success)),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (_nextStatus(o.status) != null) PopupMenuItem(value: 'next', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_forward_rounded, size: 18), const SizedBox(width: 8), Text(_nextStatus(o.status)!),
                ])),
                const PopupMenuItem(value: 'print', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.print_rounded, size: 18), SizedBox(width: 8), Text('Cetak Tag'),
                ])),
                const PopupMenuItem(value: 'edit', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red)),
                ])),
              ],
              onSelected: (v) {
                if (v == 'next') _advanceStatus(o);
                if (v == 'print') _printTag(o);
                if (v == 'edit') _openForm(order: o);
                if (v == 'delete') _deleteOrder(o);
              },
            ),
          ]),
          // ── Items chips ──
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: items.map((item) {
                final w = item['weightKg'];
                final qtyDisplay = w != null ? '${(w as num).toDouble().toStringAsFixed(1)} kg' : '${item['qty'] ?? 1}x';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill, borderRadius: BorderRadius.circular(6)),
                  child: Text('${item['name']} $qtyDisplay', style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),
          ],
          // ── Estimate + notes ──
          if (estString != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule, size: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              const SizedBox(width: 4),
              Text(estString, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              if (o.estimatedReady != null) ...[
                const SizedBox(width: 6),
                Text(DateFormat('dd/MM HH:mm').format(o.estimatedReady!), style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              ],
            ]),
          ],
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(o.notes!, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
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
                  onTap: () => _jumpToStatus(o, ns['label']),
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

  /// Jump directly to a specific status (not just next step).
  Future<void> _jumpToStatus(LaundryOrder o, String targetStatus) async {
    await LaundryOrderRepository(ref.read(databaseProvider)).updateStatus(o.id, targetStatus);
    TopToast.success(context, 'Status -> $targetStatus');
    _load();
  }

  Future<void> _advanceStatus(LaundryOrder o) async {
    final next = _nextStatus(o.status);
    if (next == null) return;
    await LaundryOrderRepository(ref.read(databaseProvider)).updateStatus(o.id, next);
    TopToast.success(context, 'Status -> $next');
    _load();
  }

  Future<void> _printTag(LaundryOrder o) async {
    // Fire-and-forget tag print via Bluetooth thermal printer
    try {
      if (!await ReceiptPrinter.ensureBluetoothReady()) {
        if (mounted) TopToast.error(context, 'Bluetooth tidak siap');
        return;
      }
      final printer = ReceiptPrinter();
      final devices = await printer.discover();
      if (devices.isEmpty) {
        if (mounted) TopToast.error(context, 'Tidak ada printer terhubung');
        return;
      }
      await printer.connect(devices.first);
      List<Map<String, dynamic>> items = [];
      try { items = List<Map<String, dynamic>>.from(jsonDecode(o.itemsJson)); } catch (_) {}
      final lines = <ReceiptLine>[];
      for (final item in items) {
        final name = '${item['name'] ?? ''}';
        final qty = (item['qty'] as num?)?.toInt() ?? 1;
        final price = (item['price'] as num?)?.toInt() ?? 0;
        lines.add(ReceiptLine(name: name, qty: qty, price: price));
      }
      await printer.printReceipt(
        storeName: o.customerName,
        lines: lines,
        total: o.total,
        paymentMethod: 'Tag',
        cashierName: '#LND-${o.id.toString().padLeft(3, '0')}',
        paperWidth: '58',
        orderType: o.status,
        itemNotes: [o.notes],
      );
      await printer.dispose();
      if (mounted) TopToast.success(context, 'Tag #LND-${o.id.toString().padLeft(3, "0")} dicetak');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal cetak tag');
    }
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
    DateTime? estReady = order?.estimatedReady;
    final formKey = GlobalKey<FormState>();

    List<_LaundryItem> items = [];
    if (order != null) {
      try {
        final parsed = List<Map<String, dynamic>>.from(jsonDecode(order.itemsJson));
        items = parsed.map((m) => _LaundryItem(name: m['name'] ?? '', qty: m['qty'] ?? 1, price: m['price'] ?? 0)).toList();
      } catch (_) {}
    }
    if (items.isEmpty) items.add(_LaundryItem());

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
          // Estimasi Selesai
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: NusaConfig.warningSoft, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.schedule, color: NusaConfig.warning, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: estReady ?? DateTime.now().add(const Duration(days: 3)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setSheet(() => estReady = DateTime(picked.year, picked.month, picked.day, estReady?.hour ?? 17, estReady?.minute ?? 0));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                  ),
                  child: Text(
                    estReady != null ? 'Estimasi: ${DateFormat('dd MMM yyyy').format(estReady!)}' : 'Estimasi selesai (opsional)',
                    style: TextStyle(fontSize: 13, color: estReady != null
                        ? (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)
                        : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  ),
                ),
              ),
            ),
            if (estReady != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setSheet(() => estReady = null),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ]),
          const SizedBox(height: 12),
          NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
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
                await repo.update(order!.id, customerName: nameC.text.trim(), customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(), itemsJson: itemsJson, total: total, notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(), estimatedReady: estReady);
                TopToast.success(context, 'Cucian diperbarui');
              } else {
                await repo.add(customerName: nameC.text.trim(), customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(), itemsJson: itemsJson, total: total, notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(), estimatedReady: estReady);
                TopToast.success(context, 'Cucian baru ditambahkan');
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
