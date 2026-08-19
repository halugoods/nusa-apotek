// Fotocopy/Percetakan: Print/copy order management.
// Jenis layanan dari DB (PrintServiceTypes) — custom, TANPA icon bulat.
// Order punya dimensi (P×L cm) + estimasi selesai (opsional).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/print_order_repository.dart';
import 'package:nusa_kasir/data/repositories/print_service_type_repository.dart';
import 'package:nusa_kasir/data/repositories/estimate_option_repository.dart';
import 'package:nusa_kasir/shared/widgets/customer_picker_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class PrintOrderScreen extends ConsumerStatefulWidget {
  const PrintOrderScreen({super.key});

  @override
  ConsumerState<PrintOrderScreen> createState() => _PrintOrderScreenState();
}

class _PrintOrderScreenState extends ConsumerState<PrintOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusTabs = ['Baru', 'Diproses', 'Selesai', 'Diambil'];
  List<PrintOrder> _all = [];
  List<PrintOrder> _filtered = [];
  List<PrintServiceType> _serviceTypes = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _serviceCounts = {};
  String _serviceFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilter();
    });
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
    final svc = await PrintServiceTypeRepository(db).getAll();
    if (svc.isEmpty) {
      // Safety: kalau seed belum ada (DB lama), fallback ke daftar default.
      final sRepo = PrintServiceTypeRepository(db);
      for (final name in ['Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan']) {
        await sRepo.add(name);
      }
      return _load();
    }
    final sc = <String, int>{'Semua': data.length};
    for (final s in svc) {
      sc[s.name] = data.where((o) => o.serviceType == s.name).length;
    }
    if (!mounted) return;
    setState(() {
      _all = data;
      _serviceTypes = svc;
      _serviceCounts = sc;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    final idx = _tabController.index;
    var list = _all;
    if (_serviceFilter != 'Semua') {
      list = list.where((o) => o.serviceType == _serviceFilter).toList();
    }
    if (idx >= 0 && idx < _statusTabs.length) {
      list = list.where((o) => o.status == _statusTabs[idx]).toList();
    }
    if (q.isNotEmpty) {
      list = list
          .where((o) =>
              o.customerName.toLowerCase().contains(q) ||
              (o.customerPhone ?? '').contains(q))
          .toList();
    }
    setState(() => _filtered = list);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Baru':
        return NusaConfig.info;
      case 'Diproses':
        return NusaConfig.warning;
      case 'Selesai':
        return NusaConfig.success;
      case 'Diambil':
        return NusaConfig.textTertiary;
      default:
        return NusaConfig.activePrimary;
    }
  }

  String? _nextStatus(String s) {
    const flow = {'Baru': 'Diproses', 'Diproses': 'Selesai', 'Selesai': 'Diambil'};
    return flow[s];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Order Cetak',
      Column(children: [
        // Service type chips (dari DB, scrollable) — tanpa icon
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _typeChip('Semua', isDark),
              ..._serviceTypes.map((s) => _typeChip(s.name, isDark)),
            ]),
          ),
        ),
        // Kelola Layanan + Kelola Estimasi — tombol terpisah di atas
        // FAB Order Baru (bukan chip yang bercampur filter layanan).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Expanded(
              child: _manageButton(
                icon: Icons.settings_outlined,
                label: 'Kelola Layanan',
                isDark: isDark,
                onTap: _openServiceManager,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _manageButton(
                icon: Icons.timer_outlined,
                label: 'Kelola Estimasi',
                isDark: isDark,
                onTap: _openEstimateManager,
              ),
            ),
          ]),
        ),
        // Status tabs
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
                color: NusaConfig.activePrimary,
                borderRadius: BorderRadius.circular(10)),
            labelColor: Colors.white,
            unselectedLabelColor: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textTertiary,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            tabs: _statusTabs.map((t) => Tab(child: Text(t))).toList(),
          ),
        ),
        // Search + customer picker (sejajar — pola booking/laundry/servis)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Cari pelanggan...',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                }
              },
            ),
          ]),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.print_outlined,
                            size: 64,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary),
                        const SizedBox(height: 16),
                        Text('Belum ada order cetak',
                            style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? NusaConfig.darkTextSecondary
                                    : NusaConfig.textSecondary)),
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
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Order Baru'),
      ),
    );
  }

  Widget _typeChip(String label, bool isDark) {
    final active = _serviceFilter == label;
    final count = _serviceCounts[label];
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        // TANPA icon — layanan custom tidak boleh ikut icon bulat.
        label: Text(count != null ? '$label ($count)' : label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.white
                    : (isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary))),
        backgroundColor: active
            ? NusaConfig.activePrimary
            : (isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill),
        side: BorderSide(
            color: active
                ? NusaConfig.activePrimary
                : (isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
        onPressed: () {
          setState(() => _serviceFilter = label);
          _applyFilter();
        },
      ),
    );
  }

  /// Tombol pengaturan di atas FAB Order Baru — [Kelola Layanan]
  /// dan [Kelola Estimasi] (bukan chip, supaya tidak bercampur filter).
  Widget _manageButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.activeSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: NusaConfig.activePrimary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: NusaConfig.activePrimary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NusaConfig.activePrimary)),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(PrintOrder o, bool isDark) {
    final sc = _statusColor(o.status);
    final dims = (o.widthCm != null && o.lengthCm != null)
        ? '${o.widthCm}×${o.lengthCm} cm'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Tanpa icon bulat — label layanan polos (custom friendly)
            Expanded(
              child: Text(o.customerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(o.status,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
            ),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (o.status != 'Diambil')
                  PopupMenuItem(
                      value: 'next',
                      child: Text('▶ ${_nextStatus(o.status) ?? "Lanjut"}')),
                const PopupMenuItem(value: 'edit', child: Text('✏ Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('🗑 Hapus', style: TextStyle(color: Colors.red))),
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
            Text(o.serviceType,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NusaConfig.activePrimary)),
            const SizedBox(width: 8),
            Text('${o.pages} lbr · ${o.copies}x',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary)),
            if (o.paperSize != 'A4') ...[
              const SizedBox(width: 8),
              Text(o.paperSize,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary)),
            ],
            if (dims != null) ...[
              const SizedBox(width: 8),
              Text(dims,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary)),
            ],
            const Spacer(),
            if (o.total > 0)
              Text(formatRupiah(o.total),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NusaConfig.success)),
          ]),
          if (o.estimateReady != null && o.estimateReady!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('⏱ Selesai: ${o.estimateReady}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary)),
          ],
        ]),
      ),
    );
  }

  Future<void> _advanceStatus(PrintOrder o) async {
    final next = _nextStatus(o.status);
    if (next == null) return;
    await PrintOrderRepository(ref.read(databaseProvider))
        .updateStatus(o.id, next);
    if (mounted) TopToast.success(context, 'Status → $next ✓');
    _load();
  }

  Future<void> _deleteOrder(PrintOrder o) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Hapus Order?'),
              content: Text('Hapus order ${o.customerName}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Hapus',
                        style: TextStyle(color: Colors.red))),
              ],
            ));
    if (ok == true) {
      await PrintOrderRepository(ref.read(databaseProvider)).delete(o.id);
      if (mounted) TopToast.success(context, 'Order dihapus');
      _load();
    }
  }

  // ── Kelola Layanan (CRUD custom, tanpa icon bulat) ──
  Future<void> _openServiceManager() async {
    final db = ref.read(databaseProvider);
    final repo = PrintServiceTypeRepository(db);
    final services = await repo.getAll();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> refresh() async {
            final s = await repo.getAll();
            if (ctx.mounted) setSheet(() => _serviceTypes = s);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('Kelola Jenis Layanan',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: NusaConfig.activePrimary),
                    tooltip: 'Tambah layanan',
                    onPressed: () => _addService(repo, refresh),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Layanan custom tidak memakai icon — list polos.',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: services.length,
                    itemBuilder: (_, i) {
                      final s = services[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            s.isDefault
                                ? Icons.auto_awesome
                                : Icons.label_outline,
                            size: 18,
                            color: NusaConfig.activePrimary,
                          ),
                        ),
                        title: Text(s.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: s.isDefault
                            ? const Text('Bawaan',
                                style: TextStyle(fontSize: 11))
                            : null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _renameService(repo, s, refresh),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            onPressed: () => _deleteService(repo, s, refresh),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _addService(
      PrintServiceTypeRepository repo, Future<void> Function() refresh) async {
    final ctrl = TextEditingController();
    final key = GlobalKey<FormState>();
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Layanan'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Contoh: Banner, Spanduk, Stiker, Undangan...'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final exists = await repo.byName(name);
    if (exists != null) {
      if (mounted) TopToast.error(context, 'Layanan "$name" sudah ada');
      return;
    }
    await repo.add(name);
    if (mounted) TopToast.success(context, 'Layanan "$name" ditambahkan');
    await refresh();
  }

  Future<void> _renameService(PrintServiceTypeRepository repo,
      PrintServiceType s, Future<void> Function() refresh) async {
    final ctrl = TextEditingController(text: s.name);
    final key = GlobalKey<FormState>();
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Layanan'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == s.name) return;
    final exists = await repo.byName(name);
    if (exists != null) {
      if (mounted) TopToast.error(context, 'Layanan "$name" sudah ada');
      return;
    }
    await repo.rename(s.id, name);
    if (mounted) TopToast.success(context, 'Layanan diubah ✓');
    await refresh();
  }

  Future<void> _deleteService(PrintServiceTypeRepository repo,
      PrintServiceType s, Future<void> Function() refresh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Layanan?'),
        content:
            Text('Hapus layanan "${s.name}"? Order lama tetap tersimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await repo.delete(s.id);
      if (mounted) TopToast.success(context, 'Layanan dihapus');
      await refresh();
    }
  }

  // ── Kelola Estimasi (preset dropdown CRUD) ──

  /// Sheet CRUD preset estimasi selesai — dipakai dropdown di form Order.
  Future<void> _openEstimateManager() async {
    final db = ref.read(databaseProvider);
    final repo = EstimateOptionRepository(db);
    final estimates = await repo.getAll();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // List mutable lokal — refresh() memperbarui list di dalam sheet.
        var current = List<EstimateOption>.from(estimates);
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> refresh() async {
            current = await repo.getAll();
            if (ctx.mounted) setSheet(() {});
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('Kelola Estimasi Selesai',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: NusaConfig.activePrimary),
                    tooltip: 'Tambah estimasi',
                    onPressed: () => _addEstimate(repo, refresh),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Preset waktu selesai — dipilih lewat dropdown.',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: current.length,
                    itemBuilder: (_, i) {
                      final e = current[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.timer_outlined,
                              size: 18, color: NusaConfig.activePrimary),
                        ),
                        title: Text(e.label,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                onPressed: () =>
                                    _renameEstimate(repo, e, refresh),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () =>
                                    _deleteEstimate(repo, e, refresh),
                              ),
                            ]),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _addEstimate(
      EstimateOptionRepository repo, Future<void> Function() refresh) async {
    final ctrl = TextEditingController();
    final key = GlobalKey<FormState>();
    if (!mounted) return;
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Estimasi'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Cth: 1 jam, Besok 14:00, 3 hari'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    final exists = await repo.byLabel(label);
    if (exists != null) {
      if (mounted) TopToast.error(context, 'Estimasi "$label" sudah ada');
      return;
    }
    await repo.add(label);
    if (mounted) TopToast.success(context, 'Estimasi ditambahkan ✓');
    await refresh();
  }

  Future<void> _renameEstimate(EstimateOptionRepository repo,
      EstimateOption e, Future<void> Function() refresh) async {
    final ctrl = TextEditingController(text: e.label);
    final key = GlobalKey<FormState>();
    if (!mounted) return;
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Estimasi'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    if (label == null || label.isEmpty || label == e.label) return;
    final exists = await repo.byLabel(label);
    if (exists != null) {
      if (mounted) TopToast.error(context, 'Estimasi "$label" sudah ada');
      return;
    }
    await repo.rename(e.id, label);
    if (mounted) TopToast.success(context, 'Estimasi diubah ✓');
    await refresh();
  }

  Future<void> _deleteEstimate(EstimateOptionRepository repo,
      EstimateOption e, Future<void> Function() refresh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Estimasi?'),
        content: Text('Hapus preset "${e.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await repo.delete(e.id);
      if (mounted) TopToast.success(context, 'Estimasi dihapus');
      await refresh();
    }
  }

  // ── Form Order (pakai layanan DB + dimensi + estimasi) ──
  void _openForm({PrintOrder? order}) {
    final isEdit = order != null;
    final nameC = TextEditingController(text: order?.customerName ?? '');
    final phoneC = TextEditingController(text: order?.customerPhone ?? '');
    final pagesC = TextEditingController(
        text: order != null && order.pages > 0 ? '${order.pages}' : '');
    final copiesC = TextEditingController(
        text: order != null && order.copies > 1 ? '${order.copies}' : '1');
    final widthC = TextEditingController(
        text: order != null && order.widthCm != null ? '${order.widthCm}' : '');
    final lengthC = TextEditingController(
        text:
            order != null && order.lengthCm != null ? '${order.lengthCm}' : '');
    final estimateC = TextEditingController(text: order?.estimateReady ?? '');
    final totalC = TextEditingController(
        text: order != null && order.total > 0 ? '${order.total}' : '');
    final notesC = TextEditingController(text: order?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    String serviceType = order?.serviceType ??
        (_serviceTypes.isNotEmpty ? _serviceTypes.first.name : 'Fotocopy');
    String paperSize = order?.paperSize ?? 'A4';
    final paperSizes = ['A4', 'A3', 'F4', 'A5', 'Letter', 'Legal', 'Custom'];
    // Estimasi preset dari DB — dropdown + opsi "Kustom…" (input bebas).
    List<EstimateOption> estimatePresets = [];
    String? estimateSelection = order?.estimateReady ?? null;
    bool estimateIsCustom = order?.estimateReady != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // Muat preset estimasi dari DB (sebelum render dropdown).
        EstimateOptionRepository(ref.read(databaseProvider))
            .getAll()
            .then((v) {
          if (ctx.mounted) {
            estimatePresets = v;
            if (estimateSelection == null &&
                order?.estimateReady == null &&
                v.isNotEmpty) {
              estimateSelection = v.first.label;
            }
          }
        });
        return StatefulBuilder(
          builder: (ctx, setForm) {
            return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(isEdit ? 'Edit Order' : 'Order Cetak Baru',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  // Service type dropdown — dari DB, tanpa icon
                  NusaDropdownField<String>(
                    label: 'Jenis Layanan',
                    value: serviceType,
                    items: _serviceTypes
                        .map((s) => DropdownMenuItem(
                            value: s.name, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) serviceType = v;
                    },
                  ),
                  const SizedBox(height: 12),
                  NusaFormField(
                      label: 'Nama Pelanggan',
                      controller: nameC,
                      hintText: 'Nama pelanggan',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  NusaFormField(
                      label: 'No. Telepon',
                      controller: phoneC,
                      hintText: 'Contoh: 0812-3456-7890',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: NusaFormField(
                            label: 'Jumlah Lembar',
                            controller: pagesC,
                            hintText: '0',
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: NusaFormField(
                            label: 'Copy',
                            controller: copiesC,
                            hintText: '1',
                            keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: NusaDropdownField<String>(
                      label: 'Ukuran Kertas',
                      value: paperSize,
                      items: paperSizes
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) paperSize = v;
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: NusaFormField(
                            label: 'Total (Rp)',
                            controller: totalC,
                            hintText: '0',
                            keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  // Dimensi cetak (opsional) — banner/spanduk/undangan
                  Row(children: [
                    Expanded(
                        child: NusaFormField(
                            label: 'Panjang (cm)',
                            controller: lengthC,
                            hintText: 'cth: 100',
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: NusaFormField(
                            label: 'Lebar (cm)',
                            controller: widthC,
                            hintText: 'cth: 50',
                            keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  // Estimasi Selesai — dropdown preset (CRUD) + Kustom…
                  NusaDropdownField<String?>(
                    label: 'Estimasi Selesai',
                    value: estimateIsCustom ? '__custom__' : estimateSelection,
                    items: [
                      ...estimatePresets
                          .map((e) => DropdownMenuItem<String?>(
                              value: e.label, child: Text(e.label))),
                      const DropdownMenuItem<String?>(
                          value: '__custom__', child: Text('Kustom…')),
                    ],
                    onChanged: (v) {
                      setForm(() {
                        if (v == '__custom__') {
                          estimateIsCustom = true;
                          estimateSelection = null;
                        } else {
                          estimateIsCustom = false;
                          estimateSelection = v;
                          estimateC.text = v ?? '';
                        }
                      });
                    },
                  ),
                  if (estimateIsCustom) ...[
                    const SizedBox(height: 12),
                    NusaFormField(
                        label: 'Estimasi (Kustom)',
                        controller: estimateC,
                        hintText: 'cth: 2 jam, Besok 14:00, 3 hari',
                        keyboardType: TextInputType.text),
                  ],
                  const SizedBox(height: 12),
                  NusaFormField(
                      label: 'Catatan',
                      controller: notesC,
                      hintText: 'Catatan tambahan...',
                      maxLines: 2),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: NusaConfig.activePrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final db = ref.read(databaseProvider);
                        final repo = PrintOrderRepository(db);
                        final customerName = nameC.text.trim();
                        final customerPhone = phoneC.text.trim().isEmpty
                            ? null
                            : phoneC.text.trim();
                        final pages = int.tryParse(pagesC.text) ?? 0;
                        final copies = int.tryParse(copiesC.text) ?? 1;
                        final widthCm = int.tryParse(widthC.text);
                        final lengthCm = int.tryParse(lengthC.text);
                        final estimateReady =
                            (estimateIsCustom ? estimateC.text : estimateSelection)
                                    ?.trim()
                                    .isEmpty ??
                                false
                                ? null
                                : (estimateIsCustom
                                    ? estimateC.text.trim()
                                    : estimateSelection);
                        final total = int.tryParse(totalC.text) ?? 0;
                        final notes = notesC.text.trim().isEmpty
                            ? null
                            : notesC.text.trim();
                        if (isEdit) {
                          await repo.update(order.id,
                              customerName: customerName,
                              customerPhone: customerPhone,
                              serviceType: serviceType,
                              pages: pages,
                              copies: copies,
                              paperSize: paperSize,
                              widthCm: widthCm,
                              lengthCm: lengthCm,
                              estimateReady: estimateReady,
                              total: total,
                              notes: notes);
                          if (ctx.mounted) {
                            TopToast.success(ctx, 'Order diperbarui ✓');
                          }
                        } else {
                          await repo.add(
                            customerName: customerName,
                            customerPhone: customerPhone,
                            serviceType: serviceType,
                            pages: pages,
                            copies: copies,
                            paperSize: paperSize,
                            widthCm: widthCm,
                            lengthCm: lengthCm,
                            estimateReady: estimateReady,
                            total: total,
                            notes: notes,
                          );
                          if (ctx.mounted) {
                            TopToast.success(
                                ctx, 'Order cetak baru ditambahkan ✓');
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      child:
                          Text(isEdit ? 'Simpan Perubahan' : 'Tambah Order'),
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
