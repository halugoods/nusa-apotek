import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/product_discount.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_status_badge.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/animated_scanner_overlay.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

/// Sort options.
enum _SortBy { nameAsc, nameDesc, priceHigh, priceLow }

const _sortLabels = <_SortBy, String>{
  _SortBy.nameAsc: 'Nama (A-Z)',
  _SortBy.nameDesc: 'Nama (Z-A)',
  _SortBy.priceHigh: 'Harga (Tertinggi)',
  _SortBy.priceLow: 'Harga (Terendah)',
};

class ProductsScreen extends ConsumerStatefulWidget {
  ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  String _statusFilter = 'Semua';
  _SortBy _sortBy = _SortBy.nameAsc;
  List<Product> _products = [];
  bool _loading = true;
  int _gridColumns = 2;
  bool _showKategori = false; // Produk vs Kategori tab
  List<String> labels = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _initGrid();
    _load();
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _initGrid() async {
    final settings = SettingsRepository(ref.read(databaseProvider));
    final cols = await settings.getProductsGridColumns();
    if (mounted) setState(() => _gridColumns = cols);
  }

  Future<void> _setGridColumns(int cols) async {
    setState(() => _gridColumns = cols);
    await SettingsRepository(ref.read(databaseProvider)).setProductsGridColumns(cols);
  }

  void _onSearchChanged() => _load();

  Future<void> _load() async {
    final repo = ref.read(productRepoProvider);
    final q = _search.text.trim().toLowerCase();

    List<Product> all;
    if (q.isNotEmpty) {
      all = await repo.searchProducts(q);
    } else {
      all = await repo.getProducts(
        status: _statusFilter == 'Semua' ? null : _statusFilter,
      );
    }
    all = _sort(all);

    if (mounted) {
      setState(() { _products = all; _loading = false; });
    }
  }

  List<Product> _sort(List<Product> list) {
    switch (_sortBy) {
      case _SortBy.nameAsc: list.sort((a, b) => a.name.compareTo(b.name));
      case _SortBy.nameDesc: list.sort((a, b) => b.name.compareTo(a.name));
      case _SortBy.priceHigh: list.sort((a, b) => b.sellPrice.compareTo(a.sellPrice));
      case _SortBy.priceLow: list.sort((a, b) => a.sellPrice.compareTo(b.sellPrice));
    }
    return list;
  }

  // ── Export / Import bottom sheet ──

