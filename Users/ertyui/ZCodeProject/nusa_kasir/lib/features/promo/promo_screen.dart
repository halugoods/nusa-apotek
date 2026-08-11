import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/promo_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import "package:nusa_kasir/shared/widgets/top_toast.dart";
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';

class PromoScreen extends ConsumerStatefulWidget {
  PromoScreen({super.key});
  @override
  ConsumerState<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends ConsumerState<PromoScreen> {
  List<Promo> _promos = [];
  bool _loading = true;
  String _filter = 'Aktif'; // 'Aktif' | 'Nonaktif' | 'Kadaluarsa'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = PromoRepository(ref.read(databaseProvider));
    final all = await repo.getPromos();
    if (mounted) setState(() { _promos = all; _loading = false; });
  }

  List<Promo> get _filtered {
    final now = DateTime.now();
    return _promos.where((p) {
      if (_filter == 'Aktif') return p.status == 'Aktif' && (p.endDate == null || p.endDate!.isAfter(now));
      if (_filter == 'Nonaktif') return p.status == 'Nonaktif';
      // Kadaluarsa
      return p.endDate != null && p.endDate!.isBefore(now);
    }).toList();
  }

  Future<void> _toggle(Promo p) async {
    final repo = PromoRepository(ref.read(databaseProvider));
    final next = p.status == 'Aktif' ? 'Nonaktif' : 'Aktif';
    await repo.updateStatus(p.id, next);
    _load();
  }

  Future<void> _delete(Promo p) async {
    final repo = PromoRepository(ref.read(databaseProvider));
    await repo.deletePromo(p.id);
    if (mounted) TopToast.success(context, 'Promo "${p.name}" dihapus');
    _load();
  }

