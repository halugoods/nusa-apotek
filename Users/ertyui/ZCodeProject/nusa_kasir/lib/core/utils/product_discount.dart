import 'package:nusa_kasir/data/database/app_database.dart';

/// Helper untuk diskon standalone per produk.
///
/// `discountPercent` berisi nilai diskon, dan `discountType` menentukan
/// bentuknya:
///   - 'persen'  → potongan % dari harga jual (0–100)
///   - 'nominal' → potongan langsung dalam Rupiah (≤ sellPrice)
///
/// Harga efektif yang dibayar customer = sellPrice − diskon. Dipakai di POS
/// (harga masuk keranjang), daftar produk, dan struk.
extension ProductDiscountX on Product {
  static const String typePersen = 'persen';
  static const String typeNominal = 'nominal';

  /// Harga jual setelah diskon standalone (dibulatkan ke bawah).
  int get effectivePrice {
    final d = discountPercent;
    if (d <= 0) return sellPrice;
    return switch (discountType) {
      typeNominal => (sellPrice - d).clamp(0, sellPrice),
      _ => (sellPrice - (sellPrice * d / 100).round()).clamp(0, sellPrice),
    };
  }

  /// True kalau produk punya diskon aktif.
  bool get hasDiscount => discountPercent > 0 && effectivePrice < sellPrice;

  /// Label ringkas untuk tampilan daftar/struk, mis. "-10%" atau "-Rp 5.000".
  String get discountLabel {
    if (!hasDiscount) return '';
    return discountType == typeNominal
        ? '-${_rp(discountPercent)}'
        : '-$discountPercent%';
  }

  static String _rp(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return 'Rp $b';
  }
}
