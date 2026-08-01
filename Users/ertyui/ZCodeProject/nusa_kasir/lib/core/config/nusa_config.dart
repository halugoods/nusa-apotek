import 'package:flutter/material.dart';

abstract class NusaConfig {
  static const String appName = "NUSA";
  static const String brandName = "NUSA";
	static const String productId = "nusa-bengkel";
	static const String appSubtitle = "Aplikasi Kasir untuk Bengkel & Otomotif";
		static const String appVersion = "1.0.0";
		static const int appBuildNumber = 1;
	  static const String githubRepo = "halugoods/nusa-bengkel";
	  static const String landingPageUrl = "https://nusa-online.vercel.app";
	  static const String whatsappOrder = "https://wa.me/628976280303?text=Halo%2C%20saya%20mau%20beli%20NUSA%20Kelontong";
	  static const String applicationId = "com.nusa.bengkel"; // shared for all variants (Firebase constraint)
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://sakeuhcbcnueplzlkltm.supabase.co');
  static const String supabaseAnon = String.fromEnvironment('SUPABASE_ANON', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNha2V1aGNiY251ZXBsemxrbHRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2ODIzMDEsImV4cCI6MjA5OTI1ODMwMX0.WvjZJ8Sd3o5T8a4vMApyvoCoS01Qv493mo1PxyWO06M');

  // ═══════════════════════════════════════════
  //  DESIGN TOKENS — Single source of truth
  // ═══════════════════════════════════════════

  // ── Brand colors ──
	static const Color primaryColor = Color(0xFF374151);   // Orange — Kelontong
	static const Color primaryDark = Color(0xFF1F2937);
	static const Color primarySoft = Color(0xFFF3F4F6);
  static const Color backgroundColor = Color(0xFFF7F7F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color dividerColor = Color(0xFFE5E7EB);
  static const Color borderColor = Color(0xFFF3F4F6);
  static const Color inputFill = Color(0xFFF9FAFB);
  static const Color inputBorder = Color(0xFFE5E7EB);

  // ── Semantic colors ──
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color successText = Color(0xFF065F46);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color errorText = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFFD97706);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color infoText = Color(0xFF1E40AF);

  // ── Stock status colors ──
  static const Color stockActive = Color(0xFFDCFCE7);
  static const Color stockActiveText = Color(0xFF16A34A);
  static const Color stockLow = Color(0xFFFEF3C7);
  static const Color stockLowText = Color(0xFFD97706);
  static const Color stockOut = Color(0xFFFEE2E2);
  static const Color stockOutText = Color(0xFFDC2626);

  // ── Accent ──
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentGreenDark = Color(0xFF059669);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleDark = Color(0xFF7C3AED);
  static const Color accentGold = Color(0xFFF59E0B);

  // ── Payment method colors ──
  static const Color payCash = Color(0xFF10B981);
  static const Color payQris = Color(0xFF3B82F6);
  static const Color payTransfer = Color(0xFF8B5CF6);

  // ── Dark mode palette ──
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurface2 = Color(0xFF252540);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFE2E8F0);
  static const Color darkTextTertiary = Color(0xFFCBD5E1);
  static const Color darkDivider = Color(0xFF2D2D44);
  static const Color darkBorder = Color(0xFF3A3A52);
  static const Color darkCardShadow = Color(0x1A000000);
  static const Color darkInputFill = Color(0xFF252540);
  static const Color darkInputBorder = Color(0xFF3A3A52);

  // ── Spacing scale (4pt grid) ──
  static const double spaceXXS = 4;
  static const double spaceXS = 8;
  static const double spaceSM = 12;
  static const double spaceMD = 16;
  static const double spaceLG = 20;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;

  // ── Radius scale ──
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 20;
  static const double radiusFull = 999;

  // ── Responsive breakpoints ──
  static const double bpPhone = 600;
  static const double bpTablet = 900;
  static bool isWide(BuildContext context) => MediaQuery.of(context).size.width > 720;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600;

