import 'package:flutter/material.dart';

/// Holds all variant-specific configuration for one NUSA product variant.
/// Used by the dev variant switcher to apply runtime overrides.
class VariantData {
  final String id;
  final String name;
  final String productId;
  final String subtitle;
  final String repo;
  final String pkg;
  final Color primary;
  final Color dark;
  final Color soft;
  final Map<String, String> catEmoji;
  final Map<String, List<Color>> catGradients;
  final Map<String, IconData> catIcons;
  final List<String> hiddenMenus;

  const VariantData({
    required this.id,
    required this.name,
    required this.productId,
    required this.subtitle,
    required this.repo,
    required this.pkg,
    required this.primary,
    required this.dark,
    required this.soft,
    required this.catEmoji,
    required this.catGradients,
    required this.catIcons,
    required this.hiddenMenus,
  });

  /// All 8 variants, hardcoded identically to _build_all.py.
  static const List<VariantData> all = [
    // ── Kelontong ──
    VariantData(
      id: 'kelontong',
      name: 'NUSA Kelontong',
      productId: 'nusa-kelontong',
      subtitle: 'Aplikasi Kasir untuk Toko Kelontong',
      repo: 'halugoods/nusa-kelontong',
      pkg: 'com.nusa.kelontong',
      primary: Color(0xFFF97316),
      dark: Color(0xFFEA580C),
      soft: Color(0xFFFFF7ED),
      catEmoji: {
        'Sembako': '🍚', 'Makanan': '🍜', 'Minuman': '🥤',
        'Perlengkapan': '🧹', 'Lainnya': '📦',
      },
      catGradients: {
        'Sembako': [Color(0xFFFFEDD5), Color(0xFFFED7AA), Color(0xFFFFF7ED)],
        'Makanan': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Minuman': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Perlengkapan': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Sembako': Icons.rice_bowl_rounded,
        'Makanan': Icons.restaurant_rounded,
        'Minuman': Icons.local_drink_rounded,
        'Perlengkapan': Icons.cleaning_services_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['meja', 'laundry_status', 'servis', 'booking', 'resep', 'print_order'],
    ),
    // ── F&B ──
    VariantData(
      id: 'fnb',
      name: 'NUSA F&B',
      productId: 'nusa-fnb',
      subtitle: 'Aplikasi Kasir untuk Rumah Makan & Kafe',
      repo: 'halugoods/nusa-fnb',
      pkg: 'com.nusa.fnb',
      primary: Color(0xFFDC2626),
      dark: Color(0xFF991B1B),
      soft: Color(0xFFFEF2F2),
      catEmoji: {
        'Makanan': '🍜', 'Minuman': '🥤', 'Snack': '🍿',
        'Menu Utama': '🍽️', 'Lainnya': '📦',
      },
      catGradients: {
        'Makanan': [Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFFFEF2F2)],
        'Minuman': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Snack': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Menu Utama': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Makanan': Icons.restaurant_rounded,
        'Minuman': Icons.local_drink_rounded,
        'Snack': Icons.bakery_dining_rounded,
        'Menu Utama': Icons.dinner_dining_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['supplier', 'piutang', 'spreadsheet', 'laundry_status', 'servis', 'booking', 'resep', 'print_order'],
    ),
    // ── Laundry ──
    VariantData(
      id: 'laundry',
      name: 'NUSA Laundry',
      productId: 'nusa-laundry',
      subtitle: 'Aplikasi Kasir untuk Usaha Laundry',
      repo: 'halugoods/nusa-laundry',
      pkg: 'com.nusa.laundry',
      primary: Color(0xFFEC4899),
      dark: Color(0xFFDB2777),
      soft: Color(0xFFFDF2F8),
      catEmoji: {
        'Cuci Kering': '👕', 'Cuci Setrika': '✨', 'Setrika Only': '🔥',
        'Express': '⚡', 'Lainnya': '📦',
      },
      catGradients: {
        'Cuci Kering': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Cuci Setrika': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Setrika Only': [Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFFFEF2F2)],
        'Express': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Cuci Kering': Icons.local_laundry_service_rounded,
        'Cuci Setrika': Icons.auto_awesome_rounded,
        'Setrika Only': Icons.whatshot_rounded,
        'Express': Icons.bolt_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['supplier', 'piutang', 'promo', 'pesanan_online', 'meja', 'servis', 'booking', 'resep', 'print_order'],
    ),
    // ── Bengkel ──
    VariantData(
      id: 'bengkel',
      name: 'NUSA Bengkel',
      productId: 'nusa-bengkel',
      subtitle: 'Aplikasi Kasir untuk Bengkel & Otomotif',
      repo: 'halugoods/nusa-bengkel',
      pkg: 'com.nusa.bengkel',
      primary: Color(0xFFEAB308),
      dark: Color(0xFFCA8A04),
      soft: Color(0xFFFEF9C3),
      catEmoji: {
        'Oli': '🛢️', 'Ban': '🛞', 'Servis': '🔧',
        'Sparepart': '⚙️', 'Lainnya': '📦',
      },
      catGradients: {
        'Oli': [Color(0xFFF3F4F6), Color(0xFFE5E7EB), Color(0xFFF9FAFB)],
        'Ban': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Servis': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Sparepart': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Oli': Icons.oil_barrel_rounded,
        'Ban': Icons.tire_repair_rounded,
        'Servis': Icons.build_rounded,
        'Sparepart': Icons.settings_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['pesanan_online', 'meja', 'laundry_status', 'booking', 'resep', 'print_order'],
    ),
    // ── Salon ──
    VariantData(
      id: 'salon',
      name: 'NUSA Salon',
      productId: 'nusa-salon',
      subtitle: 'Aplikasi Kasir untuk Salon & Barbershop',
      repo: 'halugoods/nusa-salon',
      pkg: 'com.nusa.salon',
      primary: Color(0xFF3B82F6),
      dark: Color(0xFF2563EB),
      soft: Color(0xFFEFF6FF),
      catEmoji: {
        'Haircut': '✂️', 'Coloring': '🎨', 'Treatment': '💆',
        'Styling': '💇', 'Lainnya': '📦',
      },
      catGradients: {
        'Haircut': [Color(0xFFFAFAF9), Color(0xFFE7E5E4), Color(0xFFF5F5F4)],
        'Coloring': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Treatment': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Styling': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Haircut': Icons.content_cut_rounded,
        'Coloring': Icons.palette_rounded,
        'Treatment': Icons.spa_rounded,
        'Styling': Icons.face_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['supplier', 'cabang', 'piutang', 'pesanan_online', 'meja', 'laundry_status', 'servis', 'resep', 'print_order'],
    ),
    // ── Apotek ──
    VariantData(
      id: 'apotek',
      name: 'NUSA Apotek',
      productId: 'nusa-apotek',
      subtitle: 'Aplikasi Kasir untuk Apotek & Farmasi',
      repo: 'halugoods/nusa-apotek',
      pkg: 'com.nusa.apotek',
      primary: Color(0xFF10B981),
      dark: Color(0xFF059669),
      soft: Color(0xFFECFDF5),
      catEmoji: {
        'Obat Bebas': '💊', 'Obat Resep': '📋', 'Vitamin': '💪',
        'Alkes': '🩺', 'Lainnya': '📦',
      },
      catGradients: {
        'Obat Bebas': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Obat Resep': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Vitamin': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Alkes': [Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFFFEF2F2)],
        'Lainnya': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Obat Bebas': Icons.medication_rounded,
        'Obat Resep': Icons.description_rounded,
        'Vitamin': Icons.fitness_center_rounded,
        'Alkes': Icons.monitor_heart_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['promo', 'piutang', 'meja', 'laundry_status', 'servis', 'booking', 'print_order'],
    ),
    // ── Fotocopy ──
    VariantData(
      id: 'fotocopy',
      name: 'NUSA Fotocopy',
      productId: 'nusa-fotocopy',
      subtitle: 'Aplikasi Kasir untuk Fotocopy & Percetakan',
      repo: 'halugoods/nusa-fotocopy',
      pkg: 'com.nusa.fotocopy',
      primary: Color(0xFF8B5CF6),
      dark: Color(0xFF7C3AED),
      soft: Color(0xFFF5F3FF),
      catEmoji: {
        'Print': '🖨️', 'Fotocopy': '📄', 'Jilid': '📚',
        'ATK': '✏️', 'Lainnya': '📦',
      },
      catGradients: {
        'Print': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
        'Fotocopy': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Jilid': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'ATK': [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFF0FDF4)],
        'Lainnya': [Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFFFEF2F2)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'Print': Icons.print_rounded,
        'Fotocopy': Icons.copy_all_rounded,
        'Jilid': Icons.book_rounded,
        'ATK': Icons.edit_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['cabang', 'piutang', 'pesanan_online', 'meja', 'laundry_status', 'servis', 'booking', 'resep'],
    ),
    // ── Servis ──
    VariantData(
      id: 'servis',
      name: 'NUSA Servis',
      productId: 'nusa-servis',
      subtitle: 'Aplikasi Kasir untuk Jasa Servis',
      repo: 'halugoods/nusa-servis',
      pkg: 'com.nusa.servis',
      primary: Color(0xFF152C63),
      dark: Color(0xFF0F1E47),
      soft: Color(0xFFDBEAFE),
      catEmoji: {
        'LCD': '📱', 'Baterai': '🔋', 'Software': '⚡',
        'Aksesoris': '🎧', 'Lainnya': '📦',
      },
      catGradients: {
        'LCD': [Color(0xFFECFEFF), Color(0xFFCFFAFE), Color(0xFFF0FDFA)],
        'Baterai': [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFEF9C3)],
        'Software': [Color(0xFFDBEAFE), Color(0xFFBFDBFE), Color(0xFFEFF6FF)],
        'Aksesoris': [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Color(0xFFFAF5FF)],
        'Lainnya': [Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFFFEF2F2)],
      },
      catIcons: {
        'Semua': Icons.grid_view_rounded,
        'LCD': Icons.phone_android_rounded,
        'Baterai': Icons.battery_charging_full_rounded,
        'Software': Icons.terminal_rounded,
        'Aksesoris': Icons.headphones_rounded,
        'Lainnya': Icons.category_rounded,
      },
      hiddenMenus: ['meja', 'laundry_status', 'booking', 'resep', 'print_order'],
    ),
  ];

  /// Find a variant by its id.
  static VariantData? findById(String id) {
    try {
      return all.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }
}
