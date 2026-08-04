import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/features/stock_opname/stock_opname_screen.dart';

class StockScreen extends ConsumerStatefulWidget {
  final bool lowStockOnly;
  StockScreen({super.key, this.lowStockOnly = false});
  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  List<Product> _products = [];
  List<StockMovement> _movements = [];
  bool _loading = true;
  String _typeFilter = 'in'; // ''=all | 'in' | 'out'
  String _timeFilter = 'Hari ini';
  DateTimeRange? _dateRange;
  bool _lowStockFilter = false;
  int _tabIndex = 0; // 0 = Stok, 1 = Opname

  @override
  void initState() {
    super.initState();
    _lowStockFilter = widget.lowStockOnly;
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ProductRepository(db);
    final products = await repo.getProducts();
    final movements = await (db.select(db.stockMovements)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
          ]))
        .get();
    if (mounted) {
      setState(() {
        _products = products;
        _movements = movements;
        _loading = false;
      });
    }
  }

  List<Product> get _lowStock =>
      _products.where((p) => p.stock < p.minStock && p.minStock > 0).toList();

  List<Product> get _filteredProducts =>
      _lowStockFilter ? _lowStock : _products;

  List<StockMovement> get _filteredMovements {
    var list = _movements;
    if (_typeFilter == 'in') {
      list = list.where((m) => m.type == 'in').toList();
    } else if (_typeFilter == 'out') {
      list = list.where((m) => m.type == 'out').toList();
    }
    if (_timeFilter == 'custom' && _dateRange != null) {
      list = list
          .where((m) =>
              !m.date.isBefore(_dateRange!.start) &&
              !m.date.isAfter(_dateRange!.end.add(Duration(days: 1))))
          .toList();
    } else {
      final now = DateTime.now();
      final start = _timeFilter == 'Hari ini'
          ? DateTime(now.year, now.month, now.day)
          : _timeFilter == 'Kemarin'
              ? DateTime(now.year, now.month, now.day - 1)
              : _timeFilter == 'Minggu ini'
                  ? now.subtract(Duration(days: 7))
                  : _timeFilter == 'Bulan ini'
                      ? now.subtract(Duration(days: 30))
                      : _timeFilter == 'Tahun ini'
                          ? DateTime(now.year, 1, 1)
                          : DateTime(2000);
      list = list.where((m) => _timeFilter == 'Semua' || m.date.isAfter(start)).toList();
    }
    return list;
  }

  // ── Stock adjustment (Masuk / Keluar) ──
  Future<void> _submitAdjust(String mode, int productId, int qty) async {
    final db = ref.read(databaseProvider);
    final repo = ProductRepository(db);
    if (mode == 'out') {
      final product = await repo.byId(productId);
      if (product == null || product.stock < qty) {
        if (mounted) {
          TopToast.error(context,
              'Stok tidak cukup (tersedia: ${product?.stock ?? 0})');
        }
        return;
      }
      await repo.adjustStock(productId, -qty);
      await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
            productId: productId,
            type: 'out',
            qty: qty,
          ));
      if (mounted) TopToast.success(context, 'Stok berhasil dikurangi');
    } else {
      await repo.adjustStock(productId, qty);
      await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
            productId: productId,
            type: 'in',
            qty: qty,
          ));
      if (mounted) TopToast.success(context, 'Stok berhasil ditambah');
    }
    await _load();
  }

  void _openAdjustSheet(String mode, [int? presetId]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdjustSheet(
        mode: mode,
        products: _products,
        presetId: presetId,
        onSubmit: _submitAdjust,
      ),
    );
  }

  // ── Quick Restock from low-stock card ──
  void _openRestockSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RestockSheet(
        product: product,
        onRestock: _submitRestock,
      ),
    );
  }

  Future<void> _submitRestock(int productId, int qty, String note) async {
    final db = ref.read(databaseProvider);
    final repo = ProductRepository(db);
    await repo.adjustStock(productId, qty);
    await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
          productId: productId,
          type: 'in',
          qty: qty,
          note: note.isNotEmpty ? Value(note) : Value.absent(),
        ));
    if (mounted) TopToast.success(context, 'Stok berhasil ditambah +$qty');
    await _load();
  }

  // ── helpers ──
  static String _initials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      _lowStockFilter ? 'Stok Menipis' : 'Stok',
      Column(children: [
        // Tab bar — segmented control
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
              ),
            ),
            child: Row(children: [
              _segBtn('Stok', 0, isDark: isDark),
              _segBtn('Opname', 1, isDark: isDark),
            ]),
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: _tabIndex == 0
              ? (_loading ? SkeletonList() : _buildBody())
              : StockOpnameScreen(key: ValueKey('opname_$_tabIndex'), embedded: true),
        ),
      ]),
    );
  }

  Widget _segBtn(String label, int idx, {bool isDark = false}) {
    final sel = idx == _tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = idx),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? NusaConfig.activePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sel ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredMovements;
    final total = _products.length;
    final menipis =
        _products.where((p) => p.stock < p.minStock && p.minStock > 0).length;
    final habis = _products.where((p) => p.stock <= 0).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // ── Dismissible low-stock-filter banner ──
          if (_lowStockFilter)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: NusaConfig.warningSoft,
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                  border: Border.all(color: NusaConfig.warning.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: NusaConfig.warningText),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Menampilkan ${_lowStock.length} produk dengan stok menipis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: NusaConfig.warningText,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _lowStockFilter = false),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: NusaConfig.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                      ),
                      child: Text(
                        'Semua Stok',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: NusaConfig.warningText,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

          // ── Summary tiles ──
          Row(children: [
            Expanded(
              child: _StatTile(
                label: 'Total Produk',
                value: total.toString(),
                color: NusaConfig.activePrimary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Stok Menipis',
                value: menipis.toString(),
                color: NusaConfig.warning,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Stok Habis',
                value: habis.toString(),
                color: NusaConfig.error,
              ),
            ),
          ]),
          SizedBox(height: 16),

          // ── Quick actions ──
          if (!_lowStockFilter) ...[
            Row(children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_rounded,
                  label: 'Stok Masuk',
                  color: NusaConfig.accentGreen,
                  onTap: () => _openAdjustSheet('in'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.remove_rounded,
                  label: 'Stok Keluar',
                  color: NusaConfig.activePrimary,
                  onTap: () => _openAdjustSheet('out'),
                ),
              ),
            ]),
            SizedBox(height: 24),
          ],

          // ── Stok Menipis section ──
          _SectionHeader(
            title: _lowStockFilter ? 'Daftar Stok Menipis' : 'Stok Menipis',
            subtitle: _lowStock.isEmpty
                ? 'Semua stok aman'
                : '${_lowStock.length} produk perlu restok',
            icon: Icons.warning_amber_rounded,
          ),
          SizedBox(height: 12),
          if (_lowStock.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Tidak ada stok menipis',
            )
          else
            ..._lowStock
                .map((p) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _LowStockCard(
                        product: p,
                        onTap: () => context.push('/produk/edit/${p.id}'),
                        onRestock: () => _openRestockSheet(p),
                      ),
                    )),
          SizedBox(height: 24),

          // ── All products section (only when not filtered) ──
          if (!_lowStockFilter) ...[
            _SectionHeader(
              title: 'Semua Produk',
              icon: Icons.inventory_2_outlined,
              subtitle: '$total produk',
            ),
            SizedBox(height: 12),
            if (_products.isEmpty)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'Belum ada produk',
              )
            else
              ..._products.take(20).map((p) {
                final isLow = p.stock < p.minStock && p.minStock > 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _ProductRow(
                    product: p,
                    highlightLowStock: isLow,
                    onTap: () => context.push('/produk/edit/${p.id}'),
                    onRestock: isLow ? () => _openRestockSheet(p) : null,
                  ),
                );
              }),
            SizedBox(height: 24),
          ],

          // ── Aktivitas section ──
          if (!_lowStockFilter) ...[
            _SectionHeader(
              title: 'Aktivitas Stok',
              icon: Icons.history_rounded,
              subtitle: '${filtered.length} pergerakan',
            ),
            SizedBox(height: 12),
            _buildFilterBar(isDark),
            SizedBox(height: 12),
            if (filtered.isEmpty)
              EmptyState(
                icon: Icons.history_rounded,
                message: 'Belum ada riwayat',
              )
            else
              ...filtered.map((m) {
                final name = _nameOf(m.productId);
                return Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _HistoryCard(movement: m, productName: name),
                );
              }),
          ],
          SizedBox(height: 8),
        ],
      ),
    );
  }

  String _nameOf(int id) {
    final p = _products.where((e) => e.id == id).firstOrNull;
    return p?.name ?? '#$id';
  }

  Widget _buildFilterBar(bool isDark) {
    return Row(
      children: [
        // ── Type switch (Masuk | Keluar) bagi rata ──
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color:
                  isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            ),
            child: Row(
              children: [
                _typeBtn('Masuk', 'in', true),
                _typeBtn('Keluar', 'out', false),
              ],
            ),
          ),
        ),
        SizedBox(width: 10),
        // ── Time dropdown ──
        _timeDropdown(isDark),
      ],
    );
  }

  Widget _typeBtn(String label, String value, bool isLeft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _typeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _typeFilter = value == _typeFilter ? '' : value),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? NusaConfig.activePrimary : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(isLeft ? 8 : 0),
              right: Radius.circular(isLeft ? 0 : 8),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active
                  ? Colors.white
                  : (isDark
                      ? NusaConfig.darkTextSecondary
                      : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeDropdown(bool isDark) {
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeFilter == 'custom' ? 'custom' : _timeFilter,
          isDense: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          ),
          borderRadius: BorderRadius.circular(12),
          underline: SizedBox.shrink(),
          icon: Icon(Icons.expand_more_rounded,
              size: 18,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          items: [
            _ddItem('Hari ini'),
            _ddItem('Kemarin'),
            _ddItem('Minggu ini'),
            _ddItem('Bulan ini'),
            _ddItem('Tahun ini'),
            _ddItem('Semua'),
            if (_timeFilter == 'custom' && _dateRange != null)
              DropdownMenuItem(
                value: 'custom',
                enabled: false,
                child: Text(
                  '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  style: TextStyle(
                      fontSize: 11,
                      color: NusaConfig.activePrimary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            _ddItem('Pilih Periode'),
          ],
          onChanged: (v) {
            if (v == 'Pilih Periode') {
              _pickDateRange();
            } else {
              setState(() {
                _timeFilter = v!;
                _dateRange = null;
              });
            }
          },
        ),
      ),
    );
  }

  DropdownMenuItem<String> _ddItem(String label) => DropdownMenuItem(
        value: label,
        child: Text(label),
      );

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
          initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now(),
          ),
    );
    if (picked != null && mounted) {
      setState(() {
        _timeFilter = 'custom';
        _dateRange = picked;
      });
    }
  }
}

