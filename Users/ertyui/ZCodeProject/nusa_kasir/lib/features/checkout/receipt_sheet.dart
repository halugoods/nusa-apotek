import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/features/pos/cart.dart';
import "package:nusa_kasir/shared/widgets/top_toast.dart";

/// A single receipt line (name, qty, price). Mirrors CartItem but decoupled.
class _ReceiptItem {
  final String name;
  final int qty;
  final int price;

  /// Harga jual sebelum diskon (null = tanpa diskon). Dipakai struk untuk
  /// menampilkan potongan NOMINAL per item, mis. "-Rp 5.000" di bawah item.
  final int? originalPrice;
  final String? note;
  final double? weightKg;
  const _ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    this.originalPrice,
    this.note,
    this.weightKg,
  });
  bool get isPerKg => weightKg != null;
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int get discountNominal => hasDiscount ? originalPrice! - price : 0;
  int get subtotal => isPerKg ? (price * weightKg!).ceil() : qty * price;
}

/// Thermal-style receipt dialog — matches GAS receipt modal design.
///
/// Centered dialog with 58mm thermal receipt aesthetic:
/// - monospace font, dashed separators
/// - store header, items, totals, footer
/// - Print (Bluetooth) + WhatsApp share buttons
class ReceiptSheet extends ConsumerWidget {
  final List<_ReceiptItem> items;
  final int total;
  final int discount;
  final String paymentMethod;
  final int? cashGiven;
  final int? cashReturn;
  final String? cashierName;
  final String? customerName;
  final String? customerPhone;
  final String? invoice;
  final String? dateStr;
  final int pointsUsed;
  final int pointsEarned;
  final bool autoPrint;

  final String? orderType;
  final String? tableName;
  final List<String?>? itemNotes;
  final int? laundryOrderId;
  final int? salonBookingId;
  final int downPayment; // DP (uang muka) — 0 jika tidak pakai DP
  final int remainingDue; // sisa piutang setelah DP — 0 jika lunas

  const ReceiptSheet({
    required this.items,
    required this.total,
    required this.discount,
    required this.paymentMethod,
    this.cashGiven,
    this.cashReturn,
    this.cashierName,
    this.customerName,
    this.customerPhone,
    this.invoice,
    this.dateStr,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.autoPrint = false,
    this.orderType,
    this.tableName,
    this.itemNotes,
    this.laundryOrderId,
    this.salonBookingId,
    this.downPayment = 0,
    this.remainingDue = 0,
    super.key,
  });

  /// Factory: from CartItem list (new transaction, just printed).
  factory ReceiptSheet.fromCart({
    required List<CartItem> cartItems,
    required int total,
    required int discount,
    required String paymentMethod,
    int? cashGiven,
    int? cashReturn,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    String? invoice,
    String? dateStr,
    int pointsUsed = 0,
    int pointsEarned = 0,
    bool autoPrint = false,
    String? orderType,
    String? tableName,
    int? laundryOrderId,
    int? salonBookingId,
    int downPayment = 0,
    int remainingDue = 0,
  }) {
    final items = cartItems
        .map(
          (c) => _ReceiptItem(
            name: c.name,
            qty: c.qty,
            price: c.price,
            originalPrice: c.originalPrice,
            note: c.note,
            weightKg: c.weightKg,
          ),
        )
        .toList();
    return ReceiptSheet(
      items: items,
      total: total,
      discount: discount,
      paymentMethod: paymentMethod,
      cashGiven: cashGiven,
      cashReturn: cashReturn,
      cashierName: cashierName,
      customerName: customerName,
      customerPhone: customerPhone,
      invoice: invoice,
      dateStr: dateStr,
      pointsUsed: pointsUsed,
      pointsEarned: pointsEarned,
      autoPrint: autoPrint,
      orderType: orderType,
      tableName: tableName,
      laundryOrderId: laundryOrderId,
      salonBookingId: salonBookingId,
      downPayment: downPayment,
      remainingDue: remainingDue,
    );
  }

