import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/cashier_session_repository.dart';
import 'package:nusa_kasir/data/repositories/category_repository.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/features/pos/cart.dart';
import "package:nusa_kasir/shared/widgets/top_toast.dart";
import 'package:nusa_kasir/shared/widgets/nusa_cart_controls.dart';

class PosScreen extends ConsumerStatefulWidget {
  final int? sessionId;
  PosScreen({super.key, this.sessionId});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _category = 'Semua';
  String _cashierName = '';
  bool _searching = false;
  bool _cartExpanded = false;
  final _memberPhone = TextEditingController();
  final _promoCode = TextEditingController();
  String? _memberName;
  int _memberPoints = 0;
  String _paymentMethod = 'Tunai';
  bool _checkingMember = false;
  int _gridColumns = 2;

  List<Product>? _allProducts;
  bool _productsLoading = true;
  List<String> _allCats = []; // dynamically loaded from CategoryRepository

  List<String> get _chips => ['Semua', ..._allCats];

  @override
  void initState() {
    super.initState();
    _loadCashier();
    _preloadProducts();
    _loadGridColumns();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searching = _searchFocus.hasFocus);
    });
  }

  Future<void> _loadGridColumns() async {
    final repo = ref.read(settingsRepoProvider);
    final cols = await repo.getPosGridColumns();
    if (mounted) setState(() => _gridColumns = cols.clamp(1, 3));
  }

  void _setGridColumns(int cols) {
    setState(() => _gridColumns = cols);
    ref.read(settingsRepoProvider).setPosGridColumns(cols);
  }

  Future<void> _preloadProducts() async {
    final repo = ProductRepository(ref.read(databaseProvider));
    final all = await repo.getProducts();
    // Also load real categories for the filter chips.
    final catRepo = CategoryRepository(ref.read(databaseProvider));
    final cats = await catRepo.getAll();
    if (mounted) setState(() { _allProducts = all; _allCats = cats; _productsLoading = false; });
  }

  @override
  void dispose() {
    _search.dispose(); _searchFocus.dispose();
    _memberPhone.dispose(); _promoCode.dispose();
    super.dispose();
  }

  Future<void> _loadCashier() async {
    if (widget.sessionId == null) return;
    final repo = CashierSessionRepository(ref.read(databaseProvider));
    final session = await repo.getLast();
    if (session != null && mounted) {
      final emps = await (ref.read(databaseProvider).select(
              ref.read(databaseProvider).employees)
            ..where((t) => t.id.equals(session.employeeId)))
          .get();
      if (emps.isNotEmpty) setState(() => _cashierName = emps.first.name);
    }
  }

  List<Product> _filteredProducts() {
    final all = _allProducts ?? [];
    final q = _search.text.toLowerCase();
    return all.where((p) {
      if (_category != 'Semua' && p.category != _category) return false;
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  Future<void> _scanBarcode(BuildContext context) async {
    String? scannedCode;
    final controller = MobileScannerController();
    if (!mounted) return;

    // Full-screen route — avoids dialog+camera crash on Xiaomi/Redmi/Oppo
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('Pindai Barcode'),
            leading: IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.pop(_),
            ),
          ),
          body: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (scannedCode != null) return;
              final barcode = capture.barcodes.firstOrNull;
              final raw = barcode?.rawValue;
              if (raw == null || raw.isEmpty) return;
              scannedCode = raw;
              Navigator.pop(_, raw);
            },
          ),
        ),
      ),
    );
    await controller.dispose();
    if (code == null || !context.mounted) return;

    final product = await ProductRepository(ref.read(databaseProvider)).byBarcode(code);
    if (product != null) {
      ref.read(cartProvider.notifier).addProduct(product.id, product.name, product.sellPrice);
      TopToast.success(context, '${product.name} ditambahkan');
    } else if (context.mounted) {
      TopToast.error(context, 'Produk tidak ditemukan');
    }
  }

  Future<void> _closeKasir() async {
    if (widget.sessionId == null) { if (mounted) context.go('/home'); return; }
    final repo = CashierSessionRepository(ref.read(databaseProvider));
    await repo.close(widget.sessionId!);
    if (mounted) { context.go('/home'); TopToast.success(context, 'Kasir ditutup. Sampai jumpa! 👋'); }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalItems = cart.fold(0, (s, e) => s + e.qty);
    final totalPrice = cart.fold(0, (s, e) => s + e.subtotal);
    final isWide = MediaQuery.of(context).size.width > 720;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeKasir();
      },
      child: Scaffold(
        backgroundColor: isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor,
        body: SafeArea(
          child: isWide
              ? _buildWideLayout(isDark, cart, totalItems, totalPrice)
              : _buildNarrowLayout(isDark, cart, totalItems, totalPrice),
        ),
      ),
    );
  }

  // =========== NARROW LAYOUT (phone) ===========

  Widget _buildNarrowLayout(bool isDark, List<CartItem> cart, int totalItems, int totalPrice) {
    return Stack(children: [
      Column(children: [
        _buildTopBar(isDark),
        Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: _buildSearchBar(isDark)),
        _buildCategoryChips(isDark),
        Expanded(child: _buildProductGrid(isDark)),
        if (!_cartExpanded) _buildCartBar(isDark, totalItems, totalPrice),
      ]),
      if (_cartExpanded) _buildCartPanel(isDark, cart, totalItems, totalPrice, isSheet: true),
    ]);
  }

  // =========== WIDE LAYOUT (tablet) ===========

  Widget _buildWideLayout(bool isDark, List<CartItem> cart, int totalItems, int totalPrice) {
    return Column(children: [
      _buildTopBar(isDark),
      Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: _buildSearchBar(isDark)),
      _buildCategoryChips(isDark),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _buildProductGrid(isDark)),
          SizedBox(width: 380, child: _buildCartPanel(isDark, cart, totalItems, totalPrice, isSheet: false)),
        ]),
      ),
    ]);
  }

  // =========== COMPONENTS ===========

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Text('Kasir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
        SizedBox(width: 12),
        _gridToggle(1, Icons.view_agenda_rounded, isDark),
        SizedBox(width: 4),
        _gridToggle(2, Icons.grid_view_rounded, isDark),
        SizedBox(width: 4),
        _gridToggle(3, Icons.apps_rounded, isDark),
        Spacer(),
        if (_cashierName.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: NusaConfig.activeSoft, borderRadius: BorderRadius.circular(NusaConfig.radiusFull)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
               Icon(Icons.person, size: 14, color: NusaConfig.activePrimary),
              SizedBox(width: 4),
              Text(_cashierName, style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
            ]),
          ),

      ]),
    );
  }

  Widget _gridToggle(int cols, IconData icon, bool isDark) {
    final active = _gridColumns == cols;
    return GestureDetector(
      onTap: () => _setGridColumns(cols),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: active ? Colors.white : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusXL),
        boxShadow: _searching
            ? [BoxShadow(color: NusaConfig.activePrimary.withValues(alpha: 0.2), blurRadius: 12, offset:  Offset(0, 3))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: TextField(
        controller: _search, focusNode: _searchFocus,
        style: TextStyle(fontSize: 15, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari produk...',
          hintStyle: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, size: 22),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => _scanBarcode(context),
              child: Container(padding:  EdgeInsets.symmetric(horizontal: 8), child:  Icon(Icons.qr_code_scanner, color: NusaConfig.activePrimary, size: 22)),
            ),
            if (_search.text.isNotEmpty)
              GestureDetector(
                onTap: () { _search.clear(); setState(() {}); },
                child: Icon(Icons.clear_rounded, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, size: 20),
              ),
          ]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, i) {
          final chip = _chips[i];
          final selected = chip == _category;
          return GestureDetector(
            onTap: () => setState(() => _category = chip),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor),
                borderRadius: BorderRadius.circular(NusaConfig.radiusFull),
                boxShadow: selected ? [BoxShadow(color: NusaConfig.activePrimary.withValues(alpha: 0.3), blurRadius: 8, offset:  Offset(0, 2))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(NusaConfig.catIcons[chip] ?? Icons.circle, size: 16,
                  color: selected ? Colors.white : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                SizedBox(width: 6),
                Text(chip, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(bool isDark) {
    if (_productsLoading) {
      return  Center(child: CircularProgressIndicator(color: NusaConfig.activePrimary));
    }
    final products = _filteredProducts();
    if (products.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 56, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
        SizedBox(height: 8),
        Text('Produk tidak ditemukan', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, fontSize: 15)),
      ]));
    }
    final cart = ref.watch(cartProvider);

    // 1x1 mode: thin horizontal list cards
    if (_gridColumns == 1) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: products.length,
        itemBuilder: (_, i) {
          final product = products[i];
          final cartItem = cart.cast<CartItem?>().firstWhere((c) => c?.productId == product.id, orElse: () => null);
          return _ProductListCard(
            product: product, isDark: isDark, qtyInCart: cartItem?.qty ?? 0,
            onAdd: () => ref.read(cartProvider.notifier).addProduct(product.id, product.name, product.sellPrice),
            onDecrement: () => ref.read(cartProvider.notifier).changeQty(product.id, -1),
            onIncrement: () => ref.read(cartProvider.notifier).addProduct(product.id, product.name, product.sellPrice),
          );
        },
      );
    }

    final cross = _gridColumns;
    final colW = (MediaQuery.of(context).size.width - 32 - 10 * (cross - 1)) / cross;
    // Image is inset (10px all sides) → ≈square of (colW-20).
    // Footer (name+cat+price+action) ≈110px. Ratio = colW/(colW+110).
    final ratio = (colW / (colW + 110)).clamp(0.4, 0.85);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridColumns, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: ratio),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final product = products[i];
        final cartItem = cart.cast<CartItem?>().firstWhere((c) => c?.productId == product.id, orElse: () => null);
        return _ProductCard(
          product: product, isDark: isDark, qtyInCart: cartItem?.qty ?? 0,
          onAdd: () => ref.read(cartProvider.notifier).addProduct(product.id, product.name, product.sellPrice),
          onDecrement: () => ref.read(cartProvider.notifier).changeQty(product.id, -1),
          onIncrement: () => ref.read(cartProvider.notifier).addProduct(product.id, product.name, product.sellPrice),
        );
      },
    );
  }

  // ── Cart Bar (collapsed, narrow only) ──

  Widget _buildCartBar(bool isDark, int totalItems, int totalPrice) {
    return GestureDetector(
      onTap: totalItems > 0 ? () => setState(() => _cartExpanded = true) : null,
      child: Container(
        margin: EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NusaConfig.radiusXL),
          gradient:  LinearGradient(colors: [NusaConfig.activePrimary, NusaConfig.activeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: NusaConfig.activePrimary.withValues(alpha: 0.35), blurRadius: 16, offset:  Offset(0, 6))],
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$totalItems item', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
            SizedBox(height: 2),
            Text(formatRupiah(totalPrice), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          ]),
          Spacer(),
          if (totalItems > 0) Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 28),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: totalItems == 0 ? null : () => context.push('/checkout?sessionId=${widget.sessionId ?? ''}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: NusaConfig.activePrimary,
              disabledBackgroundColor: Colors.white38, disabledForegroundColor: Colors.white54,
              elevation: 0, padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: Text('Bayar'),
          ),
        ]),
      ),
    );
  }

  // ── Unified Cart Panel (sheet for narrow, sidebar for wide) ──

  Widget _buildCartPanel(bool isDark, List<CartItem> cart, int totalItems, int totalPrice, {required bool isSheet}) {
    final hasMember = _memberName != null;
    final separator = Container(height: 1, color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor);

    Widget body = Column(children: [
      if (isSheet) ...[
        Center(child: Container(margin: EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
          decoration: BoxDecoration(color: NusaConfig.dividerColor, borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Keranjang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
            Spacer(),
            TextButton(onPressed: () => ref.read(cartProvider.notifier).clear(), child:  Text('Kosongkan', style: TextStyle(color: NusaConfig.activePrimary, fontWeight: FontWeight.w600))),
            IconButton(onPressed: () => setState(() => _cartExpanded = false), icon: Icon(Icons.keyboard_arrow_down, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ]),
        ),
      ] else ...[
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
             Icon(Icons.shopping_basket_outlined, color: NusaConfig.activePrimary, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Keranjang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
            TextButton(onPressed: cart.isEmpty ? null : () => ref.read(cartProvider.notifier).clear(), child:  Text('Kosongkan', style: TextStyle(fontSize: 12, color: NusaConfig.activePrimary, fontWeight: FontWeight.w600))),
          ]),
        ),
        separator,
      ],
      // Member lookup
      _buildLookupRow(isDark, isSheet ? 16 : 12),
      if (hasMember) _buildMemberBadge(isDark, isSheet ? 16 : 12),
      // Promo
      _buildPromoRow(isDark, isSheet ? 16 : 12),
      separator,
      // Cart items
      Expanded(
        child: cart.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: NusaConfig.textTertiary.withValues(alpha: 0.5)),
                SizedBox(height: 8),
                Text('Keranjang masih kosong', style: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ]))
            : Consumer(
                builder: (_, ref, __) => ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: cart.length,
                  itemBuilder: (_, i) => _CartItemTile(
                    item: cart[i], isDark: isDark,
                    onDecrement: () => ref.read(cartProvider.notifier).changeQty(cart[i].productId, -1),
                    onIncrement: () => ref.read(cartProvider.notifier).addProduct(cart[i].productId, cart[i].name, cart[i].price),
                  ),
                ),
              ),
      ),
      // Payment method chips
      Padding(
        padding: EdgeInsets.symmetric(horizontal: isSheet ? 16.0 : 12.0, vertical: 4),
        child: Row(children: [
          _payChip('Tunai', Icons.money, _paymentMethod == 'Tunai', () => setState(() => _paymentMethod = 'Tunai')),
          SizedBox(width: 8),
          _payChip('QRIS', Icons.qr_code, _paymentMethod == 'QRIS', () => setState(() => _paymentMethod = 'QRIS')),
          SizedBox(width: 8),
          _payChip('Transfer', Icons.account_balance, _paymentMethod == 'Transfer', () => setState(() => _paymentMethod = 'Transfer')),
        ]),
      ),
      // Summary + checkout
      Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
          border: Border(top: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$totalItems item', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            Text(formatRupiah(totalPrice), style:  TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary, letterSpacing: -0.5)),
          ]),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: totalItems == 0 ? null : () => context.push('/checkout?sessionId=${widget.sessionId ?? ''}'),
              style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, padding:  EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle:  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              child: Text('Bayar'),
            ),
          ),
        ]),
      ),
    ]);

    if (isSheet) {
      return Positioned.fill(
        top: MediaQuery.of(context).padding.top + 80,
        child: GestureDetector(
          onVerticalDragEnd: (d) { if (d.primaryVelocity! > 500) setState(() => _cartExpanded = false); },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkBackground : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(NusaConfig.radiusXL)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: Offset(0, -5))],
            ),
            child: body,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        border: Border(left: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor)),
      ),
      child: body,
    );
  }

  Widget _buildLookupRow(bool isDark, double padH) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padH, 8, padH, 4),
      child: Row(children: [
        Expanded(
          child: SizedBox(height: 42,
            child: TextField(
              controller: _memberPhone, keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
              decoration: InputDecoration(
                hintText: 'No WhatsApp member...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                prefixIcon: Icon(Icons.person_outline, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                filled: true, fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(height: 42,
          child: ElevatedButton(
            onPressed: _checkingMember ? null : _lookupMember,
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.info, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD)), padding: EdgeInsets.symmetric(horizontal: 14), textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            child: _checkingMember ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Cek'),
          ),
        ),
      ]),
    );
  }

  Widget _buildMemberBadge(bool isDark, double padH) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: padH),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: NusaConfig.warningSoft, borderRadius: BorderRadius.circular(NusaConfig.radiusMD), border: Border.all(color: Color(0xFFFCD34D))),
      child: Row(children: [
        Icon(Icons.stars_rounded, size: 18, color: NusaConfig.warning),
        SizedBox(width: 8),
        Expanded(child: Text(_memberName!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.warningText))),
        Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: NusaConfig.warning, borderRadius: BorderRadius.circular(8)), child: Text('$_memberPoints pts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
      ]),
    );
  }

  Widget _buildPromoRow(bool isDark, double padH) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padH, 6, padH, 4),
      child: Row(children: [
        Expanded(
          child: SizedBox(height: 40,
            child: TextField(
              controller: _promoCode,
              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
              decoration: InputDecoration(
                hintText: 'Kode promo...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                prefixIcon: Icon(Icons.local_offer_outlined, size: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                filled: true, fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(height: 40,
          child: ElevatedButton(
            onPressed: null, // promo apply — not yet implemented
            style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.success.withValues(alpha: 0.5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NusaConfig.radiusMD)), padding: EdgeInsets.symmetric(horizontal: 12), textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            child: Text('Pakai'),
          ),
        ),
      ]),
    );
  }

  Future<void> _lookupMember() async {
    final phone = _memberPhone.text.trim();
    if (phone.isEmpty) return;
    setState(() => _checkingMember = true);
    try {
      final repo = CustomerRepository(ref.read(databaseProvider));
      final customer = await repo.byPhone(phone);
      if (customer != null && mounted) {
        setState(() { _memberName = customer.name; _memberPoints = customer.points; });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Member tidak ditemukan'), duration: Duration(seconds: 2)));
        setState(() { _memberName = null; _memberPoints = 0; });
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingMember = false);
  }

  Widget _payChip(String label, IconData icon, bool active, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? NusaConfig.activeSoft : (isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill),
            borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
            border: Border.all(color: active ? NusaConfig.activePrimary : NusaConfig.dividerColor, width: active ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 20, color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

// ── Product Card ──

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isDark;
  final int qtyInCart;
  final VoidCallback onAdd;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  _ProductCard({
    required this.product, required this.isDark, required this.qtyInCart,
    required this.onAdd, required this.onDecrement, required this.onIncrement,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= product.minStock;
    final gradient = NusaConfig.catGradientFor(product.category);
    final hasImage = product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
      child: InkWell(
        onTap: outOfStock ? null : () { if (qtyInCart == 0) onAdd(); },
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.08), blurRadius: 10, offset: Offset(0, 3))],
            border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
          ),
          padding: EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Image (inset, square with own rounded corners) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(NusaConfig.radiusSM),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(children: [
                  if (hasImage)
                    Image.file(File(product.imagePath!), fit: BoxFit.cover, width: double.infinity)
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
                        color: outOfStock ? NusaConfig.stockOut : (lowStock ? NusaConfig.stockLow : NusaConfig.surfaceColor.withValues(alpha: 0.92)),
                        borderRadius: BorderRadius.circular(NusaConfig.radiusFull),
                      ),
                      child: Text(
                        outOfStock ? 'Habis' : '${product.stock}x',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: outOfStock ? NusaConfig.stockOutText : (lowStock ? NusaConfig.stockLowText : NusaConfig.activePrimary)),
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
                color: outOfStock ? isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
            SizedBox(height: 2),
            // ── Category ──
            Text(product.category, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            SizedBox(height: 6),
            // ── Price ──
            Text(formatRupiah(product.sellPrice),
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary)),
            SizedBox(height: 8),
            // ── Action ──
            outOfStock
                ? Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('Stok Habis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  )
                : qtyInCart == 0
                    ? NusaAddButton(onTap: onAdd, fullWidth: true)
                    : NusaQtyStepper(qty: qtyInCart, onDecrement: onDecrement, onIncrement: onIncrement, fullWidth: true),
          ]),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item; final bool isDark;
  final VoidCallback? onDecrement, onIncrement;
  _CartItemTile({required this.item, required this.isDark, this.onDecrement, this.onIncrement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2),
            Text(formatRupiah(item.price), style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ]),
        ),
        Container(
          height: 32,
          decoration: BoxDecoration(border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor), borderRadius: BorderRadius.circular(10), color: isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(onTap: onDecrement, behavior: HitTestBehavior.opaque, child: SizedBox(width: 30, height: 32, child: Center(child: Icon(Icons.remove, size: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)))),
            Text('${item.qty}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
            GestureDetector(onTap: onIncrement, behavior: HitTestBehavior.opaque, child: SizedBox(width: 30, height: 32, child: Center(child: Icon(Icons.add, size: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)))),
          ]),
        ),
        SizedBox(width: 8),
        Text(formatRupiah(item.subtotal), style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
      ]),
    );
  }
}

