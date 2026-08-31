import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/receipt/receipt_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_data.dart';
import 'package:nusa_kasir/core/receipt/receipt_preview_widget.dart';
import 'package:nusa_kasir/core/receipt/receipt_renderer.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
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

  /// Diskon nominal per SATUAN (v2.2.57+116) — diteruskan ke ReceiptItem
  /// supaya preview/print/share konsisten (baris "Disc." per item).
  final int? discountPerItem;
  const _ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    this.originalPrice,
    this.note,
    this.weightKg,
    this.discountPerItem,
  });
  bool get isPerKg => weightKg != null;
  bool get hasDiscount =>
      (originalPrice != null && originalPrice! > price) ||
      (discountPerItem != null && discountPerItem! > 0);
  int get discountNominal => discountPerItem ?? 0;
  int get subtotal =>
      isPerKg
          ? (price * weightKg!).ceil() - (discountPerItem ?? 0)
          : qty * price - (discountPerItem ?? 0) * qty;

  /// Subtotal KOTOR (sebelum diskon item) — struk menampilkan harga ASLI,
  /// bukan harga yang sudah dipotong diskon.
  int get grossSubtotal =>
      isPerKg ? (originalPrice ?? price) * weightKg!.ceil() : qty * (originalPrice ?? price);

  /// Potongan diskon item total (per unit × qty) — angka hemat yang benar.
  int get discountTotal =>
      (discountPerItem ?? 0) * (isPerKg ? 1 : qty);
}

/// Thermal-style receipt dialog — matches GAS receipt modal design.
///
/// Centered dialog with 58mm thermal receipt aesthetic:
/// - preview dari SATU ReceiptPreview widget (renderer SAMA dengan print)
/// - Print (Bluetooth) + WhatsApp share + Unduh PDF
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
            // v2.2.57+122: harga sementara (tempPrice) ikut tampil di preview
            // struk — sebelumnya c.price (harga asli) sehingga preview struk
            // bisa beda dengan struk tercetak/tersimpan.
            price: c.unitPrice,
            originalPrice: c.originalPrice,
            note: c.note,
            weightKg: c.weightKg,
            discountPerItem: c.discountPerItem,
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

    return FutureBuilder<ReceiptLoad>(
      future: _loadConfig(db),
      builder: (context, snap) {
        final load = snap.data;
        final config = load?.config ?? ReceiptConfig.sample();
        final storeName = load?.storeName ?? 'NUSA Kasir';
        final data = ReceiptData(
          invoiceNumber: invoice ?? '',
          dateStr: dateStr ?? '',
          cashierName: cashierName,
          customerName: customerName,
          orderType: orderType,
          tableName: tableName,
          items: items
              .map(
                (it) => ReceiptItem(
                  name: it.name,
                  qty: it.qty,
                  price: it.price,
                  originalPrice: it.originalPrice,
                  note: it.note,
                  weightKg: it.weightKg,
                  discountPerItem: it.discountPerItem,
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
                      child: ReceiptPreview(
                        config: config,
                        data: data,
                        storeName: storeName,
                        dark: isDark,
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
                                    _shareWA(context, storeName, config, data),
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
                                  config,
                                  data,
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

  /// Load config struk (SATU sumber) + nama toko.
  Future<ReceiptLoad> _loadConfig(AppDatabase db) async {
    final settingsRepo = SettingsRepository(db);
    final storeName = await settingsRepo.getStoreName();
    final config = await ReceiptConfig.load(db);
    return ReceiptLoad(storeName: storeName, config: config);
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

      // Ensure logo is loaded for print (footer & toggle ikut config
      // dari printReceipt → ReceiptConfig.loadFromStore()).
      final logoPath = await SecureStore.getPrinterLogoPath();
      if (logoPath != null) await ReceiptPrinter.loadLogo(logoPath);

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
                discountPerItem: i.discountPerItem,
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

      // Step 5: Load logo, honor show-logo toggle (footer ikut config)
      final paperSize = await SecureStore.getPaperSize();
      final logoPath2 = await SecureStore.getPrinterLogoPath();
      if (logoPath2 != null) await ReceiptPrinter.loadLogo(logoPath2);
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
                discountPerItem: i.discountPerItem,
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

  // ── Share via WhatsApp — teks dari SATU renderer (renderText) ──
  Future<void> _shareWA(
    BuildContext context,
    String storeName,
    ReceiptConfig config,
    ReceiptData data,
  ) async {
    final text = renderText(
      config: config,
      data: data,
      storeName: storeName,
    );
    try {
      final encoded = Uri.encodeComponent(text);
      final uri = Uri.parse('https://wa.me/?text=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) TopToast.error(context, 'Gagal membuka WhatsApp');
    }
  }

  // ── Unduh PDF — file PDF ASLI dari SATU renderer (renderPdf) ──
  Future<void> _downloadPdf(
    BuildContext context,
    WidgetRef ref,
    String storeName,
    ReceiptConfig config,
    ReceiptData data,
  ) async {
    try {
      final file = await renderPdf(
        config: config,
        data: data,
        storeName: storeName,
        invoice: data.invoiceNumber,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Struk $storeName'),
      );
      if (context.mounted) {
        TopToast.success(context, 'Struk PDF berhasil dibagikan');
      }
    } catch (_) {
      if (context.mounted) TopToast.error(context, 'Gagal mengunduh struk');
    }
  }
}

/// Hasil load config struk + nama toko (dipakai FutureBuilder di build).
class ReceiptLoad {
  final String storeName;
  final ReceiptConfig config;
  const ReceiptLoad({required this.storeName, required this.config});
}