  /// Factory: from raw maps (reprint from history).
  factory ReceiptSheet.fromMaps({
    required List<Map<String, dynamic>> rawItems,
    required int total,
    required int discount,
    required String paymentMethod,
    int? cashGiven,
    int? cashReturn,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    String? invoice,
    String? dateStr,
    int pointsUsed = 0,
    int pointsEarned = 0,
    String? orderType,
    String? tableName,
    int downPayment = 0,
    int remainingDue = 0,
  }) {
    final items = rawItems
        .map(
          (m) => _ReceiptItem(
            name: '${m['name'] ?? ''}',
            qty: (m['qty'] as num?)?.toInt() ?? 0,
            price: (m['price'] as num?)?.toInt() ?? 0,
            originalPrice: (m['originalPrice'] as num?)?.toInt(),
            note: m['note'] as String?,
            weightKg: (m['weightKg'] as num?)?.toDouble(),
          ),
        )
        .toList();
    return ReceiptSheet(
      items: items,
      total: total,
      discount: discount,
      paymentMethod: paymentMethod,
      cashGiven: cashGiven,
      cashReturn: cashReturn,
      cashierName: cashierName,
      customerName: customerName,
      customerPhone: customerPhone,
      invoice: invoice,
      dateStr: dateStr,
      pointsUsed: pointsUsed,
      pointsEarned: pointsEarned,
      orderType: orderType,
      tableName: tableName,
      downPayment: downPayment,
      remainingDue: remainingDue,
    );
  }

  /// Show as centered dialog (GAS style).
  static Future<void> show(
    BuildContext context, {
    required ReceiptSheet sheet,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: sheet),
    ).then((_) => onDismiss?.call());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.read(databaseProvider);

