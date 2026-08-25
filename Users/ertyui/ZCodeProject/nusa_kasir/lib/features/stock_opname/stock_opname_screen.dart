import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/stock_count_repository.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/animated_scanner_overlay.dart';
import 'package:google_fonts/google_fonts.dart';

class StockOpnameScreen extends ConsumerStatefulWidget {
  final bool embedded;

  /// v2.2.46: callback saat State siap — dipakai layar induk (Stok) untuk
  /// memegang referensi State opname agar scan HID di tab Opname bisa
  /// diteruskan (handleBarcode). Sebelumnya GlobalKey via `screenKey` TIDAK
  /// pernah terisi (GlobalKey.currentState hanya jalan kalau key dipakai
  /// sebagai widget key) → scan HID di tab Opname jatuh ke "Stok Masuk".
  final ValueChanged<StockOpnameScreenState>? onStateReady;

  /// v2.2.44 (B6): callback ke layar induk (Stok) agar scan barcode dari
  /// Stok tab bisa diferuskan ke opname saat tab Opname aktif.
  StockOpnameScreen(
      {super.key,
      this.embedded = false,
      this.onStateReady,
      this.onBarcodeHandled});

  /// Callback dipanggil layar induk saat barcode HID diteruskan.
  final ValueChanged<String>? onBarcodeHandled;

  @override
  ConsumerState<StockOpnameScreen> createState() => StockOpnameScreenState();
}

class StockOpnameScreenState extends ConsumerState<StockOpnameScreen> {
  StockCount? _activeSession;
  List<StockCountItem> _items = [];
  List<StockCount> _sessions = [];
  bool _loading = true;
  int _tabIndex = 0; // 0 = Opname aktif, 1 = Riwayat

  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<int, TextEditingController> _physicalControllers = {};
  bool _finalizing = false;

  /// productId → barcode ternormalisasi (untuk scan opname, B6).
  final Map<int, String> _barcodeByProductId = {};

  @override
  void initState() {
    super.initState();
    // v2.2.46: daftarkan State ke layar induk via callback (fix routing
    // scan HID di tab Opname yang jatuh ke "Stok Masuk").
    widget.onStateReady?.call(this);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    for (final c in _physicalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = StockCountRepository(ref.read(databaseProvider));
    final active = await repo.getActiveSession();
    final sessions = await repo.getSessions();
    List<StockCountItem> items = [];
    if (active != null) {
      items = await repo.getItems(active.id);
    }
    // B6: peta barcode produk untuk scan opname.
    var products = await ProductRepository(ref.read(databaseProvider))
        .getProducts();
    // B10 (v2.2.44): layanan (isService) tidak dilacak stok — tak perlu opname.
    if (NusaConfig.isJasaVariant) {
      products = products.where((p) => !p.isService).toList();
    }
    final bcMap = <int, String>{};
    for (final p in products) {
      final bc = ProductRepository.normalizeBarcode(p.barcode ?? '');
      if (bc.isNotEmpty) bcMap[p.id] = bc;
    }
    if (mounted) {
      setState(() {
        _activeSession = active;
        _items = items;
        _sessions = sessions;
        _barcodeByProductId
          ..clear()
          ..addAll(bcMap);
        _loading = false;
      });
    }
  }

  /// B6: filter juga by barcode (scan produk pakai barcode fisik).
  List<StockCountItem> get _filteredItems {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (item) =>
              item.productName.toLowerCase().contains(q) ||
              _barcodeByProductId[item.productId]
                      ?.contains(ProductRepository.normalizeBarcode(q)) ==
                  true,
        )
        .toList();
  }

  /// B6: barcode masuk (HID / kamera) → resolve item → auto naikkan
  /// physical count (pola _AdjustSheet). Kembalikan apakah berhasil.
  Future<bool> handleBarcode(String code) async {
    final norm = ProductRepository.normalizeBarcode(code);
    if (norm.isEmpty) return false;
    if (_activeSession == null) {
      TopToast.info(context, 'Mulai sesi opname dulu sebelum scan');
      return false;
    }
    final item = _items
        .where((i) => _barcodeByProductId[i.productId] == norm)
        .firstOrNull;
    if (item == null) {
      TopToast.error(context, 'Barcode tidak ada di sesi opname');
      return false;
    }
    // Naikkan physical count +1 (scan fisik beruntun).
    final current = item.physicalStock ?? item.systemStock;
    final next = current + 1;
    await _updatePhysicalCount(item, '$next');
    // Set controller text agar UI sinkron.
    _physicalControllers[item.id]?.text = '$next';
    // Scroll target tidak kita setel — cukup highlight lewat toast.
    _searchController.clear();
    if (mounted) {
      setState(() {});
      TopToast.success(
          context, '${item.productName}: fisik $next');
    }
    return true;
  }

