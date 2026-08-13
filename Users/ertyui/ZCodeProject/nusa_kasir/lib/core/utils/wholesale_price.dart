import 'dart:convert';

import 'package:nusa_kasir/data/database/app_database.dart';

/// Satu tier harga grosir: dibeli minimal [minQty] → harga per unit [price].
class WholesaleTier {
  final int minQty;
  final int price;
  const WholesaleTier({required this.minQty, required this.price});

  factory WholesaleTier.fromJson(Map<String, dynamic> j) => WholesaleTier(
        minQty: (j['minQty'] as num?)?.toInt() ?? 1,
        price: (j['price'] as num?)?.toInt() ?? 0,
      );
}

/// Resolver harga grosir bertingkat yang tersimpan di `wholesaleJson` produk.
///
/// Aturan: qty ≥ minQty tier → pakai harga tier (tier terbaik = yang paling
/// rendah harganya, di antara tier yang qty-nya tercapai). Fallback ke harga
/// jual biasa kalau tidak ada tier / tidak ada qty yang memenuhi.
extension WholesalePriceX on Product {
  /// Daftar tier yang valid (minQty > 0, price > 0), diurutkan naik minQty.
  List<WholesaleTier> get wholesaleTiers {
    final raw = wholesaleJson;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => WholesaleTier.fromJson(e as Map<String, dynamic>))
          .where((t) => t.minQty > 0 && t.price > 0)
          .toList()
        ..sort((a, b) => a.minQty.compareTo(b.minQty));
      return list;
    } catch (_) {
      return const [];
    }
  }

  bool get hasWholesale => wholesaleTiers.isNotEmpty;

  /// Harga grosir terbaik untuk [qty] unit (null = pakai harga jual biasa).
  int? wholesalePriceFor(int qty) {
    if (qty <= 0) return null;
    // Iterasi dari tier terbesar → terkecil supaya tier "lebih murah & lebih
    // besar" menang ketika beberapa tier terpenuhi sekaligus.
    for (final tier in wholesaleTiers.reversed) {
      if (qty >= tier.minQty) return tier.price;
    }
    return null;
  }
}
