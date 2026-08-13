import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:intl/intl.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/cashier_session_repository.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/debt_repository.dart';
import 'package:nusa_kasir/data/repositories/dining_table_repository.dart';
import 'package:nusa_kasir/data/repositories/laundry_order_repository.dart';
import 'package:nusa_kasir/data/repositories/appointment_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/promo_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/data/repositories/tab_repository.dart';
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
  int _pointsUsed = 0; // poin yang ditukar (1 poin = Rp 1)
  bool _promoLoading = false; // untuk tombol pilih diskon
  bool _hasBebasPromos = false; // ada promo mode 'bebas' yang bisa dipilih di kasir

  // Split bill
  bool _splitBill = false;
  int _splitCount = 2;

  // DP (uang muka): bayar sebagian sekarang, sisanya dicatat sebagai piutang.
  // Lazim di servis/bengkel/salon (biasanya 50%), tapi bisa untuk semua varian.
  bool _dpEnabled = false;
  final _dpCtrl = TextEditingController();

  // FnB params
  String? _orderType;
  int? _tableId;
  String? _tableName;
  int? _activeTabId;

  // Salon booking params
  DateTime _salonDate = DateTime.now();
  final _salonTimeCtrl = TextEditingController(text: '09:00');
  final _salonStylistCtrl = TextEditingController();
  int _salonDuration = 60;

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

  /// Diskon promo dihitung ULANG dari subtotal saat itu (bukan beku di apply).
  /// - persen  → proporsional terhadap subtotal (otomatis mengikuti perubahan keranjang)
  /// - nominal → tetap, tapi tidak boleh melebihi subtotal
  /// - Jika subtotal turun di bawah min. belanja → 0 (promo tetap terpasang).
  int get _promoDiscount {
    final p = _appliedPromo;
    if (p == null) return 0;
    if (_subtotal < p.minBelanja) return 0;
    final d = p.type == 'persen'
        ? (_subtotal * p.value / 100).round()
        : p.value;
    return d.clamp(0, _subtotal);
  }

  int get _totalDiscount =>
      (_manualDiscount + _promoDiscount + _tierDiscount + _pointsUsed).clamp(0, _subtotal);
  int get _total => (_subtotal - _totalDiscount).clamp(0, _subtotal);
  int? get _kembalian =>
      _cashGiven != null && _cashGiven! >= _total ? _cashGiven! - _total : null;

  /// Nominal DP yang dipakai transaksi ini (0 jika DP mati).
  /// Saat DP aktif, uang muka = jumlah dibayar sekarang; sisa jadi piutang.
  int get _downPayment => _dpEnabled ? (int.tryParse(_dpCtrl.text) ?? 0) : 0;

  /// Sisa yang belum dibayar (piutang) — hanya saat DP aktif.
  int get _remainingDue => _downPayment > 0 ? (_total - _downPayment).clamp(0, _total) : 0;

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
    _checkBebasPromos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoApplyPromo();
      final extra = GoRouterState.of(context).uri.queryParameters;
      if (extra['orderType'] != null) {
        _orderType = extra['orderType'];
        _tableId = int.tryParse(extra['tableId'] ?? '');
        _tableName = extra['tableName'] != null ? Uri.decodeComponent(extra['tableName']!) : null;
        _activeTabId = int.tryParse(extra['activeTabId'] ?? '');
        if (mounted) setState(() {});
      }
      // ── Route customer (dari servis/booking: "Kasir" trigger) ──
      final customer = extra['customer'];
      final customerPhone = extra['customerPhone'];
      if ((customer != null && customer.isNotEmpty) ||
          (customerPhone != null && customerPhone.isNotEmpty)) {
        _preselectCustomer(
          name: customer != null ? Uri.decodeComponent(customer) : null,
          phone: customerPhone != null ? Uri.decodeComponent(customerPhone) : null,
        );
      }
    });
  }

  /// Auto-select the customer passed via route params (servis/booking →
  /// POS → checkout). If a customer with that phone exists, use it; otherwise
  /// create a lightweight record so the transaction still records the name.
  Future<void> _preselectCustomer({String? name, String? phone}) async {
    final repo = CustomerRepository(ref.read(databaseProvider));
    Customer? found;
    final cleanPhone = phone != null && phone.isNotEmpty ? phone : null;
    if (cleanPhone != null) {
      found = await repo.byPhone(cleanPhone);
    }
    if (found == null && name != null && name.isNotEmpty) {
      final all = await repo.getCustomers();
      found = all.cast<Customer?>().firstWhere(
            (c) => c!.name.toLowerCase() == name.toLowerCase(),
            orElse: () => null,
          );
    }
    if (found == null && name != null && name.isNotEmpty) {
      final id = await repo.addCustomer(name: name, phone: cleanPhone);
      found = await repo.byId(id);
    }
    if (found != null && mounted) {
      setState(() {
        _selectedCustomer = found;
        _pointsUsed = 0;
      });
    }
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
    _dpCtrl.dispose();
    _salonTimeCtrl.dispose();
    _salonStylistCtrl.dispose();
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
          (p) => p!.code.toUpperCase() == code.toUpperCase() &&
              p.status == 'Aktif' &&
              p.mode != 'otomatis', // otomatis tidak pakai kode
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

    // Calculate discount (percent promo follows the live subtotal via getter)
    final discount = (match.type == 'persen'
            ? (_subtotal * match.value / 100).round()
            : match.value)
        .clamp(0, _subtotal);

    setState(() {
      _appliedPromo = match;
    });
    TopToast.success(context, 'Promo "${match.name}" diterapkan! '
        'Diskon ${formatRupiah(discount)}');
  }

  void _clearPromo() {
    setState(() {
      _appliedPromo = null;
      _promoCtrl.clear();
    });
  }

  /// Promo aktif & valid secara umum (status, tanggal, kuota).
  bool _isPromoUsable(Promo p, {required bool checkMin}) {
    if (p.status != 'Aktif') return false;
    final now = DateTime.now();
    if (p.startDate != null && p.startDate!.isAfter(now)) return false;
    if (p.endDate != null && p.endDate!.isBefore(now)) return false;
    if (p.maxUses != null && p.usedCount >= p.maxUses!) return false;
    if (checkMin && _subtotal < p.minBelanja) return false;
    return true;
  }

  /// Promo yang BISA dipilih manual di kasir (mode 'bebas').
  Future<List<Promo>> _getSelectablePromos() async {
    final repo = PromoRepository(ref.read(databaseProvider));
    final promos = await repo.getPromos();
    return promos.where((p) =>
        p.mode == 'bebas' && _isPromoUsable(p, checkMin: true)).toList();
  }

  /// Refresh flag: apakah ada promo mode 'bebas' (tombol "Pilih diskon dari
  /// daftar" disembunyikan kalau tidak ada — hindari tombol yang selalu kosong).
  Future<void> _checkBebasPromos() async {
    try {
      final repo = PromoRepository(ref.read(databaseProvider));
      final promos = await repo.getPromos();
      final has = promos.any((p) =>
          p.mode == 'bebas' && _isPromoUsable(p, checkMin: false));
      if (mounted && has != _hasBebasPromos) {
        setState(() => _hasBebasPromos = has);
      }
    } catch (_) {}
  }

  /// Auto-apply promo mode 'otomatis' (diskon terbesar yang memenuhi syarat).
  /// Tidak menimpa promo yang sudah dipasang manual (kode/bebas).
  Future<void> _maybeAutoApplyPromo() async {
    if (_appliedPromo != null) return;
    final repo = PromoRepository(ref.read(databaseProvider));
    final promos = await repo.getPromos();
    Promo? best;
    int bestDisc = 0;
    for (final p in promos) {
      if (p.mode != 'otomatis') continue;
      if (!_isPromoUsable(p, checkMin: true)) continue;
      final d = p.type == 'persen'
          ? (_subtotal * p.value / 100).round()
          : p.value;
      if (d > bestDisc) { best = p; bestDisc = d; }
    }
    if (best != null && bestDisc > 0 && mounted) {
      setState(() => _appliedPromo = best);
    }
  }

  /// Bottom sheet daftar diskon yang bisa dipilih (mode 'bebas').
  Future<void> _showPickDiscountSheet() async {
    if (_promoLoading) return;
    setState(() => _promoLoading = true);
    try {
      final list = await _getSelectablePromos();
      if (!mounted) return;
      final selected = await showModalBottomSheet<Promo>(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: NusaConfig.dividerColor, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(children: [
                    Icon(Icons.local_offer_outlined, size: 20, color: NusaConfig.activePrimary),
                    const SizedBox(width: 8),
                    Text('Pilih Diskon', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                  ]),
                ),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Belum ada diskon yang bisa dipilih.\nBuat promo dengan mode "Pilih di Kasir".',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13,
                            color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return ListTile(
                          leading: Icon(Icons.discount_outlined, color: NusaConfig.activePrimary),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${p.type == 'persen' ? '${p.value}%' : formatRupiah(p.value)}'
                            '${p.minBelanja > 0 ? ' • Min. ${formatRupiah(p.minBelanja)}' : ''}',
                            style: TextStyle(fontSize: 12,
                                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                          ),
                          trailing: _appliedPromo?.id == p.id
                              ? Icon(Icons.check_circle, color: NusaConfig.accentGreen)
                              : Icon(Icons.chevron_right, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                          onTap: () => Navigator.of(ctx).pop(p),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      if (selected != null && mounted) {
        setState(() {
          _appliedPromo = selected;
          _promoCtrl.clear();
        });
        final d = selected.type == 'persen'
            ? (_subtotal * selected.value / 100).round()
            : selected.value;
        TopToast.success(context, 'Diskon "${selected.name}" diterapkan! '
            'Potongan ${formatRupiah(d.clamp(0, _subtotal))}');
      }
    } finally {
      if (mounted) setState(() => _promoLoading = false);
    }
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
              _dpEnabled = false;
              _dpCtrl.clear();
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
        _dpEnabled = false;
        _dpCtrl.clear();
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

    // Validasi jumlah bayar sebelum proses.
    //  - Tunai tanpa DP: jumlah dibayar (cashGiven) harus ≥ total.
    //  - Tunai dengan DP: DP harus > 0 dan < total (sisa dicatat piutang).
    //  - EDC / QRIS / Transfer: lunas dianggap dibayar penuh.
    if (_paymentMethod == 'Tunai' && _dpEnabled) {
      final dp = _downPayment;
      if (dp <= 0) {
        TopToast.error(context, 'Isi nominal uang muka (DP)');
        return;
      }
      if (dp >= _total) {
        TopToast.error(context, 'DP harus kurang dari total (sisanya piutang)');
        return;
      }
      if (_selectedCustomer == null) {
        TopToast.error(context, 'Pilih pelanggan dulu untuk mencatat sisa piutang');
        return;
      }
    } else if (_paymentMethod == 'Tunai') {
      final given = int.tryParse(_cashCtrl.text) ?? 0;
      if (given < _total) {
        TopToast.error(context, 'Jumlah dibayarkan kurang');
        return;
      }
    }

    // Validate stock before deducting (item manual — productId negatif — dilewati)
    final db = ref.read(databaseProvider);
    final productRepo = ProductRepository(db);
    for (final item in cart) {
      if (item.isManual) continue;
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
      // Saat DP aktif, total = harga penuh; yang dibayar di kasir hanya DP.
      // Sisa otomatis dicatat sebagai piutang pelanggan (lihat di bawah).
      final dp = _paymentMethod == 'Tunai' && _dpEnabled ? _downPayment : 0;
      final isDownPayment = dp > 0;

      // Wrap all DB writes (stock, transaction, loyalty, promo) in a single transaction.
      // If any step fails, it all rolls back — no partial state.
      int pointsEarned = 0;
      await db.transaction(() async {
        // Deduct stock for each item (item manual tidak punya stok)
        for (final item in cart) {
          if (item.isManual) continue;
          await productRepo.adjustStock(item.productId, -item.qty);
        }

        // Save transaction
        // employeeId = logged-in employee; sessionId = active cashier shift
        // (so each cashier's dashboard shows only their own shift's sales).
        final activeShift = await CashierSessionRepository(db).getActive();
        final savedTxId = await transactionRepo.saveTransaction(
          items: cart,
          total: _total,
          discount: _totalDiscount,
          paymentMethod: _paymentMethod,
          cashGiven: isDownPayment ? dp : cashGiven,
          cashReturn: isDownPayment ? null : cashReturn,
          cashierName: cashierName,
          customerId: _selectedCustomer?.id,
          branchId: ref.read(activeBranchProvider)?.id,
          orderType: _orderType,
          tableId: _tableId,
          employeeId: session?.employeeId,
          sessionId: activeShift?.id,
        );

        // ── DP: catat sisa sebagai piutang pelanggan ──
        // Total transaksi tetap utuh (laporan omzet benar); uang muka tercatat
        // di transaksi (cashGiven = dp), sisa tercatat di Piutang (menu Utang)
        // sampai pelanggan melunasi lewat menu tersebut.
        if (isDownPayment && _selectedCustomer != null) {
          final debtRepo = DebtRepository(db);
          await debtRepo.addDebt(
            customerId: _selectedCustomer!.id,
            customerName: _selectedCustomer!.name,
            amount: _total - dp,
            description: 'Sisa bayar transaksi INV $savedTxId (DP ${formatRupiah(dp)})',
          );
        }

        // Update customer loyalty
        if (_selectedCustomer != null) {
          final pointConfig = await SettingsRepository(db).getPointConfig();
          final cust = await CustomerRepository(db).byId(_selectedCustomer!.id);
          final beforePoints = cust?.points ?? 0;
          await CustomerRepository(db).addSpent(
            _selectedCustomer!.id, _total,
            pointsPerRupiah: pointConfig['pointsPerRupiah']!,
            goldThreshold: pointConfig['goldThreshold']!,
            platinumThreshold: pointConfig['platinumThreshold']!,
            transactionId: savedTxId,
          );
          // Poin yang didapat transaksi ini: (total belanja / poin per rupiah).
          // Saldo poin dihitung kumulatif dari totalSpent, jadi hitung delta.
          final after = await CustomerRepository(db).byId(_selectedCustomer!.id);
          pointsEarned = ((after?.points ?? 0) - beforePoints).clamp(0, 1 << 30);
        }

        // Increment promo usage
        if (_appliedPromo != null) {
          await PromoRepository(db).incrementUsed(_appliedPromo!.id);
        }

        // Redeem loyalty points
        if (_selectedCustomer != null && _pointsUsed > 0) {
          await CustomerRepository(db).redeemPoints(
              _selectedCustomer!.id, _pointsUsed,
              transactionId: savedTxId);
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
            if (c.originalPrice != null) 'originalPrice': c.originalPrice,
            if (c.costPrice != null) 'costPrice': c.costPrice,
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

      // ── Salon: auto-create Appointment after successful transaction ──
      int? _bookingId;
      if (NusaConfig.isSalonVariant && cart.isNotEmpty) {
        try {
          final aptRepo = AppointmentRepository(db);
          final services = cart.map((c) => c.name).join(', ');
          _bookingId = await aptRepo.add(
            customerName: _selectedCustomer?.name ?? 'Umum',
            customerPhone: _selectedCustomer?.phone,
            service: services,
            stylist: _salonStylistCtrl.text.trim().isEmpty ? null : _salonStylistCtrl.text.trim(),
            date: _salonDate,
            timeSlot: _salonTimeCtrl.text,
            estimatedDuration: _salonDuration,
            notes: cart.where((c) => c.note != null && c.note!.isNotEmpty)
                .map((c) => '${c.name}: ${c.note}').join('; '),
          );
        } catch (_) {}
      }

      ref.read(cartProvider.notifier).clear();

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
          downPayment: isDownPayment ? dp : 0,
          remainingDue: isDownPayment ? _total - dp : 0,
          cashierName: cashierName,
          customerName: _selectedCustomer?.name,
          customerPhone: _selectedCustomer?.phone,
          invoice: invoice,
          dateStr: dateStr,
          pointsUsed: _pointsUsed,
          pointsEarned: pointsEarned,
          autoPrint: autoPrint && !_splitBill, // split bill prints separately
          orderType: savedOrderType,
          tableName: savedTableName,
          laundryOrderId: _laundryOrderId,
          salonBookingId: _bookingId,
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
    // Auto-apply promo otomatis saat keranjang berubah (tanpa timpa promo manual).
    ref.listen(cartProvider, (_, __) => _maybeAutoApplyPromo());
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

          // ── Salon Booking Card (salon variant with jasa items) ──
          if (NusaConfig.isSalonVariant && _subtotal > 0) ...[
            _buildSalonBookingCard(isDark),
            SizedBox(height: 14),
          ],

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
          if (_paymentMethod == 'EDC / Kartu') _buildEdcCard(isDark),

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

  // ── Salon Booking Card ─────────────────────────────────────────────

  Widget _buildSalonBookingCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _sectionCard(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: NusaConfig.info.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.event_available, color: NusaConfig.info, size: 18),
          ),
          SizedBox(width: 10),
          Text('Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Spacer(),
          Text('#BKG-...', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
        ]),
        SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _salonDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _salonDate = d);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_salonDate), style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
              ),
              child: TextField(
                controller: _salonTimeCtrl,
                keyboardType: TextInputType.datetime,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                decoration: const InputDecoration.collapsed(hintText: 'HH:mm'),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _salonDuration,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30mnt')),
                    DropdownMenuItem(value: 45, child: Text('45mnt')),
                    DropdownMenuItem(value: 60, child: Text('60mnt')),
                    DropdownMenuItem(value: 90, child: Text('90mnt')),
                    DropdownMenuItem(value: 120, child: Text('2jam')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _salonDuration = v); },
                ),
              ),
            ),
          ),
        ]),
        SizedBox(height: 10),
        TextField(
          controller: _salonStylistCtrl,
          decoration: InputDecoration(
            hintText: 'Stylist (opsional)',
            hintStyle: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            filled: true,
            fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
        ),
      ]),
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
          if (_promoDiscount == 0 && _appliedPromo!.minBelanja > 0) ...[
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.info_outline, size: 13, color: Colors.amber.shade700),
              SizedBox(width: 4),
              Text('Min. belanja ${formatRupiah(_appliedPromo!.minBelanja)} belum terpenuhi',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
            ]),
          ],
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

        // ── Pilih Diskon (mode 'bebas') ──
        // Sembunyikan tombol kalau tidak ada promo mode 'bebas' yang aktif —
        // hindari tombol yang selalu muncul tapi daftarnya kosong.
        if (_hasBebasPromos || _appliedPromo?.mode == 'bebas') ...[
          SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _promoLoading ? null : _showPickDiscountSheet,
                icon: _promoLoading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.discount_outlined, size: 16),
                label: Text(_appliedPromo != null
                    ? 'Ganti diskon dari daftar'
                    : 'Pilih diskon dari daftar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NusaConfig.activePrimary,
                  side: BorderSide(color: NusaConfig.activePrimary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 10),
                  textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ],

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
          SizedBox(width: 10),
          _payCard('EDC / Kartu', Icons.credit_card, isDark),
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
        SizedBox(height: 14),
        Divider(color: Colors.grey.withValues(alpha: 0.15)),
        SizedBox(height: 4),
        _buildDpSection(isDark),
      ]),
    );
  }

  /// Bagian DP (uang muka) — bayar sebagian sekarang, sisanya piutang.
  /// Tersedia untuk semua varian (lazim di servis/bengkel/salon).
  Widget _buildDpSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Uang Muka (DP)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
              SizedBox(height: 2),
              Text('Bayar sebagian sekarang, sisa dicatat piutang',
                  style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
            ]),
          ),
          Switch(
            value: _dpEnabled,
            activeThumbColor: NusaConfig.activePrimary,
            onChanged: (v) => setState(() {
              _dpEnabled = v;
              if (!v) _dpCtrl.clear();
            }),
          ),
        ]),
        if (_dpEnabled) ...[
          SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _dpCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Rp 0',
                  hintStyle: TextStyle(fontSize: 18, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  filled: true,
                  fillColor: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF9FAFB),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: NusaConfig.activePrimary, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Quick chip: 50% total (lazim untuk servis/bengkel/salon)
            GestureDetector(
              onTap: () {
                final half = (_total / 2).ceil();
                _dpCtrl.text = half.toString();
                setState(() {});
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: NusaConfig.activeSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NusaConfig.activePrimary.withValues(alpha: 0.4)),
                ),
                child: Text('50%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary)),
              ),
            ),
          ]),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _dpRow('Uang muka (dibayar)', formatRupiah(_downPayment), isDark),
              SizedBox(height: 4),
              _dpRow('Sisa piutang', formatRupiah(_remainingDue), isDark),
              SizedBox(height: 6),
              Text('Pelanggan wajib dipilih — sisa otomatis dicatat di menu Utang.',
                  style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : const Color(0xFF854D0E))),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _dpRow(String label, String value, bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : const Color(0xFF854D0E))),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: isDark ? NusaConfig.darkTextPrimary : const Color(0xFF854D0E))),
    ]);
  }

  /// EDC / Kartu debit-kredit: pembayaran lewat mesin EDC.
  /// Dianggap lunas (total) — tidak ada input nominal, hanya info.
  Widget _buildEdcCard(bool isDark) {
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
          decoration: BoxDecoration(color: Color(0xFF0D9488).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.credit_card, size: 26, color: Color(0xFF0D9488)),
        ),
        SizedBox(height: 12),
        Text('Bayar dengan mesin EDC',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
        SizedBox(height: 4),
        Text('Total ${formatRupiah(_total)}',
            style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        SizedBox(height: 4),
        Text('Swipe / tap kartu di mesin, lalu konfirmasi.',
            style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
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
                cacheWidth: 400,
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

      final saved = await SecureStore.getPrinterAddress();
      PrinterDevice? target;
      if (saved != null && saved.contains('|')) {
        final savedAddr = saved.split('|').last;
        final found = devices.where((d) => d.address == savedAddr);
        if (found.isNotEmpty) target = found.first;
      }
      if (target == null) {
        if (mounted) TopToast.error(context, 'Printer belum diatur. Pilih printer di Pengaturan.');
        printer.dispose();
        return;
      }

      final paperSize = await SecureStore.getPaperSize();
      final logoPath2 = await SecureStore.getPrinterLogoPath();
      if (logoPath2 != null) await ReceiptPrinter.loadLogo(logoPath2);
      await printer.connect(target);

      for (int i = 1; i <= numPeople; i++) {
        final lines = cart.map((c) => ReceiptLine(name: c.name, qty: c.qty, price: c.price, originalPrice: c.originalPrice)).toList();
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