  /// Kamera scanner — dialog konsisten dg POS/stok (AlertDialog +
  /// AnimatedScannerOverlay + errorBuilder), bukan dialog hitam polos.
  Future<void> _scanCamera() async {
    String? scannedCode;
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
    );
    String? errorMsg;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 22,
                color: NusaConfig.activePrimary,
              ),
              SizedBox(width: 8),
              Text('Pindai Barcode'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScannerOverlay(
                size: 280,
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    if (scannedCode != null) return;
                    final barcode = capture.barcodes.firstOrNull;
                    final raw = barcode?.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    scannedCode = raw;
                    Navigator.pop(ctx);
                  },
                  errorBuilder: (context, error, child) {
                    debugPrint('[Opname] scanner error: $error');
                    if (errorMsg == null) {
                      errorMsg =
                          'Kamera tidak tersedia atau izin kamera ditolak.';
                      setSt(() {});
                    }
                    return Container(
                      height: 280,
                      width: 280,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.no_photography_outlined,
                              size: 36,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera tidak tersedia.\nScan manual via barcode fisik / kolom cari.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (errorMsg != null) ...[
                SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal'),
            ),
          ],
        ),
      ),
    );
    await controller.dispose();
    if (scannedCode == null || !mounted) return;
    await handleBarcode(scannedCode!);
  }

  int get _countedProducts {
    return _items.where((item) => item.physicalStock != null).length;
  }

  Future<void> _createSession() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      TopToast.error(context, 'Nama sesi opname tidak boleh kosong');
      return;
    }
    final repo = StockCountRepository(ref.read(databaseProvider));
    await repo.createSession(name);
    if (mounted) {
      TopToast.success(context, 'Sesi opname "$name" dimulai');
      _nameController.clear();
      await _load();
    }
  }

  Future<void> _updatePhysicalCount(StockCountItem item, String value) async {
    final physical = int.tryParse(value);
    if (physical == null) return;
    final repo = StockCountRepository(ref.read(databaseProvider));
    await repo.updatePhysicalCount(item.id, physical);
    // Update local state for immediate UI feedback
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = old.copyWith(physicalStock: Value<int?>(physical), difference: physical - old.systemStock);
      }
    });
  }

  /// v2.2.46: naikkan / turunkan hitungan fisik lewat tombol −/＋ (stepper),
  /// sinkron dengan controller agar tampilan qty ikut. Scan HID memakai jalur
  /// +1 beruntun terpisah (handleBarcode).
  void _adjustPhysical(StockCountItem item, int delta) {
    final current = item.physicalStock ?? item.systemStock;
    final next = (current + delta).clamp(0, 999999);
    // Sinkronkan controller dulu, lalu persist.
    _physicalControllers[item.id]?.text = '$next';
    _updatePhysicalCount(item, '$next');
  }

  Future<void> _finalize() async {
    if (_activeSession == null) return;

    final counted = _countedProducts;
    final total = _items.length;
    if (counted < total) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Konfirmasi Selesai'),
          content: Text(
            'Baru $counted dari $total produk yang dihitung. '
            'Produk yang belum dihitung tidak akan disesuaikan stoknya. '
            'Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Selesaikan'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _finalizing = true);
    final repo = StockCountRepository(ref.read(databaseProvider));
    try {
      final summary = await repo.finalizeSession(_activeSession!.id);
      if (mounted) {
        TopToast.success(context, 'Stok opname selesai!');
        _showSummaryDialog(summary);
        await _load();
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Gagal menyelesaikan opname: $e');
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  void _showSummaryDialog(Map<String, dynamic> summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: NusaConfig.accentGreen, size: 28),
            SizedBox(width: 10),
            Text('Opname Selesai', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Total Produk', '${summary['totalProducts']}'),
            _summaryRow('Stok Cocok', '${summary['matchCount']}',
                color: NusaConfig.accentGreen),
            _summaryRow('Stok Berbeda', '${summary['diffCount']}',
                color: NusaConfig.accentGold),
            Divider(height: 24),
            _summaryRow(
              'Total Nilai Selisih',
              formatRupiah(summary['totalLossValue'] as int),
              color: NusaConfig.activePrimary,
              bold: true,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.embedded) {
      return _loading ? SkeletonList() : _buildBody(isDark);
    }
    return ScreenScaffold(
      'Stok Opname',
      _loading ? SkeletonList() : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    return Column(
      children: [
        // Tab bar — segmented control
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
              ),
            ),
            child: Row(children: [
              _tabBtn('Opname Aktif', 0, isDark),
              _tabBtn('Riwayat', 1, isDark),
            ]),
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: _tabIndex == 0 ? _buildActiveTab(isDark) : _buildHistoryTab(isDark),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, int index, bool isDark) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? NusaConfig.activePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  // ── Active Opname Tab ──

  Widget _buildActiveTab(bool isDark) {
    if (_activeSession == null) {
      return _buildNewSessionCard(isDark);
    }
    return _buildActiveSession(isDark);
  }

  Widget _buildNewSessionCard(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: NusaCard(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.assignment_turned_in_outlined,
                  color: NusaConfig.accentGreen,
                  size: 28,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Mulai Stok Opname',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Hitung fisik stok dan bandingkan dengan data sistem. '
                'Sesi baru akan otomatis memuat semua produk.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                ),
              ),
              SizedBox(height: 20),
              NusaInput(
                'Nama Sesi (contoh: "Opname Juli 2026")',
                controller: _nameController,
                hint: 'Opname Juli 2026',
              ),
              SizedBox(height: 16),
              NusaButton(
                'Mulai Opname',
                onPressed: _createSession,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSession(bool isDark) {
    final counted = _countedProducts;
    final total = _items.length;
    final filtered = _filteredItems;

    final matchCount = _items
        .where((item) => item.physicalStock != null && item.physicalStock == item.systemStock)
        .length;
    final diffCount = counted - matchCount;

    return Column(
      children: [
        // Summary bar
        Container(
          margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
          ),
          child: Row(
            children: [
              _summaryStat(
                '$counted/$total',
                'Dihitung',
                NusaConfig.activePrimary,
              ),
              _summaryStat(
                '$matchCount',
                'Cocok',
                NusaConfig.accentGreen,
              ),
              _summaryStat(
                '$diffCount',
                'Berbeda',
                NusaConfig.accentGold,
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: NusaSearchBar(
            controller: _searchController,
            hint: 'Cari produk / scan barcode...',
            onChanged: (_) => setState(() {}),
            showScanner: true,
            onScan: _scanCamera,
          ),
        ),
        SizedBox(height: 8),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  message: 'Produk tidak ditemukan',
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return _ProductCountRow(
                      item: item,
                      controller: _getController(item),
                      onChanged: (v) => _updatePhysicalCount(item, v),
                      onMinus: () => _adjustPhysical(item, -1),
                      onPlus: () => _adjustPhysical(item, 1),
                    );
                  },
                ),
        ),

        // Bottom bar
        SafeArea(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor),
              ),
            ),
            child: NusaButton(
              _finalizing ? 'Menyelesaikan...' : 'Selesaikan Opname',
              onPressed: _finalizing ? null : _finalize,
            ),
          ),
        ),
      ],
    );
  }

  TextEditingController _getController(StockCountItem item) {
    if (_physicalControllers.containsKey(item.id)) {
      return _physicalControllers[item.id]!;
    }
    final c = TextEditingController(
      text: item.physicalStock?.toString() ?? '',
    );
    _physicalControllers[item.id] = c;
    return c;
  }

  Widget _summaryStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: NusaConfig.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── History Tab ──

  Widget _buildHistoryTab(bool isDark) {
    final completed = _sessions.where((s) => s.status == 'Selesai').toList();
    if (completed.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        message: 'Belum ada riwayat opname',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: completed.length,
        separatorBuilder: (_, __) => SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = completed[i];
          return _SessionHistoryCard(
            session: s,
            onTap: () => _showSessionDetail(s),
          );
        },
      ),
    );
  }

  Future<void> _showSessionDetail(StockCount session) async {
    final repo = StockCountRepository(ref.read(databaseProvider));
    final summary = await repo.getSessionSummary(session.id);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NusaConfig.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.name ?? 'Sesi #${session.id}',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${session.matchCount} cocok, ${session.diffCount} berbeda',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: (summary['items'] as List).length,
                itemBuilder: (_, i) {
                  final item = (summary['items'] as List)[i] as StockCountItem;
                  final hasDiff = item.physicalStock != null &&
                      item.physicalStock != item.systemStock;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasDiff
                              ? NusaConfig.accentGold.withValues(alpha: 0.3)
                              : (isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sistem: ${item.systemStock}  |  Fisik: ${item.physicalStock ?? "-"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? NusaConfig.darkTextTertiary
                                        : NusaConfig.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.difference != 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.difference > 0
                                    ? NusaConfig.accentGreen.withValues(alpha: 0.1)
                                    : NusaConfig.activePrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.difference > 0
                                    ? '+${item.difference}'
                                    : '${item.difference}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: item.difference > 0
                                      ? NusaConfig.accentGreen
                                      : NusaConfig.activePrimary,
                                ),
                              ),
                            )
                          else
                            Icon(Icons.check_circle,
                                color: NusaConfig.accentGreen, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product Count Row ──

/// Baris produk opname — v2.2.46: kontrol hitung fisik pakai STEpper − qty ＋
/// (bukan cuma TextField). Scan HID otomatis +1 beruntun (handleBarcode);
/// tombol ± untuk koreksi manual cepat.
class _ProductCountRow extends StatelessWidget {
  final StockCountItem item;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  _ProductCountRow({
    required this.item,
    required this.controller,
    required this.onChanged,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhysical = item.physicalStock != null;
    final isMatch = hasPhysical && item.physicalStock == item.systemStock;
    final isDiff = hasPhysical && !isMatch;

    Color accentColor;
    if (isMatch) {
      accentColor = NusaConfig.accentGreen;
    } else if (isDiff) {
      accentColor = NusaConfig.accentGold;
    } else {
      accentColor = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;
    }

    // Tombol − / ＋ — 44px tap target, warna netral.
    Widget stepBtn(IconData icon, VoidCallback onTap) {
      return Material(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder,
              ),
            ),
            child: Icon(icon, size: 20, color: NusaConfig.activePrimary),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        border: Border.all(
          color: isDiff
              ? NusaConfig.accentGold.withValues(alpha: 0.3)
              : (isMatch
                  ? NusaConfig.accentGreen.withValues(alpha: 0.2)
                  : (isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail — copas dari _AdjustProductCard
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                item.productName.isNotEmpty ? item.productName[0].toUpperCase() : '?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: NusaConfig.activePrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          // Product info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Stok sistem: ${item.systemStock}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // ── Stepper − qty ＋ ──
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                stepBtn(Icons.remove_rounded, onMinus),
                SizedBox(width: 6),
                // Qty display (editable) — 56px lebar agar angka besar muat.
                SizedBox(
                  width: 56,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    onChanged: onChanged,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Fisik',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                      ),
                      filled: true,
                      fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                stepBtn(Icons.add_rounded, onPlus),
              ],
            ),
          ),

          // Difference indicator
          SizedBox(width: 8),
          if (hasPhysical)
            Container(
              width: 44,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                color: isMatch
                    ? NusaConfig.accentGreen.withValues(alpha: 0.1)
                    : NusaConfig.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.difference > 0 ? '+${item.difference}' : '${item.difference}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isMatch ? NusaConfig.accentGreen : NusaConfig.accentGold,
                ),
              ),
            )
          else
            SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ── Session History Card ──

class _SessionHistoryCard extends StatelessWidget {
  final StockCount session;
  final VoidCallback onTap;

  _SessionHistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = session.completedAt ?? session.createdAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_turned_in_outlined,
                color: NusaConfig.accentGreen,
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name ?? 'Sesi #${session.id}',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '$dateStr  |  ${session.totalProducts} produk',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: NusaConfig.accentGreen, size: 14),
                    SizedBox(width: 4),
                    Text('${session.matchCount}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: NusaConfig.accentGreen)),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: NusaConfig.accentGold, size: 14),
                    SizedBox(width: 4),
                    Text('${session.diffCount}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: NusaConfig.accentGold)),
                  ],
                ),
              ],
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18,
                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          ],
        ),
      ),
    );
  }
}
