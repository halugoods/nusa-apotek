import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/category_repository.dart';
import 'package:nusa_kasir/data/repositories/online_order_repository.dart';
import 'package:nusa_kasir/data/repositories/branch_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_cart_controls.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:drift/drift.dart' hide Column;

/// Customer-facing online store screen.
/// Route: /toko
class StorefrontScreen extends ConsumerStatefulWidget {
  StorefrontScreen({super.key});
  @override
  ConsumerState<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StoreItem {
  final Product product;
  int qty;
  _StoreItem({required this.product, this.qty = 1});
  int get subtotal => product.sellPrice * qty;
}

class _StorefrontScreenState extends ConsumerState<StorefrontScreen> {
  List<Product> _allProducts = [];
  bool _loading = true;
  String _category = 'Semua';
  final _search = TextEditingController();
  final List<_StoreItem> _cart = [];
  bool _showCart = false;
  List<String> _allCats = [];
  List<String> _branches = ['Pusat'];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _paymentMethod = 'Tunai';
  String _branch = 'Pusat';
  String? _storeName;
  String? _storePhone;

  final _scrollCtrl = ScrollController();

  // Wishlist state
  final Set<int> _wishlist = {};
  // Cart popup state
  bool _showCartPopup = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose(); _nameCtrl.dispose(); _phoneCtrl.dispose();
    _scrollCtrl.dispose(); super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ProductRepository(db);
    final all = await repo.getProducts();
    final settingsRepo = SettingsRepository(db);
    final storeName = await settingsRepo.getStoreName();
    final storePhone = await settingsRepo.getStorePhone();
    if (mounted) {
      final catRepo = CategoryRepository(db);
      final cats = await catRepo.getAll();
      // Load branches from DB
      final branchRepo = BranchRepository(db);
      final branchList = await branchRepo.getAll();
      final branches = branchList.map((b) => b.name).toList();
      setState(() {
        _allProducts = all;
        _allCats = cats;
        _branches = branches.isNotEmpty ? branches : ['Pusat'];
        _loading = false;
        _storeName = storeName.isNotEmpty ? storeName : 'NUSA Toko';
        _storePhone = storePhone.isNotEmpty ? storePhone : null;
      });
    }
  }

