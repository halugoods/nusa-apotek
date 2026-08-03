/// F&B: Table management — cinema-seat grid layout with DB persistence.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/dining_table_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class MejaScreen extends ConsumerStatefulWidget {
  const MejaScreen({super.key});

  @override
  ConsumerState<MejaScreen> createState() => _MejaScreenState();
}

class _MejaScreenState extends ConsumerState<MejaScreen> {
  List<DiningTable> _tables = [];
  bool _loading = true;
  int _gridCols = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final repo = DiningTableRepository(db);
    final data = await repo.getAll();
    // Auto-create default tables if empty
    if (data.isEmpty) {
      for (var i = 0; i < 12; i++) {
        await repo.add(name: 'Meja ${i + 1}');
      }
      final fresh = await repo.getAll();
      if (!mounted) return;
      setState(() { _tables = fresh; _loading = false; });
    } else {
      if (!mounted) return;
      setState(() { _tables = data; _loading = false; });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Kosong': return NusaConfig.success;
      case 'Dipesan': return NusaConfig.warning;
      case 'Tutup': return NusaConfig.textTertiary;
      default: return NusaConfig.activePrimary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Kosong': return Icons.table_bar;
      case 'Dipesan': return Icons.table_bar_outlined;
      case 'Tutup': return Icons.block;
      default: return Icons.table_bar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cols = _tables.isEmpty ? _gridCols : (_tables.length < 4 ? _tables.length : _gridCols);
    return ScreenScaffold('Meja & Ruangan', _loading
        ? const Center(child: CircularProgressIndicator())
        : _tables.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.table_bar, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                const SizedBox(height: 16),
                Text('Belum ada meja', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              ]))
            : Column(children: [
                // Stats row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    _statChip('Kosong', _tables.where((t) => t.status == 'Kosong').length, NusaConfig.success, isDark),
                    _statChip('Dipesan', _tables.where((t) => t.status == 'Dipesan').length, NusaConfig.warning, isDark),
                    _statChip('Tutup', _tables.where((t) => t.status == 'Tutup').length, NusaConfig.textTertiary, isDark),
                  ]),
                ),
                // Grid size picker
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Text('Kolom: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    DropdownButton<int>(
                      value: _gridCols,
                      underline: const SizedBox(),
                      items: List.generate(6, (i) => DropdownMenuItem(value: i + 2, child: Text('${i + 2}'))),
                      onChanged: (v) => setState(() => _gridCols = v!),
                    ),
                    const Spacer(),
                    Text('${_tables.length} meja', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  ]),
                ),
                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: _tables.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (_, i) {
                      final t = _tables[i];
                      final sc = _statusColor(t.status);
                      return GestureDetector(
                        onTap: () => _cycleStatus(t),
                        onLongPress: () => _editTable(t),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sc.withOpacity(0.5), width: 2),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_statusIcon(t.status), size: 28, color: sc),
                            const SizedBox(height: 6),
                            Text(t.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(t.status, style: TextStyle(fontSize: 11, color: sc)),
                            if (t.capacity > 0)
                              Text('Kap. ${t.capacity}', style: TextStyle(fontSize: 10, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTable(),
        backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Tambah Meja'),
      ),
    );
  }

  Widget _statChip(String label, int count, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        ]),
      ),
    );
  }

  Future<void> _cycleStatus(DiningTable t) async {
    final next = t.status == 'Kosong' ? 'Dipesan' : (t.status == 'Dipesan' ? 'Tutup' : 'Kosong');
    await DiningTableRepository(ref.read(databaseProvider)).updateStatus(t.id, next);
    TopToast.success(context, '${t.name} → $next');
    _load();
  }

  void _addTable() {
    final nameC = TextEditingController();
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      return Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Tambah Meja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        NusaFormField(label: 'Nama Meja', controller: nameC, hintText: 'Contoh: Meja 13, VIP 1'),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (nameC.text.trim().isEmpty) return;
            await DiningTableRepository(ref.read(databaseProvider)).add(name: nameC.text.trim());
            TopToast.success(context, 'Meja ditambahkan ✓');
            Navigator.pop(ctx);
            _load();
          },
          child: const Text('Tambah'),
        )),
        const SizedBox(height: 8),
      ]));
    });
  }

  void _editTable(DiningTable t) {
    final nameC = TextEditingController(text: t.name);
    final capC = TextEditingController(text: t.capacity > 0 ? '${t.capacity}' : '');
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      return Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Edit Meja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        NusaFormField(label: 'Nama Meja', controller: nameC, hintText: 'Nama meja'),
        const SizedBox(height: 12),
        NusaFormField(label: 'Kapasitas', controller: capC, hintText: 'Jumlah kursi', keyboardType: TextInputType.number),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(title: const Text('Hapus Meja?'), content: Text('Hapus ${t.name}?'), actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
            ]));
            if (ok == true) { await DiningTableRepository(ref.read(databaseProvider)).delete(t.id); Navigator.pop(ctx); TopToast.success(context, 'Meja dihapus'); _load(); }
          },
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
          label: const Text('Hapus Meja', style: TextStyle(color: Colors.red, fontSize: 13)),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (nameC.text.trim().isEmpty) return;
            await DiningTableRepository(ref.read(databaseProvider)).update(t.id, name: nameC.text.trim(), capacity: int.tryParse(capC.text));
            TopToast.success(context, 'Meja diperbarui ✓');
            Navigator.pop(ctx);
            _load();
          },
          child: const Text('Simpan'),
        )),
        const SizedBox(height: 8),
      ]));
    });
  }
}
