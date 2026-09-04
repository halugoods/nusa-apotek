// Fotocopy/Percetakan: Print/copy order management.
// Jenis layanan dari DB (PrintServiceTypes) — custom, TANPA icon bulat.
// Order punya dimensi (P×L cm) + estimasi selesai (opsional).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/services/online_order_service.dart';
import 'package:nusa_kasir/core/utils/contact_picker.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/print_order_repository.dart';
import 'package:nusa_kasir/data/repositories/print_service_type_repository.dart';
import 'package:nusa_kasir/data/repositories/estimate_option_repository.dart';
import 'package:nusa_kasir/shared/widgets/customer_picker_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// v2.2.35: config field form Order Cetak per layanan.
/// `fields_json` = JSON array field: builtin (key slug) + kustom
/// (`__custom__` + label). null / parse gagal → semua field bawaan tampil.
class _PrintField {
  final String key;
  final String label;
  final bool builtin;
  const _PrintField({
    required this.key,
    required this.label,
    required this.builtin,
  });
}

/// Field bawaan yang bisa dipilih per layanan (urutan tampil).
/// 'nama' (Nama Pelanggan) selalu tampil — order wajib punya nama.
const List<(String, String)> _printBuiltinFields = [
  ('nama', 'Nama Pelanggan'),
  ('no_telp', 'No. Telepon'),
  ('jumlah_lembar', 'Jumlah Lembar'),
  ('copy', 'Copy'),
  ('ukuran_kertas', 'Ukuran Kertas'),
  ('panjang', 'Panjang (cm)'),
  ('lebar', 'Lebar (cm)'),
  ('total', 'Total (Rp)'),
  ('estimasi', 'Estimasi Selesai'),
  ('catatan', 'Catatan'),
];

/// Label bawaan dari key slug — null bila bukan field bawaan.
String? _builtinLabel(String key) {
  for (final f in _printBuiltinFields) {
    if (f.$1 == key) return f.$2;
  }
  return null;
}