  /// Scale animation durations for high-refresh-rate displays.
  /// 120 Hz panels render twice as many frames, making animations feel perceptually
  /// faster. This returns a multiplier to stretch short durations back to normal.
  static double get animationScale {
    try {
      final rate = WidgetsBinding.instance.platformDispatcher.displays.first.refreshRate;
      if (rate >= 120) return 1.5;
      if (rate >= 90) return 1.3;
    } catch (_) {}
    return 1.0;
  }

  // ── Category maps (single source across all screens) ──
	static const Map<String, String> catEmoji = {
	  'Oli': '🛢️',
	  'Ban': '🛞',
	  'Servis': '🔧',
	  'Sparepart': '⚙️',
	  'Lainnya': '📦',
	};
	  static const Map<String, List<Color>> catGradients = {
	    'Oli': [Color(0xFFF3F4F6), Color(0xFFE5E7EB), Color(0xFFF9FAFB)],
	    'Ban': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
	    'Servis': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
	    'Sparepart': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
	    'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
	  };
	  static const Map<String, IconData> catIcons = {
	    'Semua': Icons.grid_view_rounded,
	    'Oli': Icons.oil_barrel_rounded,
	    'Ban': Icons.tire_repair_rounded,
	    'Servis': Icons.build_rounded,
	    'Sparepart': Icons.settings_rounded,
	    'Lainnya': Icons.category_rounded,
	  };

  static String catEmojiFor(String cat) => catEmoji[cat] ?? '📦';
  static List<Color> catGradientFor(String cat) => catGradients[cat] ?? catGradients['Lainnya']!;

  /// Helper: resolve light/dark color from context
  static Color resolve(BuildContext context, {required Color light, required Color dark}) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ── Feature flags ──
  static const bool enableBarcode = true;
  static const bool enableQRIS = true;
  static const bool enableSpreadsheet = true;
  static const bool enableWhatsApp = true;
  static const int maxDevicesPerKey = 2;

  // ── Business constants ──
  static const List<String> roles = ["Owner", "Manager", "Kasir", "Gudang", "Finance"];
  static const List<String> productTypes = ["Regular", "Varian", "Grosir"];
  static const Map<String, List<String>> roleAccess = {
		    "Owner": ["home","kasir","produk","stok","transaksi","pelanggan","promo","laporan","presensi","karyawan","keuangan","pengaturan","supplier","spreadsheet","pesanan_online","cabang","ai_chat","piutang"],
		    "Manager": ["home","kasir","produk","stok","transaksi","pelanggan","promo","laporan","presensi","karyawan","keuangan","pengaturan","supplier","spreadsheet","pesanan_online","cabang","ai_chat","piutang"],
	    "Kasir": ["home","kasir","produk","stok","transaksi","pelanggan","ai_chat"],
	    "Gudang": ["home","produk","stok","laporan","supplier"],
	    "Finance": ["home","transaksi","keuangan","laporan","presensi","karyawan","supplier"],
	  };

  /// Menu yang perlu PIN re-entry untuk keamanan (POS/Kasir).
  static const List<String> pinGuardScreens = ['kasir'];

  /// Menu yang HANYA bisa dibuka Owner (block dengan dialog).
  static const List<String> ownerOnlyScreens = [
    'laporan', 'promo', 'pesanan_online', 'karyawan',
    'keuangan', 'spreadsheet', 'supplier', 'pengaturan', 'cabang', 'piutang',
  ];

  /// Menu yang disembunyikan secara default per domain.
  /// Owner tetap bisa mengaktifkan kembali via Kelola Fitur.
  static const List<String> hiddenMenus = [];

  /// Menu tambahan spesifik domain (bersifat aditif ke dashboard grid).
  /// Format: {'id', 'label', 'icon'}
  static const List<Map<String, String>> extraMenus = [];
}
