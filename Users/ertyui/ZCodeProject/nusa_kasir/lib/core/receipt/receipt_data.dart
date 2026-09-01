import 'package:nusa_kasir/features/pos/cart.dart';

/// Satu baris item struk — data MURNI (nama, qty, harga, diskon), tanpa
/// setting. Ini pengganti `_ReceiptItem` (receipt_sheet) & parsing manual
/// map (transactions_screen) — satu model dipakai renderer + preview.
class ReceiptItem {
  final String name;
  final int qty;
  final int price;

  /// Harga jual sebelum diskon (null = tanpa diskon). Saat diisi, struk
  /// mencetak baris "Disc. (-RpX)" di bawah item.
  final int? originalPrice;
  final String? note;

  /// Berat (kg) untuk item per-kg (market). Null = item satuan.
  final double? weightKg;

  /// Label satuan jual (v2.2.43 dinamis), mis. "dus", "karton". Null =
  /// fallback 'pcs' (renderer menampilkan qty polos).
  final String? unitLabel;

  /// Diskon nominal per SATUAN (v2.2.57+116) — dipotong di subtotal,
  /// ditampilkan sebagai baris "Disc." tambahan.
  final int? discountPerItem;

  /// Diskon dari MENU PRODUK per satuan (v2.2.57+126): diskon grosir/
  /// diskon yang sudah tercermin di [price]. Dipisah dari [discountPerItem]
  /// supaya struk tampilkan dua baris: "Disc. Produk (-X)" dan "Disc. Manual
  /// (-Y)" — user tahu mana diskon dari menu produk vs diskon ubah di kasir.
  final int? productDiscount;

  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    this.originalPrice,
    this.note,
    this.weightKg,
    this.unitLabel,
    this.discountPerItem,
    this.productDiscount,
  });

  bool get isPerKg => weightKg != null;

  /// Harga per unit efektif (setelah harga sementara & diskon per satuan).
  int get unitPrice => price;
  bool get hasDiscount =>
      (originalPrice != null && originalPrice! > price) ||
      (productDiscount != null && productDiscount! > 0) ||
      (discountPerItem != null && discountPerItem! > 0);
  /// Total potongan per SATUAN = diskon produk + diskon manual (v2.2.57+126).
  /// Tampilan struk pisahkan keduanya (Disc. Produk / Disc. Manual).
  int get discountNominal => (productDiscount ?? 0) + (discountPerItem ?? 0);
  int get subtotal =>
      isPerKg
          ? (price * weightKg!).ceil() - discountNominal
          : qty * price - discountNominal * qty;

  /// Subtotal KOTOR (sebelum diskon item) — harga ASLI di struk.
  int get grossSubtotal =>
      isPerKg
          ? (originalPrice ?? price) * weightKg!.ceil()
          : qty * (originalPrice ?? price);

  /// Potongan diskon item total (per unit × qty).
  int get discountTotal =>
      discountNominal * (isPerKg ? 1 : qty);

  /// Format qty untuk baris item: "2 x Rp 5.000" atau "1.5 kg x Rp 5.000/kg"
  /// atau "2 dus (24 pcs)" bila produk pakai satuan jual (v2.2.43).
  String get qtyLabel {
    if (isPerKg) return '${weightKg!.toStringAsFixed(1)} kg';
    if (unitLabel == null || unitLabel!.isEmpty) return '$qty';
    if (qty <= 1) return '$qty $unitLabel';
    return '$qty $unitLabel';
  }
}

/// Data transaksi struk — MURNI data, tanpa config template.
///
/// Dipisahkan dari [ReceiptConfig] (spec G): template bisa berubah tanpa
/// mengubah data, dan transaksi lama (reprint) memakai data lama + config
/// terbaru.
class ReceiptData {
  final String invoiceNumber;
  final String dateStr;
  final String? cashierName;
  final String? customerName;
  final String? orderType;
  final String? tableName;
  final List<ReceiptItem> items;
  final int discount; // diskon TRANSAKSI (promo/manual/tier/poin)
  final int total;
  final int? cashGiven;
  final int? cashReturn;
  final int downPayment; // DP (uang muka) — 0 jika tidak pakai DP
  final int remainingDue; // sisa piutang — 0 jika lunas
  final String paymentMethod;
  final int pointsUsed;
  final int pointsEarned;

