import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/dining_table_repository.dart';
import 'package:nusa_kasir/data/repositories/laundry_order_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/promo_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/data/repositories/tab_repository.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/features/pos/cart.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/features/checkout/receipt_sheet.dart';

/// Shared section card style used across all checkout cards.
BoxDecoration _sectionCard(bool isDark) => BoxDecoration(
  color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2))],
);

class CheckoutScreen extends ConsumerStatefulWidget {
  final int? sessionId;
  CheckoutScreen({super.key, this.sessionId});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _discountCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  String _paymentMethod = 'Tunai';
  bool _loading = false;
  List<int> denoms = [];
  int? _cashGiven;
  String? _qrisString;
  String? _qrisImagePath;
  String? _bankName;
  String? _bankAccount;
  String? _bankHolder;
  Customer? _selectedCustomer;
  Promo? _appliedPromo;
  int _promoDiscount = 0; // computed from applied promo
  int _pointsUsed = 0; // poin yang ditukar (1 poin = Rp 1)

  // Split bill
  bool _splitBill = false;
  int _splitCount = 2;

  // FnB params
  String? _orderType;
  int? _tableId;
  String? _tableName;
  int? _activeTabId;

  Future<void> _completeTab(AppDatabase db, {bool freeTable = true}) async {
    try {
      final tabRepo = TabRepository(db);
      await tabRepo.complete(_activeTabId!);
      if (freeTable && _tableId != null) {
        await DiningTableRepository(db).updateStatus(_tableId!, 'Kosong');
      }
    } catch (_) {}
  }

  /// Trigger kitchen printer (FnB only). Fire-and-forget — never blocks user.
  void _triggerKitchenPrint(List<CartItem> cart, String? orderType, String? tableName) {
    Future.microtask(() async {
      try {
        // Pre-flight: check Bluetooth permissions & state
        if (!await ReceiptPrinter.ensureBluetoothReady()) return;

        final enabled = await SecureStore.getKitchenPrinterEnabled();
        if (!enabled) return;
        final addr = await SecureStore.getKitchenPrinterAddress();
        if (addr == null || addr.isEmpty) return;

        final printer = ReceiptPrinter();
        final lines = cart
            .map((c) => ReceiptLine(name: c.name, qty: c.qty, price: c.price))
            .toList();
        final notes = cart.map((c) => c.note).toList();

        await printer.printKitchenOrder(
          orderType: orderType ?? 'Dine In',
          lines: lines,
          itemNotes: notes,
          tableName: tableName,
        );
      } catch (_) {
        // Silent fail — kitchen print is best-effort
      }
    });
  }