// ===========================================
//  Summary tile
// ===========================================

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconFor(label), size: 16, color: color),
          ),
          SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String label) {
    if (label.contains('Total')) return Icons.inventory_2_outlined;
    if (label.contains('Menipis')) return Icons.warning_amber_rounded;
    return Icons.error_outline_rounded;
  }
}

// ===========================================
//  Quick action
// ===========================================

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================
//  Section header
// ===========================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;

  _SectionHeader({
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: NusaConfig.activePrimary),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ===========================================
//  Filter chip
// ===========================================

//  Low stock card
// ===========================================

class _LowStockCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onRestock;

  _LowStockCard({required this.product, required this.onTap, this.onRestock});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final hasImage = product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);

    final ratio = product.minStock > 0
        ? (product.stock / product.minStock).clamp(0.0, 1.5)
        : 0.0;
    final barColor = ratio < 0.25
        ? Colors.red
        : ratio < 0.5
            ? Colors.orange
            : ratio < 1.0
                ? Colors.amber
                : NusaConfig.accentGreen;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
            border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(
                      alpha: isDark ? 0.15 : 0.06),
                  blurRadius: 10,
                  offset: Offset(0, 3))
            ],
          ),
          padding: EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Thumbnail ──
              ClipRRect(
                borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(children: [
                    if (hasImage)
                      Image.file(File(product.imagePath!),
                          fit: BoxFit.cover, width: 72, height: 72)
                    else
                      Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradient)),
                        alignment: Alignment.center,
                        child: Text(
                          _StockScreenState._initials(product.name),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5),
                        ),
                      ),
                    // Stock badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: outOfStock
                              ? NusaConfig.stockOut
                              : NusaConfig.surfaceColor
                                  .withValues(alpha: 0.92),
                          borderRadius:
                              BorderRadius.circular(NusaConfig.radiusFull),
                        ),
                        child: Text(
                          outOfStock ? 'Habis' : '${product.stock}x',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: outOfStock
                                  ? NusaConfig.stockOutText
                                  : NusaConfig.activePrimary),
                        ),
                      ),
                    ),
                    if (outOfStock)
                      Container(color: Colors.white.withValues(alpha: 0.35)),
                  ]),
                ),
              ),
              SizedBox(width: 12),
              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                    SizedBox(height: 3),
                    Text(product.category,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Stok: ${product.stock}/${product.minStock}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: barColor),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right,
                            size: 18, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      ],
                    ),
                    SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (ratio / 1.5).clamp(0.0, 1.0),
                        backgroundColor: barColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(barColor),
                        minHeight: 5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Spacer(),
                        GestureDetector(
                          onTap: onRestock,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: NusaConfig.accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                              border: Border.all(color: NusaConfig.accentGreen.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_shopping_cart_rounded, size: 14, color: NusaConfig.accentGreen),
                                SizedBox(width: 4),
                                Text(
                                  'Restock',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: NusaConfig.accentGreen,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

// ===========================================
//  History card
// ===========================================

class _HistoryCard extends StatelessWidget {
  final StockMovement movement;
  final String productName;

  _HistoryCard(
      {required this.movement, required this.productName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final m = movement;
    final isIn = m.type == 'in';
    final accent = isIn ? NusaConfig.accentGreen : NusaConfig.activePrimary;

    final date = m.date;
    final now = DateTime.now();
    String dateStr;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      dateStr =
          'Hari ini, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      dateStr = 'Kemarin';
    } else {
      dateStr = '${date.day}/${date.month}/${date.year}';
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
          border: Border.all(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: Offset(0, 2))
          ],
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            // ── Left accent bar ──
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(NusaConfig.radiusMD)),
              ),
            ),
            // ── Content ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: isDark
                                    ? NusaConfig.darkTextPrimary
                                    : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                        SizedBox(height: 3),
                        Text(
                          '${isIn ? 'Masuk' : 'Keluar'}  •  $dateStr',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? NusaConfig.darkTextTertiary
                                  : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(NusaConfig.radiusSM),
                    ),
                    child: Text(
                      '${isIn ? '+' : '-'}${m.qty}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accent),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ===========================================
//  Product thumbnail (reused in sheet)
// ===========================================

class _ProductThumb extends StatelessWidget {
  final Product product;
  final double size;
  _ProductThumb({required this.product, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.file(File(product.imagePath!), fit: BoxFit.cover, width: size, height: size)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _StockScreenState._initials(product.name),
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ),
    );
  }
}

// ===========================================
//  Product result row
// ===========================================

class _ProductResultRow extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  _ProductResultRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
            borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
            border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
          ),
          child: Row(children: [
            _ProductThumb(product: product, size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      )),
                  SizedBox(height: 2),
                  Text('${product.category}  •  Stok ${product.stock}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          ]),
        ),
      ),
    );
  }
}

