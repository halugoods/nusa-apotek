/// Pembelian Supplier (Restok): catat pembelian barang dari supplier.
/// Saat dicatat: stok masuk + harga modal (buyPrice) produk diperbarui
/// ke harga beli terbaru — HPP/laba rugi jadi presisi.
///
/// Mendukung dua jenis item:
/// - **Produk**: stok masuk + harga modal terbaru (seperti biasa).
/// - **Bahan** (non-produk, mis. plastik): hanya dicatat riwayatnya + riwayat
///   harga beli per supplier (tab "Riwayat Harga") — tanpa menyentuh stok.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/purchase_repository.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';
import 'package:nusa_kasir/features/products/product_form_screen.dart';
import 'package:nusa_kasir/shared/widgets/animated_scanner_overlay.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  /// Supplier yang sudah dipilih dari luar (mis. tombol "Beli ke Supplier"
  /// di menu Stok) — form pembelian langsung memakai supplier ini.
  final int? supplierId;
  const PurchaseScreen({super.key, this.supplierId});
  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  List<PurchaseOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = PurchaseRepository(ref.read(databaseProvider));
    final orders = await repo.getOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }
  }

  // ── Form pembelian baru ───────────────────────────────────────
  void _openForm() {
    final db = ref.read(databaseProvider);
    // supplierId bisa lewat constructor maupun query param (?supplierId=x).
    var supplierId = widget.supplierId;
    if (supplierId == null) {
      final raw = GoRouterState.of(context).uri.queryParameters['supplierId'];
      supplierId = int.tryParse(raw ?? '');
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseFormSheet(
        db: db,
        onSaved: () {
          if (mounted) {
            TopToast.success(context, 'Pembelian dicatat');
            _load();
          }
        },
        suppliersFuture: SupplierRepository(db).getSuppliers(),
        productsFuture: ProductRepository(db).getProducts(),
        presetSupplierId: supplierId,
      ),
    );
  }

  // ── Riwayat harga bahan per supplier ─────────────────────────
  Future<void> _openPriceHistory() async {
    final db = ref.read(databaseProvider);
    final suppliers = await SupplierRepository(db).getSuppliers();
    if (!mounted) return;
    if (suppliers.isEmpty) {
      TopToast.info(
        context,
        'Tambah supplier dulu untuk melihat riwayat harga',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PriceHistorySheet(db: db, suppliers: suppliers),
    );
  }

  // ── Detail riwayat ────────────────────────────────────────────
  Future<void> _openDetail(PurchaseOrder o) async {
    final db = ref.read(databaseProvider);
    final items = await PurchaseRepository(db).getItems(o.id);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: NusaConfig.activePrimary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${o.invoice} · ${o.supplierName}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? NusaConfig.darkTextPrimary
                              : NusaConfig.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('d MMM yyyy, HH:mm').format(o.date),
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
              ],
            ),
            SizedBox(height: 12),
            if (o.note != null && o.note!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Catatan: ${o.note}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada item',
                        style: TextStyle(
                          color: isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? NusaConfig.darkSurface
                                        : NusaConfig.backgroundColor)
                                    .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            it.productName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? NusaConfig.darkTextPrimary
                                                  : NusaConfig.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (it.isMaterial) ...[
                                          SizedBox(width: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: NusaConfig.accentPurple
                                                  .withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Bahan',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: NusaConfig.accentPurple,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${it.qty} × ${formatRupiah(it.buyPrice)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? NusaConfig.darkTextSecondary
                                            : NusaConfig.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatRupiah(it.total),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? NusaConfig.darkTextPrimary
                                      : NusaConfig.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    formatRupiah(o.total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: NusaConfig.activePrimary,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Pembelian',
      Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Catat restok dari supplier — stok masuk otomatis & harga modal ter-update.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: NusaConfig.activePrimary,
                    ),
                  )
                : _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada pembelian',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tekan + untuk mencatat pembelian pertama',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10),
                      itemBuilder: (_, i) => _PurchaseTile(
                        order: _orders[i],
                        onTap: () => _openDetail(_orders[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
            foregroundColor: NusaConfig.activePrimary,
            heroTag: 'purchase_history',
            icon: Icon(Icons.trending_up, size: 20),
            label: Text('Riwayat Harga'),
            onPressed: _openPriceHistory,
          ),
          SizedBox(width: 12),
          FloatingActionButton.extended(
            backgroundColor: NusaConfig.activePrimary,
            foregroundColor: Colors.white,
            heroTag: 'purchase_add',
            icon: Icon(Icons.add),
            label: Text('Catat Pembelian'),
            onPressed: _openForm,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet riwayat harga beli bahan per supplier.
class _PriceHistorySheet extends StatefulWidget {
  final AppDatabase db;
  final List<Supplier> suppliers;
  const _PriceHistorySheet({required this.db, required this.suppliers});

  @override
  State<_PriceHistorySheet> createState() => _PriceHistorySheetState();
}

class _PriceHistorySheetState extends State<_PriceHistorySheet> {
  Supplier? _supplier;
  List<MaterialPrice> _prices = [];

  @override
  void initState() {
    super.initState();
    if (widget.suppliers.isNotEmpty) {
      _supplier = widget.suppliers.first;
      _load();
    }
  }

  Future<void> _load() async {
    final s = _supplier;
    if (s == null) return;
    final prices = await PurchaseRepository(widget.db).getMaterialPrices(s.id);
    if (mounted) setState(() => _prices = prices);
  }

  /// Kelompokkan per nama bahan, urut tanggal menaik (histori harga).
  Map<String, List<MaterialPrice>> get _byMaterial {
    final map = <String, List<MaterialPrice>>{};
    for (final p in _prices) {
      map.putIfAbsent(p.materialName, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textSec = isDark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    final bg = (isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    Icons.trending_up,
                    color: NusaConfig.accentPurple,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Riwayat Harga Bahan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: Icon(Icons.close, color: textTer),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Lihat kenaikan / penurunan harga beli dari supplier.',
              style: TextStyle(fontSize: 12, color: textTer),
            ),
            SizedBox(height: 12),
            // Pilih supplier
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkInputBorder
                      : NusaConfig.inputBorder,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Supplier>(
                  isExpanded: true,
                  value: _supplier,
                  hint: Text(
                    'Pilih supplier',
                    style: TextStyle(fontSize: 14, color: textTer),
                  ),
                  dropdownColor: bg,
                  style: TextStyle(fontSize: 14, color: textPri),
                  items: widget.suppliers
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _supplier = v);
                    _load();
                  },
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: _prices.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat bahan dari supplier ini',
                        style: TextStyle(fontSize: 13, color: textTer),
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.only(bottom: 8),
                      children: _byMaterial.entries.map((entry) {
                        final name = entry.key;
                        final list = entry.value;
                        final first = list.first.price;
                        final last = list.last.price;
                        final diff = last - first;
                        final IconData trendIcon = diff > 0
                            ? Icons.trending_up
                            : diff < 0
                            ? Icons.trending_down
                            : Icons.trending_flat;
                        final Color trendColor = diff > 0
                            ? Colors.redAccent
                            : diff < 0
                            ? Colors.green
                            : textTer;
                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? NusaConfig.darkSurface2
                                        : NusaConfig.backgroundColor)
                                    .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPri,
                                      ),
                                    ),
                                  ),
                                  Icon(trendIcon, size: 16, color: trendColor),
                                  SizedBox(width: 4),
                                  Text(
                                    diff == 0
                                        ? 'tetap'
                                        : '${diff > 0 ? '+' : ''}${formatRupiah(diff)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: trendColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              ...list.map((p) {
                                final idx = list.indexOf(p);
                                final prevPrice = idx > 0
                                    ? list[idx - 1].price
                                    : p.price;
                                final d = p.price - prevPrice;
                                final Color c = d > 0
                                    ? Colors.redAccent
                                    : d < 0
                                    ? Colors.green
                                    : textTer;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat(
                                            'd MMM yyyy',
                                          ).format(p.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSec,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${p.qty} × ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textTer,
                                        ),
                                      ),
                                      Text(
                                        formatRupiah(p.price),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPri,
                                        ),
                                      ),
                                      if (d != 0) ...[
                                        SizedBox(width: 6),
                                        Text(
                                          '${d > 0 ? '▲' : '▼'} ${formatRupiah(d.abs())}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: c,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final PurchaseOrder order;
  final VoidCallback onTap;
  _PurchaseTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.inventory_2_outlined,
                color: NusaConfig.activePrimary,
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.supplierName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM yyyy, HH:mm').format(order.date),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(order.total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: NusaConfig.activePrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  order.invoice,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form sheet: POS-style — supplier + cari/scan produk + keranjang ──

class _PurchaseFormSheet extends StatefulWidget {
  final AppDatabase db;
  final Future<List<Supplier>> suppliersFuture;
  final Future<List<Product>> productsFuture;
  final VoidCallback onSaved;

  /// Supplier yang langsung terpilih saat form dibuka (dari "Beli ke Supplier").
  final int? presetSupplierId;
  const _PurchaseFormSheet({
    required this.db,
    required this.suppliersFuture,
    required this.productsFuture,
    required this.onSaved,
    this.presetSupplierId,
  });

  @override
  State<_PurchaseFormSheet> createState() => _PurchaseFormSheetState();
}

class _PurchaseFormSheetState extends State<_PurchaseFormSheet> {
  Supplier? _supplier;
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<String> _materialNames = [];
  bool _materialMode = false;

  // item draft (produk): (product, qtyCtrl, priceCtrl — harga beli opsional)
  final List<(Product, TextEditingController, TextEditingController)>
  _productItems = [];
  // item draft (bahan): (nameCtrl, priceCtrl, qtyCtrl)
  final List<
    (TextEditingController, TextEditingController, TextEditingController)
  >
  _materialItems = [];
  // Biaya tambahan (C5): (nameCtrl, amountCtrl) — packing/ongkir/stiker dll.
  final List<(TextEditingController, TextEditingController)> _extraCosts = [];
  final _noteC = TextEditingController();
  final _searchC = TextEditingController();
  String _q = '';
  String? _error;

  // ID produk yang sedang di-expand (tampilkan stepper - qty +).
  String _expandedProductId = '';

  @override
  void initState() {
    super.initState();
    widget.suppliersFuture.then((list) {
      if (!mounted) return;
      setState(() {
        _suppliers = list;
        // D2: preset supplier dari luar → langsung terpilih.
        final preset = widget.presetSupplierId;
        if (preset != null) {
          final match = list.where((s) => s.id == preset).firstOrNull;
          if (match != null) _supplier = match;
        }
        if (_supplier == null &&
            _suppliers.isNotEmpty &&
            widget.presetSupplierId == null) {
          _supplier = _suppliers.first;
        }
      });
    });
    widget.productsFuture.then((list) {
      if (mounted) setState(() => _products = list);
    });
    // Daftar nama bahan untuk autocomplete.
    PurchaseRepository(widget.db).getMaterialNames().then((names) {
      if (mounted) setState(() => _materialNames = names);
    });
  }

  @override
  void dispose() {
    _noteC.dispose();
    _searchC.dispose();
    for (final (_, qtyC, priceC) in _productItems) {
      qtyC.dispose();
      priceC.dispose();
    }
    for (final (n, p, q) in _materialItems) {
      n.dispose();
      p.dispose();
      q.dispose();
    }
    for (final (n, a) in _extraCosts) {
      n.dispose();
      a.dispose();
    }
    super.dispose();
  }

  bool get _busy => _suppliers.isEmpty;

  // Produk yang cocok dengan pencarian (nama / barcode).
  List<Product> get _filteredProducts {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              (p.barcode?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  // Subtotal item (tanpa biaya tambahan).
  int get _subtotal {
    if (_materialMode) {
      return _materialItems.fold<int>(
        0,
        (sum, e) =>
            sum +
            (int.tryParse(e.$2.text) ?? 0) * (int.tryParse(e.$3.text) ?? 0),
      );
    }
    return _productItems.fold<int>(0, (sum, e) {
      final qty = int.tryParse(e.$2.text) ?? 0;
      // Harga beli opsional: diisi = pakai harga baru, kosong = harga produk.
      final newPrice = int.tryParse(e.$3.text) ?? 0;
      final price = newPrice > 0 ? newPrice : e.$1.buyPrice;
      return sum + qty * price;
    });
  }

  int get _extraTotal =>
      _extraCosts.fold<int>(0, (s, e) => s + (int.tryParse(e.$2.text) ?? 0));

  int get _total => _subtotal + _extraTotal;

  // Total kuantitas di keranjang (untuk badge).
  int get _cartQty => _materialMode
      ? _materialItems.fold<int>(
          0,
          (s, e) => s + (int.tryParse(e.$3.text) ?? 0),
        )
      : _productItems.fold<int>(
          0,
          (s, e) => s + (int.tryParse(e.$2.text) ?? 0),
        );

  // ── tambah / naikkan qty produk di keranjang ──
  void _addProductToCart(Product p) {
    final idx = _productItems.indexWhere((e) => e.$1.id == p.id);
    setState(() {
      if (idx >= 0) {
        final (_, qtyC, _) = _productItems[idx];
        qtyC.text = ((int.tryParse(qtyC.text) ?? 0) + 1).toString();
      } else {
        _productItems.add((
          p,
          TextEditingController(text: '1'),
          TextEditingController(),
        ));
      }
    });
  }

  // Tap "+" → expand panel stepper. Tap lagi → collapse.
  // Jika produk belum ada di keranjang, langsung tambahkan (qty 1) supaya
  // kolom qty di panel selalu editable (bukan badge "0×" yang terkunci).
  void _toggleProductExpanded(Product p) {
    final idx = _productItems.indexWhere((e) => e.$1.id == p.id);
    setState(() {
      if (idx < 0) {
        _productItems.add((
          p,
          TextEditingController(text: '1'),
          TextEditingController(),
        ));
      }
      _expandedProductId = _expandedProductId == p.id.toString()
          ? ''
          : p.id.toString();
    });
  }

  // Naik / turun qty item yang sedang di-expand; qty 0 = hapus dari keranjang.
  void _changeCartQty(Product p, int delta) {
    final idx = _productItems.indexWhere((e) => e.$1.id == p.id);
    if (idx < 0) {
      if (delta > 0) _addProductToCart(p);
      return;
    }
    final (_, qtyC, _) = _productItems[idx];
    final next = (int.tryParse(qtyC.text) ?? 0) + delta;
    setState(() {
      if (next <= 0) {
        qtyC.dispose();
        _productItems.removeAt(idx);
        _expandedProductId = '';
      } else {
        qtyC.text = next.toString();
      }
    });
  }

  void _clearCart() {
    for (final (_, qtyC, priceC) in _productItems) {
      qtyC.dispose();
      priceC.dispose();
    }
    setState(() => _productItems.clear());
  }

  // ── supplier picker slide-up (mirror customer_picker_button) ──
  Future<void> _openSupplierPicker() async {
    if (_suppliers.isEmpty) {
      TopToast.info(context, 'Tambah supplier dulu lewat menu Supplier');
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String q = '';
    List<Supplier> filtered = List.from(_suppliers);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkDivider
                        : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: NusaConfig.activePrimary,
                      size: 19,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Pilih Supplier',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              TextField(
                autofocus: true,
                onChanged: (v) => setSheet(() {
                  q = v.toLowerCase();
                  filtered = _suppliers
                      .where(
                        (s) =>
                            s.name.toLowerCase().contains(q) ||
                            (s.phone ?? '').contains(q),
                      )
                      .toList();
                }),
                decoration: InputDecoration(
                  hintText: 'Cari nama supplier...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                  prefixIcon: Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? NusaConfig.darkInputFill
                      : NusaConfig.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada supplier',
                          style: TextStyle(
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: NusaConfig.activePrimary
                                  .withValues(alpha: 0.1),
                              child: Text(
                                s.name.isNotEmpty
                                    ? s.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: NusaConfig.activePrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(
                              s.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: s.phone != null && s.phone!.isNotEmpty
                                ? Text(s.phone!, style: TextStyle(fontSize: 12))
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _supplier = s);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── scan barcode → langsung masuk keranjang (restok: TIDAK guard stok) ──
  Future<void> _scanBarcode() async {
    String? scannedCode;
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
    String? errorMsg;
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 22,
                color: NusaConfig.activePrimary,
              ),
              SizedBox(width: 8),
              Text('Pindai Barcode'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScannerOverlay(
                size: 280,
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    if (scannedCode != null) return;
                    final barcode = capture.barcodes.firstOrNull;
                    final raw = barcode?.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    scannedCode = raw;
                    Navigator.pop(ctx);
                  },
                  errorBuilder: (context, error, child) {
                    debugPrint('[Pembelian] scanner error: $error');
                    if (errorMsg == null) {
                      errorMsg =
                          'Kamera tidak tersedia atau izin kamera ditolak.';
                      setSt(() {});
                    }
                    return Container(
                      height: 280,
                      width: 280,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.no_photography_outlined,
                              size: 36,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera tidak tersedia.\nBarcode manual diatur via Form Produk.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (errorMsg != null) ...[
                SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal'),
            ),
          ],
        ),
      ),
    );
    await controller.dispose();
    if (scannedCode == null || !mounted) return;
    final p = await ProductRepository(widget.db).byBarcode(scannedCode!);
    if (p != null) {
      _addProductToCart(p);
      TopToast.success(context, '${p.name} masuk keranjang');
    } else if (mounted) {
      TopToast.error(context, 'Produk tidak ditemukan');
    }
  }

  // ── C3: Tambah Produk → form produk (sheet); kembali dengan produk di keranjang ──
  Future<void> _openAddProduct() async {
    final s = _supplier;
    final createdId = await showProductFormSheet(
      context,
      supplierId: s?.id,
      supplierName: s?.name,
    );
    if (createdId == null || !mounted) return;
    final p = await ProductRepository(widget.db).byId(createdId);
    if (p != null) _addProductToCart(p);
  }

  // ── tambah bahan manual ──
  void _addMaterial() {
    setState(
      () => _materialItems.add((
        TextEditingController(),
        TextEditingController(),
        TextEditingController(text: '1'),
      )),
    );
  }

  // ── toggle Produk / Bahan ──
  Widget _buildTypeToggle(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleChip(
              label: 'Produk',
              selected: !_materialMode,
              onTap: () => setState(() => _materialMode = false),
              textPri: textPri,
            ),
          ),
          Expanded(
            child: _toggleChip(
              label: 'Bahan',
              selected: _materialMode,
              onTap: () => setState(() => _materialMode = true),
              textPri: textPri,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color textPri,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? NusaConfig.activePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : textPri,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.96,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: _materialMode
              // Mode Bahan: form manual (bukan POS).
              ? _buildMaterialLayout(isDark)
              // Mode Produk: POS 2-panel (katalog + keranjang).
              : _buildProductLayout(isDark),
        ),
      ),
    );
  }

  // ── Layout POS: lebar ≥ 720 (tablet landscape) → 2 panel samping ──
  Widget _buildProductLayout(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return Column(
            children: [
              _buildHeader(isDark),
              SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildCatalogPanel(isDark, wide: true),
                    ),
                    SizedBox(width: 12),
                    SizedBox(width: 360, child: _buildCartPanel(isDark)),
                  ],
                ),
              ),
            ],
          );
        }
        // HP (portrait): katalog penuh + floating cart bar ala POS.
        return Column(
          children: [
            _buildHeader(isDark),
            SizedBox(height: 12),
            Expanded(child: _buildCatalogPanel(isDark, wide: false)),
            SizedBox(height: 10),
            _buildFloatingCartBar(isDark),
          ],
        );
      },
    );
  }

  // ── Floating cart bar (HP) — gradient pill ala POS, tap → sheet keranjang ──
  Widget _buildFloatingCartBar(bool isDark) {
    final qty = _cartQty;
    return GestureDetector(
      onTap: qty > 0 ? _openCartSheet : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              NusaConfig.activePrimary,
              NusaConfig.activePrimary.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: NusaConfig.activePrimary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 22,
                  color: Colors.white,
                ),
                if (qty > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$qty',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: NusaConfig.activePrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                qty > 0 ? '$qty item' : 'Keranjang kosong',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              formatRupiah(_total),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                qty > 0 ? 'Lihat' : '+',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: NusaConfig.activePrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sheet keranjang (HP) — drag handle + item + biaya + catatan + simpan ──
  Future<void> _openCartSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: _buildCartSheetBody(isDark),
      ),
    );
  }

  // Isi sheet keranjang: daftar item + biaya tambahan + catatan + tombol.
  Widget _buildCartSheetBody(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 18,
                color: NusaConfig.activePrimary,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keranjang (${_cartQty})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPri,
                ),
              ),
            ),
            if (_productItems.isNotEmpty)
              TextButton(
                onPressed: _clearCart,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size(0, 32),
                ),
                child: Text(
                  'Kosongkan',
                  style: TextStyle(fontSize: 12, color: textTer),
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Expanded(
          child: _productItems.isEmpty
              ? Center(
                  child: Text(
                    'Keranjang kosong — ketuk produk di katalog',
                    style: TextStyle(fontSize: 12, color: textTer),
                  ),
                )
              : ListView.separated(
                  itemCount: _productItems.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildCartItem(isDark, i),
                ),
        ),
        SizedBox(height: 8),
        // Biaya tambahan — minimalis (ikon + kecil di samping kata Keranjang)
        _buildExtraCosts(isDark),
        SizedBox(height: 8),
        NusaInput(
          'Catatan (opsional)',
          controller: _noteC,
          hint: 'Cth: Restok mingguan',
        ),
        if (_error != null) ...[
          SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(color: NusaConfig.activePrimary, fontSize: 13),
          ),
        ],
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 14,
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
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: Icon(Icons.check, size: 18),
                label: Text(
                  'Simpan · ${formatRupiah(_total)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: NusaConfig.activePrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.shopping_cart_checkout_outlined,
            color: NusaConfig.activePrimary,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Catat Pembelian',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
        ),
        _buildTypeToggle(isDark),
      ],
    );
  }

  // ── Katalog produk (kiri / atas): search + scan + supplier + grid/list ──
  Widget _buildCatalogPanel(bool isDark, {required bool wide}) {
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search + scan barcode (di dalam) + tombol pilih supplier
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchC,
                onChanged: (v) => setState(() => _q = v),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari produk atau barcode...',
                  hintStyle: TextStyle(fontSize: 13, color: textTer),
                  prefixIcon: Icon(Icons.search, size: 20, color: textTer),
                  suffixIcon: IconButton(
                    onPressed: _scanBarcode,
                    tooltip: 'Pindai barcode',
                    icon: Icon(
                      Icons.qr_code_scanner,
                      size: 20,
                      color: NusaConfig.activePrimary,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? NusaConfig.darkInputFill
                      : NusaConfig.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            // Tombol pilih supplier (sejajar search bar)
            GestureDetector(
              onTap: _openSupplierPicker,
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.inputBorder,
                  ),
                ),
                child: _supplier != null
                    ? Text(
                        _supplier!.name.isNotEmpty
                            ? _supplier!.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: NusaConfig.activePrimary,
                        ),
                      )
                    : Icon(
                        Icons.storefront_outlined,
                        color: NusaConfig.activePrimary,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        // Katalog
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    'Produk tidak ditemukan',
                    style: TextStyle(fontSize: 13, color: textTer),
                  ),
                )
              : wide
              ? _buildProductGrid(isDark)
              : _buildProductList(isDark),
        ),
        SizedBox(height: 8),
        // C3: Tambah Produk → form produk
        OutlinedButton.icon(
          onPressed: _openAddProduct,
          icon: Icon(
            Icons.add_box_outlined,
            size: 18,
            color: NusaConfig.activePrimary,
          ),
          label: Text(
            'Tambah Produk',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: NusaConfig.activePrimary,
            side: BorderSide(
              color: NusaConfig.activePrimary.withValues(alpha: 0.4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }

  // ── Grid katalog (tablet landscape) — kartu ala POS dengan gambar ──
  Widget _buildProductGrid(bool isDark) {
    final count = _filteredProducts.length;
    final crossAxis = count > 24 ? 4 : (count > 8 ? 3 : 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ratio dinamis: colW = (lebar - padding - spacing) / kolom.
        // Gambar persegi (colW-20) + footer konten-real (nama 2 baris +
        // kategori + harga + stok + gap + tombol 36) → rasio pas sehingga
        // tombol tidak pernah meluber keluar card, di 2/3/4 kolom sekalipun.
        final colW = (constraints.maxWidth - 10 * (crossAxis - 1)) / crossAxis;
        const footerH = 168.0; // nama 2 baris + kategori + harga + stok + aksi
        final ratio = (colW / (colW - 20 + footerH)).clamp(0.4, 0.9);
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: ratio,
          ),
          itemCount: _filteredProducts.length,
          itemBuilder: (_, i) {
            final p = _filteredProducts[i];
            final idx = _productItems.indexWhere((e) => e.$1.id == p.id);
            final qty = idx >= 0
                ? (int.tryParse(_productItems[idx].$2.text) ?? 0)
                : 0;
            return _PurchaseProductCard(
              product: p,
              isDark: isDark,
              qtyInCart: qty,
              expanded: _expandedProductId == p.id.toString(),
              qtyField: idx >= 0 ? _qtyTextField(_productItems[idx].$2) : null,
              onToggleExpand: () => _toggleProductExpanded(p),
              onChangeQty: (delta) => _changeCartQty(p, delta),
            );
          },
        );
      },
    );
  }

  // ── Qty editable — TextField kecil di tengah stepper "- qty +" ──
  Widget _qtyTextField(TextEditingController qtyC) {
    return Container(
      decoration: BoxDecoration(
        color: NusaConfig.activePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: qtyC,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: NusaConfig.activePrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ── List katalog (HP) — baris dengan thumbnail gambar ──
  Widget _buildProductList(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textSec = isDark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _filteredProducts.length,
      separatorBuilder: (_, __) => SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = _filteredProducts[i];
        final idx = _productItems.indexWhere((e) => e.$1.id == p.id);
        final qty = idx >= 0
            ? (int.tryParse(_productItems[idx].$2.text) ?? 0)
            : 0;
        final expanded = _expandedProductId == p.id.toString();
        return Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: expanded
                  ? NusaConfig.activePrimary.withValues(alpha: 0.5)
                  : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                leading: _ProductThumbnail(
                  product: p,
                  size: 44,
                  isDark: isDark,
                ),
                title: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: textPri,
                  ),
                ),
                subtitle: Text(
                  'Harga beli ${formatRupiah(p.buyPrice)} · stok ${p.stock}',
                  style: TextStyle(fontSize: 12, color: textSec),
                ),
                trailing: expanded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QtyBtn(
                            icon: Icons.remove,
                            onTap: () => _changeCartQty(p, -1),
                          ),
                          SizedBox(width: 6),
                          idx >= 0
                              ? SizedBox(
                                  width: 56,
                                  child: TextField(
                                    controller: _productItems[idx].$2,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: NusaConfig.activePrimary,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: NusaConfig.activePrimary
                                          .withValues(alpha: 0.10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NusaConfig.activePrimary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$qty×',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: NusaConfig.activePrimary,
                                    ),
                                  ),
                                ),
                          SizedBox(width: 6),
                          _QtyBtn(
                            icon: Icons.add,
                            onTap: () => _changeCartQty(p, 1),
                          ),
                        ],
                      )
                    : Icon(
                        qty > 0 ? Icons.add_circle : Icons.add_circle_outline,
                        size: 24,
                        color: qty > 0
                            ? NusaConfig.activePrimary
                            : NusaConfig.activePrimary.withValues(alpha: 0.6),
                      ),
                onTap: () => _toggleProductExpanded(p),
              ),
              if (expanded)
                Padding(
                  padding: EdgeInsets.fromLTRB(56, 0, 12, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      qty > 0
                          ? 'Subtotal: ${formatRupiah(qty * p.buyPrice)}'
                          : 'Ketuk + untuk tambah ke keranjang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: qty > 0 ? textPri : textTer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Panel keranjang (kanan / bawah) ──
  Widget _buildCartPanel(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor)
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 18,
                color: NusaConfig.activePrimary,
              ),
              SizedBox(width: 8),
              Text(
                'Keranjang (${_cartQty})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              Spacer(),
              if (_productItems.isNotEmpty)
                TextButton(
                  onPressed: _clearCart,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size(0, 32),
                  ),
                  child: Text(
                    'Kosongkan',
                    style: TextStyle(fontSize: 12, color: textTer),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Expanded(
            child: _productItems.isEmpty
                ? Center(
                    child: Text(
                      'Keranjang kosong — ketuk produk di katalog',
                      style: TextStyle(fontSize: 12, color: textTer),
                    ),
                  )
                : ListView.separated(
                    itemCount: _productItems.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildCartItem(isDark, i),
                  ),
          ),
          SizedBox(height: 8),
          // C5: Modul biaya tambahan (packing/ongkir/stiker)
          _buildExtraCosts(isDark),
          SizedBox(height: 8),
          // Catatan
          NusaInput(
            'Catatan (opsional)',
            controller: _noteC,
            hint: 'Cth: Restok mingguan',
          ),
          if (_error != null) ...[
            SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(color: NusaConfig.activePrimary, fontSize: 13),
            ),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark
                          ? NusaConfig.darkBorder
                          : NusaConfig.dividerColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 14,
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
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: Icon(Icons.check, size: 18),
                  label: Text(
                    'Simpan · ${formatRupiah(_total)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Supplier pill (mode Bahan — tombol buka slide-up picker) ──
  Widget _buildSupplierPill(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    if (_suppliers.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Belum ada supplier. Tambah dulu lewat menu Supplier.',
          style: TextStyle(fontSize: 13, color: textTer),
        ),
      );
    }
    return InkWell(
      onTap: _openSupplierPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: _supplier != null
                  ? Text(
                      _supplier!.name.isNotEmpty
                          ? _supplier!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: NusaConfig.activePrimary,
                      ),
                    )
                  : Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: NusaConfig.activePrimary,
                    ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                _supplier != null ? _supplier!.name : 'Pilih supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _supplier != null ? textPri : textTer,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 20, color: textTer),
          ],
        ),
      ),
    );
  }

  // ── C5: Modul biaya tambahan (packing/ongkir/stiker) — minimalis ──
  Widget _buildExtraCosts(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Biaya Tambahan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              if (_extraTotal > 0)
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    formatRupiah(_extraTotal),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: NusaConfig.activePrimary,
                    ),
                  ),
                ),
              Spacer(),
              // "+" kecil — tambah baris biaya
              GestureDetector(
                onTap: () => setState(
                  () => _extraCosts.add((
                    TextEditingController(),
                    TextEditingController(),
                  )),
                ),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: NusaConfig.activePrimary,
                  ),
                ),
              ),
            ],
          ),
          if (_extraCosts.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Packing, ongkir, stiker dll',
                style: TextStyle(fontSize: 11, color: textTer),
              ),
            )
          else
            ...List.generate(_extraCosts.length, (i) {
              final (nameC, amountC) = _extraCosts[i];
              return Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameC,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 13, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'cth: Ongkir',
                          hintStyle: TextStyle(fontSize: 12, color: textTer),
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? NusaConfig.darkInputFill
                              : NusaConfig.inputFill,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountC,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 13, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'Rp 0',
                          hintStyle: TextStyle(fontSize: 12, color: textTer),
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(fontSize: 11, color: textTer),
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? NusaConfig.darkInputFill
                              : NusaConfig.inputFill,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: textTer),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        nameC.dispose();
                        amountC.dispose();
                        setState(() => _extraCosts.removeAt(i));
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── item kartu keranjang (produk) ──
  Widget _buildCartItem(bool isDark, int i) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    final (p, qtyC, priceC) = _productItems[i];
    final qty = int.tryParse(qtyC.text) ?? 0;
    final newPrice = int.tryParse(priceC.text) ?? 0;
    final effPrice = newPrice > 0 ? newPrice : p.buyPrice;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProductThumbnail(product: p, size: 34, isDark: isDark),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPri,
                      ),
                    ),
                    Text(
                      'Harga beli ${formatRupiah(p.buyPrice)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 17, color: textTer),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  qtyC.dispose();
                  priceC.dispose();
                  setState(() => _productItems.removeAt(i));
                },
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: qtyC,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPri,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 12, color: textTer),
                    prefixText: 'Qty ',
                    prefixStyle: TextStyle(fontSize: 11, color: textTer),
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? NusaConfig.darkInputFill
                        : NusaConfig.inputFill,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: priceC,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPri,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Harga beli (opsional)',
                    hintStyle: TextStyle(fontSize: 11, color: textTer),
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(fontSize: 11, color: textTer),
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? NusaConfig.darkInputFill
                        : NusaConfig.inputFill,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            'Subtotal: ${formatRupiah(qty * effPrice)}${newPrice > 0 ? ' · harga beli baru' : ''}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
        ],
      ),
    );
  }

  // ── Layout mode Bahan (form manual) ──
  Widget _buildMaterialLayout(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(isDark),
        SizedBox(height: 14),
        _buildSupplierPill(isDark),
        SizedBox(height: 14),
        Expanded(child: _buildMaterialItems(isDark)),
        SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addMaterial,
          icon: Icon(Icons.add, size: 18, color: NusaConfig.activePrimary),
          label: Text(
            'Tambah Bahan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: NusaConfig.activePrimary,
            side: BorderSide(
              color: NusaConfig.activePrimary.withValues(alpha: 0.4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        SizedBox(height: 10),
        NusaInput(
          'Catatan (opsional)',
          controller: _noteC,
          hint: 'Cth: Restok mingguan',
        ),
        if (_error != null) ...[
          SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: NusaConfig.activePrimary, fontSize: 13),
          ),
        ],
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 14,
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
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: Icon(Icons.check, size: 18),
                label: Text(
                  'Simpan · ${formatRupiah(_total)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── daftar item produk ──
  // ── daftar item bahan (nama + harga + qty manual) ──
  Widget _buildMaterialItems(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    if (_materialItems.isEmpty) {
      return Center(
        child: Text(
          'Belum ada bahan — tambah bahan di bawah',
          style: TextStyle(fontSize: 13, color: textTer),
        ),
      );
    }
    return ListView.separated(
      itemCount: _materialItems.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (_, i) {
        final (nameC, priceC, qtyC) = _materialItems[i];
        final price = int.tryParse(priceC.text) ?? 0;
        final qty = int.tryParse(qtyC.text) ?? 0;
        // Depth card — sama seperti card PRODUK (komplain user: form bahan
        // sebelumnya rata & field pakai UnderlineInputBorder yang tipis).
        return Container(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameC,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: NusaConfig.activePrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nama bahan (cth: Plastik HD)',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textTer,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: textTer),
                    onPressed: () {
                      nameC.dispose();
                      priceC.dispose();
                      qtyC.dispose();
                      setState(() => _materialItems.removeAt(i));
                    },
                  ),
                ],
              ),
              // Autocomplete nama bahan dari riwayat pembelian
              if (_materialNames.isNotEmpty)
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final name in _materialNames)
                        GestureDetector(
                          onTap: () {
                            nameC.text = name;
                            setState(() {});
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: NusaConfig.activePrimary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: NusaConfig.activePrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // Depth separator — pisah nama bahan (header) & area harga/jumlah
              Divider(
                height: 16,
                thickness: 1,
                color: isDark
                    ? NusaConfig.darkDivider
                    : NusaConfig.dividerColor,
              ),
              // Harga beli — field terpisah (depth, seperti form produk)
              Text(
                'Harga beli',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textTer,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: priceC,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPri,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 13, color: textTer),
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(fontSize: 12, color: textTer),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? NusaConfig.darkInputFill
                      : NusaConfig.inputFill,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? NusaConfig.darkInputBorder
                          : NusaConfig.inputBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: NusaConfig.activePrimary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Jumlah — field terpisah (depth, seperti form produk)
              Text(
                'Jumlah',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textTer,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: qtyC,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPri,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 13, color: textTer),
                  prefixText: 'Qty ',
                  prefixStyle: TextStyle(fontSize: 12, color: textTer),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? NusaConfig.darkInputFill
                      : NusaConfig.inputFill,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? NusaConfig.darkInputBorder
                          : NusaConfig.inputBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: NusaConfig.activePrimary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Subtotal: ${formatRupiah(price * qty)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_supplier == null) {
      setState(() => _error = 'Pilih supplier dulu');
      return;
    }
    final repo = PurchaseRepository(widget.db);
    // C5: biaya tambahan (packing/ongkir/stiker) — nama default bila kosong.
    final extraCosts = _extraCosts
        .where((e) => (int.tryParse(e.$2.text) ?? 0) > 0)
        .map(
          (e) => PurchaseExtraCost(
            name: e.$1.text.trim().isEmpty ? 'Biaya' : e.$1.text.trim(),
            amount: int.tryParse(e.$2.text) ?? 0,
          ),
        )
        .toList();
    if (_materialMode) {
      final items = <PurchaseItemInput>[];
      for (final (nameC, priceC, qtyC) in _materialItems) {
        final name = nameC.text.trim();
        final price = int.tryParse(priceC.text) ?? 0;
        final qty = int.tryParse(qtyC.text) ?? 0;
        if (name.isEmpty || price <= 0 || qty <= 0) continue;
        items.add(
          PurchaseItemInput(
            name: name,
            qty: qty,
            buyPrice: price,
            isMaterial: true,
          ),
        );
      }
      if (items.isEmpty) {
        setState(
          () => _error = 'Minimal 1 bahan dengan nama, harga & qty valid',
        );
        return;
      }
      await repo.recordPurchase(
        supplierId: _supplier!.id,
        supplierName: _supplier!.name,
        note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
        extraCosts: extraCosts,
        items: items,
      );
    } else {
      final valid = _productItems
          .where((e) => (int.tryParse(e.$2.text) ?? 0) > 0)
          .toList();
      if (valid.isEmpty) {
        setState(() => _error = 'Minimal 1 item dengan qty > 0');
        return;
      }
      await repo.recordPurchase(
        supplierId: _supplier!.id,
        supplierName: _supplier!.name,
        note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
        extraCosts: extraCosts,
        items: valid.map((e) {
          // Harga beli opsional: diisi = harga baru (stok & HPP ikut ter-update),
          // kosong = pakai harga beli produk yang ada.
          final newPrice = int.tryParse(e.$3.text) ?? 0;
          return PurchaseItemInput(
            productId: e.$1.id,
            name: e.$1.name,
            qty: int.parse(e.$2.text.trim()),
            buyPrice: newPrice > 0 ? newPrice : e.$1.buyPrice,
          );
        }).toList(),
      );
    }
    if (mounted) Navigator.of(context).pop();
    widget.onSaved();
  }
}

// ── Kartu produk katalog (grid tablet) — ala POS dengan gambar ──

class _PurchaseProductCard extends StatelessWidget {
  final Product product;
  final bool isDark;
  final int qtyInCart;
  final bool expanded;
  final Widget? qtyField;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onChangeQty;
  const _PurchaseProductCard({
    required this.product,
    required this.isDark,
    required this.qtyInCart,
    required this.expanded,
    this.qtyField,
    required this.onToggleExpand,
    required this.onChangeQty,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
      child: InkWell(
        onTap: expanded ? null : onToggleExpand,
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: expanded
                  ? NusaConfig.activePrimary.withValues(alpha: 0.5)
                  : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
            ),
          ),
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar produk (inset) — fallback gradien kategori
              ClipRRect(
                borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProductThumbnail(
                        product: product,
                        size: 200,
                        isDark: isDark,
                      ),
                      // Badge qty di keranjang
                      if (qtyInCart > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: NusaConfig.activePrimary,
                              borderRadius: BorderRadius.circular(
                                NusaConfig.radiusFull,
                              ),
                            ),
                            child: Text(
                              '$qtyInCart×',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
              ),
              SizedBox(height: 2),
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
              SizedBox(height: 6),
              Text(
                formatRupiah(product.buyPrice),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: NusaConfig.activePrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'stok ${product.stock}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
              ),
              SizedBox(height: 8),
              // Area aksi: "+" atau stepper "- qty +" (expand)
              if (expanded)
                Row(
                  children: [
                    _QtyBtn(icon: Icons.remove, onTap: () => onChangeQty(-1)),
                    SizedBox(width: 8),
                    Expanded(
                      child:
                          qtyField ??
                          Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: NusaConfig.activePrimary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$qtyInCart×',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: NusaConfig.activePrimary,
                              ),
                            ),
                          ),
                    ),
                    SizedBox(width: 8),
                    _QtyBtn(icon: Icons.add, onTap: () => onChangeQty(1)),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onToggleExpand,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.add_circle_outline_rounded,
                          size: 28,
                          color: NusaConfig.activePrimary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tombol qty bulat 30×30 (stepper - qty +) ──

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark
                ? NusaConfig.darkSurface2
                : NusaConfig.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Thumbnail produk: gambar file + fallback avatar gradien ──

class _ProductThumbnail extends StatelessWidget {
  final Product product;
  final double size;
  final bool isDark;
  const _ProductThumbnail({
    required this.product,
    required this.size,
    required this.isDark,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : '??';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        product.imagePath != null &&
        product.imagePath!.isNotEmpty &&
        File(product.imagePath!).existsSync();
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(product.imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 400,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final gradient = NusaConfig.catGradientFor(product.category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(product.name),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
