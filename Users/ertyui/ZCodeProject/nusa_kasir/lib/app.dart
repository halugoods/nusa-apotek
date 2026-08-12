import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/theme/nusa_theme.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/features/auth/rbac.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/core/activation/activation_screen.dart';
import 'package:nusa_kasir/core/widgets/splash_screen.dart';
import 'package:nusa_kasir/features/auth/login_screen.dart';
import 'package:nusa_kasir/features/onboarding/onboarding_screen.dart';
import 'package:nusa_kasir/features/dashboard/dashboard_screen.dart';
import 'package:nusa_kasir/features/settings/settings_screen.dart';
import 'package:nusa_kasir/features/products/products_screen.dart';
import 'package:nusa_kasir/features/products/product_form_screen.dart';
import 'package:nusa_kasir/features/products/kategori_list_screen.dart';
import 'package:nusa_kasir/features/products/products_by_category_screen.dart';
import 'package:nusa_kasir/features/stock/stock_screen.dart';
import 'package:nusa_kasir/features/pos/pos_screen.dart';
import 'package:nusa_kasir/features/checkout/checkout_screen.dart';
import 'package:nusa_kasir/features/transactions/transactions_screen.dart';
import 'package:nusa_kasir/features/customers/customers_screen.dart';
import 'package:nusa_kasir/features/promo/promo_screen.dart';
import 'package:nusa_kasir/features/reports/reports_screen.dart';
import 'package:nusa_kasir/features/attendance/attendance_screen.dart';
import 'package:nusa_kasir/features/employees/employees_screen.dart';
import 'package:nusa_kasir/features/finance/finance_screen.dart';
import 'package:nusa_kasir/features/suppliers/suppliers_screen.dart';
import 'package:nusa_kasir/features/spreadsheet/spreadsheet_screen.dart';
import 'package:nusa_kasir/features/branches/branch_screen.dart';
import 'package:nusa_kasir/features/setup/setup_screen.dart';
import 'package:nusa_kasir/features/online_orders/online_orders_screen.dart';
import 'package:nusa_kasir/features/online_orders/online_store_setup_screen.dart';
import 'package:nusa_kasir/features/settings/payment_settings_screen.dart';
import 'package:nusa_kasir/features/ai_assistant/ai_chat_screen.dart';
import 'package:nusa_kasir/features/toko_online/storefront_screen.dart';
import 'package:nusa_kasir/features/debts/debt_screen.dart';
import 'package:nusa_kasir/features/domain/meja_screen.dart';
import 'package:nusa_kasir/features/domain/laundry_status_screen.dart';
import 'package:nusa_kasir/features/domain/servis_screen.dart';
import 'package:nusa_kasir/features/domain/booking_screen.dart';
import 'package:nusa_kasir/features/domain/resep_screen.dart';
import 'package:nusa_kasir/features/domain/print_order_screen.dart';
import 'package:nusa_kasir/core/dev/variant_picker_screen.dart';

const _publicRoutes = {
  '/splash',
  '/activation',
  '/login',
  '/onboarding',
  '/setup',
  '/variant-picker',
};

/// Menu routes are protected centrally so deep links cannot bypass Dashboard's
/// menu-level RBAC checks. Route keys intentionally match NusaConfig.roleAccess.
const _protectedRouteKeys = {
  '/home': 'home',
  '/kasir': 'kasir',
  '/checkout': 'kasir',
  '/produk': 'produk',
  '/produk/tambah': 'produk',
  '/produk/edit': 'produk',
  '/produk/kategori': 'produk',
  '/produk/kategori/': 'produk',
  '/stok': 'stok',
  '/transaksi': 'transaksi',
  '/pelanggan': 'pelanggan',
  '/piutang': 'piutang',
  '/promo': 'promo',
  '/laporan': 'laporan',
  '/karyawan': 'karyawan',
  '/presensi': 'presensi',
  '/keuangan': 'keuangan',
  '/pengaturan': 'pengaturan',
  '/supplier': 'supplier',
  '/spreadsheet': 'spreadsheet',
  '/cabang': 'cabang',
  '/pesanan_online': 'pesanan_online',
  '/toko_online_setup': 'pesanan_online',
  '/ai_chat': 'ai_chat',
  '/toko': 'pesanan_online',
  '/pengaturan_pembayaran': 'pengaturan',
  '/meja': 'meja',
  '/laundry_status': 'laundry_status',
  '/servis': 'servis',
  '/booking': 'booking',
  '/resep': 'resep',
  '/print_order': 'print_order',
};