  void _showExportImportSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(NusaConfig.spaceLG),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Ekspor / Impor Produk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: NusaConfig.spaceMD),
            _exportTile(Icons.table_chart_outlined, NusaConfig.accentGreen, 'Ekspor CSV (Excel)', 'File spreadsheet, bisa dibuka di Excel', _exportCSV),
            SizedBox(height: NusaConfig.spaceXS),
            _exportTile(Icons.picture_as_pdf_outlined, NusaConfig.activePrimary, 'Ekspor', 'Dokumen siap cetak', _exportPDF),
            SizedBox(height: NusaConfig.spaceXS),
            _exportTile(Icons.upload_file_outlined, NusaConfig.info, 'Impor CSV', 'Impor produk dari file CSV', _importCSV),
          ]),
        ),
      ),
    );
  }

  Widget _exportTile(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD)),
      tileColor: color.withValues(alpha: 0.06),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }

  Future<void> _exportCSV() async {
    try {
      final rows = <List<String>>[
        ['Nama', 'SKU', 'Barcode', 'Kategori', 'Harga Beli', 'Harga Jual', 'Diskon %', 'Stok', 'Tipe', 'Kadaluarsa'],
      ];
      for (final p in _products) {
        rows.add([
          p.name, p.sku ?? '', p.barcode ?? '', p.category,
          p.buyPrice.toString(), p.sellPrice.toString(), p.discountPercent.toString(), p.stock.toString(),
          p.productType ?? 'Regular',
          p.expiryDate != null ? DateFormat('dd/MM/yyyy').format(p.expiryDate!) : '',
        ]);
      }
      final csv = ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/produk_nusa_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Daftar Produk NUSA Kasir');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor CSV');
    }
  }

  Future<void> _exportPDF() async {
    try {
      final buf = StringBuffer('DAFTAR PRODUK - NUSA KASIR\n');
      buf.writeln('=' * 60);
      buf.writeln('Nama | SKU | Kategori | Harga Jual | Stok | Tipe | Kadaluarsa');
      buf.writeln('-' * 60);
      for (final p in _products) {
        buf.writeln('${p.name} | ${p.sku ?? '-'} | ${p.category} | ${formatRupiah(p.sellPrice)} | ${p.stock} | ${p.productType ?? 'Regular'} | ${p.expiryDate != null ? DateFormat('dd/MM/yyyy').format(p.expiryDate!) : '-'}');
      }
      buf.writeln('=' * 60);
      buf.writeln('Total: ${_products.length} produk');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/produk_nusa_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Daftar Produk NUSA Kasir');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor');
    }
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) return;
      final contents = utf8.decode(bytes);
      final rows = CsvToListConverter().convert(contents);
      if (rows.isEmpty) {
        if (mounted) TopToast.error(context, 'File CSV kosong');
        return;
      }
      // Skip header row
      int imported = 0;
      final repo = ref.read(productRepoProvider);
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || (row.length >= 1 && row[0].toString().trim().isEmpty)) continue;
        try {
          final name = row.length > 0 ? row[0].toString().trim() : '';
          final sku = row.length > 1 ? row[1].toString().trim() : '';
          final barcode = row.length > 2 ? row[2].toString().trim() : '';
          final category = row.length > 3 ? row[3].toString().trim() : 'Lainnya';
          final buyPrice = row.length > 4 ? int.tryParse(row[4].toString().trim()) ?? 0 : 0;
          final sellPrice = row.length > 5 ? int.tryParse(row[5].toString().trim()) ?? 0 : 0;
          final discountPercent = row.length > 6 ? (int.tryParse(row[6].toString().trim()) ?? 0).clamp(0, 100) : 0;
          final stock = row.length > 7 ? int.tryParse(row[7].toString().trim()) ?? 0 : 0;
          if (name.isEmpty || sellPrice == 0) continue;
          await repo.addProduct(
            name: name, category: category, buyPrice: buyPrice,
            sellPrice: sellPrice, stock: stock, minStock: 0,
            discountPercent: discountPercent,
            sku: sku.isEmpty ? null : sku,
            barcode: barcode.isEmpty ? null : barcode,
          );
          imported++;
        } catch (_) {}
      }
      if (mounted) {
        TopToast.success(context, '$imported produk berhasil diimpor');
        _load();
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal impor CSV');
    }
  }

  // ── Barcode scan ──

  Future<void> _scanBarcode() async {
    final controller = MobileScannerController(
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
    final manualCtrl = TextEditingController();
    String? scanned;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(children: [
            Icon(Icons.qr_code_scanner, size: 22, color: NusaConfig.activePrimary),
            SizedBox(width: 8),
            Text('Scan Barcode Produk'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScannerOverlay(
                size: 280,
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final barcode = capture.barcodes.firstOrNull;
                    if (barcode != null && barcode.rawValue != null) {
                      scanned = barcode.rawValue;
                      Navigator.pop(ctx);
                    }
                  },
                  errorBuilder: (context, error, child) {
                    debugPrint('[Products] scanner error: $error');
                    return Container(
                      height: 280,
                      width: 280,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.no_photography_outlined,
                                size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Kamera tidak tersedia.\nGunakan input manual di bawah.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: manualCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Masukkan kode barcode manual',
                  hintText: 'contoh: 8991002101234',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty) {
                    scanned = t;
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final t = manualCtrl.text.trim();
                if (t.isNotEmpty) {
                  scanned = t;
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Gunakan'),
            ),
          ],
        ),
      ),
    );
    await controller.dispose();
    manualCtrl.dispose();
    if (scanned == null || !mounted) return;

    final repo = ref.read(productRepoProvider);
    final product = await repo.byBarcode(scanned!);
    if (product != null && mounted) { context.push('/produk/edit/${product.id}'); return; }
    if (mounted) { _search.text = scanned!; TopToast.info(context, 'Produk tidak ditemukan. Coba cari manual.'); }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusXL)),
        title: Text('Hapus Produk'),
        content: Text('Hapus "${product.name}"?\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: NusaConfig.activePrimary),
            child: Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(productRepoProvider).deleteProduct(product.id);
    if (mounted) { TopToast.success(context, 'Produk dihapus'); _load(); }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Daftar Produk',
      Column(children: [
        // Produk-Kategori switch + grid toggle + export/import
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            // Produk / Kategori segment switch
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _SegmentTab(
                  label: 'Produk',
                  active: !_showKategori,
                  onTap: () => setState(() => _showKategori = false),
                ),
                _SegmentTab(
                  label: 'Kategori',
                  active: _showKategori,
                  onTap: () => setState(() => _showKategori = true),
                ),
              ]),
            ),
            Spacer(),
            // Grid toggle (only when in Produk mode)
            if (!_showKategori) ...[
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _GridToggleBtn(icon: Icons.view_agenda_rounded, active: _gridColumns == 1, onTap: () => _setGridColumns(1)),
                  _GridToggleBtn(icon: Icons.grid_view_rounded, active: _gridColumns == 2, onTap: () => _setGridColumns(2)),
                  _GridToggleBtn(icon: Icons.apps_rounded, active: _gridColumns == 3, onTap: () => _setGridColumns(3)),
                ]),
              ),
              SizedBox(width: 8),
            ],
            // Export/Import button
            GestureDetector(
              onTap: _showExportImportSheet,
              child: Container(
                height: 36, width: 36,
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
                ),
                child: Icon(Icons.file_download_outlined, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
              ),
            ),
          ]),
        ),
        SizedBox(height: 10),

        // Search + scan
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: NusaInput(
            'Cari nama atau barcode...',
            controller: _search,
            hint: 'Cari nama atau barcode...',
            prefixIcon: Icon(Icons.search, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            suffixIcon: GestureDetector(
              onTap: _scanBarcode,
              child: Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.qr_code_scanner, size: 20, color: NusaConfig.activePrimary),
              ),
            ),
          ),
        ),

        // Content: either product list or category grid
        if (_showKategori)
          Expanded(child: _KategoriView())
        else ...[
          // Status chips row
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (_, i) {
                labels = ['Semua', 'Aktif', 'Habis'];
                final label = labels[i];
                final selected = label == _statusFilter;
                return FilterChip(
                  label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                  selected: selected, showCheckmark: false,
                  selectedColor: NusaConfig.activePrimary,
                  backgroundColor: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) { if (label != _statusFilter) { setState(() => _statusFilter = label); _load(); } },
                );
              },
            ),
          ),
          SizedBox(height: 8),
          // Sort + count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.sort, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
              SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<_SortBy>(
                  value: _sortBy, isDense: true,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                  items: _sortLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) { if (v != null) { setState(() => _sortBy = v); _load(); } },
                ),
              ),
              Spacer(),
              if (!_loading)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NusaConfig.radiusFull)),
                  child: Text('${_products.length} produk',
                    style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
                ),
            ]),
          ),
          SizedBox(height: 8),
          // Product list/grid
          Expanded(
            child: _loading
                ? SkeletonList()
                : _products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: _search.text.isNotEmpty ? 'Produk tidak ditemukan' : 'Belum ada produk',
                        actionLabel: 'Tambah Produk',
                        onAction: () => context.push('/produk/tambah'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _gridColumns == 1
                            ? _buildListView()
                            : _gridColumns == 2
                                ? _buildGridView()
                                : _buildMultiGridView(_gridColumns),
                      ),
          ),
        ],
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: Icon(_showKategori ? Icons.create_new_folder : Icons.add),
        label: Text(_showKategori ? 'Tambah Kategori' : 'Tambah Produk'),
        onPressed: () => context.push(_showKategori ? '/produk/kategori' : '/produk/tambah'),
      ),
    );
  }

  // 1-column list view (thin horizontal cards)
  Widget _buildListView() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _products.length,
      separatorBuilder: (_, __) => SizedBox(height: 8),
      itemBuilder: (_, i) => _ProductListCard(
        product: _products[i],
        onEdit: () => context.push('/produk/edit/${_products[i].id}'),
        onDelete: () => _deleteProduct(_products[i]),
        onTogglePriceType: () => _togglePriceType(_products[i]),
        onToggleProductType: () => _toggleProductType(_products[i]),
      ),
    );
  }

  // 2-column grid view
  Widget _buildGridView() {
    final colW = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    final ratio = (colW / (colW + 110)).clamp(0.4, 0.85);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: ratio),
      itemCount: _products.length,
      itemBuilder: (_, i) => _ProductGridCard(
        product: _products[i],
        onEdit: () => context.push('/produk/edit/${_products[i].id}'),
        onDelete: () => _deleteProduct(_products[i]),
        onTogglePriceType: () => _togglePriceType(_products[i]),
        onToggleProductType: () => _toggleProductType(_products[i]),
      ),
    );
  }

  // N-column grid view (3+)
  Widget _buildMultiGridView(int columns) {
    final colW = (MediaQuery.of(context).size.width - 32 - 10 * (columns - 1)) / columns;
    final ratio = (colW / (colW + 110)).clamp(0.4, 0.85);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: ratio),
      itemCount: _products.length,
      itemBuilder: (_, i) => _ProductGridCard(
        product: _products[i],
        onEdit: () => context.push('/produk/edit/${_products[i].id}'),
        onDelete: () => _deleteProduct(_products[i]),
        onTogglePriceType: () => _togglePriceType(_products[i]),
        onToggleProductType: () => _toggleProductType(_products[i]),
      ),
    );
  }

  Future<void> _togglePriceType(Product product) async {
    final newType = product.priceType == 'kg' ? 'pcs' : 'kg';
    await ref.read(productRepoProvider).setPriceType(product.id, newType);
    TopToast.success(context, newType == 'kg' ? 'Harga per kg' : 'Harga per pcs');
    _load();
  }

  Future<void> _toggleProductType(Product product) async {
    final current = product.productType;
    final newType = (current == 'jasa' || current == 'Jasa') ? null : 'jasa';
    await ref.read(productRepoProvider).setProductType(product.id, newType);
    TopToast.success(context, newType == 'jasa' ? 'Jasa' : 'Produk');
    _load();
  }
}

