/// Pembelian Supplier (Restok): catat pembelian barang dari supplier.
/// Saat dicatat: stok masuk + harga modal (buyPrice) produk diperbarui
/// ke harga beli terbaru — HPP/laba rugi jadi presisi.
///
/// Mendukung dua jenis item:
/// - **Produk**: stok masuk + harga modal terbaru (seperti biasa).
/// - **Bahan** (non-produk, mis. plastik): hanya dicatat riwayatnya + riwayat
///   harga beli per supplier (tab "Riwayat Harga") — tanpa menyentuh stok.
import 'dart:convert';
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
import 'package:nusa_kasir/shared/widgets/nusa_cart_controls.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
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
  void _openForm({String? initialBarcode}) {
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
        initialBarcode: initialBarcode,
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
                                      '${it.qty} × ${formatRupiah(it.buyPrice)}'
                                      ' = ${formatRupiah(it.total)}',
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
            if (o.extraCostsJson != null && o.extraCostsJson!.isNotEmpty) ...[
              SizedBox(height: 8),
              ..._extraCostRows(o),
            ],
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

  // Baris biaya tambahan (ongkir/packing) dari extraCostsJson header.
  List<Widget> _extraCostRows(PurchaseOrder o) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    final costs = _parseExtraCosts(o);
    if (costs.isEmpty) return const [];
    return [
      for (final c in costs)
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 14, color: textSec),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(fontSize: 13, color: textSec),
                ),
              ),
              Text(
                formatRupiah(c.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textSec,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<PurchaseExtraCost> _parseExtraCosts(PurchaseOrder o) {
    try {
      final raw = o.extraCostsJson;
      if (raw == null || raw.isEmpty) return const [];
      final list = (jsonDecode(raw) as List)
          .map((e) => PurchaseExtraCost.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
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
      onBarcode: _onExternalBarcode,
    );
  }

  /// Barcode eksternal (HID) — v2.2.43: scan di layar utama Pembelian membuka
  /// form "Catat Pembelian" dengan barcode di-pre-fill agar langsung resolve
  /// produk tanpa tap kolom cari / scan ulang.
  Future<void> _onExternalBarcode(String code) async {
    final norm = ProductRepository.normalizeBarcode(code);
    if (norm.isEmpty) return;
    _openForm(initialBarcode: norm);
  }
}

/// Bottom sheet Biaya & Catatan — StatefulWidget mandiri.
///
/// State biaya tambahan (controller list) & catatan dipegang DI SINI, bukan
/// widget induk. Tombol '+' & X memanggil setState LOCAL → merespons instan
/// tanpa rebuild layar belakang (sebelumnya pakai setState induk → '+' dan X
/// seolah "tidak responsif" sampai sheet dibuka ulang). Hasil dikirim balik
/// via Navigator.pop dengan record (costs, note).
class _CostsNoteSheet extends StatefulWidget {
  final bool isDark;
  final List<(TextEditingController, TextEditingController)> initialCosts;
  final TextEditingController initialNote;
  const _CostsNoteSheet({
    required this.isDark,
    required this.initialCosts,
    required this.initialNote,
  });

  @override
  State<_CostsNoteSheet> createState() => _CostsNoteSheetState();
}

class _CostsNoteSheetState extends State<_CostsNoteSheet> {
  late final List<(TextEditingController, TextEditingController)> _costs;
  late final TextEditingController _noteC;

  @override
  void initState() {
    super.initState();
    _costs = widget.initialCosts;
    _noteC = widget.initialNote;
  }

  @override
  void dispose() {
    // Dismiss tanpa Selesai → buang controller sementara (milik sheet).
    if (!_committed) {
      for (final (n, a) in _costs) {
        n.dispose();
        a.dispose();
      }
      _noteC.dispose();
    }
    super.dispose();
  }

  bool _committed = false;

  void _commit() {
    _committed = true;
    Navigator.pop(
      context,
      (costs: _costs, note: _noteC.text.trim()),
    );
  }

  int get _extraTotal => _costs.fold<int>(
        0,
        (s, e) => s + (int.tryParse(e.$2.text) ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        // Konten scrollable → keyboard tidak pernah memotong kolom
        // Biaya Tambahan / Catatan (tetap responsif di layar kecil).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkDivider
                        : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                      size: 20,
                      color: NusaConfig.activePrimary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Biaya & Catatan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 20, color: textTer),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _ExtraCostsSection(
                isDark: isDark,
                costs: _costs,
                extraTotal: _extraTotal,
                onAdd: () => setState(
                  () => _costs.add((
                    TextEditingController(),
                    TextEditingController(),
                  )),
                ),
                onRemove: (i) => setState(() {
                  _costs[i].$1.dispose();
                  _costs[i].$2.dispose();
                  _costs.removeAt(i);
                }),
                onChanged: () => setState(() {}),
              ),
              SizedBox(height: 12),
              NusaInput(
                'Catatan (opsional)',
                controller: _noteC,
                hint: 'Cth: Restok mingguan',
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _commit,
                icon: Icon(Icons.check, size: 18),
                label: Text(
                  'Selesai',
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Modul Biaya Tambahan (packing/ongkir/stiker) — stateless.
///
/// State (controller list) dipegang PEMANGGIL — _CostsNoteSheet & panel
/// kanan punya instance sendiri. '+'/X cukup memanggil callback → pemanggil
/// yang setState (di scope lokal), jadi tombol merespons instan.
class _ExtraCostsSection extends StatelessWidget {
  final bool isDark;
  final List<(TextEditingController, TextEditingController)> costs;
  final int extraTotal;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;
  const _ExtraCostsSection({
    required this.isDark,
    required this.costs,
    required this.extraTotal,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              if (extraTotal > 0)
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    formatRupiah(extraTotal),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: NusaConfig.activePrimary,
                    ),
                  ),
                ),
              const Spacer(),
              // "+" kecil — tambah baris biaya
              GestureDetector(
                onTap: onAdd,
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
          if (costs.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Packing, ongkir, stiker dll',
                style: TextStyle(fontSize: 11, color: textTer),
              ),
            )
          else
            ...List.generate(costs.length, (i) {
              final (nameC, amountC) = costs[i];
              return Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameC,
                        onChanged: (_) => onChanged(),
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
                        onChanged: (_) => onChanged(),
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
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
              );
            }),
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

  /// v2.2.43: barcode dari scan HID di layar utama Pembelian — di-pre-fill ke
  /// kolom cari form agar langsung resolve produk tanpa scan ulang.
  final String? initialBarcode;

  const _PurchaseFormSheet({
    required this.db,
    required this.suppliersFuture,
    required this.productsFuture,
    required this.onSaved,
    this.presetSupplierId,
    this.initialBarcode,
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
  final _searchFocus = FocusNode();
  String _q = '';
  String? _error;

  // Harga beli custom per produk (opsional): productId → TextEditingController.
  // Diisi via sheet "Atur Harga Beli" per produk; kosong = pakai harga produk.
  final Map<int, TextEditingController> _customPrices = {};
  // Proses simpan batch sedang berjalan (cegah double-tap).
  bool _saving = false;

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
    // Scan HID dari layar utama: pre-fill kolom cari lalu submit (setelah
    // daftar produk termuat, supaya byBarcode bisa resolve).
    final initBc = widget.initialBarcode;
    if (initBc != null && initBc.isNotEmpty) {
      widget.productsFuture.then((_) {
        if (!mounted) return;
        _searchC.text = initBc;
        _submitScanHid();
      });
    }
  }

  @override
  void dispose() {
    _noteC.dispose();
    _searchC.dispose();
    _searchFocus.dispose();
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
    for (final c in _customPrices.values) {
      c.dispose();
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

  // Harga beli efektif item produk: custom (sheet "Atur Harga Beli") jika
  // diisi, else harga beli produk saat ini.
  int _priceOf((Product, TextEditingController, TextEditingController) e) {
    final custom = _customPrices[e.$1.id];
    final customVal = custom != null ? (int.tryParse(custom.text) ?? 0) : 0;
    return customVal > 0 ? customVal : e.$1.buyPrice;
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
      return sum + qty * _priceOf(e);
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

  // Tap "+" → tambahkan ke keranjang (qty 1). Stepper "- qty +" TETAP tampil
  // selama qty > 0 (tidak pernah hide) — boleh banyak produk sekaligus.
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
    });
  }

  // Naik / turun qty item; qty 0 = hapus dari keranjang.
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
        final priceC = _customPrices.remove(p.id);
        priceC?.dispose();
      } else {
        qtyC.text = next.toString();
      }
    });
  }

  /// Buka sheet "Atur Harga Beli" per produk — harga beli terbaru (opsional).
  Future<void> _openPriceSheet(Product p) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existing = _customPrices[p.id];
    final ctrl = TextEditingController(
      text: existing != null ? existing.text : '${p.buyPrice}',
    );
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkDivider
                        : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                      Icons.payments_outlined,
                      size: 20,
                      color: NusaConfig.activePrimary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Harga Beli',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPri,
                          ),
                        ),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textTer),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, size: 20, color: textTer),
                  ),
                ],
              ),
              SizedBox(height: 16),
              NusaInput(
                'Harga beli terbaru (opsional)',
                controller: ctrl,
                type: TextInputType.number,
                hint: 'Kosongkan = pakai harga ${formatRupiah(p.buyPrice)}',
              ),
              SizedBox(height: 6),
              Text(
                'Harga ini dipakai untuk menghitung modal pembelian '
                '(stok masuk + HPP). Jika kosong, harga beli produk dipakai.',
                style: TextStyle(fontSize: 11, color: textTer),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  final val = int.tryParse(ctrl.text) ?? 0;
                  setState(() {
                    if (val > 0) {
                      _customPrices[p.id] = ctrl;
                    } else {
                      _customPrices.remove(p.id);
                      ctrl.dispose();
                    }
                  });
                  Navigator.pop(ctx);
                },
                icon: Icon(Icons.check, size: 18),
                label: Text(
                  'Simpan',
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
            ],
          ),
        ),
      ),
    );
  }

  void _clearCart() {
    for (final (_, qtyC, priceC) in _productItems) {
      qtyC.dispose();
      priceC.dispose();
    }
    for (final c in _customPrices.values) {
      c.dispose();
    }
    setState(() {
      _productItems.clear();
      _customPrices.clear();
    });
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
                      Icons.local_shipping_outlined,
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
              // JANGAN autofocus — keyboard tidak muncul otomatis saat
              // buka sheet (komplain user: "jangan auto munculin keyboard").
              // User ketuk kolom cari hanya jika memang ingin mencari.
              NusaSearchBar(
                hint: 'Cari nama supplier...',
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
                          final isSelected = _supplier?.id == s.id;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: NusaConfig.activePrimary
                                .withValues(alpha: 0.06),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected
                                  ? NusaConfig.activePrimary
                                  : NusaConfig.activePrimary.withValues(
                                      alpha: 0.1,
                                    ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : Text(
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
                                color: isSelected
                                    ? NusaConfig.activePrimary
                                    : null,
                              ),
                            ),
                            subtitle: s.phone != null && s.phone!.isNotEmpty
                                ? Text(
                                    s.phone!,
                                    style: TextStyle(fontSize: 12),
                                  )
                                : null,
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NusaConfig.activePrimary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Dipilih',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: NusaConfig.activePrimary,
                                      ),
                                    ),
                                  )
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
  /// Scanner barcode KAMERA — modal popup (UI asli, konsisten dengan
  /// products_screen): buka → scan SATU barcode → tutup → masuk keranjang.
  /// Scan kontinu hanya berlaku untuk scanner EKSTERNAL (HID/keyboard):
  /// ketik barcode di kolom cari + Enter, langsung masuk keranjang.
  ///
  /// Handler Enter dari scanner HID: resolve barcode → produk, langsung
  /// tambah keranjang, lalu kembalikan fokus ke kolom cari supaya bisa scan
  /// barcode yang SAMA berulang tanpa tap ulang (v2.2.29).
  Future<void> _submitScanHid() async {
    final raw = _searchC.text.trim();
    if (raw.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }
    final p = await ProductRepository(widget.db).byBarcode(raw);
    if (p != null) {
      _addProductToCart(p);
      _searchC.clear();
      setState(() => _q = '');
      TopToast.success(context, '${p.name} masuk keranjang');
    } else {
      _searchC.clear();
      setState(() => _q = '');
      TopToast.error(context, 'Produk tidak ditemukan');
    }
    // Fokus TETAP di kolom cari — scan berikutnya langsung jalan.
    _searchFocus.requestFocus();
  }
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
    // Kembalikan fokus ke kolom cari — scan EKSTERNAL lanjut beruntun
    // tanpa tap ulang (v2.2.29).
    _searchFocus.requestFocus();
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
        // HP (portrait): katalog penuh + bottom bar (keranjang + biaya/catatan
        // + tombol Tambah Stok batch).
        return Column(
          children: [
            _buildHeader(isDark),
            SizedBox(height: 12),
            Expanded(child: _buildCatalogPanel(isDark, wide: false)),
            SizedBox(height: 10),
            _buildPurchaseBottomBar(isDark),
          ],
        );
      },
    );
  }

  // ── Bottom bar (HP) — ringkasan keranjang + biaya/catatan + Tambah Stok ──
  // Menampilkan SEMUA item sekaligus (bukan 1 per 1) lalu submit batch.
  Widget _buildPurchaseBottomBar(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    final qty = _cartQty;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: qty > 0 ? _openCostsNoteSheet : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${qty} item',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textPri,
                        ),
                      ),
                      SizedBox(width: 6),
                      if (_extraTotal > 0 || _noteC.text.trim().isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Biaya & Catatan',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: NusaConfig.activePrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    qty > 0 ? formatRupiah(_total) : 'Belum ada item',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: qty > 0 ? NusaConfig.activePrimary : textTer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          // Tombol kecil buka Biaya & Catatan
          GestureDetector(
            onTap: qty > 0 ? _openCostsNoteSheet : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:
                    (isDark
                            ? NusaConfig.darkSurface
                            : NusaConfig.backgroundColor)
                        .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: NusaConfig.activePrimary,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Biaya &\nCatatan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          // Tombol besar: Tambah Stok (submit batch)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: (_saving || qty == 0) ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.add, size: 18),
              label: Text(
                _saving ? 'Menyimpan\u2026' : 'Tambah Stok',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
    );
  }

  // ── Sheet Biaya & Catatan (HP) — biaya tambahan + catatan pembelian ──
  // Dijadikan StatefulWidget (_CostsNoteSheet) supaya tombol '+' & X
  // merespons INSTAN — sebelumnya sheet pakai setState widget induk yang
  // rebuild berlebihan & tabrakan dengan keyboard (komplain user: "+" tidak
  // muncul, X tidak hilang sampai buka ulang). State biaya/catatan dipakai
  // bersama dengan _extraCosts & _noteC induk (copy saat buka, commit saat
  // Selesai/tutup) — jadi hasil tetap tersimpan seperti sebelumnya.
  Future<void> _openCostsNoteSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final costs = List<(TextEditingController, TextEditingController)>.generate(
      _extraCosts.length,
      (i) => (
        TextEditingController(text: _extraCosts[i].$1.text),
        TextEditingController(text: _extraCosts[i].$2.text),
      ),
    );
    final note = TextEditingController(text: _noteC.text);
    final result = await showModalBottomSheet<({List<(TextEditingController,
                TextEditingController)> costs, String note})?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CostsNoteSheet(
        isDark: isDark,
        initialCosts: costs,
        initialNote: note,
      ),
    );
    if (result != null) {
      // Commit hasil ke induk — dispose controller lama, pakai yang baru.
      for (final (n, a) in _extraCosts) {
        n.dispose();
        a.dispose();
      }
      _extraCosts
        ..clear()
        ..addAll(result.costs);
      _noteC.text = result.note;
      if (mounted) setState(() {});
    } else {
      // Dismiss — buang controller sementara.
      for (final (n, a) in costs) {
        n.dispose();
        a.dispose();
      }
      note.dispose();
    }
  }

  // ── Sheet Biaya & Catatan — StatefulWidget mandiri ──
  // State biaya/catatan dipegang di sini (bukan widget induk), jadi '+' & X
  // merespons instan tanpa rebuild induk. Hasil dikirim balik saat Selesai.
  Widget _buildHeader(bool isDark) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    return Row(
      children: [
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
              // Scan barcode EKSTERNAL (HID): ketik barcode + Enter →
              // langsung masuk keranjang, fokus TETAP di kolom cari supaya
              // bisa scan beruntun tanpa tap ulang (v2.2.29).
              child: NusaSearchBar(
                controller: _searchC,
                hint: 'Cari produk atau barcode...',
                onChanged: (v) => setState(() => _q = v),
                onSubmit: (_) => _submitScanHid(),
                showScanner: true,
                onScan: _scanBarcode,
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
                child: Icon(
                  // Selalu ikon supplier (truk) — bukan inisial supplier.
                  // Inisial bikin tombol terbaca "profil" padahal ini tombol
                  // Pilih Supplier (komplain user).
                  Icons.local_shipping_outlined,
                  color: NusaConfig.activePrimary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        // Status supplier yang DIPILIH — tampil jelas di bawah baris search
        // supaya user tahu sedang mencatat pembelian untuk supplier mana
        // (komplain user: "habis pilih ga muncul ket supplier mana yg dipilih").
        if (_supplier != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: NusaConfig.activePrimary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 16,
                  color: NusaConfig.activePrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supplier: ${_supplier!.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openSupplierPicker,
                  child: Text(
                    'Ganti',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NusaConfig.activePrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              inCart: idx >= 0,
              qtyField: idx >= 0 ? _qtyTextField(_productItems[idx].$2) : null,
              hasCustomPrice: _customPrices.containsKey(p.id),
              effectivePrice: idx >= 0 ? _priceOf(_productItems[idx]) : null,
              onToggleExpand: () => _toggleProductExpanded(p),
              onChangeQty: (delta) => _changeCartQty(p, delta),
              onEditPrice: () => _openPriceSheet(p),
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
        final inCart = idx >= 0;
        final customPrice = _customPrices.containsKey(p.id);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inCart
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
                  customPrice
                      ? 'Harga beli: ${formatRupiah(_priceOf(_productItems[idx]))}'
                      : 'Harga beli ${formatRupiah(p.buyPrice)} · stok ${p.stock}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: customPrice ? FontWeight.w700 : FontWeight.w400,
                    color: customPrice ? NusaConfig.activePrimary : textSec,
                  ),
                ),
                trailing: inCart
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              size: 17,
                              color: customPrice
                                  ? NusaConfig.activePrimary
                                  : textTer,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _openPriceSheet(p),
                            tooltip: 'Atur harga beli',
                          ),
                          _QtyBtn(
                            icon: Icons.remove,
                            onTap: () => _changeCartQty(p, -1),
                          ),
                          SizedBox(width: 6),
                          SizedBox(
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
                                fillColor: NusaConfig.activePrimary.withValues(
                                  alpha: 0.10,
                                ),
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
                          ),
                          SizedBox(width: 6),
                          _QtyBtn(
                            icon: Icons.add,
                            onTap: () => _changeCartQty(p, 1),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NusaAddButton(
                            onTap: () => _addProductToCart(p),
                            compact: true,
                          ),
                        ],
                      ),
              ),
              if (inCart)
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Subtotal: ${formatRupiah(qty * _priceOf(_productItems[idx]))}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textPri,
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

  // ── Panel keranjang (kanan) — item + biaya/catatan + Tambah Stok batch ──
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
                    itemBuilder: (_, i) => _buildCartPanelItem(isDark, i),
                  ),
          ),
          SizedBox(height: 8),
          // C5: Modul biaya tambahan (packing/ongkir/stiker)
          _buildExtraCosts(
            isDark,
            costs: _extraCosts,
            extraTotal: _extraTotal,
            onAdd: () => setState(
              () => _extraCosts.add((
                TextEditingController(),
                TextEditingController(),
              )),
            ),
            onRemove: (i) => setState(() {
              _extraCosts[i].$1.dispose();
              _extraCosts[i].$2.dispose();
              _extraCosts.removeAt(i);
            }),
            onChanged: () => setState(() {}),
          ),
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
          SizedBox(height: 10),
          // Tombol besar: Tambah Stok (submit batch semua item)
          ElevatedButton.icon(
            onPressed: (_saving || _productItems.isEmpty) ? null : _submit,
            icon: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.add, size: 18),
            label: Text(
              _saving
                  ? 'Menyimpan\u2026'
                  : 'Tambah Stok · ${_productItems.length} item',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: NusaConfig.activePrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Baris item di panel keranjang (lebar) — bersih: nama + qty + subtotal,
  // tanpa field harga beli (edit harga lewat ikon pensil di kartu katalog) ──
  Widget _buildCartPanelItem(bool isDark, int i) {
    final textPri = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    final (p, qtyC, priceC) = _productItems[i];
    final qty = int.tryParse(qtyC.text) ?? 0;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: Row(
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
                  '${formatRupiah(_priceOf(_productItems[i]))} × $qty',
                  style: TextStyle(fontSize: 11, color: textTer),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            formatRupiah(qty * _priceOf(_productItems[i])),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
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
                      Icons.local_shipping_outlined,
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

  // ── C5: Modul biaya tambahan (packing/ongkir/stiker) — delegasi ke
  // _ExtraCostsSection (top-level stateless). State (controller list)
  // dipegang PEMANGGIL — sheet & panel kanan punya instance sendiri.
  Widget _buildExtraCosts(
    bool isDark, {
    required List<(TextEditingController, TextEditingController)> costs,
    required int extraTotal,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
    required VoidCallback onChanged,
  }) {
    return _ExtraCostsSection(
      isDark: isDark,
      costs: costs,
      extraTotal: extraTotal,
      onAdd: onAdd,
      onRemove: onRemove,
      onChanged: onChanged,
    );
  }

  // ── item kartu keranjang (produk) ──
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
  final bool inCart;
  final bool hasCustomPrice;
  final int? effectivePrice; // harga beli efektif di keranjang (custom/aktual)
  final Widget? qtyField;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onChangeQty;
  final VoidCallback onEditPrice;
  const _PurchaseProductCard({
    required this.product,
    required this.isDark,
    required this.qtyInCart,
    required this.inCart,
    required this.hasCustomPrice,
    this.effectivePrice,
    this.qtyField,
    required this.onToggleExpand,
    required this.onChangeQty,
    required this.onEditPrice,
  });

  @override
  Widget build(BuildContext context) {
    final textTer = isDark
        ? NusaConfig.darkTextTertiary
        : NusaConfig.textTertiary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
      child: InkWell(
        onTap: inCart ? null : onToggleExpand,
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
              color: inCart
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
                style: TextStyle(fontSize: 11, color: textTer),
              ),
              SizedBox(height: 6),
              // Harga beli — warna aksen bila harga custom di-set
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatRupiah(effectivePrice ?? product.buyPrice),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: NusaConfig.activePrimary,
                      ),
                    ),
                  ),
                  if (inCart)
                    GestureDetector(
                      onTap: onEditPrice,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: hasCustomPrice
                              ? NusaConfig.activePrimary
                              : textTer,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'stok ${product.stock}',
                style: TextStyle(fontSize: 11, color: textTer),
              ),
              SizedBox(height: 8),
              // Area aksi: stepper "- qty +" TETAP tampil selama di keranjang;
              // belum masuk keranjang → pill "+" (tambah ke keranjang).
              if (inCart)
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
                    NusaAddButton(
                      onTap: onToggleExpand,
                      compact: true,
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

// ── Tombol qty bulat 30×30 (stepper - qty +) — onTap null = nonaktif ──

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, this.onTap});

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
