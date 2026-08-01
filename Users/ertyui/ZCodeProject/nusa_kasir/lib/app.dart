import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/theme/nusa_theme.dart';
import 'package:nusa_kasir/core/providers.dart';
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

GoRouter buildRouter(String initialLocation) => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
            path: '/splash',
            pageBuilder: (_, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: SplashScreen(
                    onDone: (context) => context.go(initialLocation),
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                )),
        GoRoute(
            path: '/activation',
            pageBuilder: (_, __) => _slidePage(const ActivationScreen())),
        GoRoute(
            path: '/login', pageBuilder: (_, __) => _slidePage(const LoginScreen())),
        GoRoute(
            path: '/onboarding',
            pageBuilder: (_, __) => _slidePage(const OnboardingScreen())),
        GoRoute(
            path: '/setup',
            pageBuilder: (_, __) => _slidePage(const SetupScreen())),
        GoRoute(
            path: '/home',
            pageBuilder: (_, __) => _slidePage(const DashboardScreen())),
        GoRoute(
            path: '/kasir',
            pageBuilder: (_, state) => _slidePage(PosScreen(
                sessionId: int.tryParse(
                    state.uri.queryParameters['sessionId'] ?? '')))),
        GoRoute(
            path: '/checkout',
            pageBuilder: (_, state) => _slidePage(CheckoutScreen(
                sessionId: int.tryParse(
                    state.uri.queryParameters['sessionId'] ?? '')))),
        GoRoute(
            path: '/produk',
            pageBuilder: (_, __) => _slidePage(const ProductsScreen())),
        GoRoute(
            path: '/produk/tambah',
            pageBuilder: (_, __) => _slidePage(const ProductFormScreen())),
        GoRoute(
            path: '/produk/edit/:id',
            pageBuilder: (_, state) => _slidePage(ProductFormScreen(
                productId: int.parse(state.pathParameters['id']!)))),
        GoRoute(
            path: '/produk/kategori',
            pageBuilder: (_, __) => _slidePage(const KategoriListScreen())),
        GoRoute(
            path: '/produk/kategori/:category',
            pageBuilder: (_, state) => _slidePage(ProductsByCategoryScreen(
                category: state.pathParameters['category']!))),
        GoRoute(
            path: '/stok', pageBuilder: (_, state) => _slidePage(StockScreen(
                lowStockOnly: state.uri.queryParameters['lowStock'] == 'true'))),
        GoRoute(
            path: '/transaksi',
            pageBuilder: (_, __) => _slidePage(const TransactionsScreen())),
        GoRoute(
            path: '/pelanggan',
            pageBuilder: (_, __) => _slidePage(const CustomersScreen())),
        GoRoute(
            path: '/piutang',
            pageBuilder: (_, __) => _slidePage(const DebtScreen())),
        GoRoute(
            path: '/promo', pageBuilder: (_, __) => _slidePage(const PromoScreen())),
        GoRoute(
            path: '/laporan',
            pageBuilder: (_, __) => _slidePage(const ReportsScreen())),
        GoRoute(
            path: '/karyawan',
            pageBuilder: (_, __) => _slidePage(const EmployeesScreen())),
        GoRoute(
            path: '/presensi',
            pageBuilder: (_, __) => _slidePage(const AttendanceScreen())),
        GoRoute(
            path: '/keuangan',
            pageBuilder: (_, __) => _slidePage(const FinanceScreen())),
        GoRoute(
            path: '/pengaturan',
            pageBuilder: (_, __) => _slidePage(const SettingsScreen())),
        GoRoute(
            path: '/supplier',
            pageBuilder: (_, __) => _slidePage(const SuppliersScreen())),
        GoRoute(
            path: '/spreadsheet',
            pageBuilder: (_, __) => _slidePage(const SpreadsheetScreen())),
        GoRoute(
            path: '/cabang',
            pageBuilder: (_, __) => _slidePage(const BranchScreen())),
        GoRoute(
            path: '/pesanan_online',
            pageBuilder: (_, __) => _slidePage(const OnlineOrdersScreen())),
        GoRoute(
            path: '/toko_online_setup',
            pageBuilder: (_, __) => _slidePage(const OnlineStoreSetupScreen())),
        GoRoute(
            path: '/ai_chat',
            pageBuilder: (_, __) => _slidePage(const AiChatScreen())),
        GoRoute(
            path: '/toko',
            pageBuilder: (_, __) => _slidePage(const StorefrontScreen())),
        GoRoute(
            path: '/pengaturan_pembayaran',
            pageBuilder: (_, __) => _slidePage(const PaymentSettingsScreen())),
        // ── Domain-specific screens (F&B, Laundry, Bengkel, Salon, Apotek, Fotocopy, Service HP) ──
        GoRoute(
            path: '/meja', pageBuilder: (_, __) => _slidePage(const MejaScreen())),
        GoRoute(
            path: '/laundry_status', pageBuilder: (_, __) => _slidePage(const LaundryStatusScreen())),
        GoRoute(
            path: '/servis', pageBuilder: (_, __) => _slidePage(const ServisScreen())),
        GoRoute(
            path: '/booking', pageBuilder: (_, __) => _slidePage(const BookingScreen())),
        GoRoute(
            path: '/resep', pageBuilder: (_, __) => _slidePage(const ResepScreen())),
        GoRoute(
            path: '/print_order', pageBuilder: (_, __) => _slidePage(const PrintOrderScreen())),
      ],
    );

CustomTransitionPage _slidePage(Widget child) => CustomTransitionPage(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );

class NusaApp extends ConsumerStatefulWidget {
  final String initialLocation;
  const NusaApp({required this.initialLocation, super.key});

  @override
  ConsumerState<NusaApp> createState() => _NusaAppState();
}

class _NusaAppState extends ConsumerState<NusaApp> {
  late final GoRouter _router = buildRouter(widget.initialLocation);

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
    return MaterialApp.router(
      title: 'NUSA Kasir',
      theme: NusaTheme.light,
      darkTheme: NusaTheme.dark,
      themeMode: _toThemeMode(themeModeStr),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
