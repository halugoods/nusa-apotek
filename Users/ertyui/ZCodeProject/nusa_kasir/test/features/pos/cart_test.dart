import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/features/pos/cart.dart';

void main() {
  test('manual item carries costPrice through addManualItem', () {
    final n = CartNotifier();
    n.addManualItem('Jasa angkut', 15000, qty: 2, costPrice: 10000);
    final item = n.state.single;
    expect(item.isManual, isTrue);
    expect(item.productId, lessThan(0));
    expect(item.price, 15000);
    expect(item.costPrice, 10000);
    expect(item.qty, 2);
    expect(item.subtotal, 30000);
  });

  test('manual item without costPrice keeps null', () {
    final n = CartNotifier();
    n.addManualItem('Biaya parkir', 5000);
    expect(n.state.single.costPrice, isNull);
  });

  test('toJson includes costPrice only when set', () {
    final n = CartNotifier();
    n.addManualItem('Jasa', 10000, costPrice: 7000);
    final json = n.state.single.toJson();
    expect(json['costPrice'], 7000);
    expect(json['productId'], lessThan(0));

    n.clear();
    n.addManualItem('Jasa 2', 10000);
    expect(n.state.single.toJson().containsKey('costPrice'), isFalse);
  });

  test('qty merge preserves costPrice', () {
    final n = CartNotifier();
    n.addManualItem('Jasa', 10000, costPrice: 7000);
    n.changeQty(n.state.single.productId, 1);
    final item = n.state.single;
    expect(item.qty, 2);
    expect(item.costPrice, 7000);
    expect(item.subtotal, 20000);
  });

  test('two manual items in one cart get distinct ids', () {
    final n = CartNotifier();
    n.addManualItem('A', 1000);
    n.addManualItem('B', 2000);
    expect(n.state.length, 2);
    expect(n.state[0].productId, isNot(n.state[1].productId));
    expect(n.state[0].productId, lessThan(0));
    expect(n.state[1].productId, lessThan(0));
    // Lines stay separate — no merging of same-name manual items
    expect(n.state[0].qty, 1);
    expect(n.state[1].qty, 1);
  });

  group('Varian (v2.2.43)', () {
    test('variant items do not merge across different variants', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      n.addProduct(1, 'Kopi', 15000, variantName: 'Mentai');
      expect(n.state.length, 2);
      expect(n.state[0].variantName, 'Original');
      expect(n.state[1].variantName, 'Mentai');
    });

    test('same variant merges qty', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      expect(n.state.length, 1);
      expect(n.state.single.qty, 2);
    });

    test('setVariant switches variant on the line', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000);
      n.setVariant(1, 'Original', 17000, 2000, 10);
      final item = n.state.single;
      expect(item.variantName, 'Original');
      expect(item.price, 17000);
      expect(item.variantPriceAdjustment, 2000);
      expect(item.variantStock, 10);
      expect(item.displayName, 'Kopi — Original');
    });

    test('changeQty with variant targets only that line', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Original');
      n.addProduct(1, 'Kopi', 15000, variantName: 'Mentai');
      n.changeQty(1, 1, variantName: 'Original');
      expect(n.state[0].qty, 2);
      expect(n.state[1].qty, 1);
    });

    test('toJson includes variant fields', () {
      final n = CartNotifier();
      n.addProduct(1, 'Kopi', 15000, variantName: 'Mentai',
          variantPriceAdjustment: 5000, variantStock: 3);
      final json = n.state.single.toJson();
      expect(json['variantName'], 'Mentai');
      expect(json['variantPriceAdjustment'], 5000);
      expect(json['variantStock'], 3);
    });
  });

  group('Satuan dinamis (v2.2.43)', () {
    test('default unit is pcs with qtyPerBase 1', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 20000);
      expect(n.state.single.unitName, isNull);
      expect(n.state.single.unitQtyPerBase, 1);
      expect(n.state.single.qtyInBase, 1);
    });

    test('setUnit changes qtyInBase for stock math', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 20000);
      n.setUnit(1, 'dus', 12);
      final item = n.state.single;
      expect(item.unitName, 'dus');
      expect(item.qtyInBase, 12);
      // qty utuh tetap dalam satuan jual
      expect(item.qty, 1);
      expect(item.qtyLabel, '1 dus (12 pcs)');
    });

    test('qtyLabel simple when qtyPerBase is 1', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 5000);
      n.setUnit(1, 'pcs', 1);
      expect(n.state.single.qtyLabel, '1 pcs');
    });

    test('toJson includes unitName only when set', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 20000);
      expect(n.state.single.toJson().containsKey('unitName'), isFalse);
      n.setUnit(1, 'dus', 12);
      final json = n.state.single.toJson();
      expect(json['unitName'], 'dus');
      expect(json['unitQtyPerBase'], 12);
    });
  });

  group('Layanan isService (v2.2.44 B10)', () {
    test('addProduct with isService true marks the line', () {
      final n = CartNotifier();
      n.addProduct(99, 'Cuci Mobil', 25000, isService: true);
      expect(n.state.single.isService, isTrue);
      expect(n.state.single.isManual, isFalse);
    });

    test('regular product is not a service by default', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 5000);
      expect(n.state.single.isService, isFalse);
    });

    test('merge keeps isService when re-adding', () {
      final n = CartNotifier();
      n.addProduct(99, 'Cuci Mobil', 25000, isService: true);
      n.addProduct(99, 'Cuci Mobil', 25000, isService: true);
      final item = n.state.single;
      expect(item.qty, 2);
      expect(item.isService, isTrue);
    });

    test('service + regular product merge independently', () {
      final n = CartNotifier();
      n.addProduct(99, 'Cuci Mobil', 25000, isService: true);
      n.addProduct(99, 'Shampo', 5000); // same id, not service → separate? no—
      // Merge key = productId + variantName; service flag tidak memisahkan baris.
      // Simulasi: layanan & produk fisik punya id berbeda → 2 baris.
      n.addProduct(100, 'Shampo', 5000);
      expect(n.state.length, 2);
      expect(n.state[0].isService, isTrue);
      expect(n.state[1].isService, isFalse);
    });

    test('toJson includes isService flag (untuk draft tersimpan B7)', () {
      final n = CartNotifier();
      n.addProduct(99, 'Cuci Mobil', 25000, isService: true);
      expect(n.state.single.toJson()['isService'], isTrue);
    });
  });

  group('Grosir recompute (v2.2.44 B5)', () {
    // Tier: 10+ → 8000, 20+ → 7000. Harga normal 10000, full 12000.
    int? tierFor(int qty) {
      if (qty >= 20) return 7000;
      if (qty >= 10) return 8000;
      return null;
    }

    test('qty naik di atas ambang → harga grosir diterapkan', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 10000, originalPrice: 12000);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      // qty 1 → belum grosir
      expect(n.state.single.price, 10000);

      n.setQty(1, 12);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 8000);
      // coret = harga penuh saat grosir aktif
      expect(n.state.single.originalPrice, 12000);
    });

    test('qty turun di bawah ambang → harga balik normal (bug fix)', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 10000);
      n.setQty(1, 15);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 8000);

      // Turun di bawah ambang 10 → harus balik 10000 (sebelumnya beku 8000).
      // Produk tetap punya diskon (normal 10000 < full 12000) → coret dipertahankan.
      n.setQty(1, 5);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 10000);
      expect(n.state.single.originalPrice, 12000);
    });

    test('tanpa diskon, originalPrice bersih saat grosir mati', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 10000); // no discount: normal == full
      n.setQty(1, 12);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 10000);
      expect(n.state.single.price, 8000);
      expect(n.state.single.originalPrice, 10000);

      n.setQty(1, 3);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 10000);
      expect(n.state.single.price, 10000);
      expect(n.state.single.originalPrice, isNull);
    });

    test('decrement changeQty lalu recompute → harga ikut turun', () {
      final n = CartNotifier();
      n.addProduct(1, 'Snack', 10000);
      n.setQty(1, 22);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 7000);

      n.changeQty(1, -5); // → 17, masih tier 10
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 8000);

      n.changeQty(1, -10); // → 7, di bawah ambang
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 10000);
    });

    test('ambang grosir pakai qtyInBase (satuan jual × qtyPerBase)', () {
      final n = CartNotifier();
      n.addProduct(1, 'Air Galon', 10000);
      n.setUnit(1, 'dus', 12); // 1 dus = 12 pcs → langsung tembus ambang 10
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.qtyInBase, 12);
      expect(n.state.single.price, 8000);
    });

    test('item manual (ad-hoc) tidak kena grosir', () {
      final n = CartNotifier();
      n.addManualItem('Jasa angkut', 15000);
      n.recomputeWholesale(n.state.single.productId,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 15000);
    });

    test('per-kg item tidak kena grosir', () {
      final n = CartNotifier();
      n.addProduct(1, 'Cuci Kilo', 5000, weightKg: 3);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 10000, fullPrice: 12000);
      expect(n.state.single.price, 5000);
    });

    test('diskon standalone tetap tampil saat tanpa grosir', () {
      final n = CartNotifier();
      // Produk diskon 25%: sellPrice 12000 → effectivePrice 9000.
      n.addProduct(1, 'Snack', 9000, originalPrice: 12000);
      n.recomputeWholesale(1,
          wholesalePriceForQty: tierFor, normalPrice: 9000, fullPrice: 12000);
      // qty 1, no tier → harga normal (9000) dipertahankan, coret diskon utuh.
      expect(n.state.single.price, 9000);
      expect(n.state.single.originalPrice, 12000);
    });
  });

  group('FIX dobel diskon (v2.2.57+119)', () {
    test('produk berdiskon: unitPrice sudah final, itemDiscountTotal = 0', () {
      // Produk: harga 87500, diskon 37500 → effectivePrice 50000 (dari menu
      // Produk). originalPrice = coret 87500. Tanpa discountPerItem manual,
      // diskon produk TIDAK boleh dihitung lagi di itemDiscountTotal.
      final n = CartNotifier();
      n.addProduct(1, 'Produk Diskon', 50000, originalPrice: 87500);
      final item = n.state.single;
      expect(item.unitPrice, 50000);
      expect(item.hasDiscount, isTrue);
      expect(item.effectiveDiscountPerItem, 0);
      expect(item.itemDiscountTotal, 0);
      // Subtotal pakai harga final 50000 (bukan 12500!).
      expect(item.subtotal, 50000);
      // Total keranjang = 50000 (dulu kedobel → 12500).
      expect(n.total, 50000);
    });

    test('diskon per satuan manual tetap jalan (tidak nol)', () {
      final n = CartNotifier();
      n.addProduct(1, 'Produk', 50000);
      n.setDiscountPerItem(1, 10000);
      final item = n.state.single;
      expect(item.effectiveDiscountPerItem, 10000);
      expect(item.itemDiscountTotal, 10000);
      // Subtotal = harga final (diskon manual dipotong di total transaksi
      // lewat itemDiscountTotal — total keranjang POS = subtotal murni).
      expect(item.subtotal, 50000);
      expect(n.total, 50000);
      // Nilai yang sampai ke checkout: subtotal - itemDiscountTotal.
      expect(n.total - item.itemDiscountTotal, 40000);
    });

    test('produk berdiskon + diskon manual = TAMBAH diskon manual SAJA (tidak dobel)', () {
      // Produk 87500 → diskon 37500 → 50000. User tambah diskon manual 5000
      // → 45000 di checkout (dulu dobel: 87500-37500-37500-5000 = 7500).
      final n = CartNotifier();
      n.addProduct(1, 'Produk Diskon', 50000, originalPrice: 87500);
      n.setDiscountPerItem(1, 5000);
      final item = n.state.single;
      expect(item.unitPrice, 50000);
      expect(item.effectiveDiscountPerItem, 5000);
      expect(item.itemDiscountTotal, 5000);
      expect(item.subtotal, 50000);
      // Di checkout: 50000 - 5000 = 45000 (hanya diskon manual, tidak dobel).
      expect(n.total - item.itemDiscountTotal, 45000);
    });

    test('diskon manual tidak boleh lebih besar dari harga unit', () {
      final n = CartNotifier();
      n.addProduct(1, 'Produk', 30000);
      n.setDiscountPerItem(1, 50000);
      expect(n.state.single.effectiveDiscountPerItem, 30000);
      expect(n.state.single.itemDiscountTotal, 30000);
    });

    test('tempPrice (harga sementara) + discountPerItem tidak dobel', () {
      // Harga sementara 40000 dari harga normal 50000 → coret 50000.
      // User tambah diskon manual 5000 → di checkout 35000 (bukan 30000).
      final n = CartNotifier();
      n.addProduct(1, 'Produk', 50000, originalPrice: 50000);
      n.setTempPrice(1, 40000);
      n.setDiscountPerItem(1, 5000);
      final item = n.state.single;
      expect(item.unitPrice, 40000);
      expect(item.effectiveDiscountPerItem, 5000);
      expect(item.itemDiscountTotal, 5000);
      expect(item.subtotal, 40000);
      expect(n.total - item.itemDiscountTotal, 35000);
    });
  });
}
