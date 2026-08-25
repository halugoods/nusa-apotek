import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/features/products/product_form_screen.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_cart_controls.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/hid_barcode_listener.dart';
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
  String _filter = 'low'; // 'low' | 'out' — filter daftar produk
  int _gridColumns = 2; // 1 = list, 2 = grid, 3 = grid padat
  int _tabIndex = 0; // 0 = Stok, 1 = Opname

  /// v2.2.46: referensi State opname (embedded) — diisi via onStateReady.
  /// Dipakai _onExternalBarcode untuk scan HID di tab Opname.
  StockOpnameScreenState? _opnameState;

  @override
  void initState() {
    super.initState();
    // Hanya ada 2 mode (Menipis/Habis) — default tampil produk menipis.
    _filter = 'low';
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ProductRepository(db);
    var products = await repo.getProducts();
    // B10 (v2.2.44): layanan (isService) tidak dilacak stok — sembunyikan
    // dari layar Stok (varian jasa). Barang (non-jasa) tetap semua.
    if (NusaConfig.isJasaVariant) {
      products = products.where((p) => !p.isService).toList();
    }
    final movements =
        await (db.select(db.stockMovements)..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
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

  List<Product> get _outOfStock =>
      _products.where((p) => p.stock <= 0).toList();

  // Produk yang tampil — berdasarkan switch filter Stok Menipis / Stok Habis.
  List<Product> get _filteredProducts {
    if (_filter == 'low') return _lowStock;
    if (_filter == 'out') return _outOfStock;
    return _products;
  }

  List<StockMovement> get _filteredMovements {
    var list = _movements;
    if (_typeFilter == 'in') {
      list = list.where((m) => m.type == 'in').toList();
    } else if (_typeFilter == 'out') {
      list = list.where((m) => m.type == 'out').toList();
    }
    if (_timeFilter == 'custom' && _dateRange != null) {
      list = list
          .where(
            (m) =>
                !m.date.isBefore(_dateRange!.start) &&
                !m.date.isAfter(_dateRange!.end.add(Duration(days: 1))),
          )
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
      list = list
          .where((m) => _timeFilter == 'Semua' || m.date.isAfter(start))
          .toList();
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
          TopToast.error(
            context,
            'Stok tidak cukup (tersedia: ${product?.stock ?? 0})',
          );
        }
        return;
      }
      await repo.adjustStock(productId, -qty);
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: productId,
              type: 'out',
              qty: qty,
            ),
          );
      if (mounted) TopToast.success(context, 'Stok berhasil dikurangi');
    } else {
      await repo.adjustStock(productId, qty);
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: productId,
              type: 'in',
              qty: qty,
            ),
          );
      if (mounted) TopToast.success(context, 'Stok berhasil ditambah');
    }
    await _load();
  }

  // ── Quick Restock from low-stock card ──
  void _openRestockSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _RestockSheet(product: product, onRestock: _submitRestock),
    );
  }

  // ── Stok Masuk/Keluar — bottom sheet + search + scan barcode ──
  void _openAdjustSheet(String mode, {String? initialBarcode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdjustSheet(
        mode: mode,
        products: _products,
        onSubmit: _submitAdjust,
        initialBarcode: initialBarcode,
      ),
    );
  }

  Future<void> _submitRestock(int productId, int qty, String note) async {
    final db = ref.read(databaseProvider);
    final repo = ProductRepository(db);
    await repo.adjustStock(productId, qty);
    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            productId: productId,
            type: 'in',
            qty: qty,
            note: note.isNotEmpty ? Value(note) : Value.absent(),
          ),
        );
    if (mounted) TopToast.success(context, 'Stok berhasil ditambah +$qty');
    await _load();
  }

  // ── D2: Beli ke Supplier — buka Catat Pembelian dengan produk terpilih ──
  void _openBuyProduct(Product product) {
    if (product.supplierId != null) {
      // Produk punya supplier langganan → buka catat pembelian supplier tsb.
      context.push('/pembelian?supplierId=${product.supplierId}');
    } else {
      TopToast.info(
        context,
        'Set supplier di form produk dulu untuk beli cepat',
      );
      showProductFormSheet(context, productId: product.id);
    }
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
      _filter == 'low'
          ? 'Stok Menipis'
          : (_filter == 'out' ? 'Stok Habis' : 'Stok'),
      Column(
        children: [
          // Tab bar — segmented control
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkSurface
                    : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor,
                ),
              ),
              child: Row(
                children: [
                  _segBtn('Stok', 0, isDark: isDark),
                  _segBtn('Opname', 1, isDark: isDark),
                ],
              ),
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: _tabIndex == 0
                ? (_loading ? SkeletonList() : _buildBody())
                : StockOpnameScreen(
                    key: ValueKey('opname_$_tabIndex'),
                    embedded: true,
                    onStateReady: (state) => _opnameState = state,
                  ),
          ),
        ],
      ),
      onBarcode: _onExternalBarcode,
    );
  }

  /// Barcode eksternal (HID) — v2.2.43: scan di layar utama Stok membuka
  /// sheet "Stok Masuk" dengan barcode di-pre-fill agar langsung resolve
  /// produk tanpa tap kolom cari / scan ulang.
  /// v2.2.44 (B6): saat tab Opname aktif → scan diteruskan ke opname
  /// (auto-match produk + naikkan hitungan fisik), bukan buka sheet masuk.
  Future<void> _onExternalBarcode(String code) async {
    final norm = ProductRepository.normalizeBarcode(code);
    if (norm.isEmpty) return;
    if (_tabIndex == 1) {
      // v2.2.46: pakai _opnameState (via onStateReady) — GlobalKey lama tak
      // pernah terisi, akibatnya scan HID di tab Opname justru membuka
      // "Stok Masuk". Sekarang benar-benar diteruskan ke opname.
      final op = _opnameState;
      if (op != null) {
        await op.handleBarcode(norm);
        return;
      }
    }
    _openAdjustSheet('in', initialBarcode: norm);
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
              color: sel
                  ? Colors.white
                  : (isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredMovements;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // ── Quick actions — buka bottom sheet Masuk/Keluar ──
          Row(
            children: [
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
            ],
          ),
          SizedBox(height: 20),

          // ── Filter switch (Menipis | Habis) + toggle grid/list ──
          _buildFilterChips(isDark),
          SizedBox(height: 16),

          // ── Daftar produk (grid atau list) ──
          _buildProductSection(isDark),
          SizedBox(height: 24),

          // ── Aktivitas section ──
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
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Filter switch: Stok Menipis | Stok Habis ──
  Widget _buildFilterChips(bool isDark) {
    final items = [('low', 'Menipis'), ('out', 'Habis')];
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? NusaConfig.darkSurface
                  : NusaConfig.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = items[i].$1),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: _filter == items[i].$1
                              ? NusaConfig.activePrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(i == 0 ? 8 : 0),
                            right: Radius.circular(
                              i == items.length - 1 ? 8 : 0,
                            ),
                          ),
                        ),
                        child: Text(
                          items[i].$2,
                          maxLines: 1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _filter == items[i].$1
                                ? Colors.white
                                : (isDark
                                      ? NusaConfig.darkTextSecondary
                                      : NusaConfig.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: 10),
        // ── View toggle: list | grid | grid padat (3 pilihan ala POS) ──
        Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
            ),
          ),
          child: Row(
            children: [
              _viewBtn(Icons.view_agenda_rounded, 1, isDark),
              _viewBtn(Icons.grid_view_rounded, 2, isDark),
              _viewBtn(Icons.apps_rounded, 3, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewBtn(IconData icon, int cols, bool isDark) {
    final active = _gridColumns == cols;
    return GestureDetector(
      onTap: () => setState(() => _gridColumns = cols),
      child: Container(
        width: 34,
        height: 32,
        margin: EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: active ? NusaConfig.activePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 17,
          color: active
              ? Colors.white
              : (isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary),
        ),
      ),
    );
  }

  // ── Daftar produk — sesuai toggle grid (1=list, 2-3=grid) ──
  Widget _buildProductSection(bool isDark) {
    final list = _filteredProducts;
    final title = _filter == 'low' ? 'Stok Menipis' : 'Stok Habis';
    final subtitle = _filter == 'low'
        ? (list.isEmpty
              ? 'Semua stok aman'
              : '${list.length} produk perlu restok')
        : (list.isEmpty
              ? 'Tidak ada stok habis'
              : '${list.length} produk kosong');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: title,
          subtitle: subtitle,
          icon: Icons.inventory_2_outlined,
        ),
        SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            message: _filter == 'low'
                ? 'Tidak ada stok menipis'
                : 'Semua produk tersedia',
          )
        else if (_gridColumns == 1)
          ...list.map((p) {
            final isLow = p.stock < p.minStock && p.minStock > 0;
            final isOut = p.stock <= 0;
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _ProductRow(
                product: p,
                highlightLowStock: isLow,
                onTap: () => showProductFormSheet(context, productId: p.id),
                onRestock: isLow ? () => _openRestockSheet(p) : null,
                onBuy: (isLow || isOut) ? () => _openBuyProduct(p) : null,
              ),
            );
          })
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cross = _gridColumns == 3
                  ? 3
                  : (constraints.maxWidth >= 800
                        ? 4
                        : constraints.maxWidth >= 560
                        ? 3
                        : 2);
              // Rasio dinamis: thumbnail 1.35 + info (nama+kategori+stok) ≈85px.
              // Kolom sempit → kartu lebih tinggi supaya konten tidak meluber.
              final colW = (constraints.maxWidth - 12 * (cross - 1)) / cross;
              final ratio = (colW / (colW / 1.35 + 85)).clamp(0.55, 0.95);
              return GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: list.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: ratio,
                ),
                itemBuilder: (_, i) => _StockGridCard(
                  product: list[i],
                  onTap: () =>
                      showProductFormSheet(context, productId: list[i].id),
                  onRestock: () => _openRestockSheet(list[i]),
                ),
              );
            },
          ),
      ],
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
              color: isDark
                  ? NusaConfig.darkSurface
                  : NusaConfig.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
              ),
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
        onTap: () =>
            setState(() => _typeFilter = value == _typeFilter ? '' : value),
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
                        : isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary),
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
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
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
                : isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
          borderRadius: BorderRadius.circular(12),
          underline: SizedBox.shrink(),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
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
                    fontWeight: FontWeight.w700,
                  ),
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

  DropdownMenuItem<String> _ddItem(String label) =>
      DropdownMenuItem(value: label, child: Text(label));

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
      initialDateRange:
          _dateRange ??
          DateTimeRange(start: DateTime.now(), end: DateTime.now()),
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
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
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

  _SectionHeader({required this.title, this.subtitle, required this.icon});

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
                      : isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================