String? _protectedRouteKey(String location) {
  final path = Uri.parse(location).path;
  for (final entry in _protectedRouteKeys.entries) {
    if (path == entry.key ||
        (entry.key.endsWith('/') && path.startsWith(entry.key)) ||
        (entry.key == '/produk/edit' && path.startsWith('/produk/edit/'))) {
      return entry.value;
    }
  }
  return null;
}

Future<String?> _redirectForAuth(WidgetRef ref, GoRouterState state) async {
  final path = state.uri.path;
  if (_publicRoutes.contains(path)) return null;

  // Every non-public route requires activation and a valid employee session.
  // Route keys additionally apply menu visibility and role-based access.
  final routeKey = _protectedRouteKey(state.uri.toString());

  final activated = await SecureStore.getActivation() != null;
  if (!activated) return '/activation';

  var session = ref.read(employeeSessionProvider);
  if (session == null) {
    await ref.read(employeeSessionProvider.notifier).restore();
    session = ref.read(employeeSessionProvider);
  }

  if (session == null || session.isExpired) return '/login';

  if (routeKey != null &&
      (NusaConfig.hiddenMenus.contains(routeKey) ||
          !hasAccess(ref, session.role, routeKey))) {
    return '/home';
  }
  return null;
}

GoRouter buildRouter(String initialLocation, WidgetRef ref) => GoRouter(
  initialLocation: '/splash',
  redirect: (_, state) => _redirectForAuth(ref, state),
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, state) => CustomTransitionPage(
        key: state.pageKey,
        child: SplashScreen(onDone: (context) => context.go(initialLocation)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/variant-picker',
      pageBuilder: (_, __) => _slidePage(VariantPickerScreen()),
    ),
    GoRoute(
      path: '/activation',
      pageBuilder: (_, __) => _slidePage(ActivationScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, __) => _slidePage(LoginScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, __) => _slidePage(OnboardingScreen()),
    ),
    GoRoute(
      path: '/setup',
      pageBuilder: (_, __) => _slidePage(SetupScreen()),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (_, __) => _slidePage(DashboardScreen()),
    ),
    GoRoute(
      path: '/kasir',
      pageBuilder: (_, state) => _slidePage(
        PosScreen(
          sessionId: int.tryParse(state.uri.queryParameters['sessionId'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: '/checkout',
      pageBuilder: (_, state) => _slidePage(
        CheckoutScreen(
          sessionId: int.tryParse(state.uri.queryParameters['sessionId'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: '/produk',
      pageBuilder: (_, __) => _slidePage(ProductsScreen()),
    ),
    GoRoute(
      path: '/produk/tambah',
      pageBuilder: (_, __) => _slidePage(ProductFormScreen()),
    ),
    GoRoute(
      path: '/produk/edit/:id',
      pageBuilder: (_, state) => _slidePage(
        ProductFormScreen(productId: int.parse(state.pathParameters['id']!)),
      ),
    ),
    GoRoute(
      path: '/produk/kategori',
      pageBuilder: (_, __) => _slidePage(KategoriListScreen()),
    ),
    GoRoute(
      path: '/produk/kategori/:category',
      pageBuilder: (_, state) => _slidePage(
        ProductsByCategoryScreen(category: state.pathParameters['category']!),
      ),
    ),
    GoRoute(
      path: '/stok',
      pageBuilder: (_, state) => _slidePage(
        StockScreen(
          lowStockOnly: state.uri.queryParameters['lowStock'] == 'true',
        ),
      ),
    ),
    GoRoute(
      path: '/transaksi',
      pageBuilder: (_, __) => _slidePage(TransactionsScreen()),
    ),
    GoRoute(
      path: '/pelanggan',
      pageBuilder: (_, __) => _slidePage(CustomersScreen()),
    ),
    GoRoute(
      path: '/piutang',
      pageBuilder: (_, __) => _slidePage(DebtScreen()),
    ),
    GoRoute(
      path: '/promo',
      pageBuilder: (_, __) => _slidePage(PromoScreen()),
    ),
    GoRoute(
      path: '/laporan',
      pageBuilder: (_, __) => _slidePage(ReportsScreen()),
    ),
    GoRoute(
      path: '/karyawan',
      pageBuilder: (_, __) => _slidePage(EmployeesScreen()),
    ),
    GoRoute(
      path: '/presensi',
      pageBuilder: (_, __) => _slidePage(AttendanceScreen()),
    ),
    GoRoute(
      path: '/keuangan',
      pageBuilder: (_, __) => _slidePage(FinanceScreen()),
    ),
    GoRoute(
      path: '/pengaturan',
      pageBuilder: (_, __) => _slidePage(SettingsScreen()),
    ),
    GoRoute(
      path: '/supplier',
      pageBuilder: (_, __) => _slidePage(SuppliersScreen()),
    ),
    GoRoute(
      path: '/spreadsheet',
      pageBuilder: (_, __) => _slidePage(SpreadsheetScreen()),
    ),
    GoRoute(
      path: '/cabang',
      pageBuilder: (_, __) => _slidePage(BranchScreen()),
    ),
    GoRoute(
      path: '/pesanan_online',
      pageBuilder: (_, __) => _slidePage(OnlineOrdersScreen()),
    ),
    GoRoute(
      path: '/toko_online_setup',
      pageBuilder: (_, __) => _slidePage(OnlineStoreSetupScreen()),
    ),
    GoRoute(
      path: '/ai_chat',
      pageBuilder: (_, __) => _slidePage(AiChatScreen()),
    ),
    GoRoute(
      path: '/toko',
      pageBuilder: (_, __) => _slidePage(StorefrontScreen()),
    ),
    GoRoute(
      path: '/pengaturan_pembayaran',
      pageBuilder: (_, __) => _slidePage(PaymentSettingsScreen()),
    ),
    // ── Domain-specific screens (F&B, Laundry, Bengkel, Salon, Apotek, Fotocopy, Servis) ──
    GoRoute(
      path: '/meja',
      pageBuilder: (_, __) => _slidePage(MejaScreen()),
    ),
    GoRoute(
      path: '/laundry_status',
      pageBuilder: (_, __) => _slidePage(LaundryStatusScreen()),
    ),
    GoRoute(
      path: '/servis',
      pageBuilder: (_, __) => _slidePage(ServisScreen()),
    ),
    GoRoute(
      path: '/booking',
      pageBuilder: (_, __) => _slidePage(BookingScreen()),
    ),
    GoRoute(
      path: '/resep',
      pageBuilder: (_, __) => _slidePage(ResepScreen()),
    ),
    GoRoute(
      path: '/print_order',
      pageBuilder: (_, __) => _slidePage(PrintOrderScreen()),
    ),
  ],
);

CustomTransitionPage _slidePage(Widget child) => CustomTransitionPage(
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
);

class NusaApp extends ConsumerStatefulWidget {
  final String initialLocation;
  const NusaApp({required this.initialLocation, super.key});

  @override
  ConsumerState<NusaApp> createState() => _NusaAppState();
}

class _NusaAppState extends ConsumerState<NusaApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(widget.initialLocation, ref);

  @override
  void initState() {
    super.initState();
    // Start auto cloud sync (upload side) for the whole app lifetime.
    WidgetsBinding.instance.addObserver(this);
    try {
      ref.read(autoSyncProvider);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush pending upload when the app goes to background — data leaves the
    // device as soon as possible without waiting for the next debounce tick.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      try {
        ref.read(autoSyncProvider).flushNow();
      } catch (_) {}
    }
  }

  ThemeMode _toThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeModeStr = ref.watch(themeModeProvider);
    final themePreset = ref.watch(
      themePresetProvider,
    ); // watch for rebuild on theme change
    return MaterialApp.router(
      key: ValueKey('nusa_$themePreset'), // force rebuild when theme changes
      title: 'NUSA Kasir',
      theme: NusaTheme.light,
      darkTheme: NusaTheme.dark,
      themeMode: _toThemeMode(themeModeStr),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