/// Semua field bawaan (default saat config null).
List<_PrintField> _allBuiltinFields() => [
      for (final f in _printBuiltinFields)
        _PrintField(key: f.$1, label: f.$2, builtin: true),
    ];

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
  // Pull config field form dari cloud hanya SEKALI per sesi (fresh install /
  // clear-data) — supaya tidak mengetuk edge function tiap buka layar.
  static bool _cloudPullAttempted = false;

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
    _pullCloudConfigsIfNeeded(svc);
  }

  /// Tarik config field form dari cloud saat layanan belum punya config
  /// lokal (fresh install / clear-data / ganti device). Fire-and-forget.
  Future<void> _pullCloudConfigsIfNeeded(List<PrintServiceType> svc) async {
    if (_cloudPullAttempted) return;
    _cloudPullAttempted = true;
    final needs = svc.any((s) => s.fieldsJson == null);
    if (!needs) return;
    try {
      final online = OnlineOrderService();
      final configs = await online.getPrintFormConfigs();
      if (configs.isEmpty) return;
      final db = ref.read(databaseProvider);
      final repo = PrintServiceTypeRepository(db);
      for (final c in configs) {
        final name = c['service_name'] as String?;
        final fieldsJson = c['fields_json'] as String?;
        if (name == null || fieldsJson == null || fieldsJson.isEmpty) continue;
        final local = svc.where((s) => s.name == name).firstOrNull;
        if (local != null && local.fieldsJson == null) {
          await repo.setFieldsJson(local.id, fieldsJson);
        }
      }
      if (mounted) _load();
    } catch (e) {
      debugPrint('[PrintOrder] pull print form configs gagal (dilewati): $e');
    }
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
        // Kelola Layanan + Estimasi — SATU tombol (sheet 2 segmen).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _manageButton(
            icon: Icons.tune_rounded,
            label: 'Kelola',
            isDark: isDark,
            onTap: _openManager,
          ),
        ),
        // Status tabs — segmented 4 switch (gaya menu Pelanggan).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _segmented(
            options: _statusTabs,
            selected: _statusTabs[_tabController.index],
            onSelect: (opt) {
              final i = _statusTabs.indexOf(opt);
              if (i != _tabController.index) _tabController.animateTo(i);
            },
          ),
        ),
        // Search + customer picker (sejajar — pola booking/laundry/servis)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              // Search bar standar (v2.2.54)
              child: NusaSearchBar(
                controller: _search,
                hint: 'Cari pelanggan…',
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

  /// Segmented 4 switch — gaya menu Pelanggan (height 36, radius 10,
  /// segmen aktif activePrimary radius 8).
  Widget _segmented({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
      ),
      child: Row(
        children: options.map((opt) {
          final active = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? NusaConfig.activePrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : (isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
          // v2.2.35: field kustom per layanan — tampil di kartu order.
          if (o.customFieldsJson != null && o.customFieldsJson!.isNotEmpty)
            ..._buildCustomFieldChips(o.customFieldsJson!, isDark),
        ]),
      ),
    );
  }

  /// Chip field kustom dari JSON — hanya nilai yang terisi (bukan kosong).
  List<Widget> _buildCustomFieldChips(String raw, bool isDark) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return const [];
      final chips = <Widget>[];
      for (final e in m.entries) {
        if (e.key is String && e.value is String && (e.value as String).trim().isNotEmpty) {
          chips.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.key}: ',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary)),
              Expanded(
                child: Text(e.value as String,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)),
              ),
            ]),
          ));
        }
      }
      return chips;
    } catch (_) {
      return const [];
    }
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

  // ── Kelola (SATU tombol) — sheet 2 segmen: Layanan | Estimasi ──
  Future<void> _openManager() async {
    final db = ref.read(databaseProvider);
    final sRepo = PrintServiceTypeRepository(db);
    final eRepo = EstimateOptionRepository(db);
    final services = await sRepo.getAll();
    final estimates = await eRepo.getAll();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // List mutable lokal — refresh() memperbarui list di dalam sheet.
        var svc = List<PrintServiceType>.from(services);
        var est = List<EstimateOption>.from(estimates);
        String segmen = 'Layanan';
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> refreshServices() async {
            svc = await sRepo.getAll();
            if (ctx.mounted) setSheet(() {});
          }

          Future<void> refreshEstimates() async {
            est = await eRepo.getAll();
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
                  const Text('Kelola',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: NusaConfig.activePrimary),
                    tooltip: segmen == 'Layanan'
                        ? 'Tambah layanan'
                        : 'Tambah estimasi',
                    onPressed: () => segmen == 'Layanan'
                        ? _addService(sRepo, refreshServices)
                        : _addEstimate(eRepo, refreshEstimates),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  segmen == 'Layanan'
                      ? 'Atur layanan + field form-nya (sesuai kebutuhan cetak).'
                      : 'Preset waktu selesai — dipilih lewat dropdown.',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary),
                ),
                const SizedBox(height: 10),
                _segmented(
                  options: const ['Layanan', 'Estimasi'],
                  selected: segmen,
                  onSelect: (v) => setSheet(() => segmen = v),
                ),
                const SizedBox(height: 8),
                if (segmen == 'Layanan') ...[
                  if (svc.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Belum ada layanan — tambah dulu.',
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: svc.length,
                        itemBuilder: (_, i) {
                          final s = svc[i];
                          final fields = _serviceFields(s);
                          final sub = s.fieldsJson == null
                              ? 'Semua field tampil'
                              : '${fields.length} field form';
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
                            subtitle: Text(
                                s.isDefault ? 'Bawaan · $sub' : sub,
                                style: const TextStyle(fontSize: 11)),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Field form',
                                    icon: const Icon(Icons.checklist_rounded,
                                        size: 18),
                                    onPressed: () => _editServiceFields(
                                        sRepo, s, refreshServices),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    onPressed: () =>
                                        _renameService(sRepo, s, refreshServices),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: () =>
                                        _deleteService(sRepo, s, refreshServices),
                                  ),
                                ]),
                          );
                        },
                      ),
                    ),
                ] else ...[
                  if (est.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Belum ada preset estimasi.',
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: est.length,
                        itemBuilder: (_, i) {
                          final e = est[i];
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
                                        _renameEstimate(eRepo, e, refreshEstimates),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: () =>
                                        _deleteEstimate(eRepo, e, refreshEstimates),
                                  ),
                                ]),
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  /// Field form yang TAMPIL untuk layanan [s].
  /// fields_json null / rusak → semua field bawaan (default).
  List<_PrintField> _serviceFields(PrintServiceType s) {
    final raw = s.fieldsJson;
    if (raw == null || raw.trim().isEmpty) return _allBuiltinFields();
    try {
      final arr = jsonDecode(raw);
      if (arr is! List || arr.isEmpty) return _allBuiltinFields();
      return [
        for (final e in arr)
          if (e is String && e.isNotEmpty)
            _PrintField(
              key: e,
              label: _builtinLabel(e) ?? e,
              builtin: _builtinLabel(e) != null,
            ),
      ];
    } catch (_) {
      return _allBuiltinFields();
    }
  }

  /// Editor config field form per layanan — checkbox field bawaan +
  /// field kustom CRUD. Simpan fields_json lalu sync ke cloud (lepas).
  Future<void> _editServiceFields(
      PrintServiceTypeRepository repo,
      PrintServiceType s,
      Future<void> Function() refresh) async {
    final current = _serviceFields(s);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // selected = key field bawaan yang dicentang; customs = label kustom.
    var selected = <String>{
      for (final f in current)
        if (f.builtin) f.key,
    };
    var customs = <String>[
      for (final f in current)
        if (!f.builtin) f.label,
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
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
                  Expanded(
                    child: Text('Field Form — ${s.name}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () {
                      selected = {for (final b in _printBuiltinFields) b.$1};
                      setSheet(() {});
                    },
                    child: const Text('Pilih Semua',
                        style: TextStyle(fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('Field yang tampil saat membuat order untuk layanan ini.',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in _printBuiltinFields)
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(b.$2,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500)),
                          value: selected.contains(b.$1),
                          activeColor: NusaConfig.activePrimary,
                          onChanged: (v) => setSheet(() {
                            if (v == true) {
                              selected.add(b.$1);
                            } else {
                              selected.remove(b.$1);
                            }
                          }),
                        ),
                      const Divider(height: 20),
                      Row(children: [
                        const Text('Field Kustom',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final label = await _promptCustomField(ctx);
                            if (label == null || label.isEmpty) return;
                            if (customs.contains(label)) {
                              if (ctx.mounted) {
                                TopToast.error(ctx, 'Field "$label" sudah ada');
                              }
                              return;
                            }
                            setSheet(() => customs.add(label));
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ]),
                      if (customs.isEmpty)
                        Text('Belum ada field kustom.',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary))
                      else
                        for (final c in customs)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.label_outline,
                                size: 18, color: NusaConfig.activePrimary),
                            title: Text(c,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500)),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    onPressed: () async {
                                      final label =
                                          await _promptCustomField(ctx, old: c);
                                      if (label == null ||
                                          label.isEmpty ||
                                          label == c) {
                                        return;
                                      }
                                      if (customs.contains(label)) {
                                        if (ctx.mounted) {
                                          TopToast.error(ctx,
                                              'Field "$label" sudah ada');
                                        }
                                        return;
                                      }
                                      setSheet(() {
                                        customs[customs.indexOf(c)] = label;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: () => setSheet(
                                        () => customs.remove(c)),
                                  ),
                                ]),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: NusaConfig.activePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      // Semua bawaan tercentang + tanpa kustom → null (default).
                      final allBuiltin = _printBuiltinFields
                          .every((b) => selected.contains(b.$1));
                      final list = <String>[
                        for (final b in _printBuiltinFields)
                          if (selected.contains(b.$1)) b.$1,
                        ...customs,
                      ];
                      final jsonStr =
                          (allBuiltin && customs.isEmpty) ? null : jsonEncode(list);
                      await repo.setFieldsJson(s.id, jsonStr);
                      if (ctx.mounted) {
                        TopToast.success(ctx, 'Form layanan diperbarui ✓');
                      }
                      await refresh();
                      _syncPrintConfigsToCloud();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Simpan'),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        });
      },
    );
  }

  /// Dialog input label field kustom (tambah/rename). Kembalikan label.
  Future<String?> _promptCustomField(BuildContext ctx, {String? old}) async {
    final ctrl = TextEditingController(text: old ?? '');
    final key = GlobalKey<FormState>();
    return showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(old == null ? 'Tambah Field Kustom' : 'Ubah Field Kustom'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Cth: Warna, Bahan, Ukuran Banner...'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal')),
          TextButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(dialogCtx, ctrl.text.trim());
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
  }

  /// Upload config field form SEMUA layanan ke cloud (fire-and-forget) —
  /// cadangan supaya tidak hilang saat clear-data / ganti device.
  void _syncPrintConfigsToCloud() {
    unawaited(() async {
      try {
        final db = ref.read(databaseProvider);
        final svc = await PrintServiceTypeRepository(db).getAll();
        final online = OnlineOrderService();
        await online.syncPrintFormConfigs([
          for (final s in svc)
            {
              'service_name': s.name,
              'fields_json': s.fieldsJson,
            },
        ]);
      } catch (e) {
        debugPrint('[PrintOrder] syncPrintFormConfigs gagal (dilewati): $e');
      }
    }());
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
    // v2.2.35: field kustom per layanan — controller per label.
    // Order lama: customFieldsJson mungkin null → muat dari label field
    // kustom yang tampil (biar edit tidak kehilangan nilai).
    final customCtrls = <String, TextEditingController>{};
    final savedCustom = <String, String>{};
    if (order != null && order.customFieldsJson != null) {
      try {
        final m = jsonDecode(order.customFieldsJson!);
        if (m is Map) {
          for (final e in m.entries) {
            if (e.key is String && e.value is String) {
              savedCustom[e.key as String] = e.value as String;
            }
          }
        }
      } catch (_) {}
    }
    // Sinkronkan service type + controller kustom bila layanan berubah.
    void syncCustomForService(String svcName) {
      final svc = _serviceTypes.where((s) => s.name == svcName).firstOrNull;
      if (svc == null) return;
      for (final f in _serviceFields(svc)) {
        if (f.builtin) continue;
        customCtrls.putIfAbsent(
            f.label,
            () =>
                TextEditingController(text: savedCustom[f.label] ?? ''));
      }
    }

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
        syncCustomForService(serviceType);
        return StatefulBuilder(
          builder: (ctx, setForm) {
            // Field kustom sesuai layanan terpilih — render dinamis.
            final activeSvc =
                _serviceTypes.where((s) => s.name == serviceType).firstOrNull;
            final formFields =
                activeSvc != null ? _serviceFields(activeSvc) : _allBuiltinFields();
            bool has(String key) =>
                formFields.any((f) => f.builtin && f.key == key);
            final customFields =
                formFields.where((f) => !f.builtin).toList();

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
                      if (v == null || v == serviceType) return;
                      setForm(() {
                        serviceType = v;
                        syncCustomForService(v);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (has('nama')) ...[
                    NusaFormField(
                        label: 'Nama Pelanggan',
                        controller: nameC,
                        hintText: 'Nama pelanggan',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 12),
                  ],
                  if (has('no_telp')) ...[
                    NusaFormField(
                        label: 'No. Telepon',
                        controller: phoneC,
                        hintText: 'Contoh: 0812-3456-7890',
                        keyboardType: TextInputType.phone,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.contacts_outlined,
                              size: 20, color: NusaConfig.activePrimary),
                          onPressed: () async {
                            final contact = await pickContact();
                            if (contact != null && ctx.mounted) {
                              final name = contact['name'] ?? '';
                              final phone = contact['phone'] ?? '';
                              setForm(() {
                                if (name.isNotEmpty && nameC.text.isEmpty) {
                                  nameC.text = name;
                                }
                                if (phone.isNotEmpty) {
                                  phoneC.text = phone;
                                }
                              });
                            }
                          },
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (has('jumlah_lembar') && has('copy')) ...[
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
                  ] else if (has('jumlah_lembar')) ...[
                    NusaFormField(
                        label: 'Jumlah Lembar',
                        controller: pagesC,
                        hintText: '0',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ] else if (has('copy')) ...[
                    NusaFormField(
                        label: 'Copy',
                        controller: copiesC,
                        hintText: '1',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ],
                  if (has('ukuran_kertas') && has('total')) ...[
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
                  ] else if (has('ukuran_kertas')) ...[
                    NusaDropdownField<String>(
                      label: 'Ukuran Kertas',
                      value: paperSize,
                      items: paperSizes
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) paperSize = v;
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else if (has('total')) ...[
                    NusaFormField(
                        label: 'Total (Rp)',
                        controller: totalC,
                        hintText: '0',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ],
                  // Dimensi cetak (opsional) — banner/spanduk/undangan
                  if (has('panjang') && has('lebar')) ...[
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
                  ] else if (has('panjang')) ...[
                    NusaFormField(
                        label: 'Panjang (cm)',
                        controller: lengthC,
                        hintText: 'cth: 100',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ] else if (has('lebar')) ...[
                    NusaFormField(
                        label: 'Lebar (cm)',
                        controller: widthC,
                        hintText: 'cth: 50',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ],
                  if (has('estimasi')) ...[
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
                  ],
                  if (has('catatan')) ...[
                    NusaFormField(
                        label: 'Catatan',
                        controller: notesC,
                        hintText: 'Catatan tambahan...',
                        maxLines: 2),
                    const SizedBox(height: 12),
                  ],
                  // ── Field kustom per layanan ──
                  for (final f in customFields) ...[
                    NusaFormField(
                        label: f.label,
                        controller: customCtrls[f.label] ??
                            (customCtrls[f.label] = TextEditingController(
                                text: savedCustom[f.label] ?? '')),
                        hintText: 'Isi ${f.label.toLowerCase()}...',
                        keyboardType: TextInputType.text),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
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
                        // Nilai field kustom yang TAMPAK (bukan yang sudah
                        // dihapus dari config) — map label→nilai.
                        final customJson = customFields.isEmpty
                            ? null
                            : jsonEncode({
                                for (final f in customFields)
                                  f.label:
                                      (customCtrls[f.label]?.text ?? '').trim(),
                              });
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
                              notes: notes,
                              customFieldsJson: customJson);
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
                            customFieldsJson: customJson,
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