  const ReceiptData({
    this.invoiceNumber = '',
    this.dateStr = '',
    this.cashierName,
    this.customerName,
    this.orderType,
    this.tableName,
    this.items = const [],
    this.discount = 0,
    this.total = 0,
    this.cashGiven,
    this.cashReturn,
    this.downPayment = 0,
    this.remainingDue = 0,
    this.paymentMethod = '',
    this.pointsUsed = 0,
    this.pointsEarned = 0,
  });

  /// Total diskon struk = diskon item (harga asli vs final × qty) +
  /// diskon transaksi. Dipakai summary "Disc. (-RpX)" (spec S/T).
  int get totalDiscount {
    final itemDisc = items.fold<int>(
      0,
      (acc, it) => acc + it.discountTotal,
    );
    return itemDisc + discount;
  }

  /// Alokasi diskon TRANSAKSI ([discount] — promo/manual/tier/poin) secara
  /// PROPORSIONAL ke tiap item (v2.2.57+122).
  ///
  /// Bug fix: sebelumnya diskon transaksi hanya tampil di summary "Disc."
  /// sehingga Σ subtotal item ≠ Grand Total. Sekarang potongan dibagi ke
  /// tiap item sebanding subtotal nettonya (largest-remainder method, jadi
  /// Σ alokasi == [discount] persis), lalu renderer mengurangi dari subtotal
  /// item → akumulasi harga item di struk = Grand Total.
  ///
  /// Index paralel dengan [items] (0 = item pertama). Item dengan subtotal 0
  /// atau saat tidak ada diskon transaksi mendapat 0.
  List<int> get allocatedTransactionDiscounts {
    final d = discount;
    if (d <= 0 || items.isEmpty) return List.filled(items.length, 0);
    final net = items.map((it) => it.subtotal).toList();
    final totalNet = net.fold<int>(0, (a, b) => a + b);
    if (totalNet <= 0) return List.filled(items.length, 0);

    final alloc = List<int>.filled(items.length, 0);
    final remainder = <double>[];
    var used = 0;
    for (var i = 0; i < items.length; i++) {
      final exact = net[i] * d / totalNet;
      final floor = exact.floor();
      final a = floor > net[i] ? net[i] : floor; // tak boleh > subtotal item
      alloc[i] = a;
      used += a;
      remainder.add(exact - floor);
    }
    // Sisa pembulatan (maks < items.length) → item dengan sisa pecahan
    // terbesar dulu, supaya distribusi paling adil & Σ == d persis.
    var sisa = d - used;
    final order = List<int>.generate(items.length, (i) => i)
      ..sort((a, b) => remainder[b].compareTo(remainder[a]));
    for (final idx in order) {
      if (sisa <= 0) break;
      final room = net[idx] - alloc[idx];
      if (room > 0) {
        alloc[idx] += 1;
        sisa -= 1;
      }
    }
    return alloc;
  }

  /// Catatan per item (paralel dengan [items], null = tidak ada).
  List<String?> get itemNotes => items.map((i) => i.note).toList();

