import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/features/checkout/receipt_sheet.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/skeleton_list.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _timeFilter = 'Hari ini';
  String _payFilter = 'Semua';
  DateTimeRange? _dateRange;
  int _refreshKey = 0;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Transaction> _filter(List<Transaction> all) {
    final now = DateTime.now();
    var filtered = switch (_timeFilter) {
      'Hari ini' => all
          .where((t) =>
              !t.date.isBefore(DateTime(now.year, now.month, now.day)))
          .toList(),
      'Kemarin' => all
          .where((t) =>
              !t.date.isBefore(DateTime(now.year, now.month, now.day - 1)) &&
              t.date.isBefore(DateTime(now.year, now.month, now.day)))
          .toList(),
      'Minggu ini' => all
          .where((t) => t.date.isAfter(now.subtract(Duration(days: 7))))
          .toList(),
      'Bulan ini' => all
          .where((t) => t.date.isAfter(now.subtract(Duration(days: 30))))
          .toList(),
      'Tahun ini' => all
          .where((t) => !t.date.isBefore(DateTime(now.year, 1, 1)))
          .toList(),
      'Semua' => all,
      'custom' => _dateRange == null
          ? all
          : all
              .where((t) =>
                  !t.date.isBefore(_dateRange!.start) &&
                  !t.date.isAfter(
                      _dateRange!.end.add(Duration(days: 1))))
              .toList(),
      _ => all,
    };
    if (_payFilter != 'Semua') {
      filtered = filtered.where((t) => t.paymentMethod == _payFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) => t.invoice.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return filtered;
  }

  String get _selectedTimeLabel => _timeFilter; 

  Future<void> _voidTransaction(Transaction tx) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Void Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${tx.invoice}',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Total: ${formatRupiah(tx.total)}',
                style: TextStyle(
                    color: NusaConfig.activePrimary,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Alasan void *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          NusaButton(
            'Void',
            fullWidth: false,
            onPressed: () {
              final r = reasonCtrl.text.trim();
              if (r.isEmpty) {
                TopToast.error(context, 'Alasan void wajib diisi');
                return;
              }
              Navigator.pop(context, r);
            },
          ),
        ],
      ),
    );

    reasonCtrl.dispose();
    if (reason == null || reason.isEmpty) return;

    final repo = ref.read(transactionRepoProvider);
    final err = await repo.voidTransaction(tx.id, reason);
    if (mounted) {
      if (err != null) {
        TopToast.error(context, err);
      } else {
        TopToast.success(context, 'Transaksi #${tx.invoice} berhasil di-void');
        setState(() => _refreshKey++);
      }
    }
  }

  Future<void> _reprintTransaction(Transaction tx) async {
    String? custName;
    String? custPhone;
    if (tx.customerId != null) {
      final custRepo = CustomerRepository(ref.read(databaseProvider));
      final cust = await custRepo.byId(tx.customerId!);
      if (cust != null) {
        custName = cust.name;
        custPhone = cust.phone;
      }
    }

    final rawItems = _parseItems(tx.items);
    final dateStr =
        '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year} '
        '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}';

    if (mounted) {
      await ReceiptSheet.show(
        context,
        sheet: ReceiptSheet.fromMaps(
          rawItems: rawItems,
          total: tx.total,
          discount: tx.discount,
          paymentMethod: tx.paymentMethod,
          cashGiven: tx.cashGiven,
          cashReturn: tx.cashReturn,
          cashierName: tx.cashierName,
          customerName: custName,
          customerPhone: custPhone,
          invoice: tx.invoice,
          dateStr: dateStr,
          orderType: tx.orderType,
          tableName: null, // table name not stored in transaction, only tableId
        ),
      );
    }
  }

  Widget _timeDropdown(bool isDark) {
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeFilter == 'custom' ? 'custom' : _timeFilter,
          isDense: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          ),
          borderRadius: BorderRadius.circular(12),
          underline: SizedBox.shrink(),
          icon: Icon(Icons.expand_more_rounded,
              size: 18,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
          items: [
            _ddItem('Hari ini'),
            _ddItem('Kemarin'),
            _ddItem('Minggu ini'),
            _ddItem('Bulan ini'),
            _ddItem('Tahun ini'),
            _ddItem('Semua'),
            if (_timeFilter == 'custom' && _dateRange != null)
              DropdownMenuItem(
                value: 'custom',
                enabled: false,
                child: Text(
                  '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  style: TextStyle(
                      fontSize: 11,
                      color: NusaConfig.activePrimary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            _ddItem('Pilih Periode'),
          ],
          onChanged: (v) {
            if (v == 'Pilih Periode') {
              _pickDateRange();
            } else {
              setState(() {
                _timeFilter = v!;
                _dateRange = null;
              });
            }
          },
        ),
      ),
    );
  }

  DropdownMenuItem<String> _ddItem(String label) => DropdownMenuItem(
        value: label,
        child: Text(label),
      );

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
      initialDateRange: _dateRange ??
          DateTimeRange(start: DateTime.now(), end: DateTime.now()),
    );
    if (picked != null && mounted) {
      setState(() {
        _timeFilter = 'custom';
        _dateRange = picked;
      });
    }
  }

  Widget _paymentSegmented(bool isDark) {
    final opts = ['Semua', 'Tunai', 'QRIS', 'Transfer'];
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
      ),
      child: Row(
        children: opts.map((opt) {
          final active = _payFilter == opt;
          final Color activeColor;
          if (opt == 'QRIS') {
            activeColor = NusaConfig.payQris;
          } else if (opt == 'Transfer') {
            activeColor = NusaConfig.payTransfer;
          } else {
            activeColor = NusaConfig.activePrimary;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _payFilter = opt),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : (isDark
                            ? NusaConfig.darkTextSecondary
                            : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Share / bagikan dengan preview gambar ──

  Future<File?> _captureReceipt(GlobalKey key, Transaction tx) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/struk_${tx.invoice.replaceAll('/', '_')}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (_) {
      return null;
    }
  }

  Widget _buildReceiptPreview(Transaction tx,
      List<Map<String, dynamic>> rawItems, String dateStr, String? custName,
      {bool isDark = false}) {
    final textColor = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final subtleColor = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
    final mono = TextStyle(
        fontFamily: 'monospace', fontSize: 10, height: 1.4, color: textColor);
    final monoBold = TextStyle(
        fontFamily: 'monospace', fontSize: 10, height: 1.4,
        fontWeight: FontWeight.bold, color: textColor);
    final monoBig = TextStyle(
        fontFamily: 'monospace', fontSize: 13, height: 1.4,
        fontWeight: FontWeight.bold, color: textColor);
    final monoHeader = TextStyle(
        fontFamily: 'monospace', fontSize: 14, height: 1.3,
        fontWeight: FontWeight.bold, color: textColor);
    final monoGrey = TextStyle(
        fontFamily: 'monospace', fontSize: 10, height: 1.4,
        color: subtleColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Text('NUSA', style: monoHeader)),
        if (tx.invoice.isNotEmpty) ...[
          SizedBox(height: 2),
          Center(child: Text(tx.invoice, style: mono)),
        ],
        SizedBox(height: 6),
        _buildRDash(isDark: isDark),
        SizedBox(height: 6),
        _buildRRow('ID  : ', tx.invoice, mono, mono),
        _buildRRow('Tgl : ', dateStr, mono, mono),
        if (custName != null) _buildRRow('Pel  : ', custName, mono, mono),
        if (tx.cashierName != null && tx.cashierName!.isNotEmpty)
          _buildRRow('Kasir:', tx.cashierName!, mono, mono),
        SizedBox(height: 6),
        _buildRDash(isDark: isDark),
        SizedBox(height: 6),
        ...rawItems.map((it) {
          final name = '${it['name']}';
          final qty = (it['qty'] as num).toInt();
          final price = (it['price'] as num).toInt();
          final subtotal = qty * price;
          return Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: mono),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('$qty x ${formatRupiah(price)}', style: monoGrey),
                    Text(formatRupiah(subtotal), style: mono),
                  ]),
                ]),
          );
        }),
        SizedBox(height: 6),
        _buildRDash(isDark: isDark),
        SizedBox(height: 6),
        if (tx.discount > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Diskon/Potongan', style: monoGrey),
              Text('-${formatRupiah(tx.discount)}', style: monoGrey),
            ]),
          ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL', style: monoBig),
            Text(formatRupiah(tx.total), style: monoBig),
          ]),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Bayar (${tx.paymentMethod})', style: monoGrey),
            Text(formatRupiah(tx.cashGiven ?? tx.total), style: monoGrey),
          ]),
        ),
        if (tx.cashReturn != null && tx.cashReturn! > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Kembali', style: monoGrey),
              Text(formatRupiah(tx.cashReturn!), style: monoGrey),
            ]),
          ),
        SizedBox(height: 6),
        _buildRDash(),
        SizedBox(height: 8),
        Center(child: Text('Terima Kasih!', style: monoBold)),
      ],
    );
  }

  Widget _buildRDash({bool isDark = false}) => SizedBox(
        height: 2,
        child: CustomPaint(
            painter: _DashPainter2(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300)),
      );

  Widget _buildRRow(String label, String value, TextStyle mono, TextStyle monoGrey) =>
      Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Text(label, style: monoGrey),
          Spacer(),
          Flexible(child: Text(value, style: mono, textAlign: TextAlign.right)),
        ]),
      );

  Future<void> _showShareSheet(
      Transaction tx, String? custName, String? custPhone) async {
    final rawItems = _parseItems(tx.items);
    final dateStr =
        '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year} '
        '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}';

    final receiptKey = GlobalKey();
    bool capturing = false;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final shareDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSt) => Container(
            decoration: BoxDecoration(
              color: shareDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                SizedBox(height: 12),
                Text('Bagikan Struk ${tx.invoice}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: shareDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                    )),
                SizedBox(height: 16),
                // ── Receipt preview image ──
                RepaintBoundary(
                  key: receiptKey,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: shareDark ? NusaConfig.darkSurface2 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: shareDark ? NusaConfig.darkBorder : Colors.grey.shade200),
                    ),
                    child: _buildReceiptPreview(
                        tx, rawItems, dateStr, custName, isDark: shareDark),
                ),
              ),
              SizedBox(height: 20),
              if (capturing)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 3)),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          setSt(() => capturing = true);
                          final file =
                              await _captureReceipt(receiptKey, tx);
                          setSt(() => capturing = false);
                          if (file != null && mounted) {
                            Navigator.pop(ctx);
                            // Kirim via WA — share file image
                            if (custPhone != null &&
                                custPhone.isNotEmpty) {
                              // Direct WA with text (image not supported via wa.me)
                              final wabuf = StringBuffer();
                              wabuf.writeln(
                                  '*STRUK ${tx.invoice}*');
                              wabuf.writeln(
                                  '--------------------------------');
                              wabuf.writeln(
                                  'Total: ${formatRupiah(tx.total)}');
                              wabuf.writeln(
                                  'Bayar: ${tx.paymentMethod}');
                              wabuf.writeln(
                                  '--------------------------------');
                              wabuf.writeln(
                                  'Terima kasih!');
                              final digits = custPhone
                                  .replaceAll(RegExp(r'\D'), '');
                              final normalized = digits.startsWith('0')
                                  ? '62${digits.substring(1)}'
                                  : digits.startsWith('62')
                                      ? digits
                                      : '62$digits';
                              final waUrl =
                                  'https://wa.me/$normalized?text=${Uri.encodeComponent(wabuf.toString())}';
                              launchUrl(Uri.parse(waUrl));
                            } else {
                              SharePlus.instance.share(ShareParams(
                                  files: [XFile(file.path)]));
                            }
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF25D366)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            Icon(Icons.chat_rounded,
                                size: 32, color: Color(0xFF25D366)),
                            SizedBox(height: 8),
                            Text(
                                custPhone != null &&
                                        custPhone.isNotEmpty
                                    ? 'Kirim WA'
                                    : 'Share',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF25D366),
                                )),
                            if (custPhone != null &&
                                custPhone.isNotEmpty)
                              Text(custPhone,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: shareDark
                                          ? NusaConfig.darkTextTertiary
                                          : Colors.grey)),
                          ]),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          setSt(() => capturing = true);
                          final file =
                              await _captureReceipt(receiptKey, tx);
                          setSt(() => capturing = false);
                          if (file != null && mounted) {
                            Navigator.pop(ctx);
                            SharePlus.instance.share(ShareParams(
                                files: [XFile(file.path)]));
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            Icon(Icons.download_rounded,
                                size: 32,
                                color: NusaConfig.activePrimary),
                            SizedBox(height: 8),
                            Text('Unduh Struk',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: NusaConfig.activePrimary,
                                )),
                            Text('Gambar',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: shareDark
                                        ? NusaConfig.darkTextTertiary
                                        : NusaConfig.textTertiary)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Transaksi',
      Column(
        children: [
          SizedBox(height: 8),
          // ── Search by invoice ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                borderRadius: BorderRadius.circular(NusaConfig.radiusXL),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkInputBorder
                      : NusaConfig.inputBorder,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nomor invoice…',
                  hintStyle: TextStyle(
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.clear_rounded,
                                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary, size: 20),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                ),
              ),
            ),
          ),
          SizedBox(height: 18),
          // ── Payment segmented + time dropdown inline ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _paymentSegmented(isDark)),
                SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: _timeDropdown(isDark),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Transaction>>(
              key: ValueKey(_refreshKey),
              future: ref.watch(transactionRepoProvider).getTransactions(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return SkeletonList();
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Gagal memuat: ${snap.error}',
                        style: TextStyle(color: isDark ? NusaConfig.darkTextSecondary : Colors.grey)),
                  );
                }
                final list = _filter(snap.data ?? []);
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'Belum ada transaksi',
                  );
                }
                final totalRevenue =
                    list.fold<int>(0, (sum, t) => sum + t.total);
                final avg = list.isNotEmpty
                    ? (totalRevenue / list.length).round()
                    : 0;
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _refreshKey++);
                  },
                  child: Column(
                    children: [
                      // ── Summary ──
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary
                                .withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(NusaConfig.radiusMD),
                          ),
                          child: Row(children: [
                            Icon(Icons.summarize_rounded,
                                size: 18, color: NusaConfig.activePrimary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${list.length} transaksi',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? NusaConfig.darkTextPrimary
                                            : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                                      )),
                                  SizedBox(height: 2),
                                  Text('Rata-rata ${formatRupiah(avg)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? NusaConfig.darkTextTertiary
                                            : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                                      )),
                                ],
                              ),
                            ),
                            Text(formatRupiah(totalRevenue),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: NusaConfig.activePrimary,
                                )),
                          ]),
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          padding:
                              EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 12),
                          itemBuilder: (_, i) => _TransactionCard(
                            tx: list[i],
                            onVoid: () => _voidTransaction(list[i]),
                            onReprint: () => _reprintTransaction(list[i]),
                            onShare: () async {
                              String? custName;
                              String? custPhone;
                              if (list[i].customerId != null) {
                                final custRepo = CustomerRepository(ref.read(databaseProvider));
                                final cust = await custRepo.byId(list[i].customerId!);
                                if (cust != null) {
                                  custName = cust.name;
                                  custPhone = cust.phone;
                                }
                              }
                              _showShareSheet(list[i], custName, custPhone);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatefulWidget {
  final Transaction tx;
  final VoidCallback onVoid;
  final VoidCallback onReprint;
  final VoidCallback onShare;
  _TransactionCard({
    required this.tx,
    required this.onVoid,
    required this.onReprint,
    required this.onShare,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _expanded = false;

  static const _payColors = {
    'Tunai': NusaConfig.payCash,
    'QRIS': NusaConfig.payQris,
    'Transfer': NusaConfig.payTransfer,
  };
  static const _payIcons = {
    'Tunai': Icons.money_rounded,
    'QRIS': Icons.qr_code_rounded,
    'Transfer': Icons.account_balance_rounded,
  };

  Color _payColor(bool isDark) =>
      _payColors[widget.tx.paymentMethod] ?? (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary);
  IconData _payIcon() =>
      _payIcons[widget.tx.paymentMethod] ?? Icons.payment_rounded;

  static String _relDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hari ini, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Kemarin';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = widget.tx;
    final items = _parseItems(tx.items);
    final isVoided = tx.status == 'Void';
    final accent = isVoided ? isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary : _payColor(isDark);
    final relDate = _relDate(tx.date);

    return Opacity(
      opacity: isVoided ? 0.6 : 1.0,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? NusaConfig.darkSurface
                  : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
              border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor),
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.15 : 0.06),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(tx.invoice,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    decoration: isVoided
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDark
                                        ? NusaConfig.darkTextPrimary
                                        : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                                  )),
                              if (isVoided) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: NusaConfig.activePrimary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('VOID',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: NusaConfig.activePrimary)),
                                ),
                              ],
                            ]),
                            SizedBox(height: 4),
                            Row(children: [
                              Icon(_payIcon(),
                                  size: 14,
                                  color: isVoided
                                      ? isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary
                                      : accent),
                              SizedBox(width: 4),
                              Text('$relDate • ${tx.paymentMethod}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isVoided
                                        ? isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary
                                        : (isDark
                                            ? NusaConfig.darkTextTertiary
                                            : isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                                  )),
                            ]),
                          ],
                        ),
                      ),
                      Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatRupiah(tx.total),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isVoided
                                            ? isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary
                                            : NusaConfig.activePrimary,
                                      )),
                                  SizedBox(height: 6),
                                  Row(children: [
                                    _actionIcon(Icons.print_rounded,
                                        NusaConfig.info, widget.onReprint),
                                    SizedBox(width: 6),
                                    _actionIcon(Icons.share_rounded,
                                        NusaConfig.accentGreen, widget.onShare),
                                    if (!isVoided) ...[
                                      SizedBox(width: 6),
                                      _actionIcon(Icons.undo_rounded,
                                          NusaConfig.activePrimary, widget.onVoid),
                                    ],
                                    SizedBox(width: 2),
                                    _actionIcon(
                                        _expanded
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                                        () => setState(
                                            () => _expanded = !_expanded)),
                                  ]),
                                ],
                              ),
                            ],
                          ),
                          // ── Expanded detail ──
                          if (_expanded) ...[
                            SizedBox(height: 12),
                            Divider(
                                height: 1,
                                color: isDark
                                    ? NusaConfig.darkDivider
                                    : NusaConfig.dividerColor),
                            SizedBox(height: 10),
                            ...items.map((it) => Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Text('${it['name']} x ${it['qty']}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                color: isDark
                                                    ? NusaConfig
                                                        .darkTextSecondary
                                                    : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                                              ))),
                                      Text(
                                          formatRupiah((it['qty'] as int) *
                                              (it['price'] as int)),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? NusaConfig.darkTextPrimary
                                                : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                                          )),
                                    ],
                                  ),
                                )),
                            SizedBox(height: 8),
                            Divider(
                                height: 1,
                                color: isDark
                                    ? NusaConfig.darkDivider
                                    : NusaConfig.dividerColor),
                            SizedBox(height: 8),
                            _row('Subtotal', formatRupiah(tx.total + tx.discount), isDark: isDark),
                            _row('Diskon', formatRupiah(tx.discount), isDark: isDark),
                            _row('Total', formatRupiah(tx.total), isDark: isDark),
                            _row('Bayar',
                                tx.cashGiven != null ? formatRupiah(tx.cashGiven!) : '-', isDark: isDark),
                            _row('Kembali',
                                tx.cashReturn != null ? formatRupiah(tx.cashReturn!) : '-', isDark: isDark),
                            if (isVoided && tx.voidReason != null) ...[
                              SizedBox(height: 8),
                              Text(
                                'Alasan void: ${tx.voidReason}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: NusaConfig.activePrimary,
                                ),
                              ),
                            ],
                            if (!isVoided) ...[
                              SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: widget.onVoid,
                                  icon: Icon(Icons.undo_rounded, size: 18),
                                  label: Text('Void Transaksi',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: NusaConfig.activePrimary,
                                    side: BorderSide(
                                        color: NusaConfig.activePrimary),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ], // close if(!isVoided)
                          ], // close if(_expanded)
                        ], // close Column children
                      ), // close Column
                    ), // close Padding
                  ), // close Container
                ), // close InkWell
              ), // close Material
              ); // close Opacity
  }

  Widget _row(String label, String value, {bool isDark = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                )),
          ],
        ),
      );
}

List<Map<String, dynamic>> _parseItems(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  } catch (_) {
    // ignore malformed items
  }
  return [];
}

class _DashPainter2 extends CustomPainter {
  final Color color;
  _DashPainter2({this.color = const Color(0xFFD1D5DB)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final dashW = 3.0;
    final gapW = 2.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dashW).clamp(0, size.width), 0), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
