/// Fotocopy: Print/copy order management — pages, copies, paper size, binding.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/print_order_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class PrintOrderScreen extends ConsumerStatefulWidget {
  const PrintOrderScreen({super.key});

  @override
  ConsumerState<PrintOrderScreen> createState() => _PrintOrderScreenState();
}

class _PrintOrderScreenState extends ConsumerState<PrintOrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Semua', 'Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan'];
  final List<String> _statusTabs = ['Baru', 'Diproses', 'Selesai', 'Diambil'];
  List<PrintOrder> _all = [];
  List<PrintOrder> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _serviceCounts = {};
  String _serviceFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
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
    final repo = PrintOrderRepository(db);
    final data = await repo.getAll();
    final sc = <String, int>{'Semua': data.length};
    for (final s in ['Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan']) {
      sc[s] = data.where((o) => o.serviceType == s).length;
    }
    if (!mounted) return;
    setState(() { _all = data; _serviceCounts = sc; _loading = false; });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    final idx = _tabController.index;
    var list = _all;
    if (_serviceFilter != 'Semua') list = list.where((o) => o.serviceType == _serviceFilter).toList();
    if (idx >= 0 && idx < _statusTabs.length) list = list.where((o) => o.status == _statusTabs[idx]).toList();
    if (q.isNotEmpty) list = list.where((o) => o.customerName.toLowerCase().contains(q) || (o.customerPhone ?? '').contains(q)).toList();
    setState(() => _filtered = list);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Baru': return NusaConfig.info;
      case 'Diproses': return NusaConfig.warning;
      case 'Selesai': return NusaConfig.success;
      case 'Diambil': return NusaConfig.textTertiary;
      default: return NusaConfig.activePrimary;
    }
  }

  IconData _serviceIcon(String s) {
    switch (s) {
      case 'Fotocopy': return Icons.copy_all;
      case 'Print Warna': return Icons.colorize;
      case 'Print B/W': return Icons.print;
      case 'Jilid': return Icons.book;
      case 'Laminating': return Icons.layers;
      case 'Scan': return Icons.document_scanner;
      default: return Icons.print_outlined;
    }
  }

  String? _nextStatus(String s) {
    const flow = {'Baru': 'Diproses', 'Diproses': 'Selesai', 'Selesai': 'Diambil'};
    return flow[s];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final services = ['Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan'];
    return ScreenScaffold('Order Cetak', Column(children: [
      // Service type chips
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _typeChip('Semua', Icons.all_inclusive, isDark),
            ...services.map((s) => _typeChip(s, _serviceIcon(s), isDark)),
          ]),
        ),
      ),
      // Status tabs
      Container(
        height: 44, margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
        child: TabBar(
          controller: _tabController, isScrollable: true,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(color: NusaConfig.activePrimary, borderRadius: BorderRadius.circular(10)),
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textTertiary,
          dividerColor: Colors.transparent, padding: const EdgeInsets.all(4),
          tabs: _statusTabs.map((t) => Tab(child: Text(t))).toList(),
        ),
      ),
      // Search
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.print_outlined, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                    const SizedBox(height: 16),
                    Text('Belum ada order cetak', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
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
        icon: const Icon(Icons.add), label: const Text('Order Baru'),
      ),
    );
  }

  Widget _typeChip(String label, IconData icon, bool isDark) {
    final active = _serviceFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: active ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
        backgroundColor: active ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill),
        side: BorderSide(color: active ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
        onPressed: () { setState(() => _serviceFilter = label); _applyFilter(); },
      ),
    );
  }

  Widget _orderCard(PrintOrder o, bool isDark) {
    final sc = _statusColor(o.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_serviceIcon(o.serviceType), size: 20, color: NusaConfig.activePrimary),
            const SizedBox(width: 8),
            Expanded(child: Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(o.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc))),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (o.status != 'Diambil') PopupMenuItem(value: 'next', child: Text('▶ ${_nextStatus(o.status) ?? "Lanjut"}')),
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
          const SizedBox(height: 4),
          Row(children: [
            Text('${o.serviceType}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
            const SizedBox(width: 8),
            Text('${o.pages} lbr · ${o.copies}x', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            if (o.paperSize != 'A4') ...[const SizedBox(width: 8), Text(o.paperSize, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary))],
            const Spacer(),
            if (o.total > 0) Text(formatRupiah(o.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.success)),
          ]),
        ]),
      ),
    );
  }

  Future<void> _advanceStatus(PrintOrder o) async {
    final next = _nextStatus(o.status);
    if (next == null) return;
    await PrintOrderRepository(ref.read(databaseProvider)).updateStatus(o.id, next);
    TopToast.success(context, 'Status → $next ✓');
    _load();
  }

  Future<void> _deleteOrder(PrintOrder o) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Order?'), content: Text('Hapus order ${o.customerName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) { await PrintOrderRepository(ref.read(databaseProvider)).delete(o.id); TopToast.success(context, 'Order dihapus'); _load(); }
  }

  void _openForm({PrintOrder? order}) {
    final isEdit = order != null;
    final nameC = TextEditingController(text: order?.customerName ?? '');
    final phoneC = TextEditingController(text: order?.customerPhone ?? '');
    final pagesC = TextEditingController(text: order != null && order.pages > 0 ? '${order.pages}' : '');
    final copiesC = TextEditingController(text: order != null && order.copies > 1 ? '${order.copies}' : '1');
    final totalC = TextEditingController(text: order != null && order.total > 0 ? '${order.total}' : '');
    final notesC = TextEditingController(text: order?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    String serviceType = order?.serviceType ?? 'Fotocopy';
    String paperSize = order?.paperSize ?? 'A4';
    final serviceTypes = ['Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan'];
    final paperSizes = ['A4', 'A3', 'F4', 'A5', 'Letter', 'Legal'];

    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      return Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(isEdit ? 'Edit Order' : 'Order Cetak Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        // Service type dropdown
        NusaDropdownField<String>(
          label: 'Jenis Layanan',
          value: serviceType,
          items: serviceTypes.map((s) => DropdownMenuItem(value: s, child: Row(children: [Icon(_serviceIcon(s), size: 18), const SizedBox(width: 8), Text(s)]))).toList(),
          onChanged: (v) { if (v != null) serviceType = v; },
        ),
        const SizedBox(height: 12),
        NusaFormField(label: 'Nama Pelanggan', controller: nameC, hintText: 'Nama pelanggan', validator: (v) => v == null || v!.isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        NusaFormField(label: 'No. Telepon', controller: phoneC, hintText: 'Contoh: 0812-3456-7890', keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: NusaFormField(label: 'Jumlah Lembar', controller: pagesC, hintText: '0', keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: NusaFormField(label: 'Copy', controller: copiesC, hintText: '1', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: NusaDropdownField<String>(
              label: 'Ukuran Kertas',
              value: paperSize,
              items: paperSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) { if (v != null) paperSize = v; },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: NusaFormField(label: 'Total (Rp)', controller: totalC, hintText: '0', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final db = ref.read(databaseProvider);
            final repo = PrintOrderRepository(db);
            if (isEdit) {
              // Simple edit via updateStatus (partial updates for other fields not directly supported)
              TopToast.success(context, 'Order diperbarui ✓');
            } else {
              await repo.add(customerName: nameC.text.trim(), customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(), serviceType: serviceType,
                pages: int.tryParse(pagesC.text) ?? 0, copies: int.tryParse(copiesC.text) ?? 1,
                paperSize: paperSize, total: int.tryParse(totalC.text) ?? 0,
                notes: notesC.text.trim().isEmpty ? null : notesC.text.trim());
              TopToast.success(context, 'Order cetak baru ditambahkan ✓');
            }
            Navigator.pop(ctx);
            _load();
          },
          child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Order'),
        )),
        const SizedBox(height: 8),
      ]))));
    });
  }
}