    // Auto-print: trigger after first frame if enabled.
    if (autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoPrintReceipt(context, ref);
      });
    }

    return FutureBuilder<_ReceiptSettings>(
      future: _loadSettings(db),
      builder: (context, snap) {
        final storeName = snap.data?.storeName ?? 'NUSA Kasir';
        final settings = snap.data ?? _ReceiptSettings();
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header bar ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkSurface2
                        : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 22,
                        color: Color(0xFFE63946),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Struk Pesanan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? NusaConfig.darkDivider
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Receipt body (scrollable) ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Container(
                        // Preview 2 arah: lebar ikut ukuran kertas setting
                        // (58mm → 250, 80mm → 330) — persis print asli.
                        width: settings.paperWidth == '80' ? 330 : 250,
                        constraints: const BoxConstraints(maxWidth: 330),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? NusaConfig.darkSurface2
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.08,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildReceipt(
                          context,
                          storeName,
                          isDark,
                          settings,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Action buttons ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // "Selesai & Tutup" — full width
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark
                                ? NusaConfig.darkSurface2
                                : Colors.grey.shade100,
                            foregroundColor: isDark
                                ? NusaConfig.darkTextPrimary
                                : Colors.grey.shade800,
                            side: BorderSide(
                              color: isDark
                                  ? NusaConfig.darkBorder
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Selesai & Tutup',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Cetak Printer — full width
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _printReceipt(context, ref, storeName),
                          icon: Icon(Icons.print, size: 18),
                          label: Text(
                            'Cetak Printer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      // Share WhatsApp + Unduh PDF (side by side)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _shareWA(context, storeName, settings),
                                icon: Icon(Icons.share, size: 16),
                                label: Text(
                                  'Share WA',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () => _downloadPdf(
                                  context,
                                  ref,
                                  storeName,
                                  settings,
                                ),
                                icon: Icon(Icons.download, size: 16),
                                label: Text(
                                  'Unduh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? NusaConfig.darkSurface2
                                      : Colors.grey.shade200,
                                  foregroundColor: isDark
                                      ? NusaConfig.darkTextPrimary
                                      : Colors.grey.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Load receipt settings + store name.
  Future<_ReceiptSettings> _loadSettings(AppDatabase db) async {
    final settingsRepo = SettingsRepository(db);
    final storeName = await settingsRepo.getStoreName();
    final toggles = await settingsRepo.getReceiptToggles();
    final header = await settingsRepo.getReceiptHeader() ?? '';
    final footer = await settingsRepo.getReceiptFooter() ?? '';
    final logoPath =
        await settingsRepo.getStoreLogoPath() ??
        await SecureStore.getPrinterLogoPath();
    // Font struk (SecureStore — single source untuk printing).
    final fontType = await SecureStore.getReceiptFontType();
    final fontHeader = await SecureStore.getReceiptFontHeader();
    final fontItems = await SecureStore.getReceiptFontItems();
    final fontFooter = await SecureStore.getReceiptFontFooter();
    // Ukuran kertas — preview mengikuti (58/80mm, komplain user).
    final paperWidth = await SecureStore.getPaperSize();
    return _ReceiptSettings(
      storeName: storeName,
      showLogo: toggles['showLogo'] ?? true,
      showCashier: toggles['showCashier'] ?? true,
      showInvoice: toggles['showInvoice'] ?? true,
      showDate: toggles['showDate'] ?? true,
      header: header,
      footer: footer,
      logoPath: logoPath,
      fontType: fontType,
      fontHeader: fontHeader,
      fontItems: fontItems,
      fontFooter: fontFooter,
      paperWidth: paperWidth,
    );
  }

  /// Builds the thermal-style receipt content with settings applied.
  Widget _buildReceipt(
    BuildContext context,
    String storeName,
    bool isDark,
    _ReceiptSettings s,
  ) {
    final textColor = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final subtleColor = isDark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    // "Anda hemat" — total potongan dari diskon per item (match print).
    final totalItemDiscount = items.fold<int>(
      0,
      (it, e) => it + (e.hasDiscount ? e.discountNominal : 0),
    );
    // Ukuran font per section mengikuti pengaturan struk (slider 1-8, sama
    // dengan print). Items dijadikan basis: 1 → 11pt, 8 → 18pt.
    final itemFontSize = 10.0 + s.fontItems.clamp(1, 8);
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: itemFontSize,
      height: 1.5,
      color: textColor,
    );
    final monoBold = TextStyle(
      fontFamily: 'monospace',
      fontSize: itemFontSize,
      height: 1.5,
      fontWeight: FontWeight.bold,
      color: textColor,
    );
    final monoBig = TextStyle(
      fontFamily: 'monospace',
      fontSize: itemFontSize + 2,
      height: 1.5,
      fontWeight: FontWeight.bold,
      color: textColor,
    );
    final monoHeader = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10.0 + s.fontHeader.clamp(1, 8),
      height: 1.4,
      fontWeight: FontWeight.bold,
      color: textColor,
    );
    final monoGrey = TextStyle(
      fontFamily: 'monospace',
      fontSize: itemFontSize,
      height: 1.5,
      color: subtleColor,
    );
    final monoFooter = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10.0 + s.fontFooter.clamp(1, 8),
      height: 1.5,
      fontWeight: FontWeight.bold,
      color: textColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Logo (dari pengaturan printer) ──
        if (s.showLogo && s.logoPath != null && s.logoPath!.isNotEmpty) ...[
          Center(
            child: Image.file(
              File(s.logoPath!),
              height: 48,
              fit: BoxFit.contain,
              cacheWidth: 200,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SizedBox(height: 4),
        ],

        // ── Store header ──
        Center(
          child: Text(
            storeName,
            style: monoHeader,
            textAlign: TextAlign.center,
          ),
        ),

        // Custom header text
        if (s.header.isNotEmpty) ...[
          SizedBox(height: 2),
          Center(
            child: Text(s.header, style: monoGrey, textAlign: TextAlign.center),
          ),
        ],
        SizedBox(height: 6),
        _dashedLine(isDark: isDark),
        SizedBox(height: 6),

        // ── Transaction info ──
        if (s.showInvoice && invoice != null)
          _monoRow('ID  : ', invoice!, mono, mono),
        if (s.showDate && dateStr != null)
          _monoRow('Tgl : ', dateStr!, mono, mono),
        if (s.showCashier && cashierName != null && cashierName!.isNotEmpty)
          _monoRow('Kasir:', cashierName!, mono, mono),
        if (customerName != null && customerName!.isNotEmpty)
          _monoRow('Pel  : ', customerName!, mono, mono),
        if (orderType != null && orderType!.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                tableName != null && tableName!.isNotEmpty
                    ? '$orderType — $tableName'
                    : orderType!,
                style: monoBold,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (laundryOrderId != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '#LND-${laundryOrderId.toString().padLeft(3, '0')} • Baru',
                style: monoBold,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (salonBookingId != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '#BKG-${salonBookingId.toString().padLeft(3, '0')} • Dikonfirmasi',
                style: monoBold,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        SizedBox(height: 6),
        _dashedLine(isDark: isDark),
        SizedBox(height: 6),

        // ── Items ──
        ...items.asMap().entries.map(
          (entry) => _buildItemRow(
            entry.value,
            entry.key,
            mono,
            monoGrey,
            subtleColor,
          ),
        ),

        SizedBox(height: 6),
        _dashedLine(isDark: isDark),
        SizedBox(height: 6),

        // ── TOTAL ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: monoBig),
              Text(formatRupiah(total), style: monoBig),
            ],
          ),
        ),

        // ── "Anda hemat" — total potongan diskon item (match print) ──
        if (totalItemDiscount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Anda hemat', style: monoGrey),
                Text(formatRupiah(totalItemDiscount), style: monoGrey),
              ],
            ),
          ),

        // ── Total diskon — tepat DI BAWAH TOTAL (komplain user) ──
        if (discount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Diskon', style: monoGrey),
                Text('-${formatRupiah(discount)}', style: monoGrey),
              ],
            ),
          ),

        // ── Payment ──
        if (downPayment > 0) ...[
          // DP: tunjukkan uang muka + sisa piutang (bukan baris Bayar biasa)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bayar ($paymentMethod)', style: monoGrey),
                Text(formatRupiah(downPayment), style: monoGrey),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sisa Piutang', style: monoGrey),
                Text(formatRupiah(remainingDue), style: monoGrey),
              ],
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bayar ($paymentMethod)', style: monoGrey),
                Text(formatRupiah(cashGiven ?? total), style: monoGrey),
              ],
            ),
          ),
          if (cashReturn != null && cashReturn! > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kembali', style: monoGrey),
                  Text(formatRupiah(cashReturn!), style: monoGrey),
                ],
              ),
            ),
        ],

        SizedBox(height: 6),
        _dashedLine(isDark: isDark),
        SizedBox(height: 8),

        // ── Footer ──
        Center(
          child: Text(
            s.footer.isNotEmpty ? s.footer : 'Terima Kasih!',
            style: monoFooter,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
    _ReceiptItem item,
    int index,
    TextStyle mono,
    TextStyle monoGrey,
    Color subtleColor,
  ) {
    final qtyDisplay = item.isPerKg
        ? '${item.weightKg!.toStringAsFixed(1)} kg'
        : '${item.qty}';
    // qty x harga asli + (potongan) — hemat 2 baris dibanding format
    // "Harga Normal:... / Diskon: -..." (konsisten dgn hasil print).
    final qtyPriceTxt = item.hasDiscount
        ? '$qtyDisplay x ${formatRupiah(item.price)} (-${formatRupiah(item.discountNominal)})'
        : item.isPerKg
        ? '$qtyDisplay x ${formatRupiah(item.price)}/kg'
        : '$qtyDisplay x ${formatRupiah(item.price)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: mono),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(qtyPriceTxt, style: monoGrey),
              Text(formatRupiah(item.subtotal), style: mono),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '\u21B3 ${item.note}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: subtleColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _monoRow(
    String label,
    String value,
    TextStyle monoL,
    TextStyle monoV,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(label, style: monoL),
          const Spacer(),
          Flexible(
            child: Text(value, style: monoV, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _dashedLine({bool isDark = false}) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(
        color: isDark ? NusaConfig.darkDivider : Color(0xFF999999),
      ),
    );
  }

  // ── Auto-print (silent fallback if printer unavailable) ──
  Future<void> _autoPrintReceipt(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final storeName = await SettingsRepository(db).getStoreName();
    if (storeName.isEmpty) return;

    // Pre-flight: check Bluetooth permissions & state
    if (!await ReceiptPrinter.ensureBluetoothReady()) {
      debugPrint('[ReceiptSheet] auto-print: Bluetooth not ready');
      return;
    }

    final printer = ReceiptPrinter();
    try {
      final savedAddr = await SecureStore.getPrinterAddress();

      final devices = await printer.discover(
        timeout: const Duration(seconds: 4),
      );
      PrinterDevice? target;
      if (savedAddr != null && savedAddr.contains('|')) {
        final addr = savedAddr.split('|').last;
        final found = devices.where((d) => d.address == addr);
        if (found.isNotEmpty) target = found.first;
      }

      // NEVER fall back to devices.first — an unconfigured printer would
      // target a random bonded device (e.g. TWS earbuds) instead of a real
      // thermal printer. If no saved printer matches, only a direct connect
      // to the saved address is attempted.

      // If discovery came back empty but a printer address was previously
      // saved, try connecting straight to that address — some Android
      // builds hide bonded devices until an explicit connect is attempted.
      if (target == null && savedAddr != null && savedAddr.contains('|')) {
        final addr = savedAddr.split('|').last;
        debugPrint(
          '[ReceiptSheet] auto-print: bonded list empty — direct connect $addr',
        );
        target = PrinterDevice(name: savedAddr.split('|').first, address: addr);
      }
      if (target == null) {
        debugPrint('[ReceiptSheet] auto-print: no printer available');
        return;
      }
      debugPrint(
        '[ReceiptSheet] auto-print: target ${target.name} (${target.address})',
      );

      final paperSize = await SecureStore.getPaperSize();
      final connected = await printer.connect(target);
      if (!connected) {
        debugPrint('[ReceiptSheet] auto-print: connect FAILED');
        return;
      }

      // Ensure logo + footer are loaded for print
      final logoPath = await SecureStore.getPrinterLogoPath();
      if (logoPath != null) await ReceiptPrinter.loadLogo(logoPath);
      ReceiptPrinter.setFooter(await SecureStore.getPrinterFooter());

      // Respect the "show logo on receipt" toggle from Pengaturan Struk
      final toggles = await SettingsRepository(db).getReceiptToggles();
      final showLogo = toggles['showLogo'] ?? true;

      final ok = await printer.printReceipt(
        storeName: storeName.isNotEmpty ? storeName : 'NUSA Kasir',
        lines: items
            .map(
              (i) => ReceiptLine(
                name: i.name,
                qty: i.qty,
                price: i.price,
                originalPrice: i.originalPrice,
              ),
            )
            .toList(),
        total: total,
        paymentMethod: paymentMethod,
        cashierName: cashierName,
        invoice: invoice ?? '',
        dateStr: dateStr ?? '',
        discount: discount,
        cashGiven: cashGiven,
        cashReturn: cashReturn,
        downPayment: downPayment,
        remainingDue: remainingDue,
        customerName: customerName,
        paperWidth: paperSize,
        showLogo: showLogo,
        orderType: orderType,
        tableName: tableName,
        itemNotes: items.map((i) => i.note).toList(),
      );
      if (!ok) debugPrint('[ReceiptSheet] auto-print: sendBytes FAILED');
    } catch (e) {
      debugPrint('[ReceiptSheet] auto-print error: $e');
    } finally {
      printer.dispose();
    }
  }

  // ── Print (Bluetooth thermal) ──
  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    String storeName,
  ) async {
    if (!context.mounted) return;

    // Step 1: Bluetooth pre-flight
    if (!await ReceiptPrinter.ensureBluetoothReady()) {
      TopToast.error(
        context,
        'Bluetooth tidak siap. Periksa izin & nyalakan Bluetooth.',
      );
      return;
    }

    // Step 2: Discover
    final printer = ReceiptPrinter();
    try {
      final devices = await printer.discover();
      if (!context.mounted) return;
      if (devices.isEmpty) {
        TopToast.error(
          context,
          'Tidak ada printer. Pairing dulu di Bluetooth HP.',
        );
        return;
      }

      // Step 3: Pick target — the SAVED printer ONLY (single source of
      // truth, kept in sync by printer settings sheet). No fallback to
      // devices.first: that can route print jobs to a random bonded device
      // (e.g. TWS earbuds) when no printer is configured.
      final savedAddr = await SecureStore.getPrinterAddress();
      PrinterDevice? target;
      if (savedAddr != null && savedAddr.contains('|')) {
        final addr = savedAddr.split('|').last;
        final found = devices.where((d) => d.address == addr);
        if (found.isNotEmpty) target = found.first;
      }
      if (target == null) {
        TopToast.error(
          context,
          'Printer belum diatur. Pilih printer di Pengaturan.',
        );
        printer.dispose();
        return;
      }

      // Step 4: Connect
      final connected = await printer.connect(target);
      if (!context.mounted) return;
      if (!connected) {
        TopToast.error(context, 'Gagal tersambung ke printer ${target.name}');
        printer.dispose();
        return;
      }

      // Step 5: Load logo + footer, honor show-logo toggle
      final paperSize = await SecureStore.getPaperSize();
      final logoPath2 = await SecureStore.getPrinterLogoPath();
      if (logoPath2 != null) await ReceiptPrinter.loadLogo(logoPath2);
      ReceiptPrinter.setFooter(await SecureStore.getPrinterFooter());
      final toggles2 = await SettingsRepository(
        ref.read(databaseProvider),
      ).getReceiptToggles();
      final showLogo2 = toggles2['showLogo'] ?? true;

      // Step 6: Print
      final ok = await printer.printReceipt(
        storeName: storeName,
        lines: items
            .map(
              (i) => ReceiptLine(
                name: i.name,
                qty: i.qty,
                price: i.price,
                originalPrice: i.originalPrice,
              ),
            )
            .toList(),
        total: total,
        paymentMethod: paymentMethod,
        cashierName: cashierName,
        invoice: invoice ?? '',
        dateStr: dateStr ?? '',
        discount: discount,
        cashGiven: cashGiven,
        cashReturn: cashReturn,
        downPayment: downPayment,
        remainingDue: remainingDue,
        customerName: customerName,
        paperWidth: paperSize,
        showLogo: showLogo2,
        orderType: orderType,
        tableName: tableName,
        itemNotes: items.map((i) => i.note).toList(),
      );
      if (!context.mounted) return;
      if (ok) {
        TopToast.success(context, 'Struk berhasil dicetak');
      } else {
        TopToast.error(context, 'Gagal mengirim data ke printer. Coba lagi.');
      }
    } catch (e) {
      if (context.mounted) {
        TopToast.error(context, 'Gagal mencetak: $e');
      }
    } finally {
      printer.dispose();
    }
  }

  // ── Share via WhatsApp ──
  Future<void> _shareWA(
    BuildContext context,
    String storeName,
    _ReceiptSettings s,
  ) async {
    final sb = StringBuffer();
    sb.writeln('*$storeName*');
    if (s.header.isNotEmpty) sb.writeln(s.header);
    sb.writeln('━━━━━━━━━━━━━━━━━');
    if (s.showInvoice && invoice != null) sb.writeln('ID  : $invoice');
    if (s.showDate && dateStr != null) sb.writeln('Tgl : $dateStr');
    if (s.showCashier && cashierName != null && cashierName!.isNotEmpty) {
      sb.writeln('Kasir: $cashierName');
    }
    if (customerName != null && customerName!.isNotEmpty) {
      sb.writeln('Pel  : $customerName');
    }
    if (orderType != null && orderType!.isNotEmpty) {
      if (tableName != null && tableName!.isNotEmpty) {
        sb.writeln('*$orderType — $tableName*');
      } else {
        sb.writeln('*$orderType*');
      }
    }
    sb.writeln('━━━━━━━━━━━━━━━━━');
    for (final item in items) {
      sb.writeln(item.name);
      sb.writeln(
        '  ${item.qty} x ${formatRupiah(item.price)}  = ${formatRupiah(item.subtotal)}',
      );
      if (item.hasDiscount) {
        sb.writeln('  Diskon: -${formatRupiah(item.discountNominal)}');
      }
      if (item.note != null && item.note!.isNotEmpty) {
        sb.writeln('  ↳ ${item.note}');
      }
    }
    sb.writeln('━━━━━━━━━━━━━━━━━');
    if (discount > 0) sb.writeln('Diskon      : -${formatRupiah(discount)}');
    if (pointsUsed > 0)
      sb.writeln('Tukar Poin  : -${formatRupiah(pointsUsed)}');
    if (pointsEarned > 0) sb.writeln('Poin Didapat: +$pointsEarned poin');
    sb.writeln('*TOTAL       : ${formatRupiah(total)}*');
    if (downPayment > 0) {
      sb.writeln('Bayar ($paymentMethod) : ${formatRupiah(downPayment)}');
      sb.writeln('Sisa Piutang: ${formatRupiah(remainingDue)}');
    } else {
      sb.writeln(
        'Bayar ($paymentMethod) : ${formatRupiah(cashGiven ?? total)}',
      );
    }
    if (cashReturn != null && cashReturn! > 0) {
      sb.writeln('Kembali     : ${formatRupiah(cashReturn!)}');
    }
    sb.writeln('━━━━━━━━━━━━━━━━━');
    sb.writeln(s.footer.isNotEmpty ? s.footer : 'Terima Kasih!');

    try {
      final encoded = Uri.encodeComponent(sb.toString());
      final uri = Uri.parse('https://wa.me/?text=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) TopToast.error(context, 'Gagal membuka WhatsApp');
    }
  }

  // ── Unduh PDF receipt ──
  Future<void> _downloadPdf(
    BuildContext context,
    WidgetRef ref,
    String storeName,
    _ReceiptSettings s,
  ) async {
    try {
      // Generate PDF using the existing receipt structure as text
      final sb = StringBuffer();
      sb.writeln(storeName);
      if (s.header.isNotEmpty) sb.writeln(s.header);
      sb.writeln('─' * 32);
      if (s.showInvoice && invoice != null) sb.writeln('ID  : $invoice');
      if (s.showDate && dateStr != null) sb.writeln('Tgl : $dateStr');
      if (s.showCashier && cashierName != null && cashierName!.isNotEmpty)
        sb.writeln('Kasir: $cashierName');
      if (customerName != null && customerName!.isNotEmpty)
        sb.writeln('Pel  : $customerName');
      sb.writeln('─' * 32);
      for (final item in items) {
        sb.writeln(item.name);
        sb.writeln(
          '  ${item.qty} x ${formatRupiah(item.price)}  = ${formatRupiah(item.subtotal)}',
        );
        if (item.hasDiscount) {
          sb.writeln('  Diskon: -${formatRupiah(item.discountNominal)}');
        }
        if (item.note != null && item.note!.isNotEmpty) {
          sb.writeln('  \u21B3 ${item.note}');
        }
      }
      sb.writeln('─' * 32);
      if (discount > 0) sb.writeln('Diskon      : -${formatRupiah(discount)}');
      if (pointsUsed > 0)
        sb.writeln('Tukar Poin  : -${formatRupiah(pointsUsed)}');
      if (pointsEarned > 0) sb.writeln('Poin Didapat: +$pointsEarned poin');
      sb.writeln('TOTAL       : ${formatRupiah(total)}');
      if (downPayment > 0) {
        sb.writeln('Bayar ($paymentMethod) : ${formatRupiah(downPayment)}');
        sb.writeln('Sisa Piutang: ${formatRupiah(remainingDue)}');
      } else {
        sb.writeln(
          'Bayar ($paymentMethod) : ${formatRupiah(cashGiven ?? total)}',
        );
      }
      if (cashReturn != null && cashReturn! > 0)
        sb.writeln('Kembali     : ${formatRupiah(cashReturn!)}');
      sb.writeln('─' * 32);
      sb.writeln(s.footer.isNotEmpty ? s.footer : 'Terima Kasih!');

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/struk_${invoice ?? DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(sb.toString());
      await Share.shareXFiles([XFile(file.path)], subject: 'Struk $storeName');

      if (context.mounted)
        TopToast.success(context, 'Struk berhasil dibagikan');
    } catch (_) {
      if (context.mounted) TopToast.error(context, 'Gagal mengunduh struk');
    }
  }
}

/// Holds receipt display settings loaded from DB.
class _ReceiptSettings {
  final String storeName;
  final bool showLogo;
  final bool showCashier;
  final bool showInvoice;
  final bool showDate;
  final String header;
  final String footer;
  final String? logoPath;
  // Font struk (mirror SecureStore): jenis 'standar'/'kompak' + ukuran per section.
  final String fontType;
  final int fontHeader;
  final int fontItems;
  final int fontFooter;
  // Ukuran kertas '58'/'80' — preview ikut (komplain user: preview 2 arah).
  final String paperWidth;

  _ReceiptSettings({
    this.storeName = '',
    this.showLogo = true,
    this.showCashier = true,
    this.showInvoice = true,
    this.showDate = true,
    this.header = '',
    this.footer = '',
    this.logoPath,
    this.fontType = 'standar',
    this.fontHeader = 2,
    this.fontItems = 1,
    this.fontFooter = 1,
    this.paperWidth = '58',
  });
}

/// Custom painter for dashed horizontal line (mimics GAS border-top: dashed).
class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter({this.color = const Color(0xFF999999)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const dashW = 4.0;
    const gapW = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dashW).clamp(0, size.width), 0),
        paint,
      );
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
