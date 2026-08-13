/// Pembelian Supplier (Restok): catat pembelian barang dari supplier.
/// Saat dicatat: stok masuk + harga modal (buyPrice) produk diperbarui
/// ke harga beli terbaru — HPP/laba rugi jadi presisi.
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_shipping_outlined, color: NusaConfig.activePrimary, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o.invoice} · ${o.supplierName}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                Text(DateFormat('d MMM yyyy, HH:mm').format(o.date),
                    style: TextStyle(fontSize: 12,
                        color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ]),
            ),
          ]),
          SizedBox(height: 12),
          if (o.note != null && o.note!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Catatan: ${o.note}',
                  style: TextStyle(fontSize: 13,
                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('Tidak ada item',
                    style: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: (isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor)
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it.productName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                              SizedBox(height: 2),
                              Text('${it.qty} × ${formatRupiah(it.buyPrice)}',
                                  style: TextStyle(fontSize: 12,
                                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                            ]),
                          ),
                          Text(formatRupiah(it.total),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                        ]),
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
            child: Row(children: [
              Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              Spacer(),
              Text(formatRupiah(o.total), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: NusaConfig.activePrimary)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Pembelian',
      Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Icon(Icons.local_shipping_outlined, size: 16,
                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            SizedBox(width: 6),
            Expanded(
              child: Text('Catat restok dari supplier — stok masuk otomatis & harga modal ter-update.',
                  style: TextStyle(fontSize: 12,
                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            ),
          ]),
        ),
        SizedBox(height: 4),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: NusaConfig.activePrimary))
              : _orders.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inventory_2_outlined, size: 56,
                            color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                        SizedBox(height: 12),
                        Text('Belum ada pembelian', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                        SizedBox(height: 4),
                        Text('Tekan + untuk mencatat pembelian pertama',
                            style: TextStyle(fontSize: 12,
                                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10),
                        itemBuilder: (_, i) => _PurchaseTile(order: _orders[i], onTap: () => _openDetail(_orders[i])),
                      ),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('Catat Pembelian'),
        onPressed: _openForm,
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
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.inventory_2_outlined, color: NusaConfig.activePrimary, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.supplierName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              SizedBox(height: 2),
              Text(DateFormat('d MMM yyyy, HH:mm').format(order.date),
                  style: TextStyle(fontSize: 12,
                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatRupiah(order.total), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: NusaConfig.activePrimary)),
            SizedBox(height: 2),
            Text(order.invoice, style: TextStyle(fontSize: 11,
                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
          ]),
        ]),
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

  // item draft: (product, qtyText)
  final List<(Product, TextEditingController)> _items = [];
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
  }

  @override
  void dispose() {
    _noteC.dispose();
    for (final (_, c) in _items) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _busy =>
      _suppliers.isEmpty || _products.isEmpty;

  int get _total => _items.fold<int>(
      0, (sum, e) => sum + (int.tryParse(e.$2.text) ?? 0) * e.$1.buyPrice);

  // ── supplier dropdown ──
  Widget _buildSupplierField(bool isDark) {
    if (_suppliers.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Belum ada supplier. Tambah dulu lewat menu Supplier.',
            style: TextStyle(fontSize: 13,
                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Supplier>(
          isExpanded: true,
          value: _supplier,
          hint: Text('Pilih supplier', style: TextStyle(fontSize: 14,
              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
          dropdownColor: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          style: TextStyle(fontSize: 14, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
          items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
          onChanged: (v) => setState(() => _supplier = v),
        ),
      ),
    );
  }

  // ── picker produk → tambah item ──
  void _addItem() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: _ProductPickerList(
          products: _products,
          onPick: (p) {
            Navigator.of(ctx).pop();
            setState(() => _items.add((p, TextEditingController())));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final textSec = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shopping_cart_checkout_outlined, color: NusaConfig.activePrimary, size: 20),
              ),
              SizedBox(width: 12),
              Text('Catat Pembelian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPri)),
            ]),
            SizedBox(height: 14),
            _buildSupplierField(isDark),
            SizedBox(height: 14),
            // Item list
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text('Belum ada item — tambah produk di bawah',
                          style: TextStyle(fontSize: 13,
                              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final (p, qtyC) = _items[i];
                        final qty = int.tryParse(qtyC.text) ?? 0;
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor)
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
                                SizedBox(height: 2),
                                Text('Harga beli: ${formatRupiah(p.buyPrice)} · stok ${p.stock}',
                                    style: TextStyle(fontSize: 12, color: textSec)),
                              ]),
                            ),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: qtyC,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(fontSize: 13,
                                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: NusaConfig.activePrimary),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(formatRupiah(qty * p.buyPrice),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPri)),
                            IconButton(
                              icon: Icon(Icons.close, size: 18,
                                  color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                              onPressed: () {
                                qtyC.dispose();
                                setState(() => _items.removeAt(i));
                              },
                            ),
                          ]),
                        );
                      },
                    ),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _addItem,
              icon: Icon(Icons.add, size: 18, color: NusaConfig.activePrimary),
              label: Text('Tambah Produk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: NusaConfig.activePrimary,
                side: BorderSide(color: NusaConfig.activePrimary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 10),
            NusaInput('Catatan (opsional)', controller: _noteC, hint: 'Cth: Restok mingguan'),
            if (_error != null) ...[
              SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: NusaConfig.activePrimary, fontSize: 13)),
            ],
            SizedBox(height: 12),
            Row(children: [
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
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Simpan · ${formatRupiah(_total)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_supplier == null) {
      setState(() => _error = 'Pilih supplier dulu');
      return;
    }
    final valid = _items.where((e) => (int.tryParse(e.$2.text) ?? 0) > 0).toList();
    if (valid.isEmpty) {
      setState(() => _error = 'Minimal 1 item dengan qty > 0');
      return;
    }
    final repo = PurchaseRepository(widget.db);
    await repo.recordPurchase(
      supplierId: _supplier!.id,
      supplierName: _supplier!.name,
      note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
      items: valid.map((e) => PurchaseItemInput(e.$1.id, int.parse(e.$2.text.trim()), e.$1.buyPrice)).toList(),
    );
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
    return widget.products.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.barcode?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final textSec = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Text('Pilih Produk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPri)),
      SizedBox(height: 12),
      TextField(
        controller: _searchC,
        onChanged: (v) => setState(() => _q = v),
        style: TextStyle(fontSize: 14, color: textPri),
        decoration: InputDecoration(
          hintText: 'Cari produk...',
          prefixIcon: Icon(Icons.search, size: 20,
              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          hintStyle: TextStyle(fontSize: 14,
              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          filled: true,
          fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder),
          ),
        ),
      ),
      SizedBox(height: 10),
      Expanded(
        child: _filtered.isEmpty
            ? Center(child: Text('Produk tidak ditemukan',
                style: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)))
            : ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: TextStyle(color: NusaConfig.activePrimary, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
                    subtitle: Text('Harga beli ${formatRupiah(p.buyPrice)} · stok ${p.stock}',
                        style: TextStyle(fontSize: 12, color: textSec)),
                    onTap: () => widget.onPick(p),
                  );
                },
              ),
      ),
    ]);
  }
}