// ── Product List Card (1-column thin horizontal) ──

class _ProductListCard extends StatelessWidget {
  final Product product;
  final bool isDark;
  final int qtyInCart;
  final VoidCallback onAdd;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  _ProductListCard({
    required this.product, required this.isDark, required this.qtyInCart,
    required this.onAdd, required this.onDecrement, required this.onIncrement,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= product.minStock;
    final gradient = NusaConfig.catGradientFor(product.category);
    final hasImage = product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync();

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        child: InkWell(
          onTap: outOfStock ? null : () { if (qtyInCart == 0) onAdd(); },
          borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
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
                child: SizedBox(width: 56, height: 56,
                  child: hasImage
                      ? Image.file(File(product.imagePath!), fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
                          alignment: Alignment.center,
                          child: Text(_initials(product.name), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                ),
              ),
              SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                  SizedBox(height: 2),
                  Text(product.category, style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  SizedBox(height: 2),
                  Row(children: [
                    Text(formatRupiah(product.sellPrice), style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: outOfStock ? NusaConfig.stockOut : (lowStock ? NusaConfig.stockLow : NusaConfig.stockActive),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        outOfStock ? 'Habis' : 'Stok ${product.stock}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: outOfStock ? NusaConfig.stockOutText : (lowStock ? NusaConfig.stockLowText : NusaConfig.stockActiveText)),
                      ),
                    ),
                  ]),
                ]),
              ),
              SizedBox(width: 8),
              // Action
              if (outOfStock)
                SizedBox(width: 32, height: 32)
              else if (qtyInCart == 0)
                NusaAddButton(onTap: onAdd)
              else
                NusaQtyStepper(qty: qtyInCart, onDecrement: onDecrement, onIncrement: onIncrement),
            ]),
          ),
        ),
      ),
    );
  }
}