// ===========================================
//  Adjust sheet (Stok Masuk / Keluar) — search + scan barcode
// ===========================================

class _AdjustSheet extends StatefulWidget {
  final String mode; // in | out
  final List<Product> products;
  final int? presetId;
  final Future<void> Function(String mode, int productId, int qty) onSubmit;

  _AdjustSheet({
    required this.mode,
    required this.products,
    this.presetId,
    required this.onSubmit,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _search = TextEditingController();
  final _qty = TextEditingController();
  int? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.presetId;
    if (widget.presetId != null) {
      final p =
          widget.products.where((e) => e.id == widget.presetId).firstOrNull;
      if (p != null) _search.text = p.name;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _qty.dispose();
    super.dispose();
  }

  List<Product> get _results {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.barcode?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Map<String, Product> get _byBarcode {
    final m = <String, Product>{};
    for (final p in widget.products) {
      if (p.barcode != null && p.barcode!.isNotEmpty) m[p.barcode!] = p;
    }
    return m;
  }

  Product? get _selected =>
      widget.products.where((p) => p.id == _selectedId).firstOrNull;

  Future<void> _scan() async {
    final controller = MobileScannerController();
    String? code;
    if (!mounted) return;
        final code = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Pindai Barcode'), leading: IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(_))),
              body: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (code != null || capture.barcodes.isEmpty) return;
                  final barcode = capture.barcodes.firstOrNull;
                  if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) return;
                  code = barcode.rawValue;
                  Navigator.pop(_, code);
                },
              ),
            ),
          ),
        );
    await controller.dispose();
    if (code == null || !mounted) return;
    final product = _byBarcode[code];
    if (product != null) {
      setState(() {
        _selectedId = product.id;
        _search.text = product.name;
      });
    } else if (mounted) {
      TopToast.info(context, 'Barcode tidak terdaftar. Cari manual.');
    }
  }

  Future<void> _save() async {
    final id = _selectedId;
    final n = int.tryParse(_qty.text.trim());
    if (id == null) {
      TopToast.error(context, 'Pilih produk dulu');
      return;
    }
    if (n == null || n <= 0) {
      TopToast.error(context, 'Jumlah stok harus lebih dari 0');
      return;
    }
    setState(() => _saving = true);
    await widget.onSubmit(widget.mode, id, n);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIn = widget.mode == 'in';
    final color = isIn ? NusaConfig.accentGreen : NusaConfig.activePrimary;
    final selected = _selected;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NusaConfig.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIn ? Icons.add_rounded : Icons.remove_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                isIn ? 'Stok Masuk' : 'Stok Keluar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                ),
              ),
            ]),
            SizedBox(height: 18),
            if (selected == null) ...[
              // ── Search + scan ──
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkInputFill
                      : NusaConfig.inputFill,
                  borderRadius: BorderRadius.circular(NusaConfig.radiusXL),
                  border: Border.all(
                    color: isDark
                        ? NusaConfig.darkInputBorder
                        : NusaConfig.inputBorder,
                  ),
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau barcode…',
                    hintStyle: TextStyle(
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, size: 22),
                    suffixIcon: GestureDetector(
                      onTap: _scan,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.qr_code_scanner,
                            color: NusaConfig.activePrimary, size: 22),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 240,
                child: _results.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        message: 'Produk tidak ditemukan',
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return _ProductResultRow(
                            product: p,
                            onTap: () => setState(() {
                              _selectedId = p.id;
                              _search.text = p.name;
                            }),
                          );
                        },
                      ),
              ),
            ] else ...[
              // ── Selected product ──
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  _ProductThumb(product: selected, size: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selected.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                            )),
                        SizedBox(height: 2),
                        Text('Stok saat ini: ${selected.stock}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? NusaConfig.darkTextTertiary
                                  : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                            )),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedId = null;
                      _search.clear();
                    }),
                    child: Text('Ganti'),
                  ),
                ]),
              ),
            ],
            if (selected != null) ...[
              SizedBox(height: 16),
              NusaInput(
                isIn ? 'Jumlah stok masuk' : 'Jumlah stok keluar',
                controller: _qty,
                type: TextInputType.number,
              ),
              SizedBox(height: 20),
              NusaButton(
                isIn ? 'Tambah Stok' : 'Kurangi Stok',
                onPressed: _saving ? null : _save,
              ),
            ],
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ===========================================
//  Product row (all products list)
// ===========================================

