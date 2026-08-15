import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/branch_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';

class BranchScreen extends ConsumerStatefulWidget {
  BranchScreen({super.key});
  @override
  ConsumerState<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends ConsumerState<BranchScreen> {
  List<Branche> _list = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.toLowerCase()),
    );
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = BranchRepository(ref.read(databaseProvider));
    final list = await repo.getAll();
    if (mounted)
      setState(() {
        _list = list;
        _loading = false;
      });
  }

  List<Branche> get _filtered => _query.isEmpty
      ? _list
      : _list
            .where(
              (b) =>
                  b.name.toLowerCase().contains(_query) ||
                  (b.address?.toLowerCase().contains(_query) ?? false),
            )
            .toList();

  void _showForm({Branche? existing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String status = existing?.status ?? 'Aktif';

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
            20,
            10,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkDivider
                        : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: NusaConfig.accentPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.storefront,
                        color: NusaConfig.accentPurple,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      existing == null ? 'Tambah Cabang' : 'Edit Cabang',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                NusaInput(
                  'Nama Cabang',
                  controller: nameCtrl,
                  hint: 'Cth: Cabang Pusat',
                ),
                SizedBox(height: 12),
                NusaInput(
                  'Alamat',
                  controller: addrCtrl,
                  hint: 'Cth: Jl. Merdeka No. 10',
                ),
                SizedBox(height: 12),
                NusaInput(
                  'Telepon',
                  controller: phoneCtrl,
                  hint: 'Cth: 08123456789',
                  type: TextInputType.phone,
                ),
                SizedBox(height: 16),
                // Status chip selector
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _statusChip(
                      'Aktif',
                      status,
                      NusaConfig.accentGreen,
                      isDark,
                      onTap: () => setSt(() => status = 'Aktif'),
                    ),
                    SizedBox(width: 10),
                    _statusChip(
                      'Tutup',
                      status,
                      Color(0xFF9CA3AF),
                      isDark,
                      onTap: () => setSt(() => status = 'Tutup'),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? NusaConfig.darkInputBorder
                                : NusaConfig.inputBorder,
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: NusaButton(
                        existing == null ? 'Tambah' : 'Simpan',
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final repo = BranchRepository(
                            ref.read(databaseProvider),
                          );
                          if (existing == null) {
                            await repo.add(
                              name,
                              address: addrCtrl.text.trim().isEmpty
                                  ? null
                                  : addrCtrl.text.trim(),
                              phone: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              status: status,
                            );
                          } else {
                            await repo.update(
                              existing.id,
                              name,
                              address: addrCtrl.text.trim().isEmpty
                                  ? null
                                  : addrCtrl.text.trim(),
                              phone: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              status: status,
                            );
                          }
                          if (mounted) Navigator.of(context).pop();
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
                if (existing != null) ...[
                  SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _confirmDelete(existing);
                    },
                    child: Text(
                      'Hapus Cabang',
                      style: TextStyle(color: NusaConfig.activePrimary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    String label,
    String current,
    Color color,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    final selected = current == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : (isDark ? NusaConfig.darkSurface2 : Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? color : NusaConfig.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Branche b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Cabang'),
        content: Text(
          'Hapus "${b.name}"? Data cabang tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await BranchRepository(ref.read(databaseProvider)).delete(b.id);
              Navigator.of(ctx).pop();
              _load();
            },
            child: Text(
              'Hapus',
              style: TextStyle(color: NusaConfig.activePrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    return ScreenScaffold(
      'Cabang',
      Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari cabang...',
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? NusaConfig.darkSurface
                    : NusaConfig.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? EmptyState(
                    icon: Icons.storefront_outlined,
                    message: 'Belum ada cabang',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final b = filtered[i];
                        final isActive = b.status == 'Aktif';
                        return GestureDetector(
                          onTap: () => _showForm(existing: b),
                          child: NusaCard(
                            Padding(
                              padding: EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          (isActive
                                                  ? NusaConfig.accentGreen
                                                  : Color(0xFF9CA3AF))
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.storefront,
                                      color: isActive
                                          ? NusaConfig.accentGreen
                                          : Color(0xFF9CA3AF),
                                      size: 22,
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? NusaConfig.darkTextPrimary
                                                : NusaConfig.textPrimary,
                                          ),
                                        ),
                                        if (b.address != null &&
                                            b.address!.isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 13,
                                                color: isDark
                                                    ? NusaConfig
                                                          .darkTextTertiary
                                                    : NusaConfig.textTertiary,
                                              ),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  b.address!,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? NusaConfig
                                                              .darkTextSecondary
                                                        : NusaConfig
                                                              .textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (b.phone != null &&
                                            b.phone!.isNotEmpty) ...[
                                          SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone_outlined,
                                                size: 13,
                                                color: isDark
                                                    ? NusaConfig
                                                          .darkTextTertiary
                                                    : NusaConfig.textTertiary,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                b.phone!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? NusaConfig
                                                            .darkTextSecondary
                                                      : NusaConfig
                                                            .textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? NusaConfig.accentGreen.withValues(
                                              alpha: 0.12,
                                            )
                                          : Color(
                                              0xFF9CA3AF,
                                            ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      b.status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? NusaConfig.accentGreen
                                            : NusaConfig.textSecondary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: isDark
                                        ? NusaConfig.darkTextSecondary
                                        : NusaConfig.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.add),
        label: Text(
          'Tambah Cabang',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _showForm(),
      ),
    );
  }
}