//  Stock grid card (daftar produk — tampilan grid)
// ===========================================

class _StockGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onRestock;

  _StockGridCard({
    required this.product,
    required this.onTap,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final isLow = product.stock < product.minStock && product.minStock > 0;
    final hasImage =
        product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);
    final statusColor = outOfStock
        ? NusaConfig.stockOut
        : isLow
        ? NusaConfig.warning
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
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ──
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(NusaConfig.radiusLG - 1),
                ),
                child: AspectRatio(
                  aspectRatio: 1.35,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        Image.file(
                          File(product.imagePath!),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                        )
                      else
                        Container(
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
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      if (outOfStock)
                        Container(color: Colors.white.withValues(alpha: 0.35)),
                      // Status badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(
                              NusaConfig.radiusFull,
                            ),
                          ),
                          child: Text(
                            outOfStock
                                ? 'Habis'
                                : isLow
                                ? 'Menipis'
                                : 'Stok ${product.stock}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Info ──
              Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Stok ${product.stock}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (isLow || outOfStock)
                          GestureDetector(
                            onTap: onRestock,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: NusaConfig.accentGreen.withValues(
                                  alpha: isDark ? 0.2 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  NusaConfig.radiusSM,
                                ),
                                border: Border.all(
                                  color: NusaConfig.accentGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 14,
                                color: NusaConfig.accentGreen,
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

  _HistoryCard({required this.movement, required this.productName});

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
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // ── Icon aksen (Masuk↑ / Keluar↓) — tanpa border kiri ──
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIn ? Icons.south_west : Icons.north_east,
                  size: 17,
                  color: accent,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${isIn ? 'Masuk' : 'Keluar'}  •  $dateStr',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                ),
                child: Text(
                  '${isIn ? '+' : '-'}${m.qty}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
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
//  Product thumbnail (reused in sheet)
// ===========================================

class _ProductThumb extends StatelessWidget {
  final Product product;
  final double size;
  _ProductThumb({required this.product, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.file(
                File(product.imagePath!),
                fit: BoxFit.cover,
                width: size,
                height: size,
                cacheWidth: 400,
              )
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
//  Bottom sheet Stok Masuk / Keluar — search + scan barcode, qty editable
// ===========================================

class _AdjustSheet extends StatefulWidget {
  final String mode; // in | out
  final List<Product> products;
  final Future<void> Function(String mode, int productId, int qty) onSubmit;

  /// v2.2.43: barcode dari scan HID di layar utama Stok — di-pre-fill ke kolom
  /// cari sheet agar langsung resolve produk tanpa scan ulang.
  final String? initialBarcode;

  _AdjustSheet({
    required this.mode,
    required this.products,
    required this.onSubmit,
    this.initialBarcode,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _searchC = TextEditingController();
  final _searchFocus = FocusNode();
  final _qtyCs = <int, TextEditingController>{};
  final Set<int> _inCart = {};
  bool _saving = false;
  final Map<String, Product> _byBarcode = {};
  MobileScannerController? _scanner;

  @override
  void initState() {
    super.initState();
    for (final p in widget.products) {
      _qtyCs[p.id] = TextEditingController(text: '1');
      // v2.2.43: key dinormalisasi (trim+UPPERCASE+buang simbol) supaya kode
      // barcode berhuruf/simbol cocok dengan hasil scan HID.
      final bc = ProductRepository.normalizeBarcode(p.barcode ?? '');
      if (bc.isNotEmpty) _byBarcode[bc] = p;
    }
    // Scan HID dari layar utama: pre-fill kolom cari lalu submit.
    final init = widget.initialBarcode;
    if (init != null && init.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchC.text = init;
        _submitScanHid();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _qtyCs.values) {
      c.dispose();
    }
    _searchC.dispose();
    _searchFocus.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  bool get _isIn => widget.mode == 'in';
  bool get _isDark {
    final b = Theme.of(context).brightness == Brightness.dark;
    return b;
  }

  Color get _accent =>
      _isIn ? NusaConfig.accentGreen : NusaConfig.activePrimary;

  List<Product> get _results {
    final q = _searchC.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              (p.barcode ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Scan barcode — cari produk, auto masuk keranjang (qty naik) ──
  /// Enter dari scanner EKSTERNAL (HID): resolve barcode → produk, langsung
  /// naikkan qty keranjang, fokus TETAP di kolom cari supaya bisa scan
  /// barcode yang SAMA berulang tanpa tap ulang (v2.2.29).
  Future<void> _submitScanHid() async {
    final raw = _searchC.text.trim();
    if (raw.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }
    final found = _byBarcode[ProductRepository.normalizeBarcode(raw)];
    if (found == null) {
      _searchC.clear();
      setState(() {});
      TopToast.error(context, 'Barcode tidak terdaftar. Cari manual.');
    } else {
      _searchC.clear();
      setState(() => _addToCart(found.id));
      TopToast.success(context, '${found.name} → keranjang');
    }
    _searchFocus.requestFocus();
  }

  Future<void> _scan() async {
    if (_scanner == null) {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.qrCode,
        ],
      );
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 280,
            height: 280,
            child: MobileScanner(
              controller: _scanner,
              onDetect: (capture) {
                final codes = capture.barcodes;
                if (codes.isEmpty) return;
                final raw = codes.first.rawValue ?? '';
                final code = raw.trim();
                if (code.isEmpty) return;
                final found = _byBarcode[ProductRepository.normalizeBarcode(code)];
                if (found == null) {
                  TopToast.error(ctx, 'Barcode tidak terdaftar. Cari manual.');
                  Navigator.pop(ctx);
                  return;
                }
                setState(() {
                  _searchC.text = found.name;
                  _addToCart(found.id);
                });
                TopToast.success(ctx, '${found.name} → keranjang');
              },
            ),
          ),
        ),
      ),
    );
    // Kembalikan fokus ke kolom cari — scan EKSTERNAL lanjut beruntun
    // tanpa tap ulang (v2.2.29).
    _searchFocus.requestFocus();
  }

  bool _inCartOf(int id) => _inCart.contains(id);

  // Tambah produk ke keranjang (qty 1). Kalau sudah ada, qty naik +1.
  void _addToCart(int id) {
    if (!_inCart.contains(id)) {
      _inCart.add(id);
    } else {
      final c = _qtyCs[id];
      if (c != null) {
        final n = int.tryParse(c.text) ?? 1;
        c.text = (n + 1).toString();
      }
    }
  }

  // Naik/turun qty item; qty 0 = hapus dari keranjang.
  void _changeQty(int id, int delta) {
    final c = _qtyCs[id];
    if (c == null) return;
    if (!_inCart.contains(id)) {
      if (delta > 0) _addToCart(id);
      return;
    }
    final next = (int.tryParse(c.text) ?? 1) + delta;
    setState(() {
      if (next <= 0) {
        c.text = '1';
        _inCart.remove(id);
      } else {
        c.text = next.toString();
      }
    });
  }

  int _qtyOf(int id) {
    final c = _qtyCs[id];
    if (c == null) return 0;
    return int.tryParse(c.text.trim()) ?? 0;
  }

  // ── Submit batch: semua item di keranjang sekaligus ──
  Future<void> _submitBatch() async {
    final items = _inCart.toList();
    if (items.isEmpty) return;
    setState(() => _saving = true);
    var ok = 0;
    var skipped = 0;
    for (final id in items) {
      final n = _qtyOf(id);
      if (n <= 0) continue;
      try {
        await widget.onSubmit(widget.mode, id, n);
        ok++;
      } catch (_) {
        skipped++;
      }
    }
    if (mounted) {
      setState(() {
        _saving = false;
        for (final id in items) {
          _qtyCs[id]?.text = '1';
        }
        _inCart.clear();
      });
      if (skipped > 0) {
        TopToast.info(
          context,
          '$ok berhasil, $skipped gagal (cek stok & jumlah)',
        );
      } else if (ok > 0) {
        TopToast.success(context, '$ok item berhasil diproses');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final results = _results;
    // Scan HID jalan di SELURUH sheet (tanpa fokus kolom cari) — B6.
    // Feeds _submitScanHid sehingga barcode auto-resolve → masuk keranjang.
    return HidBarcodeListener(
      onBarcode: (code) {
        _searchC.text = code;
        _submitScanHid();
      },
      child: Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 14),
          // header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                ),
                child: Icon(
                  _isIn ? Icons.add_rounded : Icons.remove_rounded,
                  size: 20,
                  color: _accent,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isIn ? 'Stok Masuk' : 'Stok Keluar',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Tutup'),
              ),
            ],
          ),
          SizedBox(height: 16),
          // search + scan
          // Scan barcode EKSTERNAL (HID): ketik barcode + Enter → langsung
          // naikkan qty keranjang. Fokus TETAP di kolom cari (newline tidak
          // unfocus) supaya bisa scan beruntun tanpa tap ulang (v2.2.29).
          // Catatan: NusaSearchBar kelola focus node-nya sendiri, jadi
          // _searchFocus tak lagi menempel di field ini.
          NusaSearchBar(
            controller: _searchC,
            hint: 'Cari produk atau barcode\u2026',
            onChanged: (_) => setState(() {}),
            onSubmit: (_) => _submitScanHid(),
            showScanner: true,
            onScan: _scan,
          ),
          SizedBox(height: 12),
          // product list
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 420),
              child: results.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Produk tidak ditemukan',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = results[i];
                        final inCart = _inCartOf(p.id);
                        return _AdjustProductCard(
                          product: p,
                          isIn: _isIn,
                          inCart: inCart,
                          qtyC: _qtyCs[p.id]!,
                          onToggle: () {
                            if (!inCart) setState(() => _addToCart(p.id));
                          },
                          onDecrease: () => _changeQty(p.id, -1),
                          onIncrease: () => _changeQty(p.id, 1),
                          onQtyChanged: () => setState(() {}),
                        );
                      },
                    ),
            ),
          ),
          SizedBox(height: 12),
          // ── Bar bawah (batch): ringkasan + Tambah/Kurangi Stok ──
          if (_inCart.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkSurface2
                    : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_inCart.length} item',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _isIn
                            ? 'Stok masuk +${_inCart.length} produk'
                            : 'Stok keluar ${_inCart.length} produk',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submitBatch,
                    icon: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isIn ? Icons.add_rounded : Icons.remove_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _saving
                          ? 'Menyimpan\u2026'
                          : (_isIn ? 'Tambah Stok' : 'Kurangi Stok'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

// ===========================================
//  Product card di dalam _AdjustSheet
// ===========================================

class _AdjustProductCard extends StatelessWidget {
  final Product product;
  final bool isIn;
  final bool inCart;
  final TextEditingController qtyC;
  final VoidCallback onToggle;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onQtyChanged;

  _AdjustProductCard({
    required this.product,
    required this.isIn,
    required this.inCart,
    required this.qtyC,
    required this.onToggle,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isIn ? NusaConfig.accentGreen : NusaConfig.activePrimary;
    final qty = int.tryParse(qtyC.text.trim()) ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        border: Border.all(
          color: inCart
              ? accent.withValues(alpha: 0.5)
              : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            _ProductThumb(product: product, size: 36),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Stok saat ini: ${product.stock}',
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
            SizedBox(width: 8),
            if (inCart)
              // Stepper "- qty +" TETAP tampil selama di keranjang
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyBtn(
                    icon: Icons.remove_rounded,
                    onTap: onDecrease,
                    accent: accent,
                  ),
                  SizedBox(width: 6),
                  Container(
                    width: 46,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? NusaConfig.darkInputFill
                          : NusaConfig.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : NusaConfig.dividerColor,
                      ),
                    ),
                    child: TextField(
                      controller: qtyC,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (_) => onQtyChanged(),
                    ),
                  ),
                  SizedBox(width: 6),
                  _QtyBtn(
                    icon: Icons.add_rounded,
                    onTap: onIncrease,
                    accent: accent,
                  ),
                ],
              )
            else
              // Pill "+ Tambah" — tap → masuk keranjang, stepper tetap tampil
              NusaAddButton(onTap: onToggle, compact: true, color: accent),
          ],
        ),
      ),
    );
  }
}