class _ProductRow extends StatelessWidget {
  final Product product;
  final bool highlightLowStock;
  final VoidCallback onTap;
  final VoidCallback? onRestock;

  _ProductRow({
    required this.product,
    required this.highlightLowStock,
    required this.onTap,
    this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
            border: Border.all(
              color: highlightLowStock
                  ? NusaConfig.warning.withValues(alpha: 0.4)
                  : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(children: [
              if (highlightLowStock)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: NusaConfig.warning,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(NusaConfig.radiusMD),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: hasImage
                            ? Image.file(File(product.imagePath!), fit: BoxFit.cover)
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: gradient,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _StockScreenState._initials(product.name),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? NusaConfig.darkTextPrimary
                                    : NusaConfig.textPrimary,
                              )),
                          SizedBox(height: 2),
                          Text(
                            '${product.category}  \u2022  Stok ${product.stock}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? NusaConfig.darkTextTertiary
                                  : NusaConfig.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (highlightLowStock)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          '${product.stock}/${product.minStock}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NusaConfig.warningText,
                          ),
                        ),
                      ),
                    if (onRestock != null)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: onRestock,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: NusaConfig.accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                              border: Border.all(color: NusaConfig.accentGreen.withValues(alpha: 0.3)),
                            ),
                            child: Icon(Icons.add_shopping_cart_rounded, size: 16, color: NusaConfig.accentGreen),
                          ),
                        ),
                      ),
                    if (!highlightLowStock && onRestock == null)
                      Icon(Icons.chevron_right, size: 18,
                          color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ===========================================
//  Quick Restock bottom sheet
// ===========================================

class _RestockSheet extends StatefulWidget {
  final Product product;
  final Future<void> Function(int productId, int qty, String note) onRestock;

  _RestockSheet({required this.product, required this.onRestock});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  int _restockQty = 0;

  @override
  void initState() {
    super.initState();
    final needed = (widget.product.minStock - widget.product.stock).clamp(1, 1000);
    _restockQty = needed;
    _qty.text = needed.toString();
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = int.tryParse(_qty.text.trim());
    if (n == null || n <= 0) {
      TopToast.error(context, 'Jumlah minimal 1');
      return;
    }
    setState(() => _saving = true);
    await widget.onRestock(widget.product.id, n, _note.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = widget.product;
    final needed = (product.minStock - product.stock).clamp(0, 1000000);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NusaConfig.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_shopping_cart_rounded, color: NusaConfig.accentGreen, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Quick Restock',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                ),
              ),
            ]),
            SizedBox(height: 18),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NusaConfig.accentGreen.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                border: Border.all(color: NusaConfig.accentGreen.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                _ProductThumb(product: product, size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                          )),
                      SizedBox(height: 2),
                      Row(children: [
                        Text('Stok saat ini: ${product.stock}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                            )),
                        SizedBox(width: 8),
                        Text('Min: ${product.minStock}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NusaConfig.warningText,
                            )),
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
            SizedBox(height: 16),
            Text(
              'Jumlah Restock',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QtyBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    if (_restockQty > 1) {
                      setState(() {
                        _restockQty--;
                        _qty.text = _restockQty.toString();
                      });
                    }
                  },
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) _restockQty = n;
                    },
                  ),
                ),
                _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    setState(() {
                      _restockQty++;
                      _qty.text = _restockQty.toString();
                    });
                  },
                ),
              ],
            ),
            if (needed > 0)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Butuh $needed lagi untuk mencapai stok minimum',
                  style: TextStyle(
                    fontSize: 11,
                    color: NusaConfig.warningText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            SizedBox(height: 16),
            NusaInput(
              'Catatan (opsional)',
              controller: _note,
            ),
            SizedBox(height: 20),
            NusaButton(
              'Konfirmasi Restock',
              onPressed: _saving ? null : _save,
            ),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        ),
        child: Icon(icon, size: 22, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
      ),
    );
  }
}