  int get _subtotal => ref.watch(cartProvider).fold(0, (s, e) => s + e.subtotal);
  int get _manualDiscount => int.tryParse(_discountCtrl.text) ?? 0;
  int get _tierDiscount {
    if (_selectedCustomer == null) return 0;
    final pct = CustomerRepository.tierDiscountPercent(_selectedCustomer!.level);
    return (_subtotal * pct / 100).round();
  }
  int get _totalDiscount =>
      (_manualDiscount + _promoDiscount + _tierDiscount + _pointsUsed).clamp(0, _subtotal);
  int get _total => (_subtotal - _totalDiscount).clamp(0, _subtotal);
  int? get _kembalian =>
      _cashGiven != null && _cashGiven! >= _total ? _cashGiven! - _total : null;

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).uri.queryParameters;
      if (extra['orderType'] != null) {
        _orderType = extra['orderType'];
        _tableId = int.tryParse(extra['tableId'] ?? '');
        _tableName = extra['tableName'] != null ? Uri.decodeComponent(extra['tableName']!) : null;
        _activeTabId = int.tryParse(extra['activeTabId'] ?? '');
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _loadPaymentSettings() async {
    final repo = ref.read(settingsRepoProvider);
    final qris = await repo.getQris();
    final qrisImg = await repo.getQrisImagePath();
    final bankName = await repo.getBankName();
    final bankAccount = await repo.getBankAccount();
    final bankHolder = await repo.getBankHolder();
    if (mounted) setState(() {
      _qrisString = qris;
      _qrisImagePath = qrisImg;
      _bankName = bankName;
      _bankAccount = bankAccount;
      _bankHolder = bankHolder;
    });
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _cashCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) {
      TopToast.error(context, 'Masukkan kode promo');
      return;
    }
    final repo = PromoRepository(ref.read(databaseProvider));
    final promos = await repo.getPromos();
    final match = promos.cast<Promo?>().firstWhere(
          (p) => p!.code.toUpperCase() == code.toUpperCase() && p.status == 'Aktif',
          orElse: () => null,
        );
    if (match == null) {
      TopToast.error(context, 'Kode promo tidak valid atau tidak aktif');
      return;
    }

    // Check min belanja
    if (_subtotal < match.minBelanja) {
      TopToast.error(context, 'Min. belanja ${formatRupiah(match.minBelanja)}');
      return;
    }

    // Check kuota
    if (match.maxUses != null && match.usedCount >= match.maxUses!) {
      TopToast.error(context, 'Kuota promo sudah habis');
      return;
    }

    // Calculate discount
    int discount;
    if (match.type == 'persen') {
      discount = (_subtotal * match.value / 100).round();
    } else {
      discount = match.value;
    }
    discount = discount.clamp(0, _subtotal);

    setState(() {
      _appliedPromo = match;
      _promoDiscount = discount;
    });
    TopToast.success(context, 'Promo "${match.name}" diterapkan!');
  }

  void _clearPromo() {
    setState(() {
      _appliedPromo = null;
      _promoDiscount = 0;
      _promoCtrl.clear();
    });
  }

  Future<void> _pickCustomer() async {
    final repo = CustomerRepository(ref.read(databaseProvider));
    final customers = await repo.getCustomers();
    if (!mounted) return;

    final result = await showDialog<Customer?>(
      context: context,
      builder: (ctx) => _CustomerPickerDialog(
        customers: customers,
        onAddNew: () async {
          Navigator.pop(ctx); // close picker first
          final created = await _showAddCustomerSheet();
          if (created != null) {
            setState(() {
              _selectedCustomer = created;
              _pointsUsed = 0;
            });
            if (mounted) TopToast.success(context, 'Pelanggan: ${created.name}');
          }
        },
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCustomer = result;
        _pointsUsed = 0;
      });
      TopToast.success(context, 'Pelanggan: ${result.name}');
    }
  }

  Future<void> _confirmPayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      TopToast.error(context, 'Keranjang kosong');
      return;
    }

    if (_paymentMethod == 'Tunai') {
      final given = int.tryParse(_cashCtrl.text) ?? 0;
      if (given < _total) {
        TopToast.error(context, 'Jumlah dibayarkan kurang');
        return;
      }
    }

    // Validate stock before deducting
    final db = ref.read(databaseProvider);
    final productRepo = ProductRepository(db);
    for (final item in cart) {
      final product = await productRepo.byId(item.productId);
      if (product == null || product.stock < item.qty) {
        final name = product?.name ?? item.name;
        if (mounted) {
          TopToast.error(context, 'Stok "$name" tidak cukup (tersedia: ${product?.stock ?? 0})');
        }
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final transactionRepo = ref.read(transactionRepoProvider);
      final session = ref.read(employeeSessionProvider);
      final cashierName = session?.name;
      final cashGiven = int.tryParse(_cashCtrl.text);
      final cashReturn = cashGiven != null && cashGiven >= _total
          ? cashGiven - _total
          : null;

      // Wrap all DB writes (stock, transaction, loyalty, promo) in a single transaction.
      // If any step fails, it all rolls back — no partial state.
      await db.transaction(() async {
        // Deduct stock for each item
        for (final item in cart) {
          await productRepo.adjustStock(item.productId, -item.qty);
        }

        // Save transaction
        await transactionRepo.saveTransaction(
          items: cart,
          total: _total,
          discount: _totalDiscount,
          paymentMethod: _paymentMethod,
          cashGiven: cashGiven,
          cashReturn: cashReturn,
          cashierName: cashierName,
          customerId: _selectedCustomer?.id,
          branchId: ref.read(activeBranchProvider)?.id,
          orderType: _orderType,
          tableId: _tableId,
        );

        // Update customer loyalty
        if (_selectedCustomer != null) {
          final pointConfig = await SettingsRepository(db).getPointConfig();
          await CustomerRepository(db).addSpent(
            _selectedCustomer!.id, _total,
            pointsPerRupiah: pointConfig['pointsPerRupiah']!,
            goldThreshold: pointConfig['goldThreshold']!,
            platinumThreshold: pointConfig['platinumThreshold']!,
          );
        }

        // Increment promo usage
        if (_appliedPromo != null) {
          await PromoRepository(db).incrementUsed(_appliedPromo!.id);
        }

        // Redeem loyalty points
        if (_selectedCustomer != null && _pointsUsed > 0) {
          await CustomerRepository(db).redeemPoints(
              _selectedCustomer!.id, _pointsUsed);
        }
      });

      // Clear cart
      // Capture total & discount before clearing — getters depend on cartProvider
      final savedTotal = _total;
      final savedDiscount = _totalDiscount;
      final savedOrderType = _orderType;
      final savedTableName = _tableName;

      // ── Laundry: auto-create LaundryOrder after successful transaction ──
      int? _laundryOrderId;
      if (NusaConfig.isLaundryVariant && cart.isNotEmpty) {
        try {
          final laundryRepo = LaundryOrderRepository(db);
          final itemsJson = jsonEncode(cart.map((c) => {
            'name': c.name, 'qty': c.isPerKg ? 1 : c.qty,
            'price': c.price,
            if (c.isPerKg) 'weightKg': c.weightKg,
          }).toList());
          _laundryOrderId = await laundryRepo.add(
            customerName: _selectedCustomer?.name ?? 'Umum',
            customerPhone: _selectedCustomer?.phone,
            itemsJson: itemsJson,
            total: savedTotal,
            notes: cart.where((c) => c.note != null && c.note!.isNotEmpty)
                .map((c) => '${c.name}: ${c.note}').join('; '),
          );
        } catch (_) {}
      }

      ref.read(cartProvider.notifier).clear();

      // Auto-upload backup ke cloud setelah transaksi (background)
      Future.microtask(() async {
        try {
          await ref.read(activationRepoProvider).uploadBackupNow();
        } catch (_) {}
      });

      if (!mounted) return;

      // Build receipt data
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final invoice = 'INV${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      // Show receipt as centered dialog (GAS thermal style)
      if (mounted) {
        final autoPrint = await SecureStore.getAutoPrint();
        if (!mounted) return;
        await ReceiptSheet.show(
          context,
        sheet: ReceiptSheet.fromCart(
          cartItems: cart,
          total: savedTotal,
          discount: savedDiscount,
          paymentMethod: _paymentMethod,
          cashGiven: cashGiven,
          cashReturn: cashReturn,
          cashierName: cashierName,
          customerName: _selectedCustomer?.name,
          customerPhone: _selectedCustomer?.phone,
          invoice: invoice,
          dateStr: dateStr,
          pointsUsed: _pointsUsed,
          autoPrint: autoPrint && !_splitBill, // split bill prints separately
          orderType: savedOrderType,
          tableName: savedTableName,
          laundryOrderId: _laundryOrderId,
        ),
          onDismiss: () async {
            // ── Split bill: print splits after receipt shown ──
            if (_splitBill) {
              final perPerson = (savedTotal / _splitCount).ceil();
              await _printSplitBills(_splitCount, perPerson, cart);
            }

            // ── FnB: complete open tab (if any) + manage table ──
            if (NusaConfig.isFnbVariant) {
              final payFirst = await SecureStore.getFnbPaymentFirst();
              if (_activeTabId != null) {
                // Complete tab; in Bayar Dulu mode don't free table yet
                _completeTab(db, freeTable: !payFirst);
              } else if (_tableId != null) {
                if (payFirst) {
                  // Bayar Dulu: mark table as Dipesan (occupied after payment)
                  DiningTableRepository(db).updateStatus(_tableId!, 'Dipesan');
                } else {
                  // Pesan Dulu: direct payment → free table immediately
                  DiningTableRepository(db).updateStatus(_tableId!, 'Kosong');
                }
              }
              // ── Kitchen print (fire-and-forget) ──
              _triggerKitchenPrint(cart, savedOrderType, savedTableName);
            }
            // Return to POS screen after receipt is dismissed
            if (mounted && widget.sessionId != null) {
              context.go('/kasir?sessionId=${widget.sessionId}');
            } else if (mounted) {
              context.go('/home');
            }
          },
        );
      } else {
        // Return to POS screen if not mounted
        if (widget.sessionId != null) {
          context.go('/kasir?sessionId=${widget.sessionId}');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Gagal memproses pembayaran: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cartProvider);
    final subtotal = _subtotal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Pembayaran',
      ListView(
        padding: EdgeInsets.all(16),
        children: [
          // ── Customer Card ──
          _buildCustomerCard(isDark),
          SizedBox(height: 14),

          // ── Ringkasan Belanja Card ──
          _buildSummaryCard(isDark, subtotal),
          SizedBox(height: 14),

          // ── Split Bill Toggle (above payment method) ──
          _buildSplitToggle(isDark),
          SizedBox(height: 14),

          // ── Metode Pembayaran Card ──
          _buildPaymentMethodCard(isDark),
          SizedBox(height: 14),

          // ── Detail Pembayaran Card ──
          if (_paymentMethod == 'Tunai') _buildTunaiCard(isDark),
          if (_paymentMethod == 'QRIS') _buildQrisCard(isDark),
          if (_paymentMethod == 'Transfer') _buildTransferCard(isDark),

          SizedBox(height: 24),

          // ── Konfirmasi Button ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NusaConfig.activePrimary, NusaConfig.activeDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.3),
                  blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: GestureDetector(
              onTap: _loading ? null : _confirmPayment,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else ...[
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text('Konfirmasi Pembayaran',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => context.pop(),
              child: Text('← Kembali ke Kasir',
                  style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Builders ────────────────────────────────────────────────

  Widget _buildSplitToggle(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _sectionCard(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row with toggle
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: NusaConfig.activePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.people_outline, color: NusaConfig.activePrimary, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text('Split Bill', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Switch(
            value: _splitBill,
            onChanged: (v) => setState(() => _splitBill = v),
            activeColor: NusaConfig.activePrimary,
          ),
        ]),
        // Split count input (visible when ON)
        if (_splitBill) ...[
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _splitCount > 2
                    ? () => setState(() => _splitCount--)
                    : null,
                icon: Icon(Icons.remove_circle_outline, color: NusaConfig.activePrimary),
              ),
              SizedBox(width: 16),
              Text('$_splitCount Orang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              SizedBox(width: 16),
              IconButton(
                onPressed: _splitCount < 10
                    ? () => setState(() => _splitCount++)
                    : null,
                icon: Icon(Icons.add_circle_outline, color: NusaConfig.activePrimary),
              ),
            ],
          ),
          SizedBox(height: 6),
          Center(
            child: Text('Rp ${formatRupiah((_total / _splitCount).ceil())} / orang',
                style: TextStyle(fontSize: 14, color: NusaConfig.activePrimary, fontWeight: FontWeight.w700)),
          ),
          SizedBox(height: 4),
          Center(
            child: Text('Cetak $_splitCount struk setelah konfirmasi',
                style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
          ),
        ],
      ]),
    );
  }

  Widget _buildCustomerCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _sectionCard(isDark),
      child: InkWell(
        onTap: _pickCustomer,
        borderRadius: BorderRadius.circular(12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:  Icon(Icons.person_outline, color: NusaConfig.activePrimary, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selectedCustomer != null ? _selectedCustomer!.name : 'Pilih Pelanggan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              SizedBox(height: 2),
              Text(_selectedCustomer != null
                  ? 'Level: ${_selectedCustomer!.level} • Rp ${formatRupiah(_selectedCustomer!.totalSpent)}'
                  : 'Opsional — dapatkan diskon member',
                  style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            ]),
          ),
          if (_selectedCustomer != null)
            GestureDetector(
              onTap: () => setState(() => _selectedCustomer = null),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close, size: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, int subtotal) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _sectionCard(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: NusaConfig.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.receipt_long_outlined, color: NusaConfig.success, size: 18),
          ),
          SizedBox(width: 10),
          Text('Ringkasan Belanja', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 14),

        _summaryRow('Subtotal', formatRupiah(subtotal), isDark),
        if (_selectedCustomer != null) ...[
          SizedBox(height: 6),
          _summaryRow('Diskon ${_selectedCustomer!.level}',
              '-${formatRupiah(_tierDiscount)}', isDark, isDiscount: true),
        ],
        if (_appliedPromo != null) ...[
          SizedBox(height: 6),
          _summaryRow('Promo ${_appliedPromo!.name}',
              '-${formatRupiah(_promoDiscount)}', isDark, isDiscount: true),
        ],
        if (_pointsUsed > 0) ...[
          SizedBox(height: 6),
          _summaryRow('Tukar Poin', '-${formatRupiah(_pointsUsed)}', isDark, isDiscount: true),
        ],

        // ── Disc / Promo / Points Row ──
        SizedBox(height: 12),
        Row(children: [
          // Promo code
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _promoCtrl,
                style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                decoration: InputDecoration(
                  hintText: _appliedPromo != null ? _appliedPromo!.name : 'Kode promo...',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  prefixIcon: Icon(Icons.local_offer_outlined, size: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  filled: true, fillColor: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          if (_appliedPromo != null)
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: _clearPromo,
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFEF4444), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(horizontal: 14)),
                child: Text('Hapus', style: TextStyle(fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: _applyPromo,
                style: ElevatedButton.styleFrom(backgroundColor: NusaConfig.activePrimary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(horizontal: 14)),
                child: Text('Pakai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),

        // Diskon manual
        SizedBox(height: 10),
        Row(children: [
          Icon(Icons.discount_outlined, size: 16, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _discountCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
              decoration: InputDecoration(
                hintText: 'Diskon Rp',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true, fillColor: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Spacer(),
          // Poin tukar
          if (_selectedCustomer != null && _selectedCustomer!.points > 0) ...[
            _buildPointsBadge(isDark),
            SizedBox(width: 6),
            Container(
              height: 32,
              child: ElevatedButton(
                onPressed: _pointsUsed > 0 ? () => setState(() => _pointsUsed = 0) : _showRedeemPoints,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pointsUsed > 0 ? Color(0xFFEF4444) : Colors.amber,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  _pointsUsed > 0 ? 'Batal' : 'Tukar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ]),

        SizedBox(height: 12),
        Divider(color: Colors.grey.withValues(alpha: 0.2)),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, letterSpacing: 1)),
          Text(formatRupiah(_total),
              style:  TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary, letterSpacing: -0.5)),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark, {bool isDiscount = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: isDiscount ? Color(0xFF10B981) : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
    ]);
  }

  Widget _buildPaymentMethodCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _sectionCard(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: NusaConfig.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.payment_outlined, color: NusaConfig.accentPurple, size: 18),
          ),
          SizedBox(width: 10),
          Text('Metode Pembayaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 14),
        Row(children: [
          _payCard('Tunai', Icons.money, isDark),
          SizedBox(width: 10),
          _payCard('QRIS', Icons.qr_code_2, isDark),
          SizedBox(width: 10),
          _payCard('Transfer', Icons.account_balance, isDark),
        ]),
      ]),
    );
  }

  Widget _payCard(String method, IconData icon, bool isDark) {
    final active = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? NusaConfig.activeSoft : (isDark ? NusaConfig.darkSurface2 :  Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? NusaConfig.activePrimary : NusaConfig.dividerColor, width: active ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 28, color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            SizedBox(height: 6),
            Text(method, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: active ? NusaConfig.activePrimary : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTunaiCard(bool isDark) {
    denoms = [100000, 50000, 20000, 10000, 5000, 2000, 1000];
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: NusaConfig.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.money, color: NusaConfig.accentGreen, size: 18),
          ),
          SizedBox(width: 10),
          Text('Pembayaran Tunai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 14),
        TextField(
          controller: _cashCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
          decoration: InputDecoration(
            hintText: 'Rp 0',
            hintStyle: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary, fontSize: 20),
            filled: true, fillColor: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: NusaConfig.activePrimary, width: 2)),
          ),
          onChanged: (v) => setState(() => _cashGiven = int.tryParse(v)),
        ),
        SizedBox(height: 10),
        // Quick-action denomination chips
        Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            for (final d in denoms)
              GestureDetector(
                onTap: () {
                  final prev = int.tryParse(_cashCtrl.text) ?? 0;
                  final newVal = prev + d;
                  _cashCtrl.text = newVal.toString();
                  setState(() => _cashGiven = newVal);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? NusaConfig.darkBorder : Color(0xFFBBF7D0)),
                  ),
                  child: Text(formatRupiah(d), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                ),
              ),
            // Reset button
            GestureDetector(
              onTap: () {
                _cashCtrl.clear();
                setState(() => _cashGiven = null);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFFECACA)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh, size: 12, color: Color(0xFFDC2626)),
                  SizedBox(width: 4),
                  Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                ]),
              ),
            ),
          ],
        ),
        if (_kembalian != null) ...[
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFA7F3D0))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Kembalian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
              Text(formatRupiah(_kembalian!),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildQrisCard(bool isDark) {
    // Check if uploaded QRIS image exists
    final hasQrisImage = _qrisImagePath != null &&
        _qrisImagePath!.isNotEmpty &&
        File(_qrisImagePath!).existsSync();
    final hasQrisString = _qrisString != null && _qrisString!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: _sectionCard(isDark),
      child: Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.qr_code_2, color: Color(0xFF6366F1), size: 18),
        ),
        SizedBox(height: 14),
        if (hasQrisImage) ...[
          // ── Uploaded QRIS photo (priority 1) ──
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NusaConfig.dividerColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_qrisImagePath!),
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text('Scan QRIS untuk membayar',
              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        ] else if (hasQrisString) ...[
          // ── Generated QR code from text (priority 2) ──
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NusaConfig.dividerColor)),
            child: QrImageView(data: _qrisString!, version: QrVersions.auto, size: 180),
          ),
          SizedBox(height: 12),
          Text('Scan QRIS untuk membayar',
              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        ] else ...[
          // ── No QRIS configured ──
          Icon(Icons.qr_code, size: 64, color: isDark ? NusaConfig.darkTextSecondary : Colors.grey),
          SizedBox(height: 8),
              Text('Set QRIS di Pengaturan',
                style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : Colors.grey, fontSize: 15)),
        ],
      ]),
    );
  }

  Widget _buildTransferCard(bool isDark) {
    final bankName = _bankName ?? '';
    final bankAccount = _bankAccount ?? '';
    final bankHolder = _bankHolder ?? '';
    final hasBankInfo = bankName.isNotEmpty || bankAccount.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.account_balance, size: 26, color: Color(0xFF6366F1)),
        ),
        SizedBox(height: 12),
        if (hasBankInfo) ...[
          Text('Transfer ke rekening', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              if (bankName.isNotEmpty)
                Text(bankName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              if (bankAccount.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(bankAccount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    fontFamily: 'monospace', letterSpacing: 1, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              ],
              if (bankHolder.isNotEmpty) ...[
                SizedBox(height: 4),
                Text('a.n. $bankHolder', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
              ],
            ]),
          ),
        ] else ...[
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: isDark ? NusaConfig.darkTextSecondary : Colors.grey),
          SizedBox(height: 8),
              Text('Atur rekening di Pengaturan',
                style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : Colors.grey, fontSize: 15)),
        ],
      ]),
    );
  }

  Widget _buildPointsBadge(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
        SizedBox(width: 4),
        if (_pointsUsed > 0)
          Text('${_selectedCustomer!.points - _pointsUsed} → ${_pointsUsed} pts',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)))
        else
          Text('${_selectedCustomer!.points} pts',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
      ]),
    );
  }

  Future<void> _printSplitBills(int numPeople, int perPerson, List<CartItem> cart) async {
    // Pre-flight: check Bluetooth permissions & state
    if (!await ReceiptPrinter.ensureBluetoothReady()) {
      if (mounted) TopToast.error(context, 'Bluetooth tidak siap. Periksa izin & nyalakan Bluetooth.');
      return;
    }

    final printer = ReceiptPrinter();
    try {
      final devices = await printer.discover();
      if (devices.isEmpty) {
        if (mounted) TopToast.error(context, 'Sambungkan printer di Pengaturan');
        return;
      }

      final saved = await SettingsRepository(ref.read(databaseProvider)).getPrinterAddress();
      PrinterDevice target = devices.first;
      if (saved != null && saved.contains('|')) {
        final savedAddr = saved.split('|').last;
        final found = devices.where((d) => d.address == savedAddr);
        if (found.isNotEmpty) target = found.first;
      }

      final paperSize = await SecureStore.getPaperSize();
      final logoPath2 = await SecureStore.getPrinterLogoPath();
      if (logoPath2 != null) await ReceiptPrinter.loadLogo(logoPath2);
      await printer.connect(target);

      for (int i = 1; i <= numPeople; i++) {
        final lines = cart.map((c) => ReceiptLine(name: c.name, qty: c.qty, price: c.price)).toList();
        final notes = cart.map((c) => c.note).toList();
        await printer.printReceipt(
          storeName: 'Split ${i}/$numPeople',
          lines: lines,
          total: perPerson,
          discount: 0,
          paymentMethod: 'Split',
          cashierName: 'Split Bill',
          paperWidth: paperSize,
          orderType: _orderType,
          tableName: _tableName,
          itemNotes: notes,
        );
      }

      await printer.dispose();
      if (mounted) TopToast.success(context, '$numPeople struk berhasil dicetak');
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal mencetak split bill');
    }
  }

  void _showRedeemPoints() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxPts = _selectedCustomer?.points ?? 0;
    final maxRp = maxPts; // 1 poin = Rp 1
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tukar Poin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kamu punya ${_selectedCustomer?.points ?? 0} poin.',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 4),
            Text('1 poin = Rp 1',
                style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : Colors.grey.shade600)),
            SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah poin',
                hintText: 'Maksimal $maxRp',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final val = int.tryParse(v) ?? 0;
                if (val > maxPts) ctrl.text = maxPts.toString();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final pts = int.tryParse(ctrl.text) ?? 0;
              if (pts <= 0 || pts > maxPts) return;
              setState(() => _pointsUsed = pts);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white),
            child: Text('Tukar'),
          ),
        ],
      ),
    );
  }

  // ── Customer quick-add from checkout ──

  /// Shows a bottom sheet to register a new customer on the spot.
  /// Returns the newly created Customer, or null if cancelled.
  Future<Customer?> _showAddCustomerSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Daftar Pelanggan Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nama Pelanggan',
                  hintText: 'Cth: Dimas',
                  filled: true,
                  fillColor: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telepon (opsional)',
                  hintText: 'Cth: 0812xxxx',
                  filled: true,
                  fillColor: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Nama wajib diisi')),
                        );
                      }
                      return;
                    }
                    final repo = CustomerRepository(ref.read(databaseProvider));
                    final id = await repo.addCustomer(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                    );
                    final created = await repo.byId(id);
                    Navigator.pop(ctx, created);
                  },
                  child: const Text('Daftar'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Customer picker dialog with "Tambah Baru" option.
class _CustomerPickerDialog extends StatelessWidget {
  final List<Customer> customers;
  final VoidCallback onAddNew;

  const _CustomerPickerDialog({
    required this.customers,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text('Pilih Pelanggan'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Tambah Baru" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Daftar Pelanggan Baru'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NusaConfig.activePrimary,
                  side: BorderSide(color: NusaConfig.activePrimary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (customers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: customers.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(customers[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${formatRupiah(customers[i].totalSpent)} • ${customers[i].level}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, customers[i]),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Belum ada pelanggan',
                  style: TextStyle(
                    color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
