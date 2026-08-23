import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/recipe_repository.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// CRUD kamus satuan global (tambah/rename/hapus) — REUSABLE (v2.2.44 B4).
///
/// Dibuka dari 3 tempat: form produk (toggle Satuan), tab Bahan Baku (F&B),
/// dan tab Produk (header action). Kembali `true` bila kamus diubah sehingga
/// pemanggil bisa reload kamusnya.
class UnitManagerSheet extends StatefulWidget {
  final RecipeRepository repo;
  const UnitManagerSheet({super.key, required this.repo});

  /// Buka sebagai bottom sheet; return `true` bila ada perubahan.
  static Future<bool> show({
    required BuildContext context,
    required RecipeRepository repo,
  }) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnitManagerSheet(repo: repo),
    );
    return res ?? false;
  }

  @override
  State<UnitManagerSheet> createState() => _UnitManagerSheetState();
}

class _UnitManagerSheetState extends State<UnitManagerSheet> {
  late Future<List<Unit>> _future;
  final _newCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getUnits();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.repo.getUnits());
  }

  Future<void> _add() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) {
      TopToast.error(context, 'Isi nama satuan');
      return;
    }
    try {
      await widget.repo.addUnit(name);
      _newCtrl.clear();
      _reload();
    } catch (_) {
      TopToast.error(context, 'Satuan "$name" sudah ada');
    }
  }

  Future<void> _rename(Unit u) async {
    final newCtrl = TextEditingController(text: u.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : NusaConfig.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Ubah Satuan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nama satuan',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Batal'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(ctx, newCtrl.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NusaConfig.activePrimary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    newCtrl.dispose();
    if (result == null || result.isEmpty || result == u.name) return;
    try {
      await widget.repo.renameUnit(u.id, result);
      _reload();
    } catch (_) {
      TopToast.error(context, 'Nama satuan sudah ada');
    }
  }

  Future<void> _delete(Unit u) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Hapus Satuan "${u.name}"?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Satuan yang dipakai bahan/produk akan dilepas (tidak dihapus datanya).',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Batal'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NusaConfig.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await widget.repo.deleteUnit(u.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kelola Satuan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: NusaConfig.textSecondary),
                  onPressed: () {
                    // Tutup dengan hasil "diubah" — pemanggil reload kamus
                    // sendiri; selalu true karena bisa saja pengguna mengubah
                    // lalu menutup tanpa menekan tombol lain.
                    Navigator.pop(context, true);
                  },
                ),
              ],
            ),
            // Tambah baru (keyboard naik → konten tetap terlihat via viewInsets)
            Padding(
              padding: EdgeInsets.only(bottom: bottom > 0 ? 8 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nama satuan baru (cth: dus)',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _add,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NusaConfig.activePrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text('Tambah'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Unit>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final units = snap.data ?? const [];
                  if (units.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada satuan. Tambah di atas.',
                        style: TextStyle(
                          color: NusaConfig.textSecondary,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: units.length,
                    separatorBuilder: (_, __) => Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = units[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          u.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20),
                              color: NusaConfig.activePrimary,
                              onPressed: () => _rename(u),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 20),
                              color: NusaConfig.error,
                              onPressed: () => _delete(u),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