  void _confirmDelete(Promo p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus Promo'),
        content: Text('Yakin hapus promo "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal')),
          NusaButton('Hapus', fullWidth: false, onPressed: () {
            Navigator.of(context).pop();
            _delete(p);
          }),
        ],
      ),
    );
  }

  void _showForm({Promo? existing}) {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final codeC = TextEditingController(text: existing?.code ?? '');
    final valueC =
        TextEditingController(text: existing != null ? existing.value.toString() : '');
    final minC = TextEditingController(
        text: existing != null ? existing.minBelanja.toString() : '0');
    final maxC = TextEditingController(
        text: existing?.maxUses?.toString() ?? '');
    String type = existing?.type ?? 'persen';
    String mode = existing?.mode ?? 'otomatis'; // 'otomatis' | 'kode' | 'bebas'
    DateTime? start = existing?.startDate;
    DateTime? end = existing?.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSt) => Container(
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20, 10, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: NusaConfig.dividerColor,
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
                    child: Icon(Icons.local_offer_outlined,
                        color: NusaConfig.activePrimary, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(isEdit ? 'Edit Promo' : 'Tambah Promo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      )),
                ]),
                SizedBox(height: 16),
                // Form content
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NusaInput('Nama Promo', controller: nameC, hint: 'Cth: Diskon Spesial'),
                      SizedBox(height: 12),
                      NusaInput(
                        mode == 'kode'
                            ? 'Kode Promo (wajib)'
                            : mode == 'otomatis'
                                ? 'Kode Promo (opsional — dipakai otomatis)'
                                : 'Kode Promo (opsional)',
                        controller: codeC,
                        hint: mode == 'kode' ? 'Cth: HEMAT10' : 'Opsional',
                      ),
                      SizedBox(height: 12),
                      // ── Mode Promo (3-arah hybrid) ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Cara Pakai Promo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                              )),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
                              ),
                            ),
                            child: Row(children: [
                              _modeChip('Otomatis', 'otomatis', mode, () => setSt(() => mode = 'otomatis'), isDark),
                              _modeChip('Kode', 'kode', mode, () => setSt(() => mode = 'kode'), isDark),
                              _modeChip('Pilih di Kasir', 'bebas', mode, () => setSt(() => mode = 'bebas'), isDark),
                            ]),
                          ),
                          SizedBox(height: 6),
                          Text(
                            mode == 'otomatis'
                                ? '⚡ Dipakai otomatis saat belanja memenuhi syarat'
                                : mode == 'kode'
                                    ? '🔑 Hanya bisa dipakai lewat kode promo'
                                    : '🛒 Muncul di daftar "Pilih Diskon" saat kasir',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tipe Diskon',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                              )),
                          SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: type,
                                isExpanded: true,
                                isDense: true,
                                icon: Icon(Icons.expand_more, size: 20,
                                    color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                                ),
                                dropdownColor: isDark ? NusaConfig.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                underline: SizedBox.shrink(),
                                items: [
                                  DropdownMenuItem(value: 'persen', child: Text('Persen (%)')),
                                  DropdownMenuItem(value: 'nominal', child: Text('Nominal (Rp)')),
                                ],
                                onChanged: (v) => setSt(() => type = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      NusaInput(type == 'persen' ? 'Nilai (%)' : 'Nilai (Rp)',
                          controller: valueC, type: TextInputType.number, hint: 'Cth: 10'),
                      SizedBox(height: 12),
                      NusaInput('Min. Belanja (Rp)',
                          controller: minC, type: TextInputType.number, hint: 'Cth: 50000'),
                      SizedBox(height: 12),
                      NusaInput('Kuota (kosong = tanpa batas)',
                          controller: maxC, type: TextInputType.number, hint: 'Cth: 100'),
                      SizedBox(height: 12),
                      Text('Periode Promo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                          )),
                      SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            useRootNavigator: true,
                            initialDateRange: start != null && end != null
                                ? DateTimeRange(start: start!, end: end!)
                                : null,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            helpText: 'Pilih Periode Promo',
                            cancelText: 'BATAL',
                            confirmText: 'PILIH',
                          );
                          if (picked != null) {
                            setSt(() { start = picked.start; end = picked.end; });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18,
                                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  start != null && end != null
                                      ? '${_fmtDate(start)} – ${_fmtDate(end)}'
                                      : 'Pilih tanggal mulai – selesai',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: start != null
                                        ? (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)
                                        : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                                  ),
                                ),
                              ),
                              if (start != null)
                                GestureDetector(
                                  onTap: () => setSt(() { start = null; end = null; }),
                                  child: Icon(Icons.close, size: 18,
                                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Bottom actions
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('Batal'),
                            ),
                          ),
                          if (isEdit)
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _confirmDelete(existing);
                              },
                              child: Text('Hapus', style: TextStyle(color: Colors.red)),
                            ),
                          Expanded(
                            child: NusaButton(
                              isEdit ? 'Simpan' : 'Tambah',
                              fullWidth: false,
                              onPressed: () async {
                                final name = nameC.text.trim();
                                final code = codeC.text.trim();
                                final value = int.tryParse(valueC.text.trim());
                                if (name.isEmpty) {
                                  TopToast.error(context, 'Nama promo wajib diisi');
                                  return;
                                }
                                if (mode == 'kode' && code.isEmpty) {
                                  TopToast.error(context, 'Kode promo wajib diisi untuk mode Kode');
                                  return;
                                }
                                if (value == null) {
                                  TopToast.error(context, 'Nilai diskon wajib diisi');
                                  return;
                                }
                                final repo = PromoRepository(ref.read(databaseProvider));
                                final min = int.tryParse(minC.text.trim()) ?? 0;
                                final max = maxC.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(maxC.text.trim());
                                // Kode hanya wajib untuk mode 'kode'; mode lain
                                // boleh kosong (kolom DB non-null → simpan '').
                                final finalCode = code.trim();
                                if (isEdit) {
                                  await repo.updatePromo(existing.id,
                                      name: name,
                                      code: finalCode,
                                      type: type,
                                      value: value,
                                      minBelanja: min,
                                      startDate: start,
                                      endDate: end,
                                      maxUses: max,
                                      mode: mode);
                                } else {
                                  await repo.addPromo(
                                    name: name,
                                    code: finalCode,
                                    type: type,
                                    value: value,
                                    minBelanja: min,
                                    startDate: start,
                                    endDate: end,
                                    maxUses: max,
                                    mode: mode,
                                  );
                                }
                                if (mounted) Navigator.of(ctx).pop();
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Promo',
      _loading
          ? SkeletonList()
          : Column(
              children: [
                // ── Filter tabs ──
                _buildFilterTabs(isDark),
                // ── Content ──
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => SizedBox(height: 12),
                            itemBuilder: (_, i) => _PromoTile(
                              promo: _filtered[i],
                              onTap: () => _showForm(existing: _filtered[i]),
                              onToggle: () => _toggle(_filtered[i]),
                              onEdit: () => _showForm(existing: _filtered[i]),
                              onDelete: () => _confirmDelete(_filtered[i]),
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
        label: Text('Tambah Promo'),
        onPressed: () => _showForm(),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final tabs = ['Aktif', 'Nonaktif', 'Kadaluarsa'];
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        ),
        child: Row(
          children: tabs.map((tab) {
            final selected = _filter == tab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = tab),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? NusaConfig.activePrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tab,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 24),
          // Illustration icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_offer_outlined,
                size: 36, color: NusaConfig.activePrimary),
          ),
          SizedBox(height: 16),
          Text(
            _promos.isEmpty ? 'Belum ada promo' : 'Tidak ada promo $_filter',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            _promos.isEmpty
                ? 'Buat promo pertama untuk menarik pelanggan dengan diskon spesial.'
                : 'Coba ubah filter atau buat promo baru.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
            ),
          ),
          SizedBox(height: 20),
          if (_promos.isEmpty) ...[
            // Quick templates
            Text('Template Cepat',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            SizedBox(height: 10),
            _quickTemplate(isDark, 'Diskon 10%', 'HEMAT10', 'persen', 10, 50000, mode: 'kode'),
            SizedBox(height: 8),
            _quickTemplate(isDark, 'Potongan 5rb', 'FLASH5', 'nominal', 5000, 30000, mode: 'kode'),
            SizedBox(height: 8),
            _quickTemplate(isDark, 'Beli 2 Gratis 1', 'B2G1', 'persen', 50, 0, mode: 'otomatis'),
          ] else ...[
            // Button to add promo
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: Icon(Icons.add, size: 18),
              label: Text('Buat Promo Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _quickTemplate(bool isDark, String title, String code, String type, int value, int minBelanja, {String mode = 'otomatis'}) {
    return GestureDetector(
      onTap: () async {
        final repo = PromoRepository(ref.read(databaseProvider));
        await repo.addPromo(
          name: title, code: code, type: type, value: value,
          minBelanja: minBelanja, maxUses: 100, mode: mode,
        );
        _load();
        if (mounted) TopToast.success(context, 'Promo "$title" dibuat!');
      },
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:  Icon(Icons.bolt, size: 18, color: NusaConfig.activePrimary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text(
                    mode == 'otomatis'
                        ? '${type == 'persen' ? '$value%' : formatRupiah(value)} • Auto saat belanja memenuhi syarat'
                        : 'Kode: $code • ${type == 'persen' ? '$value%' : formatRupiah(value)} • Min: ${formatRupiah(minBelanja)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, size: 20,
                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, String value, String current, VoidCallback onSelect, bool isDark) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? NusaConfig.activePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  final Promo promo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  _PromoTile(
      {required this.promo, required this.onTap, required this.onToggle,
      required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = promo.status == 'Aktif';
    final expired = promo.endDate != null &&
        promo.endDate!.isBefore(DateTime.now());
    final quotaUsed = promo.maxUses != null && promo.maxUses! > 0
        ? promo.usedCount / promo.maxUses!
        : -1.0;
    final quotaColor = quotaUsed < 0
        ? NusaConfig.accentGreen
        : quotaUsed < 0.5
            ? NusaConfig.accentGreen
            : quotaUsed < 0.75
                ? Colors.orange
                : Colors.red;
    return Opacity(
      opacity: expired ? 0.55 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: NusaCard(
          Container(
            padding: EdgeInsets.fromLTRB(12, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: name + switch ──
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: active && !expired
                            ? NusaConfig.accentGreen.withValues(alpha: 0.12)
                            : NusaConfig.activePrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_offer,
                        size: 18,
                        color: active && !expired ? NusaConfig.accentGreen : NusaConfig.activePrimary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(promo.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                          )),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: active,
                        activeColor: NusaConfig.activePrimary,
                        onChanged: (_) => onToggle(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // ── Discount label + mode badge ──
                Row(children: [
                  Flexible(
                    child: Text(_discountLabel(promo),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: active && !expired
                                ? NusaConfig.accentGreen
                                : NusaConfig.activePrimary)),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_modeLabel(promo),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: NusaConfig.activePrimary)),
                  ),
                ]),
                SizedBox(height: 3),
                // ── Info row ──
                Text(
                    'Min. belanja ${formatRupiah(promo.minBelanja)} • Aktif: ${_fmtDate(promo.startDate)}–${_fmtDate(promo.endDate)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                SizedBox(height: 3),
                // ── Quota + progress bar ──
                Row(
                  children: [
                    Text(
                        'Kuota: ${_quotaLabel(promo)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    SizedBox(width: 8),
                    if (quotaUsed >= 0)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: quotaUsed.clamp(0.0, 1.0),
                            backgroundColor: quotaColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(quotaColor),
                            minHeight: 4,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6),
                // ── Bottom row: code + edit/delete actions ──
                Row(
                  children: [
                    // Code with copy
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: promo.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kode disalin'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14,
                                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text('Kode: ${promo.code}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: NusaConfig.activePrimary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Edit button
                    _ActionChip(
                      icon: Icons.edit_outlined,
                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                      onTap: onEdit,
                    ),
                    SizedBox(width: 4),
                    // Delete button
                    _ActionChip(
                      icon: Icons.delete_outline,
                      color: NusaConfig.activePrimary.withValues(alpha: 0.7),
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon chip for card actions (edit/delete).
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionChip({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

String _discountLabel(Promo p) =>
    p.type == 'persen' ? 'Diskon ${p.value}%' : 'Potongan ${formatRupiah(p.value)}';

String _modeLabel(Promo p) =>
    p.mode == 'otomatis' ? '⚡ Otomatis' : p.mode == 'kode' ? '🔑 Kode' : '🛒 Pilih di Kasir';

String _fmtDate(DateTime? d) =>
    d == null ? '-' : '${d.day}/${d.month}/${d.year}';

String _quotaLabel(Promo p) =>
    p.maxUses == null ? 'Tanpa batas' : '${p.usedCount}/${p.maxUses}';
