import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/core/utils/receipt_renderer.dart';
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

  /// Subtotal KOTOR (sebelum diskon item) — struk menampilkan harga ASLI,
  /// bukan harga yang sudah dipotong diskon.
  int get grossSubtotal =>
      isPerKg ? (originalPrice ?? price) * weightKg!.ceil() : qty * (originalPrice ?? price);

  /// Potongan diskon item total (per unit × qty) — angka hemat yang benar.
  int get discountTotal => hasDiscount ? discountNominal * qty : 0;
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
                        // Preview = PNG yang SAMA dengan yang dicetak printer
                        // (renderReceiptPng → bit-image) — tidak mungkin beda.
                        width: settings.paperWidth == '80' ? 330 : 250,
                        constraints: const BoxConstraints(maxWidth: 330),
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
                        clipBehavior: Clip.antiAlias,
                        child: _receiptPreview(
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
    final logoPercent = await SecureStore.getReceiptLogoWidthPercent();
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
      logoPercent: logoPercent,
      paperWidth: paperWidth,
    );
  }

  /// Preview struk = widget NYATA (bukan PNG) yang meniru hasil print:
  /// header + logo digambar sebagai image dengan skala PERSEN dari lebar
  /// kertas (sama seperti bit-image di printer), rincian & footer sebagai
  /// teks mode Kecil(×1)/Besar(×2) — persis alur print hybrid v2.2.25.
  Widget _receiptPreview(
    BuildContext context,
    String storeName,
    bool isDark,
    _ReceiptSettings s,
  ) {
    final paperW = s.paperWidth == '80' ? 330.0 : 250.0;
    final headerScale = s.fontHeader.clamp(1, 100) / 100;
    final logoScale = s.logoPercent.clamp(1, 100) / 100;
    final itemsBig = s.fontItems >= 1;
    final footerBig = s.fontFooter >= 1;

    final mono = TextStyle(
      fontFamily: 'monospace',
      color: isDark ? NusaConfig.darkTextPrimary : Colors.black,
      fontSize: 11,
      height: 1.35,
    );
    final monoBold = mono.copyWith(fontWeight: FontWeight.w800);
    final monoGrey = mono.copyWith(
      color: isDark ? NusaConfig.darkTextSecondary : Colors.grey.shade600,
    );
    final itemsStyle = itemsBig ? mono.copyWith(fontSize: 15) : mono;
    final smallStyle = itemsBig ? mono.copyWith(fontSize: 11) : monoGrey;
    final footerStyle = footerBig
        ? mono.copyWith(fontSize: 13, fontWeight: FontWeight.w700)
        : mono.copyWith(fontSize: 11, fontWeight: FontWeight.w700);

    // Header yang benar-benar dicetak sebagai image: header custom jika ada,
    // fallback nama toko.
    final headerText = s.header.trim().isNotEmpty
        ? s.header.trim()
        : (storeName.isNotEmpty ? storeName : 'NUSA Kasir');
    final footerText = s.footer.trim().isNotEmpty
        ? s.footer.trim()
        : 'Terima Kasih!';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo (image, skala persen) — sama dengan bit-image print ──
          if (s.showLogo && s.logoPath != null && s.logoPath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Image.file(
                  File(s.logoPath!),
                  width: paperW * logoScale,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          // ── Header (image, skala persen) ──
          Center(
            child: Text(
              headerText,
              style: monoBold.copyWith(fontSize: 12 * headerScale),
              textAlign: TextAlign.center,
            ),
          ),
          if (s.showInvoice && invoice != null && invoice!.isNotEmpty)
            Center(child: Text(invoice!, style: smallStyle)),
          if (s.showDate && dateStr != null && dateStr!.isNotEmpty)
            Center(child: Text(dateStr!, style: smallStyle)),
          const SizedBox(height: 6),
          _dashedPreviewLine(),
          const SizedBox(height: 6),
          if (s.showCashier && cashierName != null && cashierName!.isNotEmpty)
            Text('Kasir: $cashierName', style: smallStyle),
          if (customerName != null && customerName!.isNotEmpty)
            Text('Pelanggan: $customerName', style: smallStyle),
          if (orderType != null && orderType!.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  tableName != null && tableName!.isNotEmpty
                      ? '$orderType - $tableName'
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
          const SizedBox(height: 6),
          _dashedPreviewLine(),
          const SizedBox(height: 6),
          // ── Rincian (teks mode Kecil/Besar — seperti print) ──
          ...items.map(
            (i) => _previewItem(i, itemsStyle, smallStyle),
          ),
          const SizedBox(height: 6),
          _dashedPreviewLine(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: monoBold),
              Text(_fmtPreview(total), style: monoBold),
            ],
          ),
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Diskon', style: smallStyle),
                  Text('-${_fmtPreview(discount)}', style: smallStyle),
                ],
              ),
            ),
          if (downPayment > 0) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bayar ($paymentMethod)', style: smallStyle),
                  Text(_fmtPreview(downPayment), style: smallStyle),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sisa Piutang', style: smallStyle),
                  Text(_fmtPreview(remainingDue), style: smallStyle),
                ],
              ),
            ),
          ] else ...[
            if (paymentMethod.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bayar ($paymentMethod)', style: smallStyle),
                    Text(_fmtPreview(cashGiven ?? total), style: smallStyle),
                  ],
                ),
              ),
            if (cashReturn != null && cashReturn! > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kembali', style: smallStyle),
                    Text(_fmtPreview(cashReturn!), style: smallStyle),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          _dashedPreviewLine(),
          const SizedBox(height: 8),
          if (footerText.isNotEmpty)
            Center(
              child: Text(
                footerText,
                style: footerStyle,
                textAlign: TextAlign.center,
              ),
            ),
          Center(child: Text(storeName, style: smallStyle)),
        ],
      ),
    );
  }

  /// Baris item preview — nama (teks mode), lalu qty × harga + diskon kurung
  /// + subtotal, persis layout print hybrid.
  Widget _previewItem(_ReceiptItem item, TextStyle itemsStyle, TextStyle smallStyle) {
    final isPerKg = item.isPerKg;
    final qtyLabel = isPerKg
        ? '${item.weightKg!.toStringAsFixed(1)} kg'
        : '${item.qty}';
    final unitPrice = item.price;
    final qtyTxt = isPerKg
        ? '$qtyLabel x ${_fmtPreview(unitPrice)}/kg'
        : '$qtyLabel x ${_fmtPreview(unitPrice)}';
    final discSuffix = item.hasDiscount
        ? '( -${_fmtPreview(item.discountTotal)} ) '
        : '';
    final subtotalTxt = isPerKg
        ? _fmtPreview((item.price * item.weightKg!).ceil())
        : _fmtPreview(item.qty * item.price);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: itemsStyle),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(qtyTxt, style: smallStyle),
              Text('$discSuffix$subtotalTxt', style: smallStyle),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '  > ${item.note}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Format angka "Rp1.234" ringkas (sama dengan teks print).
  static String _fmtPreview(int v) {
    final s = v.toString();
    final buf = StringBuffer('Rp');
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  Widget _dashedPreviewLine() => SizedBox(
    height: 2,
    child: CustomPaint(painter: _DashPainterPreview()),
  );

  /// Render PNG struk via `renderReceiptPng` — SATU-SATUNYA sumber untuk
  /// preview, print (bit-image), share, dan PDF.
  Future<Uint8List?> _renderPng(_ReceiptSettings s, {required bool real}) async {
    try {
      return await renderReceiptPng(_buildRenderConfig(s, real: real));
    } catch (_) {
      return null;
    }
  }

  /// Bangun `ReceiptRenderConfig` dari data transaksi (print/share/PDF) atau
  /// dummy (preview) — pengaturan ukuran dari SecureStore, jalur sama.
  ReceiptRenderConfig _buildRenderConfig(
    _ReceiptSettings s, {
    required bool real,
  }) {
    final logoBytes = (s.showLogo &&
            s.logoPath != null &&
            s.logoPath!.isNotEmpty &&
            File(s.logoPath!).existsSync())
        ? File(s.logoPath!).readAsBytesSync()
        : null;
    final paperWidth = s.paperWidth == '80' ? '80' : '58';

    if (real) {
      return ReceiptRenderConfig(
        storeName: s.storeName.isEmpty ? 'NUSA Kasir' : s.storeName,
        header: s.header,
        footer: s.footer,
        logoBytes: logoBytes,
        showLogo: s.showLogo,
        lines: items
            .map(
              (i) => ReceiptRenderLine(
                name: i.name,
                qty: i.qty,
                price: i.price,
                originalPrice: i.originalPrice,
                note: i.note,
                isPerKg: i.isPerKg,
                weightKg: i.weightKg,
              ),
            )
            .toList(),
        total: total,
        paymentMethod: paymentMethod,
        cashierName: s.showCashier ? cashierName : null,
        invoice: s.showInvoice ? (invoice ?? '') : '',
        dateStr: s.showDate ? (dateStr ?? '') : '',
        discount: discount,
        cashGiven: cashGiven,
        cashReturn: cashReturn,
        downPayment: downPayment,
        remainingDue: remainingDue,
        customerName: customerName,
        paperWidth: paperWidth,
        orderType: orderType,
        tableName: tableName,
        itemNotes: items.map((i) => i.note).toList(),
        // v2.2.25 hybrid: header persen 1-100 (image), rincian/footer mode
        // Kecil(×1)/Besar(×2) → ukuran share/PDF mengikuti mode yang dipilih.
        headerPercent: s.fontHeader.clamp(1, 100),
        itemsSizePx: s.fontItems >= 1 ? 24 : 12,
        footerSizePx: s.fontFooter >= 1 ? 24 : 12,
        logoWidthPercent: s.logoPercent.clamp(1, 100),
      );
    }

    // Preview dummy — struk contoh dengan pengaturan SAMA (sheet preview
    // tidak punya data transaksi asli; data dummy agar tampilan tetap hidup).
    return ReceiptRenderConfig(
      storeName: s.storeName.isEmpty ? 'NUSA Kasir' : s.storeName,
      header: s.header,
      footer: s.footer,
      logoBytes: logoBytes,
      showLogo: s.showLogo,
      lines: const [
        ReceiptRenderLine(name: 'Indomie Goreng', qty: 4, price: 3500),
        ReceiptRenderLine(name: 'Beras 5kg', qty: 1, price: 72000),
        ReceiptRenderLine(
          name: 'Minyak Goreng 2L',
          qty: 2,
          price: 34000,
          originalPrice: 38000,
        ),
        ReceiptRenderLine(name: 'Telur Ayam 10 butir', qty: 1, price: 28000),
        ReceiptRenderLine(name: 'Gula Pasir 1kg', qty: 1, price: 16000),
      ],
      total: 168000,
      discount: 8000,
      paymentMethod: 'Tunai',
      cashGiven: 200000,
      cashReturn: 32000,
      cashierName: s.showCashier ? 'Budi' : null,
      invoice: s.showInvoice ? 'INV-001' : '',
      dateStr: s.showDate ? '25 Jul 2026  14:30 WIB' : '',
      paperWidth: paperWidth,
      headerPercent: s.fontHeader.clamp(1, 100),
      itemsSizePx: s.fontItems >= 1 ? 24 : 12,
      footerSizePx: s.fontFooter >= 1 ? 24 : 12,
      logoWidthPercent: s.logoPercent.clamp(1, 100),
    );
  }

  /// Bangun file PDF dari PNG struk (preview = print = PDF) — satu halaman
  /// selebar gambar, identik dengan yang dicetak.
  Future<File> _buildReceiptPdf(_ReceiptSettings s, {required bool real}) async {
    final png = await _renderPng(s, real: real);
    if (png == null) throw Exception('render struk gagal');
    final decoded = await decodeImageFromList(png);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          decoded.width.toDouble(),
          decoded.height.toDouble(),
          marginAll: 0,
        ),
        build: (ctx) => pw.Image(
          pw.MemoryImage(png),
          fit: pw.BoxFit.contain,
          width: decoded.width.toDouble(),
          height: decoded.height.toDouble(),
        ),
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/struk_${invoice ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await doc.save());
    return file;
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

  // ── Share via WhatsApp — kirim GAMBAR struk (PNG yang sama dengan print) ──
  Future<void> _shareWA(
    BuildContext context,
    String storeName,
    _ReceiptSettings s,
  ) async {
    try {
      final png = await _renderPng(s, real: true);
      if (png == null) {
        if (context.mounted) TopToast.error(context, 'Gagal membuat struk');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/struk_${invoice ?? DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png);
      await Share.shareXFiles([XFile(file.path)], subject: 'Struk $storeName');
    } catch (_) {
      if (context.mounted) TopToast.error(context, 'Gagal membagikan struk');
    }
  }

  // ── Unduh PDF — PDF asli dari PNG struk (preview = print = PDF) ──
  Future<void> _downloadPdf(
    BuildContext context,
    WidgetRef ref,
    String storeName,
    _ReceiptSettings s,
  ) async {
    try {
      final file = await _buildReceiptPdf(s, real: true);
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
  // Font struk (mirror SecureStore): header persen 1-100 (image), rincian &
  // footer mode 0=Kecil(×1) / 1=Besar(×2).
  final String fontType;
  final int fontHeader;
  final int fontItems;
  final int fontFooter;
  final int logoPercent;
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
    this.fontHeader = receiptHeaderDefaultPercent,
    this.fontItems = 0,
    this.fontFooter = 0,
    this.logoPercent = receiptLogoDefaultPercent,
    this.paperWidth = '58',
  });
}

/// Garis putus-putus tipis di preview struk (meniru hasil print).
class _DashPainterPreview extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final dashW = 5.0;
    final gapW = 2.5;
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

