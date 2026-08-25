import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/sound_service.dart';
import 'package:nusa_kasir/core/services/online_order_service.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/online_order_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/core/utils/wa_phone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class OnlineOrdersScreen extends ConsumerStatefulWidget {
  OnlineOrdersScreen({super.key});
  @override
  ConsumerState<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends ConsumerState<OnlineOrdersScreen>
    with SingleTickerProviderStateMixin {
  List<OnlineOrder> _orders = [];
  List<OnlineOrder> _allOrders = []; // unfiltered cache for stats
  bool _loading = true;
  late TabController _tabController;
  RealtimeChannel? _channel;
  // Label tab = status AKTUAL di DB (satu sumber). Sebelumnya 'Verifikasi'/
  // 'Baru' tidak cocok dengan status asli ("Menunggu Verifikasi Pembeli"/
  // "Online Baru") sehingga filter dua tab itu TIDAK berfungsi (v2.2.27).
  final List<String> _tabs = [
    'Semua',
    'Menunggu Verifikasi Pembeli',
    'Online Baru',
    'Disiapkan',
    'Siap Diambil',
    'Lunas',
    'Direfund',
  ];
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _filter();
    });
    _search.addListener(_applySearch);
    _load();
    _listenSupabase();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tabController.dispose();
    _search.removeListener(_applySearch);
    _search.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _search.text.toLowerCase();
    setState(() {
      _query = q;
    });
  }

  Future<void> _load() async {
    final repo = OnlineOrderRepository(ref.read(databaseProvider));
    final all = await repo.getAll();
    if (mounted)
      setState(() {
        _allOrders = all;
        _filter();
      });
  }

  void _filter() {
    setState(() => _loading = true);
    final idx = _tabController.index;
    // Tab label = status aktual → filter langsung cocok tanpa mapping.
    final status = idx == 0 ? null : _tabs[idx];
    var filtered = _allOrders;
    if (status != null) {
      filtered = filtered.where((o) => o.status == status).toList();
    }
    if (_query.isNotEmpty) {
      filtered = filtered
          .where(
            (o) =>
                o.invoice.toLowerCase().contains(_query) ||
                o.customerName.toLowerCase().contains(_query) ||
                o.customerPhone.contains(_query),
          )
          .toList();
    }
    if (mounted)
      setState(() {
        _orders = filtered;
        _loading = false;
      });
  }

  void _listenSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final svc = OnlineOrderService(supabase);
      final storeId = await svc.storeId;
      if (storeId == null) return;

      _channel = supabase
          .channel('online-orders-$storeId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'online_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (payload) {
              // ORDER BARU MASUK — simpan ke DB lokal SEKARANG (bukan nunggu
              // polling 2 menit stok_alert_worker) + notif realtime. Ini
              // akar "notif delay" — sebelumnya callback hanya _load() dari
              // DB lokal yang belum berisi order baru.
              _handleRealtimeInsert(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'online_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (payload) {
              if (mounted) _load();
            },
          )
          .subscribe();
    } catch (e) {
      // ignore: avoid_print
      print('[OnlineOrders] Gagal subscribe Supabase realtime: $e');
    }
  }

  /// Order baru dari realtime — tulis ke DB lokal (anti-duplikat by invoice)
  /// lalu refresh list + toast/sound notif. Kalau gagal parse, tetap refresh
  /// (kemungkinan order lama masuk dari polling).
  Future<void> _handleRealtimeInsert(Map<String, dynamic> rec) async {
    final db = ref.read(databaseProvider);
    final invoice = rec['invoice'] as String? ?? '';
    try {
      // Payload realtime bisa punya keys lowercase — petakan ke kolom lokal.
      final existing = invoice.isNotEmpty
          ? await (db.select(db.onlineOrders)
                ..where((t) => t.invoice.equals(invoice)))
              .getSingleOrNull()
          : null;
      if (existing == null) {
        await db.into(db.onlineOrders).insert(
          OnlineOrdersCompanion.insert(
            invoice: invoice,
            customerName: rec['customer_name'] as String? ?? '',
            customerPhone: rec['customer_phone'] as String? ?? '',
            items: jsonEncode(rec['items']),
            total: (rec['total'] as num?)?.toInt() ?? 0,
            subtotal: Value((rec['subtotal'] as num?)?.toInt() ?? 0),
            discount: Value((rec['discount'] as num?)?.toInt() ?? 0),
            handlingFee: Value((rec['handling_fee'] as num?)?.toInt() ?? 0),
            paymentMethod:
                Value(rec['payment_method'] as String? ?? 'Tunai'),
            pickupTime: Value(rec['pickup_time'] as String?),
            branch: Value(rec['branch'] as String? ?? 'Pusat'),
            notes: Value(rec['notes'] as String?),
            status: Value(rec['status'] as String? ?? 'Online Baru'),
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[OnlineOrders] Gagal simpan order realtime $invoice: $e');
    }
    if (!mounted) return;
    _load();
    // Notif visual realtime: toast di atas layar + bunyi notif sistem.
    // (Jika sedang di layar ini, kasir langsung lihat order baru.)
    final cust = rec['customer_name'] as String? ?? '';
    TopToast.show(
      context,
      '🛒 Pesanan baru${cust.isNotEmpty ? ' dari $cust' : ''} masuk!',
      type: ToastType.info,
      duration: const Duration(seconds: 4),
    );
    HapticFeedback.mediumImpact();
    SoundService.I.play(NusaSound.ding);
  }

  /// State machine transition buttons
  List<Widget> _actionsFor(OnlineOrder order) {
    final buttons = <Widget>[];
    final status = order.status;

    if (status == 'Menunggu Verifikasi Pembeli') {
      // Pembeli pakai non-tunai (QRIS/transfer) → belum kirim bukti.
      buttons.add(
        _actionBtn(
          'Terima & Proses',
          NusaConfig.accentGold,
          () => _transition(order, 'Online Baru'),
        ),
      );
      buttons.add(SizedBox(height: 6));
      buttons.add(
        _actionBtn(
          'Tolak / Batal',
          NusaConfig.activePrimary,
          () => _transition(order, 'Dibatalkan'),
        ),
      );
    } else if (status == 'Online Baru') {
      buttons.add(
        _actionBtn(
          'Terima & Siapkan',
          NusaConfig.accentGreen,
          () => _transition(order, 'Disiapkan'),
        ),
      );
      buttons.add(SizedBox(height: 6));
      buttons.add(
        _actionBtn(
          'Tolak / Batal',
          NusaConfig.activePrimary,
          () => _transition(order, 'Dibatalkan'),
        ),
      );
    } else if (status == 'Disiapkan') {
      buttons.add(
        _actionBtn(
          'Siap Diambil',
          NusaConfig.accentPurple,
          () => _transition(order, 'Siap Diambil'),
        ),
      );
      buttons.add(SizedBox(height: 6));
      buttons.add(
        _actionBtn(
          'Batal',
          NusaConfig.activePrimary,
          () => _transition(order, 'Dibatalkan'),
        ),
      );
    } else if (status == 'Siap Diambil') {
      buttons.add(
        _actionBtn(
          'Selesai (Lunas)',
          NusaConfig.accentGreenDark,
          () => _completeOrder(order),
        ),
      );
      buttons.add(SizedBox(height: 6));
      buttons.add(
        _actionBtn(
          'Batal',
          NusaConfig.activePrimary,
          () => _transition(order, 'Dibatalkan'),
        ),
      );
    } else if (status == 'Lunas' || status == 'Dibatalkan') {
      buttons.add(
        _actionBtn('Refund', Color(0xFF6B7280), () => _refundOrder(order)),
      );
    }

    return buttons;
  }

  Future<void> _transition(OnlineOrder order, String newStatus) async {
    // Confirm
    final labels = {
      'Disiapkan': 'Terima pesanan & mulai siapkan?',
      'Siap Diambil': 'Tandai pesanan siap diambil?',
      'Dibatalkan': 'Yakin batalkan pesanan ini?',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          newStatus == 'Dibatalkan' ? 'Batalkan Pesanan' : 'Update Status',
        ),
        content: Text(labels[newStatus] ?? 'Update ke "$newStatus"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Tidak'),
          ),
          NusaButton(
            newStatus == 'Dibatalkan' ? 'Ya, Batalkan' : 'Ya, Lanjutkan',
            fullWidth: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Update local DB
    final session = ref.read(employeeSessionProvider);
    final repo = OnlineOrderRepository(ref.read(databaseProvider));
    await repo.updateStatus(order.id, newStatus, processedBy: session?.name);

    // Update Supabase
    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      await svc.updateOrderStatus(
        orderId: order.id,
        status: newStatus,
        processedBy: session?.name,
      );
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Gagal sync ke server: $e');
      }
    }

    if (mounted) {
      TopToast.success(context, 'Pesanan #${order.invoice}: $newStatus');
      _load();
    }
  }

  Future<void> _completeOrder(OnlineOrder order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Selesaikan Pesanan'),
        content: Text(
          'Pesanan #${order.invoice} selesai?\n\n'
          'Stok akan otomatis berkurang & transaksi tercatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          NusaButton(
            'Selesai',
            fullWidth: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Parse items — fail early if JSON is corrupt
    final List items;
    try {
      items = (jsonDecode(order.items) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (mounted) {
        TopToast.error(
          context,
          'Gagal membaca data pesanan #${order.invoice}. Hubungi developer.',
        );
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final session = ref.read(employeeSessionProvider);
    final productRepo = ProductRepository(db);
    final trxRepo = TransactionRepository(db);
    final customerRepo = CustomerRepository(db);

    final cartItems = items
        .map(
          (i) => {
            'productId': i['product_id'],
            'name': i['name'] ?? '',
            'qty': i['qty'] ?? 1,
            'price': i['price'] ?? 0,
          },
        )
        .toList();

    try {
      // Wrap stock deduction, transaction, loyalty, and status in a single DB transaction.
      // If any step fails, the entire block rolls back — no partial state.
      await db.transaction(() async {
        // Deduct stock for each item
        for (final item in items) {
          final pid = item['product_id'] as int?;
          final qty = item['qty'] as int? ?? 1;
          if (pid != null) {
            await productRepo.adjustStock(pid, -qty);
          }
        }

        // Record transaction locally
        // employeeId = null → online order counts toward ALL cashiers'
        // dashboards (shared revenue, not tied to one shift).
        await trxRepo.addTransaction(
          invoice: order.invoice,
          items: jsonEncode(cartItems),
          total: order.total,
          discount: order.discount,
          cashierName: session?.name ?? 'Sistem',
          paymentMethod: order.paymentMethod,
          branchId: null,
          cashGiven: order.total,
          cashReturn: 0,
          employeeId: null,
        );

        // Add loyalty points for customer (if phone exists)
        // Auto-register customer if they don't exist yet
        if (order.customerPhone.isNotEmpty) {
          var customer = await customerRepo.byPhone(order.customerPhone);
          if (customer == null) {
            // Auto-register: setiap orang yg order online langsung masuk daftar pelanggan
            final newId = await customerRepo.addCustomer(
              name: order.customerName.isNotEmpty
                  ? order.customerName
                  : 'Pelanggan Online',
              phone: order.customerPhone,
            );
            customer = await customerRepo.byId(newId);
          }
          if (customer != null) {
            await customerRepo.addSpent(customer.id, order.total);
          }
        }

        // Update local status to Lunas
        final repo = OnlineOrderRepository(ref.read(databaseProvider));
        await repo.updateStatus(order.id, 'Lunas', processedBy: session?.name);
      });
    } catch (e) {
      if (mounted) {
        TopToast.error(
          context,
          'Gagal menyelesaikan pesanan #${order.invoice}: $e',
        );
      }
      return;
    }

    // Update Supabase (outside transaction — network call)
    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      await svc.updateOrderStatus(
        orderId: order.id,
        status: 'Lunas',
        processedBy: session?.name,
      );
    } catch (_) {
      // Supabase sync failed but local DB is consistent — will sync on next poll
    }

    if (mounted) {
      TopToast.success(context, 'Pesanan #${order.invoice} selesai! ✅');
      _load();
    }
  }

  Future<void> _refundOrder(OnlineOrder order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Refund Pesanan'),
        content: Text(
          'Yakin refund pesanan #${order.invoice}?\n\n'
          'Status akan diubah menjadi "Direfund".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          NusaButton(
            'Refund',
            fullWidth: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final session = ref.read(employeeSessionProvider);
    final repo = OnlineOrderRepository(ref.read(databaseProvider));
    await repo.updateStatus(order.id, 'Direfund', processedBy: session?.name);

    // Try Supabase
    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      await svc.updateOrderStatus(
        orderId: order.id,
        status: 'Direfund',
        processedBy: session?.name,
      );
    } catch (_) {}

    if (mounted) {
      TopToast.success(context, 'Pesanan #${order.invoice}: Direfund');
      _load();
    }
  }

  Widget _actionBtn(String label, Color color, VoidCallback fn) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onPressed: fn,
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Format JSON items list to readable text
  String _formatItems(String itemsJson) {
    try {
      final items = (jsonDecode(itemsJson) as List)
          .cast<Map<String, dynamic>>();
      return items.map((i) => '${i['qty']}x ${i['name']}').join(', ');
    } catch (_) {
      return itemsJson;
    }
  }

  /// Open WhatsApp with customer
  Future<void> _openWA(OnlineOrder order) async {
    if (order.customerPhone.isEmpty) return;
    // Normalisasi via helper (v2.2.35): 0818… → 62818… biar wa.me valid.
    final uri = waLink(order.customerPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _statusColor(String status, bool isDark) {
    switch (status) {
      case 'Menunggu Verifikasi Pembeli':
        return Color(0xFFF59E0B); // amber — menunggu bukti bayar
      case 'Online Baru':
        return NusaConfig.accentGold;
      case 'Disiapkan':
        return NusaConfig.accentGreen;
      case 'Siap Diambil':
        return NusaConfig.accentPurple;
      case 'Lunas':
        return Color(0xFF059669);
      case 'Dibatalkan':
        return NusaConfig.activePrimary;
      case 'Direfund':
        return Color(0xFF6B7280);
      default:
        return isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Stats from cached _allOrders
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayCount = _allOrders
        .where((o) => o.createdAt.isAfter(todayStart))
        .length;
    final pendingCount = _allOrders
        .where(
          (o) =>
              o.status == 'Menunggu Verifikasi Pembeli' ||
              o.status == 'Online Baru' ||
              o.status == 'Disiapkan',
        )
        .length;
    final doneCount = _allOrders.where((o) => o.status == 'Lunas').length;

    return ScreenScaffold(
      _tabs[_tabController.index] == 'Semua'
          ? 'Pesanan Online'
          : 'Pesanan Online — ${_tabs[_tabController.index]}',
      Column(
        children: [
          // Stats row
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Hari Ini',
                      todayCount.toString(),
                      NusaConfig.activePrimary,
                      isDark,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Menunggu',
                      pendingCount.toString(),
                      NusaConfig.accentGold,
                      isDark,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Selesai',
                      doneCount.toString(),
                      NusaConfig.accentGreenDark,
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          // Tab bar
          Container(
            height: 44,
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textTertiary,
              indicator: BoxDecoration(
                color: NusaConfig.activePrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              padding: EdgeInsets.all(4),
              tabs: _tabs
                  .map(
                    (t) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t),
                          if (t != 'Semua') ...[
                            SizedBox(width: 4),
                            _badgeFor(t, isDark),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onTap: (_) => setState(() {}),
            ),
          ),
          // Search (search bar standar v2.2.54)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: NusaSearchBar(
              controller: _search,
              hint: 'Cari invoice atau nama pelanggan…',
            ),
          ),
          SizedBox(height: 4),

          // Order list
          Expanded(
            child: _loading
                ? SkeletonList()
                : _orders.isEmpty
                ? EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    message: 'Belum ada pesanan online',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12),
                      itemBuilder: (_, i) => _orderCard(_orders[i], isDark),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badgeFor(String tab, bool isDark) {
    int count = 0;
    // Tab label = status aktual → hitung langsung (v2.2.27).
    if (tab != 'Semua') {
      count = _allOrders.where((o) => o.status == tab).length;
    }

    if (count == 0) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (tab == 'Menunggu Verifikasi Pembeli' || tab == 'Online Baru')
            ? NusaConfig.activePrimary.withValues(alpha: 0.12)
            : NusaConfig.textTertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: (tab == 'Menunggu Verifikasi Pembeli' || tab == 'Online Baru')
              ? NusaConfig.activePrimary
              : isDark
              ? NusaConfig.darkTextSecondary
              : NusaConfig.textSecondary,
        ),
      ),
    );
  }

  Widget _orderCard(OnlineOrder order, bool isDark) {
    final sColor = _statusColor(order.status, isDark);
    final itemCount = _itemCount(order.items);

    return NusaCard(
      padding: EdgeInsets.zero,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: invoice + status + time ago
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Invoice
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.invoice}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: isDark
                              ? NusaConfig.darkTextPrimary
                              : NusaConfig.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _timeAgo(order.createdAt),
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
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
          ),

          // Customer info
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.customerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                ),
                if (order.customerPhone.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openWA(order),
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Color(0xFF25D366).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💬 WA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF128C7E),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Phone (tappable to WA)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: GestureDetector(
              onTap: order.customerPhone.isNotEmpty
                  ? () => _openWA(order)
                  : null,
              child: Text(
                order.customerPhone.isNotEmpty
                    ? '📱 ${order.customerPhone}'
                    : 'Tanpa nomor WA',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                  decoration: order.customerPhone.isNotEmpty
                      ? TextDecoration.underline
                      : null,
                ),
              ),
            ),
          ),

          // Items + count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _formatItems(order.items),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (itemCount > 0) ...[
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$itemCount item',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: NusaConfig.activePrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 8),

          // Payment + total
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.payment,
                  size: 14,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
                SizedBox(width: 4),
                Text(
                  order.paymentMethod,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                ),
                Spacer(),
                Text(
                  formatRupiah(order.total),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: NusaConfig.activePrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Pickup time
          if (order.pickupTime != null &&
              order.pickupTime!.isNotEmpty &&
              order.pickupTime != 'Segera')
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Pickup: ${order.pickupTime}',
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

          // Action buttons
          if (_actionsFor(order).isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _actionsFor(order),
              ),
            ),
        ],
      ),
    );
  }

  int _itemCount(String itemsJson) {
    try {
      final items = (jsonDecode(itemsJson) as List)
          .cast<Map<String, dynamic>>();
      return items.fold(0, (sum, i) => sum + (i['qty'] as int? ?? 1));
    } catch (_) {
      return 0;
    }
  }

  Widget _statCard(String title, String value, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textSecondary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