// ===========================================
//  Product row — tampilan 1 kolom (list)
// ===========================================

class _ProductRow extends StatelessWidget {
  final Product product;
  final bool highlightLowStock;
  final VoidCallback onTap;
  final VoidCallback? onRestock;
  final VoidCallback? onBuy;

  _ProductRow({
    required this.product,
    required this.highlightLowStock,
    required this.onTap,
    this.onRestock,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage =
        product.imagePath != null &&
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
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 16, 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            NusaConfig.radiusSM,
                          ),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: hasImage
                                ? Image.file(
                                    File(product.imagePath!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 150,
                                  )
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
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? NusaConfig.darkTextPrimary
                                      : NusaConfig.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${product.category}  \u2022  Stok ${product.stock}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: NusaConfig.accentGreen.withValues(
                                    alpha: isDark ? 0.2 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    NusaConfig.radiusSM,
                                  ),
                                  border: Border.all(
                                    color: NusaConfig.accentGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 16,
                                  color: NusaConfig.accentGreen,
                                ),
                              ),
                            ),
                          ),
                        if (onBuy != null)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: onBuy,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: NusaConfig.activePrimary.withValues(
                                    alpha: isDark ? 0.2 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    NusaConfig.radiusSM,
                                  ),
                                  border: Border.all(
                                    color: NusaConfig.activePrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 13,
                                      color: NusaConfig.activePrimary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Beli',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: NusaConfig.activePrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!highlightLowStock &&
                            onRestock == null &&
                            onBuy == null)
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    final needed = (widget.product.minStock - widget.product.stock).clamp(
      1,
      1000,
    );
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
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_shopping_cart_rounded,
                    color: NusaConfig.accentGreen,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Quick Restock',
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
            SizedBox(height: 18),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NusaConfig.accentGreen.withValues(
                  alpha: isDark ? 0.14 : 0.08,
                ),
                borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                border: Border.all(
                  color: NusaConfig.accentGreen.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  _ProductThumb(product: product, size: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Stok saat ini: ${product.stock}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Min: ${product.minStock}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: NusaConfig.warningText,
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
            SizedBox(height: 16),
            Text(
              'Jumlah Restock',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
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
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
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
            NusaInput('Catatan (opsional)', controller: _note),
            SizedBox(height: 20),
            NusaButton('Konfirmasi Restock', onPressed: _saving ? null : _save),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;
  _QtyBtn({required this.icon, this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent != null
              ? accent!.withValues(alpha: 0.10)
              : (isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill),
          borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
          border: Border.all(
            color: accent != null
                ? accent!.withValues(alpha: 0.35)
                : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
              accent ??
              (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
        ),
      ),
    );
  }
}