  // ── Product initials helper ──
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '??';
  }

  List<Product> _filtered() {
    final q = _search.text.toLowerCase();
    return _allProducts.where((p) {
      if (_category != 'Semua' && p.category != _category) return false;
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  void _incCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        _cart[idx].qty++;
      } else {
        _cart.add(_StoreItem(product: p));
        // Show cart popup
        _showCartPopup = true;
        Future.delayed(Duration(seconds: 4), () {
          if (mounted) setState(() => _showCartPopup = false);
        });
      }
    });
  }

  void _decCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        if (_cart[idx].qty <= 1) {
          _cart.removeAt(idx);
        } else {
          _cart[idx].qty--;
        }
      }
    });
  }

  void _toggleWishlist(int productId) {
    setState(() {
      if (_wishlist.contains(productId)) {
        _wishlist.remove(productId);
      } else {
        _wishlist.add(productId);
      }
    });
  }

  int get _totalItems => _cart.fold(0, (s, e) => s + e.qty);
  int get _totalPrice => _cart.fold(0, (s, e) => s + e.subtotal);

  Future<void> _sendWhatsApp() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama dan WhatsApp wajib diisi')));
      return;
    }
    
    // 1. Save to OnlineOrders local DB first
    final db = ref.read(databaseProvider);
    final onlineRepo = OnlineOrderRepository(db);
    final invoice = 'INV-ONL-${DateTime.now().millisecondsSinceEpoch}';
    final itemsJson = jsonEncode(_cart.map((c) => {
      'product_id': c.product.id,
      'name': c.product.name,
      'qty': c.qty,
      'price': c.product.sellPrice,
      'subtotal': c.subtotal,
    }).toList());
    
    try {
      await onlineRepo.upsert(OnlineOrdersCompanion.insert(
        invoice: invoice,
        customerName: name,
        customerPhone: phone,
        items: itemsJson,
        subtotal: Value(_totalPrice),
        total: _totalPrice,
        paymentMethod: Value(_paymentMethod),
        branch: Value(_branch),
        notes: Value('Pesanan dari Storefront'),
        status: Value('Online Baru'),
      ));
      TopToast.success(context, 'Pesanan berhasil disimpan!');
    } catch (e) {
      TopToast.error(context, 'Gagal menyimpan pesanan');
      // Continue to WA anyway
    }
    
    // 2. Send WhatsApp notification (existing flow)
    final itemsText = _cart.map((c) =>
      '• ${c.product.name} x${c.qty} — ${formatRupiah(c.subtotal)}'
    ).join('\n');
    final msg = Uri.encodeComponent(
      '🛒 *Pesanan Baru*\n\n'
      '👤 $name\n📱 $phone\n🏪 $_branch\n💳 $_paymentMethod\n\n'
      '*Item:*\n$itemsText\n\n'
      '*Total: ${formatRupiah(_totalPrice)}*');
    final targetPhone = _storePhone ?? '';
    final waUrl = Uri.parse('https://wa.me/$targetPhone?text=$msg');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }
    
    // 3. Clear cart after successful order
    _cart.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = _filtered();
    final cats = ['Semua', ..._allCats];

    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            // ── Header ──
            Container(
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 2))],
              ),
              child: Column(children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient:  LinearGradient(colors: [NusaConfig.activePrimary, NusaConfig.activeDark]),
                        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                        boxShadow: [BoxShadow(color: NusaConfig.activePrimary.withValues(alpha: 0.3), blurRadius: 8, offset:  Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: Text('N', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_storeName ?? 'NUSA Toko', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                        SizedBox(height: 1),
                        Row(children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: NusaConfig.success, shape: BoxShape.circle)),
                          SizedBox(width: 4),
                          Text('Buka • Online Order', style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                        ]),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showCart = true),
                      child: Container(
                        padding: EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(clipBehavior: Clip.none, children: [
                          Icon(Icons.shopping_bag_outlined, size: 24, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                          if (_totalItems > 0)
                            Positioned(right: -5, top: -5,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration:  BoxDecoration(color: NusaConfig.activePrimary, shape: BoxShape.circle),
                                child: Text('$_totalItems', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(color: NusaConfig.errorSoft, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.close, size: 20, color: NusaConfig.error),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _search, onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 14, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari menu...',
                        hintStyle: TextStyle(fontSize: 14, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                        border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = cats[i];
                      final active = cat == _category;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? NusaConfig.activePrimary : (isDark ? NusaConfig.darkSurface2 : NusaConfig.dividerColor),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: active ? [BoxShadow(color: NusaConfig.activePrimary.withValues(alpha: 0.25), blurRadius: 8, offset:  Offset(0, 2))] : [],
                          ),
                          child: Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
            // ── Product Grid ──
            Expanded(
              child: _loading
                  ?  Center(child: CircularProgressIndicator(color: NusaConfig.activePrimary))
                  : products.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inventory_2_outlined, size: 56, color: (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary).withValues(alpha: 0.5)),
                          SizedBox(height: 12),
                          Text('Belum ada produk', style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, fontSize: 15)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            controller: _scrollCtrl,
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                              childAspectRatio: (() {
                                final colW = (MediaQuery.of(context).size.width - 32 - 12) / 2;
                                return (colW / (colW + 110)).clamp(0.4, 0.85);
                              })()),
                            itemCount: products.length,
                            itemBuilder: (_, i) => _ProductCard(
                              product: products[i], isDark: isDark,
                              cartQty: _cart.firstWhere((c) => c.product.id == products[i].id, orElse: () => _StoreItem(product: products[i])).qty,
                              onAdd: () => _incCart(products[i]),
                              onDecrement: () => _decCart(products[i]),
                              isWishlisted: _wishlist.contains(products[i].id),
                              onWishlist: () => _toggleWishlist(products[i].id),
                              initials: _initials(products[i].name),
                            ),
                          ),
                        ),
            ),
          ]),

          // ── Cart popup ──
          if (_showCartPopup && _totalItems > 0)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: GestureDetector(
                onTap: () { setState(() { _showCartPopup = false; _showCart = true; }); },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: NusaConfig.activePrimary.withValues(alpha: 0.4), blurRadius: 16, offset:  Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Lihat Keranjang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    Text('$_totalItems item Â· ${formatRupiah(_totalPrice)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      bottomSheet: _showCart && _cart.isNotEmpty ? _buildCartSheet(isDark) : null,
    );
  }

  Widget _buildCartSheet(bool isDark) {
    return SafeArea(
      child: GestureDetector(
        onVerticalDragEnd: (d) { if (d.primaryVelocity! > 500) setState(() => _showCart = false); },
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: Offset(0, -5))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(margin: EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('🛒  Keranjang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                Spacer(),
                TextButton(onPressed: () { _cart.clear(); setState(() => _showCart = false); },
                  child:  Text('Kosongkan', style: TextStyle(color: NusaConfig.activePrimary, fontWeight: FontWeight.w600))),
              ]),
            ),
            Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _cart.length,
                itemBuilder: (_, i) {
                  final item = _cart[i];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor,
                      borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.product.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                          SizedBox(height: 2),
                          Text(formatRupiah(item.product.sellPrice), style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
                        ]),
                      ),
                      Container(
                        height: 34,
                        decoration: BoxDecoration(border: Border.all(color: NusaConfig.activePrimary, width: 1.5), borderRadius: BorderRadius.circular(10), color: NusaConfig.activeSoft),
                        child: Row(children: [
                          GestureDetector(
                            onTap: () { if (item.qty <= 1) { _cart.removeAt(i); } else { item.qty--; } setState(() {}); if (_cart.isEmpty) setState(() => _showCart = false); },
                            child:  SizedBox(width: 30, height: 34, child: Icon(Icons.remove, size: 16, color: NusaConfig.activePrimary)),
                          ),
                          Text('${item.qty}', style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.activePrimary)),
                          GestureDetector(
                            onTap: () { item.qty++; setState(() {}); },
                            child:  SizedBox(width: 30, height: 34, child: Icon(Icons.add, size: 16, color: NusaConfig.activePrimary)),
                          ),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(color: isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor, border: Border(top: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('$_totalItems item', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                  Text(formatRupiah(_totalPrice), style:  TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary, letterSpacing: -0.5)),
                ]),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () { setState(() => _showCart = false); _showCheckoutSheet(context, isDark); },
                    style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle:  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    child: Text('Lanjutkan Pesanan'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showCheckoutSheet(BuildContext ctx, bool isDark) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => StatefulBuilder(
        builder: (bCtx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(bCtx).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(margin: EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
                decoration: BoxDecoration(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor, borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Selesaikan Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                  SizedBox(height: 6),
                  Text(formatRupiah(_totalPrice), style:  TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary, letterSpacing: -1)),
                  SizedBox(height: 20),
                  Text('DATA PEMESAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, letterSpacing: 0.5)),
                  SizedBox(height: 8),
                  _checkoutField('Nama', _nameCtrl, 'Nama Anda', Icons.person_outline),
                  SizedBox(height: 8),
                  _checkoutField('WhatsApp', _phoneCtrl, '0812-3456-7890', Icons.phone_outlined, keyboard: TextInputType.phone),
                  SizedBox(height: 16),
                  Text('CABANG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, letterSpacing: 0.5)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill, borderRadius: BorderRadius.circular(NusaConfig.radiusMD), border: Border.all(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _branch, isExpanded: true,
                        style: TextStyle(fontSize: 14, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                        items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) { if (v == null) return; _branch = v; setSheetState(() {}); },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('METODE PEMBAYARAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, letterSpacing: 0.5)),
                  SizedBox(height: 8),
                  Row(children: [
                    _paymentOption('Tunai', Icons.money, isDark, setSheetState: setSheetState),
                    SizedBox(width: 10),
                    _paymentOption('QRIS', Icons.qr_code, isDark, setSheetState: setSheetState),
                    SizedBox(width: 10),
                    _paymentOption('Transfer', Icons.account_balance, isDark, setSheetState: setSheetState),
                  ]),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(bCtx); _sendWhatsApp(); },
                      icon: Icon(Icons.chat, size: 20),
                      label: Text('Kirim Pesanan via WhatsApp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25D366), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                  SizedBox(height: 20),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _checkoutField(String label, TextEditingController ctrl, String hint, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill, borderRadius: BorderRadius.circular(NusaConfig.radiusMD), border: Border.all(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor)),
      child: TextField(
        controller: ctrl, keyboardType: keyboard,
        style: TextStyle(fontSize: 14, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
        decoration: InputDecoration(
          labelText: label, labelStyle: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
          hintText: hint, hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          prefixIcon: Icon(icon, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _paymentOption(String method, IconData icon, bool isDark, {required void Function(void Function()) setSheetState}) {
    final active = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () { _paymentMethod = method; setSheetState(() {}); },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? NusaConfig.activeSoft : NusaConfig.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? NusaConfig.activePrimary : NusaConfig.dividerColor, width: active ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 24, color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            SizedBox(height: 4),
            Text(method, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

// ── Product Card (storefront) ──

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isDark;
  final int cartQty;
  final VoidCallback onAdd;
  final VoidCallback onDecrement;
  final bool isWishlisted;
  final VoidCallback onWishlist;
  final String initials;
  _ProductCard({
    required this.product, required this.isDark,
    required this.cartQty, required this.onAdd, required this.onDecrement,
    required this.isWishlisted, required this.onWishlist,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outOfStock = product.stock <= 0;
    final gradient = NusaConfig.catGradientFor(product.category);
    final hasImage = product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync();

    return GestureDetector(
      onTap: outOfStock ? null : () { if (cartQty == 0) onAdd(); },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.10), blurRadius: 10, offset: Offset(0, 3))],
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
                  Image.file(File(product.imagePath!), fit: BoxFit.cover, width: double.infinity, cacheWidth: 400)
                else
                  Container(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)),
                    alignment: Alignment.center,
                    child: Text(initials, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ),
                // Wishlist button (top-right)
                Positioned(top: 6, right: 6,
                  child: GestureDetector(
                    onTap: onWishlist,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: isWishlisted ? NusaConfig.activePrimary : Colors.black.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                // Stock badge (top-left)
                Positioned(top: 6, left: 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: outOfStock ? NusaConfig.stockOut : NusaConfig.surfaceColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(NusaConfig.radiusFull),
                    ),
                    child: Text(
                      outOfStock ? 'Habis' : '${product.stock}x',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: outOfStock ? NusaConfig.stockOutText : NusaConfig.activePrimary),
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
                  decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text('Stok Habis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                )
              : cartQty == 0
                  ? NusaAddButton(onTap: onAdd, fullWidth: true)
                  : NusaQtyStepper(qty: cartQty, onDecrement: onDecrement, onIncrement: onAdd, fullWidth: true),
        ]),
      ),
    );
  }
}
