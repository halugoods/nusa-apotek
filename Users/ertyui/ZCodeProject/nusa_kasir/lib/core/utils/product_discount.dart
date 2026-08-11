import 'package:nusa_kasir/data/database/app_database.dart';

/// Helper untuk diskon standalone per produk.
///
/// `discountPercent` (0–100) adalah potongan % dari harga jual. Harga
/// efektif yang dibayar customer = sellPrice − diskon. Dipakai di POS
/// (harga masuk keranjang), daftar produk, dan struk.
extension ProductDiscountX on Product {
  /// Harga jual setelah diskon standalone (dibulatkan ke bawah).
  int get effectivePrice {
    final pct = discountPercent.clamp(0, 100);
    if (pct == 0) return sellPrice;
    return sellPrice - (sellPrice * pct / 100).round();
  }

  /// True kalau produk punya diskon aktif.
  bool get hasDiscount => discountPercent > 0 && discountPercent <= 100;
}
