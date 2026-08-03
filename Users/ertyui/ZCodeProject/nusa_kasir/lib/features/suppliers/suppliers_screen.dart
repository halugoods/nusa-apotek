import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/contact_picker.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  SuppliersScreen({super.key});
  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  List<Supplier> _list = [];
  bool _loading = true;
  String _query = '';
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() => _query = _searchC.text);

  List<Supplier> get _filtered => _query.isEmpty
      ? _list
      : _list.where((s) =>
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          (s.phone?.contains(_query) ?? false) ||
          (s.contactPerson?.toLowerCase().contains(_query.toLowerCase()) ?? false)
      ).toList();

  Future<void> _load() async {
    final repo = SupplierRepository(ref.read(databaseProvider));
    final all = await repo.getSuppliers();
    if (mounted) setState(() { _list = all; _loading = false; });
  }

  void _showForm({Supplier? existing}) {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final addrC = TextEditingController(text: existing?.address ?? '');
    final cpC = TextEditingController(text: existing?.contactPerson ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String? error;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20, 10, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with icon
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_shipping_outlined,
                        color: NusaConfig.activePrimary, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      )),
                ]),
                SizedBox(height: 16),
                NusaInput('Nama Supplier', controller: nameC, hint: 'Cth: PT Maju Jaya'),
                SizedBox(height: 12),
                NusaInput('Kontak Person', controller: cpC, hint: 'Cth: Bapak Budi',
                    prefixIcon: Icon(Icons.person_outline, size: 18,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: NusaInput('Telepon', controller: phoneC, type: TextInputType.phone, hint: 'Cth: 08123456789',
                          prefixIcon: Icon(Icons.phone, size: 18,
                              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final contact = await pickContact();
                        if (contact != null) {
                          final name = contact['name'] ?? '';
                          final phone = contact['phone'] ?? '';
                          // Kontak Person ← nama kontak
                          if (name.isNotEmpty && cpC.text.trim().isEmpty) {
                            cpC.text = name;
                          }
                          // Telepon ← nomor kontak
                          if (phone.isNotEmpty) {
                            phoneC.text = phone;
                          }
                          setSt(() {}); // refresh UI
                        }
                      },
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.contacts_outlined,
                            color: NusaConfig.activePrimary, size: 22),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                NusaInput('Alamat', controller: addrC, hint: 'Cth: Jl. Merdeka No. 10',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                SizedBox(height: 12),
                NusaInput('Catatan', controller: noteC, hint: 'Cth: Supplier bahan baku',
                    prefixIcon: Icon(Icons.notes_outlined, size: 18,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                if (error != null) ...[
                  SizedBox(height: 8),
                  Text(error!, style:  TextStyle(color: NusaConfig.activePrimary, fontSize: 13)),
                ],
                SizedBox(height: 20),
                // Action buttons
                Row(children: [
                  if (isEdit)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _confirmDelete(existing);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NusaConfig.activePrimary,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Hapus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (isEdit) SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameC.text.trim();
                        if (name.isEmpty) {
                          setSt(() => error = 'Nama wajib diisi');
                          return;
                        }
                        final repo = SupplierRepository(ref.read(databaseProvider));
                        if (isEdit) {
                          await repo.updateSupplier(existing.id,
                              name: name,
                              phone: phoneC.text.trim(),
                              address: addrC.text.trim(),
                              contactPerson: cpC.text.trim(),
                              note: noteC.text.trim());
                        } else {
                          await repo.addSupplier(
                            name: name,
                            phone: phoneC.text.trim(),
                            address: addrC.text.trim(),
                            contactPerson: cpC.text.trim(),
                            note: noteC.text.trim(),
                          );
                        }
                        if (mounted) Navigator.of(context).pop();
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NusaConfig.activePrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isEdit ? 'Simpan' : 'Tambah',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Supplier s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Supplier'),
        content: Text('Yakin hapus "${s.name}"?\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal')),
          TextButton(
            onPressed: () async {
              final repo = SupplierRepository(ref.read(databaseProvider));
              await repo.deleteSupplier(s.id);
              if (mounted) { Navigator.of(context).pop(); TopToast.success(context, 'Supplier dihapus'); }
              _load();
            },
            style: TextButton.styleFrom(foregroundColor: NusaConfig.activePrimary),
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Export ─────────────────────────────────────────────────────

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(NusaConfig.spaceLG),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Ekspor Data Supplier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: NusaConfig.spaceMD),
            ListTile(
              leading: Icon(Icons.table_chart_outlined, color: NusaConfig.accentGreen),
              title: Text('Ekspor CSV (Excel)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text('File spreadsheet, bisa dibuka di Excel', style: TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD)),
              tileColor: NusaConfig.accentGreen.withValues(alpha: 0.06),
              onTap: () { Navigator.pop(context); _exportCSV(); },
            ),
            SizedBox(height: NusaConfig.spaceXS),
            ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined, color: NusaConfig.activePrimary),
              title: Text('Ekspor PDF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text('Dokumen PDF siap cetak', style: TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD)),
              tileColor: NusaConfig.activePrimary.withValues(alpha: 0.06),
              onTap: () { Navigator.pop(context); _exportPDF(); },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _exportCSV() async {
    try {
      final rows = <List<String>>[
        ['Nama', 'Telepon', 'Alamat', 'Kontak Person', 'Catatan'],
      ];
      for (final s in _list) {
        rows.add([s.name, s.phone ?? '', s.address ?? '', s.contactPerson ?? '', s.note ?? '']);
      }
      final csv = ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/supplier_nusa_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Daftar Supplier NUSA Kasir');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor CSV');
    }
  }

  Future<void> _exportPDF() async {
    try {
      final buf = StringBuffer('DAFTAR SUPPLIER - NUSA KASIR\n');
      buf.writeln('=' * 60);
      buf.writeln('Nama | Telepon | Alamat | Kontak Person | Catatan');
      buf.writeln('-' * 60);
      for (final s in _list) {
        buf.writeln('${s.name} | ${s.phone ?? '-'} | ${s.address ?? '-'} | ${s.contactPerson ?? '-'} | ${s.note ?? '-'}');
      }
      buf.writeln('=' * 60);
      buf.writeln('Total: ${_list.length} supplier');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/supplier_nusa_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Daftar Supplier NUSA Kasir');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Supplier',
      Column(
        children: [
          // Search + Export row
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder),
                  ),
                  child: TextField(
                    controller: _searchC,
                    style: TextStyle(fontSize: 14, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Cari supplier...',
                      prefixIcon: Icon(Icons.search, size: 20,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _searchC.clear(),
                              child: Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.clear_rounded, size: 18,
                                    color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                              ),
                            )
                          : null,
                      hintStyle: TextStyle(
                          color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                          fontSize: 14),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ]),
          ),
          // Count badge
          if (!_loading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NusaConfig.radiusFull),
                  ),
                  child: Text('${_filtered.length} supplier',
                      style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
                ),
              ]),
            ),
          SizedBox(height: 4),
          Expanded(
            child: _loading
                ? SkeletonList()
                : _list.isEmpty
                    ? EmptyState(
                        icon: Icons.local_shipping_outlined,
                        message: 'Belum ada supplier',
                        actionLabel: 'Tambah Supplier',
                        onAction: null,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.search_off,
                                    message: 'Supplier tidak ditemukan',
                                    onAction: () { _searchC.clear(); },
                                    actionLabel: 'Reset Pencarian',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(16, 4, 16, 80),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => SizedBox(height: 10),
                                itemBuilder: (_, i) => _SupplierTile(
                                  supplier: _filtered[i],
                                  onTap: () => _showForm(existing: _filtered[i]),
                                ),
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('Tambah Supplier'),
        onPressed: () => _showForm(),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  _SupplierTile({required this.supplier, required this.onTap});

  static const _avatarColors = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF06B6D4),
  ];

  Color _avatarColor() => _avatarColors[supplier.name.hashCode.abs() % _avatarColors.length];

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final textSec = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
    final textTer = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;
    final hasPhone = supplier.phone != null && supplier.phone!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: NusaCard(Padding(
        padding: EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _avatarColor().withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
              style: TextStyle(color: _avatarColor(), fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(supplier.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri)),
              if (hasPhone)
                Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(supplier.phone!, style: TextStyle(fontSize: 13, color: textSec)),
                ),
              if (supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('CP: ${supplier.contactPerson}', style: TextStyle(fontSize: 13, color: textSec)),
                ),
              if (supplier.address != null && supplier.address!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined, size: 13, color: textTer),
                    SizedBox(width: 3),
                    Expanded(child: Text(supplier.address!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: textTer))),
                  ]),
                ),
            ]),
          ),
          if (hasPhone)
            PopupMenuButton<String>(
              icon: Icon(Icons.phone_outlined, size: 20, color: NusaConfig.activePrimary),
              onSelected: (v) {
                if (v == 'tel') _launchPhone(supplier.phone!);
                if (v == 'wa') _launchWhatsApp(supplier.phone!);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'tel', child: Text('Telepon')),
                PopupMenuItem(value: 'wa', child: Text('WhatsApp')),
              ],
            ),
        ]),
      )),
    );
  }
}
