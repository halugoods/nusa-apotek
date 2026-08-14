import 'dart:convert';
import 'dart:io';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/activation/activation_key.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/image_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/product_discount.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/category_repository.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/animated_scanner_overlay.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Variant data model (stored as JSON in variantsJson)
class _ProductVariant {
  String name;
  int priceAdjustment;
  int stock;
  _ProductVariant({this.name = '', this.priceAdjustment = 0, this.stock = 0});

  Map<String, dynamic> toJson() => {
    'name': name,
    'priceAdjustment': priceAdjustment,
    'stock': stock,
  };
  factory _ProductVariant.fromJson(Map<String, dynamic> j) => _ProductVariant(
    name: j['name'] ?? '',
    priceAdjustment: j['priceAdjustment'] ?? 0,
    stock: j['stock'] ?? 0,
  );
}

/// Wholesale tier data model (stored as JSON in wholesaleJson)
class _WholesaleTier {
  int minQty;
  int price;
  _WholesaleTier({this.minQty = 1, this.price = 0});

  Map<String, dynamic> toJson() => {'minQty': minQty, 'price': price};
  factory _WholesaleTier.fromJson(Map<String, dynamic> j) =>
      _WholesaleTier(minQty: j['minQty'] ?? 1, price: j['price'] ?? 0);
}

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;

  /// Supplier yang sudah dipilih (dari Catat Pembelian) — toggle supplier
  /// langsung ON + terisi. Bisa lewat constructor atau query param.
  final int? supplierId;
  final String? supplierName;
  ProductFormScreen({
    this.productId,
    this.supplierId,
    this.supplierName,
    super.key,
  });
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  final _discount = TextEditingController();
  final _stock = TextEditingController();
  final _min = TextEditingController();
  String _category = '';
  List<String> _availableCategories = [];
  late String _barcode;
  Product? _existing;
  bool _loading = true;
  bool _saving = false;
  bool _barcodeOn = false;
  final _barcodeCtrl = TextEditingController();
  bool _isOnline = false;
  String? _imagePath;
  DateTime? _expiryDate;
  // Diskon: 'persen' | 'nominal' (Rp)
  String _discountType = ProductDiscountX.typePersen;

  // Supplier langganan produk (C4): toggle + dropdown supplier.
  bool _hasSupplier = false;
  Supplier? _supplier;
  List<Supplier> _suppliers = [];
  bool _suppliersLoading = true;

  // Toggle-based product type
  bool _hasVarian = false;
  bool _hasGrosir = false;

  // Dynamic lists
  List<_ProductVariant> _variants = [];
  List<_WholesaleTier> _wholesaleTiers = [];

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _barcode = ActivationKey.generateSerial();
    _barcodeCtrl.text = _barcode;
    _init();
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _buy.dispose();
    _sell.dispose();
    _stock.dispose();
    _min.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final repo = CategoryRepository(ref.read(databaseProvider));
    final cats = await repo.getAll();
    if (mounted) {
      setState(() {
        _availableCategories = cats;
        if (_category.isEmpty && cats.isNotEmpty)
          _category = cats.first;
        else if (!cats.contains(_category) && cats.isNotEmpty)
          _category = cats.first;
      });
    }
  }

  Future<void> _loadSuppliers() async {
    final list = await SupplierRepository(
      ref.read(databaseProvider),
    ).getSuppliers();
    if (mounted)
      setState(() {
        _suppliers = list;
        _suppliersLoading = false;
      });
  }

  Future<void> _init() async {
    await _loadCategories();
    await _loadSuppliers();
    // C6: dibuka dari Catat Pembelian → toggle supplier ON + terisi
    // (via query param /produk/tambah?supplierId=..&supplierName=..).
    var fromSupplierId = widget.supplierId;
    var fromSupplierName = widget.supplierName;
    if (fromSupplierId == null) {
      try {
        final uri = GoRouterState.of(context).uri;
        final sid = int.tryParse(uri.queryParameters['supplierId'] ?? '');
        if (sid != null && sid > 0) {
          fromSupplierId = sid;
          fromSupplierName = uri.queryParameters['supplierName'];
        }
      } catch (_) {}
    }
    if (fromSupplierId != null && !_isEdit) {
      _hasSupplier = true;
      final match = _suppliers.where((s) => s.id == fromSupplierId).firstOrNull;
      if (match != null) {
        _supplier = match;
      } else if (fromSupplierName != null && fromSupplierName.isNotEmpty) {
        // Supplier mungkin belum tersimpan — tampilkan nama saja.
        _supplier = Supplier(
          id: fromSupplierId,
          name: fromSupplierName,
          phone: null,
          address: null,
          contactPerson: null,
          note: null,
          createdAt: DateTime.now(),
        );
      }
    }
    if (!_isEdit) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final repo = ProductRepository(ref.read(databaseProvider));
    final p = await repo.byId(widget.productId!);
    if (p != null && mounted) {
      _existing = p;
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _buy.text = p.buyPrice > 0 ? p.buyPrice.toString() : '';
      _sell.text = p.sellPrice.toString();
      _discount.text = p.discountPercent > 0
          ? p.discountPercent.toString()
          : '';
      _discountType = (p.discountType == ProductDiscountX.typeNominal)
          ? ProductDiscountX.typeNominal
          : ProductDiscountX.typePersen;
      _stock.text = p.stock.toString();
      _min.text = p.minStock > 0 ? p.minStock.toString() : '';
      _category = _availableCategories.contains(p.category)
          ? p.category
          : (_availableCategories.isNotEmpty ? _availableCategories.first : '');
      _imagePath = p.imagePath;
      _isOnline = p.isOnline;
      _expiryDate = p.expiryDate;
      // Supplier tersimpan pada produk (edit mode).
      if (p.supplierId != null) {
        _hasSupplier = true;
        final match = _suppliers.where((s) => s.id == p.supplierId).firstOrNull;
        if (match != null) _supplier = match;
      }

      // Load variants
      if (p.variantsJson != null && p.variantsJson!.isNotEmpty) {
        try {
          final list = jsonDecode(p.variantsJson!) as List;
          _variants = list
              .map((e) => _ProductVariant.fromJson(e as Map<String, dynamic>))
              .toList();
          _hasVarian = _variants.isNotEmpty;
        } catch (_) {}
      }
      // Load wholesale tiers
      if (p.wholesaleJson != null && p.wholesaleJson!.isNotEmpty) {
        try {
          final list = jsonDecode(p.wholesaleJson!) as List;
          _wholesaleTiers = list
              .map((e) => _WholesaleTier.fromJson(e as Map<String, dynamic>))
              .toList();
          _hasGrosir = _wholesaleTiers.isNotEmpty;
        } catch (_) {}
      }

      if (p.barcode != null && p.barcode!.isNotEmpty) {
        _barcodeOn = true;
        _barcode = p.barcode!;
        _barcodeCtrl.text = p.barcode!;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  int? _toInt(String v) {
    if (v.trim().isEmpty) return null;
    return int.tryParse(v.trim());
  }

  void _toggleBarcode(bool v) {
    setState(() {
      _barcodeOn = v;
      if (v && _existing?.barcode != null && _existing!.barcode!.isNotEmpty) {
        _barcode = _existing!.barcode!;
        _barcodeCtrl.text = _barcode;
      } else if (v && _barcodeCtrl.text.trim().isEmpty) {
        _barcode = ActivationKey.generateSerial();
        _barcodeCtrl.text = _barcode;
      }
    });
  }

  /// Scan barcode from camera (no manual input here — manual lives in the
  /// barcode TextField in the form itself).
  Future<void> _scanBarcodeFromCamera() async {
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
    String? scanned;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 22,
              color: NusaConfig.activePrimary,
            ),
            SizedBox(width: 8),
            Text('Scan Barcode'),
          ],
        ),
        content: AnimatedScannerOverlay(
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
              debugPrint('[ProductForm] scanner error: $error');
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
                      Icon(
                        Icons.no_photography_outlined,
                        size: 36,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Kamera tidak tersedia.\nKetuk Batal lalu ketik kode barcode manual.',
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
        ],
      ),
    );
    await controller.dispose();
    if (scanned == null || !mounted) return;
    setState(() {
      _barcodeOn = true;
      _barcode = scanned!;
      _barcodeCtrl.text = scanned!;
    });
  }

  Future<void> _pickImage() async {
    // Downscale via ImagePicker (maxWidth) instead of file_picker withData:
    // avoids OOM on low-RAM devices (Samsung A14 50MP photos crash the app).
    final path = await pickAndSaveImage(maxSize: 1024, prefix: 'product_');
    if (path == null) return;
    setState(() => _imagePath = path);
    TopToast.success(context, 'Gambar ditambahkan');
  }

  void _uploadToCloud(String localPath) {
    // Skip per-image upload — full DB backup via uploadBackupNow()
    // already includes all product images in the encrypted archive.
    // Supabase Auth user is always null because the app uses
    // GoogleSignIn plugin, not Supabase Auth.
  }

  String? _serializeVariants() {
    if (!_hasVarian || _variants.isEmpty) return null;
    return jsonEncode(_variants.map((v) => v.toJson()).toList());
  }

  String? _serializeWholesale() {
    if (!_hasGrosir || _wholesaleTiers.isEmpty) return null;
    return jsonEncode(_wholesaleTiers.map((w) => w.toJson()).toList());
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final sell = _toInt(_sell.text);
    if (name.isEmpty) {
      TopToast.error(context, 'Nama produk wajib diisi');
      return;
    }
    if (sell == null) {
      TopToast.error(context, 'Harga jual wajib diisi');
      return;
    }
    if (_category.isEmpty) {
      TopToast.error(context, 'Pilih atau buat kategori dulu');
      return;
    }

    final db = ref.read(databaseProvider);
    final buy = _toInt(_buy.text) ?? 0;
    final stock = _toInt(_stock.text) ?? 0;
    final min = _toInt(_min.text) ?? 0;
    final isNominal = _discountType == ProductDiscountX.typeNominal;
    // Nominal: berapa pun ≤ harga jual; Persen: clamp 0–100.
    final rawDiscount = _toInt(_discount.text) ?? 0;
    final discount = isNominal
        ? rawDiscount.clamp(0, sell)
        : rawDiscount.clamp(0, 100);
    final sku = _sku.text.trim().isEmpty ? null : _sku.text.trim();
    final variants = _serializeVariants();
    final wholesale = _serializeWholesale();
    final pType = _hasVarian ? 'Varian' : (_hasGrosir ? 'Grosir' : 'Regular');

    setState(() => _saving = true);
    try {
      final supplierVal = _hasSupplier && _supplier != null
          ? Value<int?>(_supplier!.id)
          : const Value<int?>(null);
      int? createdId;
      if (_isEdit) {
        await (db.update(
          db.products,
        )..where((t) => t.id.equals(widget.productId!))).write(
          ProductsCompanion(
            name: Value(name),
            category: Value(_category),
            buyPrice: Value(buy),
            sellPrice: Value(sell),
            minStock: Value(min),
            sku: Value(sku),
            stock: Value(stock),
            barcode: Value(_barcodeOn ? _barcodeCtrl.text.trim() : null),
            imagePath: Value(_imagePath),
            isOnline: Value(_isOnline),
            expiryDate: Value(_expiryDate),
            productType: Value(pType == 'Regular' ? null : pType),
            variantsJson: Value(variants),
            wholesaleJson: Value(wholesale),
            discountPercent: Value(discount),
            discountType: Value(
              isNominal
                  ? ProductDiscountX.typeNominal
                  : ProductDiscountX.typePersen,
            ),
            supplierId: supplierVal,
          ),
        );
      } else {
        createdId = await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                name: name,
                sellPrice: sell,
                category: Value(_category),
                buyPrice: Value(buy),
                stock: Value(stock),
                minStock: Value(min),
                sku: Value(sku),
                imagePath: Value(_imagePath),
                barcode: Value(_barcodeOn ? _barcodeCtrl.text.trim() : null),
                isOnline: Value(_isOnline),
                expiryDate: Value(_expiryDate),
                productType: Value(pType == 'Regular' ? null : pType),
                variantsJson: Value(variants),
                wholesaleJson: Value(wholesale),
                discountPercent: Value(discount),
                discountType: Value(
                  isNominal
                      ? ProductDiscountX.typeNominal
                      : ProductDiscountX.typePersen,
                ),
                supplierId: supplierVal,
              ),
            );
      }
      // Upload image to cloud in background
      if (_imagePath != null) _uploadToCloud(_imagePath!);
      if (mounted) {
        TopToast.success(
          context,
          _isEdit ? 'Produk diperbarui' : 'Produk disimpan',
        );
        // C3: balik ke Catat Pembelian dengan id produk baru (untuk masuk keranjang).
        context.pop(createdId);
      }
    } catch (e) {
      debugPrint('[ProductForm] save error: $e');
      if (mounted) {
        setState(() => _saving = false);
        TopToast.error(context, 'Gagal menyimpan produk. Coba lagi.');
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Kategori Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Nama kategori',
            hintStyle: TextStyle(
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: NusaConfig.activePrimary,
              foregroundColor: Colors.white,
            ),
            child: Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final catRepo = CategoryRepository(ref.read(databaseProvider));
      await catRepo.add(result);
      await _loadCategories();
      setState(() => _category = result);
      TopToast.success(context, 'Kategori "$result" disimpan');
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      _isEdit ? 'Edit Produk' : 'Tambah Produk',
      _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(NusaConfig.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Product image ──
                  _buildImagePicker(isDark),
                  SizedBox(height: NusaConfig.spaceMD),

                  // ── 2. Nama Produk ──
                  NusaFormField(label: 'Nama Produk', controller: _name),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── 3. SKU (opsional) ──
                  NusaFormField(label: 'SKU (opsional)', controller: _sku),
                  SizedBox(height: NusaConfig.spaceMD),

                  // ── 4. Kategori ──
                  _buildCategorySection(isDark),
                  SizedBox(height: NusaConfig.spaceMD),

                  // ── 5. Harga Beli (opsional) ──
                  NusaFormField(
                    label: 'Harga Beli (opsional)',
                    controller: _buy,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── 5. Harga Jual ──
                  NusaFormField(
                    label: 'Harga Jual',
                    controller: _sell,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── 5b. Diskon Standalone (opsional) — % atau nominal Rp ──
                  _buildDiscountField(isDark),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── 6. Stok ──
                  NusaFormField(
                    label: 'Stok',
                    controller: _stock,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── 7. Kadaluarsa (opsional) ──
                  _buildExpiryPicker(isDark),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── 8. Stok Minimum (opsional) ──
                  NusaFormField(
                    label: 'Stok Minimum (opsional)',
                    controller: _min,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: NusaConfig.spaceMD),

                  // ── Divider ──
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark
                              ? NusaConfig.darkDivider
                              : NusaConfig.dividerColor,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Opsi Lanjutan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark
                              ? NusaConfig.darkDivider
                              : NusaConfig.dividerColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: NusaConfig.spaceMD),

                  // ── Toggle: Varian ──
                  _buildToggleCard(
                    title: 'Varian (Rasa/Ukuran)',
                    icon: Icons.layers_outlined,
                    value: _hasVarian,
                    onChanged: (v) => setState(() {
                      _hasVarian = v;
                      if (!v) _variants.clear();
                    }),
                    expandedChild: _hasVarian
                        ? _buildVariantList(isDark)
                        : null,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── Toggle: Grosir ──
                  _buildToggleCard(
                    title: 'Harga Grosir',
                    icon: Icons.inventory_2_outlined,
                    value: _hasGrosir,
                    onChanged: (v) => setState(() {
                      _hasGrosir = v;
                      if (!v) _wholesaleTiers.clear();
                    }),
                    expandedChild: _hasGrosir
                        ? _buildWholesaleList(isDark)
                        : null,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── Toggle: Barcode ──
                  _buildToggleCard(
                    title: 'Barcode',
                    icon: Icons.qr_code_2,
                    value: _barcodeOn,
                    onChanged: _toggleBarcode,
                    expandedChild: _barcodeOn
                        ? Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? NusaConfig.darkSurface2
                                  : Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Scan kamera + input manual (barcode form pindah ke sini)
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _barcodeCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          color: isDark
                                              ? NusaConfig.darkTextPrimary
                                              : NusaConfig.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Kode barcode',
                                          hintText: 'contoh: 8991002101234',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      tooltip: 'Scan kamera',
                                      onPressed: _scanBarcodeFromCamera,
                                      icon: Icon(
                                        Icons.qr_code_scanner,
                                        size: 20,
                                        color: NusaConfig.activePrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                if (_barcodeCtrl.text.trim().isNotEmpty) ...[
                                  BarcodeWidget(
                                    data: _barcodeCtrl.text.trim(),
                                    barcode: Barcode.code128(),
                                    width: double.infinity,
                                    height: 60,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _barcodeCtrl.text.trim(),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: isDark
                                          ? NusaConfig.darkTextSecondary
                                          : NusaConfig.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── Toggle: Toko Online ──
                  _buildToggleCard(
                    title: 'Tampil di Toko Online',
                    icon: Icons.storefront_outlined,
                    value: _isOnline,
                    onChanged: (v) => setState(() => _isOnline = v),
                    expandedChild: _isOnline
                        ? Container(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? NusaConfig.darkSurface2
                                  : Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Produk akan muncul di website toko online Anda.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? NusaConfig.darkTextSecondary
                                    : NusaConfig.textSecondary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: NusaConfig.spaceSM),

                  // ── Toggle: Supplier langganan (C4) ──
                  _buildToggleCard(
                    title: 'Supplier (opsional)',
                    icon: Icons.local_shipping_outlined,
                    value: _hasSupplier,
                    onChanged: (v) => setState(() {
                      _hasSupplier = v;
                      if (v && _supplier == null && _suppliers.isNotEmpty)
                        _supplier = _suppliers.first;
                    }),
                    expandedChild: _hasSupplier
                        ? Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? NusaConfig.darkSurface2
                                  : Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_suppliersLoading)
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      'Memuat supplier…',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? NusaConfig.darkTextSecondary
                                            : NusaConfig.textSecondary,
                                      ),
                                    ),
                                  )
                                else if (_suppliers.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      'Belum ada supplier. Tambah lewat menu Supplier.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? NusaConfig.darkTextSecondary
                                            : NusaConfig.textSecondary,
                                      ),
                                    ),
                                  )
                                else ...[
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<Supplier>(
                                      isExpanded: true,
                                      value: _supplier,
                                      hint: Text(
                                        'Pilih supplier',
                                        style: TextStyle(
                                          fontSize: 13,
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
                                        color: isDark
                                            ? NusaConfig.darkTextPrimary
                                            : NusaConfig.textPrimary,
                                      ),
                                      items: _suppliers
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _supplier = v),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Produk ini dipasok dari supplier tersebut. HPP tetap dari harga beli.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? NusaConfig.darkTextTertiary
                                          : NusaConfig.textTertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: NusaConfig.spaceMD),

                  // ── Divider ──
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark
                              ? NusaConfig.darkDivider
                              : NusaConfig.dividerColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: NusaConfig.spaceLG),

                  // ── Save button ──
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NusaConfig.activePrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: NusaConfig.activePrimary
                            .withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _saving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Menyimpan…'),
                              ],
                            )
                          : Text('Simpan Produk'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Discount field (% atau nominal Rp) ──
  Widget _buildDiscountField(bool isDark) {
    final isNominal = _discountType == ProductDiscountX.typeNominal;
    final sell = _toInt(_sell.text) ?? 0;
    final d = _toInt(_discount.text) ?? 0;
    final preview = d > 0 && sell > 0
        ? formatRupiah(
            isNominal
                ? (sell - d).clamp(0, sell)
                : (sell - (sell * d / 100).round()).clamp(0, sell),
          )
        : null;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Diskon Produk (opsional)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Toggle % / Rp
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkSurface2
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _discountSegBtn('Persen (%)', false, isDark),
                    SizedBox(width: 3),
                    _discountSegBtn('Nominal (Rp)', true, isDark),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          TextField(
            controller: _discount,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? NusaConfig.darkTextPrimary
                  : NusaConfig.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: isNominal
                  ? 'Contoh: 10000 → potong Rp 10.000'
                  : 'Contoh: 10 → potong 10%',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary,
              ),
              isDense: true,
              prefixText: isNominal ? 'Rp ' : '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (preview != null) ...[
            SizedBox(height: 8),
            Text(
              'Harga setelah diskon: ${preview}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _discountSegBtn(String label, bool isNominal, bool isDark) {
    final selected =
        _discountType ==
        (isNominal
            ? ProductDiscountX.typeNominal
            : ProductDiscountX.typePersen);
    return GestureDetector(
      onTap: () => setState(
        () => _discountType = isNominal
            ? ProductDiscountX.typeNominal
            : ProductDiscountX.typePersen,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? NusaConfig.activePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary),
          ),
        ),
      ),
    );
  }

  // ── Image picker ──
  Widget _buildImagePicker(bool isDark) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
          border: Border.all(
            color: isDark ? NusaConfig.darkInputBorder : Color(0xFFD1D5DB),
            width: 2,
          ),
        ),
        child: _imagePath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Ganti Foto',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'TAP UNTUK UPLOAD FOTO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'atau drag & drop',
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
    );
  }

  // ── Expiry date picker ──
  Widget _buildExpiryPicker(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _expiryDate ?? now,
          firstDate: now,
          lastDate: DateTime(now.year + 10),
          helpText: 'Pilih Tanggal Kadaluarsa',
        );
        if (picked != null) setState(() => _expiryDate = picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kadaluarsa (opsional)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    _expiryDate != null
                        ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                        : 'Pilih tanggal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _expiryDate != null
                          ? isDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary
                          : isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (_expiryDate != null)
              GestureDetector(
                onTap: () => setState(() => _expiryDate = null),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
              ),
            SizedBox(width: 4),
            Icon(
              Icons.calendar_today,
              size: 18,
              color: isDark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ── Category section at bottom with CRUD ──
  Widget _buildCategorySection(bool isDark) {
    final items = <DropdownMenuItem<String>>[
      for (final cat in _availableCategories)
        DropdownMenuItem(
          value: cat,
          child: Text(
            cat,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      DropdownMenuItem<String>(
        value: '__divider__',
        enabled: false,
        child: Divider(height: 1, thickness: 1),
      ),
      DropdownMenuItem<String>(
        value: '__add__',
        child: Text(
          'Tambah Kategori',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: NusaConfig.activePrimary,
          ),
        ),
      ),
      DropdownMenuItem<String>(
        value: '__manage__',
        child: Text(
          'Kelola Kategori',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
        ),
      ),
    ];
    return NusaDropdownField<String>(
      label: 'Kategori',
      value: _category.isNotEmpty ? _category : null,
      items: items,
      onChanged: (val) {
        if (val == null) return;
        if (val == '__add__') {
          _showAddCategoryDialog();
        } else if (val == '__manage__') {
          _showManageCategorySheet();
        } else {
          setState(() => _category = val);
        }
      },
    );
  }

  // ── Category management (reachable from the dropdown) ──
  Future<void> _showManageCategorySheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cats = List<String>.from(_availableCategories);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 8,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NusaConfig.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Kelola Kategori',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              ...cats.map(
                (cat) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? NusaConfig.darkSurface2
                          : NusaConfig.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : NusaConfig.dividerColor,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : NusaConfig.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _renameCategory(ctx, setSt, cats, cat),
                          child: Text('Ubah'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _confirmDeleteCategory(ctx, setSt, cats, cat),
                          child: Text(
                            'Hapus',
                            style: TextStyle(color: NusaConfig.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showAddCategoryDialog();
                  },
                  icon: Icon(Icons.add),
                  label: Text('Tambah Kategori'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NusaConfig.activePrimary,
                    side: BorderSide(color: NusaConfig.activePrimary),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _loadCategories();
    if (mounted) setState(() {});
  }

  Future<void> _renameCategory(
    BuildContext ctx,
    StateSetter setSt,
    List<String> cats,
    String oldName,
  ) async {
    final ctrl = TextEditingController(text: oldName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newName = await showDialog<String>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text('Ubah Nama Kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintStyle: TextStyle(
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: NusaConfig.activePrimary,
              foregroundColor: Colors.white,
            ),
            child: Text('Simpan'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final catRepo = CategoryRepository(ref.read(databaseProvider));
      await catRepo.rename(oldName, newName);
      setSt(() {
        final i = cats.indexOf(oldName);
        if (i >= 0) cats[i] = newName;
      });
      if (_category == oldName) setState(() => _category = newName);
    }
  }

  Future<void> _confirmDeleteCategory(
    BuildContext ctx,
    StateSetter setSt,
    List<String> cats,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text('Hapus Kategori'),
        content: Text(
          'Hapus kategori "$name"? Produk dengan kategori ini akan dipindah ke "Lainnya".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: NusaConfig.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final catRepo = CategoryRepository(ref.read(databaseProvider));
      final db = ref.read(databaseProvider);
      await catRepo.delete(name);
      await (db.update(db.products)..where((t) => t.category.equals(name)))
          .write(ProductsCompanion(category: Value('Lainnya')));
      setSt(() => cats.remove(name));
      if (_category == name)
        setState(() => _category = cats.isNotEmpty ? cats.first : '');
    }
  }

  // ── Toggle card with visual depth ──
  Widget _buildToggleCard({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? expandedChild,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  ),
                ),
                Text(
                  value ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value
                        ? NusaConfig.accentGreen
                        : isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  width: 44,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: NusaConfig.activePrimary,
                  ),
                ),
              ],
            ),
          ),
          // Expanded child with depth
          if (value && expandedChild != null) ...[
            Container(
              height: 1,
              color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
            ),
            expandedChild,
          ],
        ],
      ),
    );
  }

  // ── Variant list ──
  Widget _buildVariantList(bool isDark) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._variants.asMap().entries.map((e) {
            final i = e.key;
            final v = e.value;
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Text(
                        'Varian ${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _variants.removeAt(i)),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: NusaConfig.errorSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Hapus',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: NusaConfig.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Nama Varian — card sendiri
                  _variantFieldCard(
                    isDark,
                    label: 'Nama Varian',
                    controller: TextEditingController(text: v.name),
                    onChanged: (val) => _variants[i].name = val,
                  ),
                  SizedBox(height: 8),
                  // Â± Harga — card sendiri
                  _variantFieldCard(
                    isDark,
                    label: 'Â± Harga',
                    controller: TextEditingController(
                      text: v.priceAdjustment == 0
                          ? ''
                          : v.priceAdjustment.toString(),
                    ),
                    onChanged: (val) =>
                        _variants[i].priceAdjustment = int.tryParse(val) ?? 0,
                    keyboardType: TextInputType.number,
                    prefixText: '+/- ',
                  ),
                  SizedBox(height: 8),
                  // Stok — card sendiri
                  _variantFieldCard(
                    isDark,
                    label: 'Stok',
                    controller: TextEditingController(
                      text: v.stock == 0 ? '' : v.stock.toString(),
                    ),
                    onChanged: (val) =>
                        _variants[i].stock = int.tryParse(val) ?? 0,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _variants.add(_ProductVariant())),
            icon: Icon(Icons.add, size: 18),
            label: Text('Tambah Varian'),
            style: TextButton.styleFrom(
              foregroundColor: NusaConfig.activePrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Per-field card for variant / wholesale ──
  Widget _variantFieldCard(
    bool isDark, {
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    String? prefixText,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
          isDense: true,
          border: InputBorder.none,
          prefixText: prefixText,
        ),
      ),
    );
  }

  // ── Wholesale list ──
  Widget _buildWholesaleList(bool isDark) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._wholesaleTiers.asMap().entries.map((e) {
            final i = e.key;
            final w = e.value;
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Text(
                        'Tingkat ${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _wholesaleTiers.removeAt(i)),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: NusaConfig.errorSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Hapus',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: NusaConfig.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Min Qty — card sendiri
                  _variantFieldCard(
                    isDark,
                    label: 'Min Qty',
                    controller: TextEditingController(
                      text: w.minQty == 1 ? '' : w.minQty.toString(),
                    ),
                    onChanged: (val) =>
                        _wholesaleTiers[i].minQty = int.tryParse(val) ?? 1,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 8),
                  // Harga Grosir — card sendiri
                  _variantFieldCard(
                    isDark,
                    label: 'Harga Grosir',
                    controller: TextEditingController(
                      text: w.price == 0 ? '' : w.price.toString(),
                    ),
                    onChanged: (val) =>
                        _wholesaleTiers[i].price = int.tryParse(val) ?? 0,
                    keyboardType: TextInputType.number,
                    prefixText: 'Rp ',
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () =>
                setState(() => _wholesaleTiers.add(_WholesaleTier())),
            icon: Icon(Icons.add, size: 18),
            label: Text('Tambah Harga Grosir'),
            style: TextButton.styleFrom(
              foregroundColor: NusaConfig.activePrimary,
            ),
          ),
        ],
      ),
    );
  }
}