// ── Segment Tab ──

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  _SegmentTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? NusaConfig.activePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
        )),
      ),
    );
  }
}

// ── Grid Toggle Button ──

class _GridToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  _GridToggleBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 34,
        decoration: BoxDecoration(
          color: active ? NusaConfig.activeSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18,
          color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
      ),
    );
  }
}

// ── Kategori View (inline) ──

class _KategoriView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_KategoriView> createState() => _KategoriViewState();
}

class _KategoriViewState extends ConsumerState<_KategoriView> {
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final counts = await ref.read(productRepoProvider).categoryProductCounts();
    if (mounted) setState(() { _counts = counts; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) return Center(child: CircularProgressIndicator());
    final cats = _counts.entries.toList();
    if (cats.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.category_outlined, size: 48, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
        SizedBox(height: 8),
        Text('Belum ada kategori', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: cats.length,
        separatorBuilder: (_, __) => SizedBox(height: 8),
        itemBuilder: (_, i) {
          final cat = cats[i].key;
          final count = cats[i].value;
          return GestureDetector(
            onTap: () => context.push('/produk/kategori/$cat'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                    SizedBox(height: 2),
                    Text('$count produk', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                  ]),
                ),
                Icon(Icons.chevron_right, size: 20, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Product Grid Card (2-column) ──

class _ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePriceType;
  final VoidCallback? onToggleProductType;
  _ProductGridCard({required this.product, required this.onEdit, required this.onDelete, this.onTogglePriceType, this.onToggleProductType});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final hasImage = product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
            border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06), blurRadius: 10, offset: Offset(0, 3))],
          ),
          padding: EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Image (inset) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(children: [
                  if (hasImage)
                    Image.file(File(product.imagePath!), fit: BoxFit.cover, width: double.infinity, cacheWidth: 400)
                  else
                    Container(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
                      alignment: Alignment.center,
                      child: Text(_initials(product.name), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    ),
                  // Stock badge top-left
                  Positioned(top: 6, left: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: outOfStock ? NusaConfig.stockOut : (product.stock <= product.minStock ? NusaConfig.stockLow : NusaConfig.surfaceColor.withValues(alpha: 0.92)),
                        borderRadius: BorderRadius.circular(NusaConfig.radiusFull)),
                      child: Text(
                        outOfStock ? 'Habis' : '${product.stock}x',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: outOfStock ? NusaConfig.stockOutText : (product.stock <= product.minStock ? NusaConfig.stockLowText : NusaConfig.activePrimary)),
                      ),
                    ),
                  ),
                  if (outOfStock) Container(color: Colors.white.withValues(alpha: 0.4)),
                ]),
              ),
            ),
            SizedBox(height: 8),
            // ── Name ──
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, height: 1.25,
                color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
            SizedBox(height: 2),
            // ── Category ──
            Text(product.category, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            SizedBox(height: 6),
            // ── Price ──
            product.hasDiscount
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatRupiah(product.effectivePrice),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary)),
                      SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(formatRupiah(product.sellPrice),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                          )),
                      ),
                    ],
                  )
                : Text(formatRupiah(product.sellPrice),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary)),
            Spacer(),
            // ── Actions ──
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (NusaConfig.isSalonVariant && onToggleProductType != null) ...[
                _ActionButton(
                  icon: (product.productType == 'jasa' || product.productType == 'Jasa') ? Icons.design_services_rounded : Icons.inventory_2_rounded,
                  color: (product.productType == 'jasa' || product.productType == 'Jasa') ? NusaConfig.accentPurple : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  onTap: onToggleProductType!,
                ),
                SizedBox(width: 6),
              ],
              if (NusaConfig.isLaundryVariant && onTogglePriceType != null) ...[
                _ActionButton(
                  icon: product.priceType == 'kg' ? Icons.scale_rounded : Icons.inventory_2_rounded,
                  color: product.priceType == 'kg' ? NusaConfig.accentPurple : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  onTap: onTogglePriceType!,
                ),
                SizedBox(width: 6),
              ],
              _ActionButton(icon: Icons.edit_outlined, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, onTap: onEdit),
              SizedBox(width: 6),
              _ActionButton(icon: Icons.delete_outline, color: NusaConfig.error, onTap: onDelete),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Product List Card (1-column, thin horizontal) ──

