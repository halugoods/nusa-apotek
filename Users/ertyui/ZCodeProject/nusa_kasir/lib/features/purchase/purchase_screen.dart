/// Pembelian Supplier (Restok): catat pembelian barang dari supplier.
/// Saat dicatat: stok masuk + harga modal (buyPrice) produk diperbarui
/// ke harga beli terbaru — HPP/laba rugi jadi presisi.
///
/// Mendukung dua jenis item:
/// - **Produk**: stok masuk + harga modal terbaru (seperti biasa).
/// - **Bahan** (non-produk, mis. plastik): hanya dicatat riwayatnya + riwayat
///   harga beli per supplier (tab "Riwayat Harga") — tanpa menyentuh stok.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/purchase_repository.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});
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
                    Icons.local_shipping_outlined,
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
                  Icons.local_shipping_outlined,
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

// ── Form sheet: pilih supplier + tambah item + harga beli ──────

class _PurchaseFormSheet extends StatefulWidget {
  final AppDatabase db;
  final Future<List<Supplier>> suppliersFuture;
  final Future<List<Product>> productsFuture;
  final VoidCallback onSaved;
  const _PurchaseFormSheet({
    required this.db,
    required this.suppliersFuture,
    required this.productsFuture,
    required this.onSaved,
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
  final _noteC = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.suppliersFuture.then((list) {
      if (mounted) setState(() => _suppliers = list);
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
    for (final (_, qtyC, priceC) in _productItems) {
      qtyC.dispose();
      priceC.dispose();
    }
    for (final (n, p, q) in _materialItems) {
      n.dispose();
      p.dispose();
      q.dispose();
    }
    super.dispose();
  }

  bool get _busy =>
      _suppliers.isEmpty || (_materialMode ? false : _products.isEmpty);

  int get _total {
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

  // ── supplier dropdown ──
  Widget _buildSupplierField(bool isDark) {
    if (_suppliers.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Belum ada supplier. Tambah dulu lewat menu Supplier.',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Supplier>(
          isExpanded: true,
          value: _supplier,
          hint: Text(
            'Pilih supplier',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
          ),
          dropdownColor: isDark
              ? NusaConfig.darkSurface
              : NusaConfig.surfaceColor,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
          items: _suppliers
              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
              .toList(),
          onChanged: (v) => setState(() => _supplier = v),
        ),
      ),
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
              icon: Icons.inventory_2_outlined,
              selected: !_materialMode,
              onTap: () => setState(() => _materialMode = false),
              textPri: textPri,
            ),
          ),
          Expanded(
            child: _toggleChip(
              label: 'Bahan',
              icon: Icons.category_outlined,
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
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color textPri,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? NusaConfig.activePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : textPri),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : textPri,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── picker produk → tambah item ──
  void _addProduct() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: _ProductPickerList(
          products: _products,
          onPick: (p) {
            Navigator.of(ctx).pop();
            setState(
              () => _productItems.add((
                p,
                TextEditingController(text: '1'),
                TextEditingController(),
              )),
            );
          },
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                      Icons.shopping_cart_checkout_outlined,
                      color: NusaConfig.activePrimary,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Catat Pembelian',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              _buildTypeToggle(isDark),
              SizedBox(height: 14),
              _buildSupplierField(isDark),
              SizedBox(height: 14),
              // Item list
              Expanded(
                child: _materialMode
                    ? _buildMaterialItems(isDark)
                    : _buildProductItems(isDark),
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : (_materialMode ? _addMaterial : _addProduct),
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: NusaConfig.activePrimary,
                ),
                label: Text(
                  _materialMode ? 'Tambah Bahan' : 'Tambah Produk',
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
                  style: TextStyle(
                    color: NusaConfig.activePrimary,
                    fontSize: 13,
                  ),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
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
        ),
      ),
    );
  }

  // ── daftar item produk ──
  Widget _buildProductItems(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textSec = isDark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    if (_productItems.isEmpty) {
      return Center(
        child: Text(
          'Belum ada item — tambah produk di bawah',
          style: TextStyle(fontSize: 13, color: textTer),
        ),
      );
    }
    return ListView.separated(
      itemCount: _productItems.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (_, i) {
        final (p, qtyC, priceC) = _productItems[i];
        final qty = int.tryParse(qtyC.text) ?? 0;
        final newPrice = int.tryParse(priceC.text) ?? 0;
        // Harga beli yang dipakai: diisi = harga baru, kosong = harga produk.
        final effPrice = newPrice > 0 ? newPrice : p.buyPrice;
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPri,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Harga beli sekarang: ${formatRupiah(p.buyPrice)} · stok ${p.stock}',
                          style: TextStyle(fontSize: 12, color: textSec),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: textTer),
                    onPressed: () {
                      qtyC.dispose();
                      priceC.dispose();
                      setState(() => _productItems.removeAt(i));
                    },
                  ),
                ],
              ),
              SizedBox(height: 6),
              // Qty — di bawah nama item (bukan kanan)
              Text(
                'Jumlah',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textTer,
                ),
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
                  ),
                  SizedBox(width: 10),
                  // Harga beli opsional — kosong = pakai harga produk
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: priceC,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPri,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Harga beli (opsional)',
                        hintStyle: TextStyle(fontSize: 12, color: textTer),
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
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Subtotal: ${formatRupiah(qty * effPrice)}'
                '${newPrice > 0 ? ' · harga beli baru' : ''}',
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPri,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nama bahan (cth: Plastik HD)',
                        hintStyle: TextStyle(fontSize: 13, color: textTer),
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
              const SizedBox(height: 6),
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

class _ProductPickerList extends StatefulWidget {
  final List<Product> products;
  final ValueChanged<Product> onPick;
  const _ProductPickerList({required this.products, required this.onPick});

  @override
  State<_ProductPickerList> createState() => _ProductPickerListState();
}

class _ProductPickerListState extends State<_ProductPickerList> {
  String _q = '';
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              (p.barcode?.toLowerCase().contains(q) ?? false),
        )
        .toList();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          'Pilih Produk',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPri,
          ),
        ),
        SizedBox(height: 12),
        TextField(
          controller: _searchC,
          onChanged: (v) => setState(() => _q = v),
          style: TextStyle(fontSize: 14, color: textPri),
          decoration: InputDecoration(
            hintText: 'Cari produk...',
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
            filled: true,
            fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? NusaConfig.darkInputBorder
                    : NusaConfig.inputBorder,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'Produk tidak ditemukan',
                    style: TextStyle(
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: NusaConfig.activePrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: NusaConfig.activePrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPri,
                        ),
                      ),
                      subtitle: Text(
                        'Harga beli ${formatRupiah(p.buyPrice)} · stok ${p.stock}',
                        style: TextStyle(fontSize: 12, color: textSec),
                      ),
                      onTap: () => widget.onPick(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
