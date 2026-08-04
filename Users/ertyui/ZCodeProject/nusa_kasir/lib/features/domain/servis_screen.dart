/// Bengkel & Service HP: Service ticket management (status, sparepart needed, cost est).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/service_ticket_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class ServisScreen extends ConsumerStatefulWidget {
  const ServisScreen({super.key});

  @override
  ConsumerState<ServisScreen> createState() => _ServisScreenState();
}

class _ServisScreenState extends ConsumerState<ServisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Semua', 'Diagnosa', 'Estimasi', 'Perbaikan', 'Selesai', 'Diambil'];
  List<ServiceTicket> _all = [];
  List<ServiceTicket> _filtered = [];
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
    final repo = ServiceTicketRepository(db);
    final data = await repo.getAll();
    final counts = <String, int>{};
    for (final s in _tabs) {
      if (s == 'Semua') {
        counts[s] = data.length;
      } else {
        counts[s] = await repo.countByStatus(s);
      }
    }
    if (!mounted) return;
    setState(() { _all = data; _counts = counts; _loading = false; });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    final idx = _tabController.index;
    var list = _all;
    if (idx > 0) list = list.where((t) => t.status == _tabs[idx]).toList();
    if (q.isNotEmpty) {
      list = list.where((t) =>
          t.customerName.toLowerCase().contains(q) ||
          (t.customerPhone ?? '').contains(q) ||
          t.deviceName.toLowerCase().contains(q) ||
          t.issue.toLowerCase().contains(q)).toList();
    }
    setState(() => _filtered = list);
  }

  Color _chipColor(String status) {
    switch (status) {
      case 'Diagnosa': return NusaConfig.warning;
      case 'Estimasi': return NusaConfig.info;
      case 'Perbaikan': return NusaConfig.accentPurple;
      case 'Selesai': return NusaConfig.success;
      case 'Diambil': return NusaConfig.textTertiary;
      default: return NusaConfig.activePrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Tiket Servis',
      Column(children: [
        // Tab bar
        Container(
          height: 48,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: NusaConfig.activePrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(3),
            tabs: _tabs.map((t) => Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t),
                if ((_counts[t] ?? 0) > 0) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _tabController.index == _tabs.indexOf(t)
                          ? Colors.white24
                          : (isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_counts[t]}', style: const TextStyle(fontSize: 10)),
                  ),
                ],
              ]),
            )).toList(),
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Cari pelanggan, device, atau masalah...',
              hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
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
                      Icon(Icons.build_circle_outlined, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      const SizedBox(height: 16),
                      Text('Belum ada tiket servis', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _ticketCard(_filtered[i], isDark),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tiket Baru'),
      ),
    );
  }

  Widget _ticketCard(ServiceTicket t, bool isDark) {
    final statusColor = _chipColor(t.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(t.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          if (t.customerPhone != null && t.customerPhone!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(t.customerPhone!, style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.devices, size: 16, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(width: 4),
            Expanded(child: Text(t.deviceName, style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.report_problem_outlined, size: 16, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(width: 4),
            Expanded(child: Text(t.issue, style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          if (t.estimatedCost > 0 || t.finalCost > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              if (t.estimatedCost > 0)
                Chip(label: Text('Estimasi: ${formatRupiah(t.estimatedCost)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.warning.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              if (t.finalCost > 0) ...[const SizedBox(width: 6),
                Chip(label: Text('Final: ${formatRupiah(t.finalCost)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.success.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              ],
            ]),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _nextStatusButton(t),
            const SizedBox(width: 6),
            _actionButton(Icons.edit_outlined, 'Edit', () => _openForm(ticket: t), isDark),
            const SizedBox(width: 4),
            _actionButton(Icons.delete_outline, 'Hapus', () => _deleteTicket(t), isDark),
          ]),
        ]),
      ),
    );
  }

  Widget _nextStatusButton(ServiceTicket t) {
    final next = _nextStatus(t.status);
    if (next == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () => _advanceStatus(t, next),
      icon: Icon(Icons.arrow_forward, size: 14, color: NusaConfig.activePrimary),
      label: Text(next, style: TextStyle(fontSize: 11, color: NusaConfig.activePrimary)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: NusaConfig.activePrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget _actionButton(IconData icon, String tooltip, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
      ),
    );
  }

  String? _nextStatus(String s) {
    const flow = {'Diagnosa': 'Estimasi', 'Estimasi': 'Perbaikan', 'Perbaikan': 'Selesai', 'Selesai': 'Diambil'};
    return flow[s];
  }

  Future<void> _advanceStatus(ServiceTicket t, String to) async {
    final db = ref.read(databaseProvider);
    await ServiceTicketRepository(db).updateStatus(t.id, to);
    TopToast.success(context, 'Status → $to ✓');
    _load();
  }

  Future<void> _deleteTicket(ServiceTicket t) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Tiket?'),
      content: Text('Hapus tiket servis ${t.customerName} — ${t.deviceName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      await ServiceTicketRepository(ref.read(databaseProvider)).delete(t.id);
      TopToast.success(context, 'Tiket dihapus');
      _load();
    }
  }

  void _openForm({ServiceTicket? ticket}) {
    final isEdit = ticket != null;
    final nameC = TextEditingController(text: ticket?.customerName ?? '');
    final phoneC = TextEditingController(text: ticket?.customerPhone ?? '');
    final deviceC = TextEditingController(text: ticket?.deviceName ?? '');
    final issueC = TextEditingController(text: ticket?.issue ?? '');
    final estC = TextEditingController(text: ticket != null && ticket.estimatedCost > 0 ? '${ticket.estimatedCost}' : '');
    final finalC = TextEditingController(text: ticket != null && ticket.finalCost > 0 ? '${ticket.finalCost}' : '');
    final notesC = TextEditingController(text: ticket?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Tiket' : 'Tiket Servis Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                NusaFormField(label: 'Nama Pelanggan', controller: nameC, hintText: 'Nama pelanggan', validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                NusaFormField(label: 'No. Telepon', controller: phoneC, hintText: 'Contoh: 0812-3456-7890', keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                NusaFormField(label: 'Nama Perangkat', controller: deviceC, hintText: 'Contoh: iPhone 13, Samsung A52', validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                NusaFormField(label: 'Keluhan / Masalah', controller: issueC, hintText: 'Deskripsikan masalah perangkat...', maxLines: 3, validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: NusaFormField(label: 'Estimasi Biaya', controller: estC, hintText: 'Rp', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: NusaFormField(label: 'Biaya Final', controller: finalC, hintText: 'Rp', keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
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
                      final db = ref.read(databaseProvider);
                      final repo = ServiceTicketRepository(db);
                      final estCost = int.tryParse(estC.text) ?? 0;
                      if (isEdit) {
                        await repo.updateCost(ticket!.id, finalCost: int.tryParse(finalC.text), notes: notesC.text.isNotEmpty ? notesC.text : null);
                        TopToast.success(context, 'Tiket diperbarui ✓');
                      } else {
                        await repo.add(
                          customerName: nameC.text.trim(),
                          customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                          deviceName: deviceC.text.trim(),
                          issue: issueC.text.trim(),
                          estimatedCost: estCost,
                          notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                        );
                        TopToast.success(context, 'Tiket servis baru ditambahkan ✓');
                      }
                      Navigator.pop(ctx);
                      _load();
                    },
                    child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Tiket'),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        );
      },
    );
  }
}