class _ProductListCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePriceType;
  final VoidCallback? onToggleProductType;
  _ProductListCard({required this.product, required this.onEdit, required this.onDelete, this.onTogglePriceType, this.onToggleProductType});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final hasImage = product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync();
    final gradient = NusaConfig.catGradientFor(product.category);

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 60, height: 60,
              child: hasImage
                  ? Image.file(File(product.imagePath!), fit: BoxFit.cover, cacheWidth: 200)
                  : Container(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
                      alignment: Alignment.center,
                      child: Text(_initials(product.name), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
            ),
          ),
          SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              SizedBox(height: 3),
              Row(children: [
                Text(product.category, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: outOfStock ? NusaConfig.stockOut : (product.stock <= product.minStock ? NusaConfig.stockLow : NusaConfig.stockActive),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    outOfStock ? 'Habis' : (product.stock <= product.minStock ? 'Menipis' : 'Aktif'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: outOfStock ? NusaConfig.stockOutText : (product.stock <= product.minStock ? NusaConfig.stockLowText : NusaConfig.stockActiveText)),
                  ),
                ),
              ]),
              SizedBox(height: 2),
              product.hasDiscount
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatRupiah(product.effectivePrice), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
                        SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Text(formatRupiah(product.sellPrice),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                            )),
                        ),
                      ],
                    )
                  : Text(formatRupiah(product.sellPrice), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
            ]),
          ),
          SizedBox(width: 8),
          // Actions
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (NusaConfig.isSalonVariant && onToggleProductType != null) ...[
              _ActionButton(
                icon: (product.productType == 'jasa' || product.productType == 'Jasa') ? Icons.design_services_rounded : Icons.inventory_2_rounded,
                color: (product.productType == 'jasa' || product.productType == 'Jasa') ? NusaConfig.accentPurple : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                onTap: onToggleProductType!,
              ),
              SizedBox(width: 4),
            ],
            if (NusaConfig.isLaundryVariant && onTogglePriceType != null) ...[
              _ActionButton(
                icon: product.priceType == 'kg' ? Icons.scale_rounded : Icons.inventory_2_rounded,
                color: product.priceType == 'kg' ? NusaConfig.accentPurple : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                onTap: onTogglePriceType!,
              ),
              SizedBox(width: 4),
            ],
            _ActionButton(icon: Icons.edit_outlined, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, onTap: onEdit),
            SizedBox(width: 4),
            _ActionButton(icon: Icons.delete_outline, color: NusaConfig.error, onTap: onDelete),
          ]),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