  // ── Factory dari CartItem (transaksi baru / checkout) ──
  factory ReceiptData.fromCart({
    required List<CartItem> cartItems,
    required int total,
    required int discount,
    required String paymentMethod,
    int? cashGiven,
    int? cashReturn,
    String? cashierName,
    String? customerName,
    String? invoiceNumber,
    String? dateStr,
    int pointsUsed = 0,
    int pointsEarned = 0,
    String? orderType,
    String? tableName,
    int downPayment = 0,
    int remainingDue = 0,
  }) {
    return ReceiptData(
      invoiceNumber: invoiceNumber ?? '',
      dateStr: dateStr ?? '',
      cashierName: cashierName,
      customerName: customerName,
      orderType: orderType,
      tableName: tableName,
      items: cartItems
          // v2.2.57+116: item dengan toggle "informasikan di struk" OFF
          // tidak dicetak di struk (transaksi tetap tersimpan lengkap).
          .where((c) => c.showInReceipt)
          .map(
            (c) => ReceiptItem(
              // v2.2.43: nama + varian ("Nama — Varian") di struk.
              name: c.displayName,
              qty: c.qty,
              price: c.unitPrice,
              originalPrice: c.originalPrice,
              note: c.note,
              weightKg: c.weightKg,
              // v2.2.43: satuan jual dinamis (qtyLabel pakai ini).
              unitLabel: c.unitName,
              // v2.2.57+116: diskon per satuan → baris "Disc." struk.
              // v2.2.57+126: pisahkan diskon produk vs diskon manual.
              discountPerItem: c.discountPerItem,
              productDiscount: c.productDiscount,
            ),
          )
          .toList(),
      discount: discount,
      total: total,
      cashGiven: cashGiven,
      cashReturn: cashReturn,
      downPayment: downPayment,
      remainingDue: remainingDue,
      paymentMethod: paymentMethod,
      pointsUsed: pointsUsed,
      pointsEarned: pointsEarned,
    );
  }

  /// Factory dari raw maps (reprint dari riwayat transaksi).
  factory ReceiptData.fromMaps({
    required List<Map<String, dynamic>> rawItems,
    required int total,
    required int discount,
    required String paymentMethod,
    int? cashGiven,
    int? cashReturn,
    String? cashierName,
    String? customerName,
    String? invoiceNumber,
    String? dateStr,
    int pointsUsed = 0,
    int pointsEarned = 0,
    String? orderType,
    String? tableName,
    int downPayment = 0,
    int remainingDue = 0,
  }) {
    return ReceiptData(
      invoiceNumber: invoiceNumber ?? '',
      dateStr: dateStr ?? '',
      cashierName: cashierName,
      customerName: customerName,
      orderType: orderType,
      tableName: tableName,
      items: rawItems
          .map((m) {
            final baseName = '${m['name'] ?? ''}';
            final v = m['variantName'] as String?;
            // v2.2.43: reprint tampilkan varian bila disimpan saat checkout.
            final display = (v != null && v.isNotEmpty && baseName.isNotEmpty)
                ? '$baseName — $v'
                : baseName;
            return ReceiptItem(
              name: display,
              qty: (m['qty'] as num?)?.toInt() ?? 0,
              price: (m['price'] as num?)?.toInt() ?? 0,
              originalPrice: (m['originalPrice'] as num?)?.toInt(),
              note: m['note'] as String?,
              weightKg: (m['weightKg'] as num?)?.toDouble(),
              unitLabel: m['unitName'] as String?,
              discountPerItem: (m['discountPerItem'] as num?)?.toInt(),
              productDiscount: (m['productDiscount'] as num?)?.toInt(),
            );
          })
          .toList(),
      discount: discount,
      total: total,
      cashGiven: cashGiven,
      cashReturn: cashReturn,
      downPayment: downPayment,
      remainingDue: remainingDue,
      paymentMethod: paymentMethod,
      pointsUsed: pointsUsed,
      pointsEarned: pointsEarned,
    );
  }

  /// Data sample untuk Tes Cetak & preview Pengaturan Struk (spec W):
  /// invoice INV-20260817-0001, kasir Halu, 5 item (2 berdiskon),
  /// TOTAL 112.300, Disc. 5.700, Tunai 120.000, Kembalian 7.700.
  factory ReceiptData.sample() {
    return const ReceiptData(
      invoiceNumber: 'INV-20260817-0001',
      dateStr: '17/08/2026  15:42',
      cashierName: 'Halu',
      items: [
        ReceiptItem(name: 'Dimsum Original', qty: 2, price: 13500, originalPrice: 15000),
        ReceiptItem(name: 'Dimsum Mentai', qty: 1, price: 20000),
        ReceiptItem(name: 'Dimsum Keju', qty: 3, price: 17100, originalPrice: 18000),
        ReceiptItem(name: 'Es Teh Manis', qty: 2, price: 5000),
        ReceiptItem(name: 'Air Mineral', qty: 1, price: 4000),
      ],
      total: 112300,
      discount: 0,
      cashGiven: 120000,
      cashReturn: 7700,
      paymentMethod: 'Tunai',
    );
  }
}
