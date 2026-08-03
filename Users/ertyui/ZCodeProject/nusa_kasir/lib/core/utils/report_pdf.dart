import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';

/// Build a clean PDF report and return the file (ready to share).
Future<File> exportReportPdf({
  required String period,
  required Map<String, dynamic> summary,
  required List<Map<String, dynamic>> topProducts,
  required List<Map<String, dynamic>> categories,
  required Map<String, int> payments,
}) async {
  final omzet = summary['omzet'] as int? ?? 0;
  final count = summary['count'] as int? ?? 0;
  final avg = summary['avg'] as int? ?? 0;

  final pdf = pw.Document(title: 'Laporan NUSA Kasir', author: 'NUSA Kasir');

  pw.Widget _stat(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Laporan NUSA Kasir',
            style: pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text('Periode: $period',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          _stat('Omzet', formatRupiah(omzet)),
          pw.SizedBox(width: 8),
          _stat('Transaksi', count.toString()),
          pw.SizedBox(width: 8),
          _stat('Rata-rata', formatRupiah(avg)),
        ]),
        pw.SizedBox(height: 24),
        pw.Text('Produk Terlaris',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (topProducts.isEmpty)
          pw.Text('Belum ada data',
              style: const pw.TextStyle(color: PdfColors.grey600))
        else
          pw.Table.fromTextArray(
            headers: const ['Produk', 'Qty', 'Revenue'],
            data: topProducts
                .map((p) => [
                      p['name'].toString(),
                      (p['qty'] as int).toString(),
                      formatRupiah(p['revenue'] as int),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        pw.SizedBox(height: 24),
        pw.Text('Penjualan per Kategori',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (categories.isEmpty)
          pw.Text('Belum ada data',
              style: const pw.TextStyle(color: PdfColors.grey600))
        else
          pw.Table.fromTextArray(
            headers: const ['Kategori', 'Qty', 'Revenue'],
            data: categories
                .map((c) => [
                      c['category'].toString(),
                      (c['qty'] as int).toString(),
                      formatRupiah(c['revenue'] as int),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        pw.SizedBox(height: 24),
        pw.Text('Metode Pembayaran',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (payments.isEmpty)
          pw.Text('Belum ada data',
              style: const pw.TextStyle(color: PdfColors.grey600))
        else
          pw.Table.fromTextArray(
            headers: const ['Metode', 'Total'],
            data: payments.entries
                .map((e) => [e.key, formatRupiah(e.value)])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
        pw.SizedBox(height: 24),
        pw.Divider(),
        pw.Text(
            'Dicetak otomatis oleh NUSA Kasir • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
      ],
    ),
  );

  final dir = await getTemporaryDirectory();
  final safe = period.replaceAll(RegExp(r'[^a-z0-9]', caseSensitive: false), '');
  final file = File('${dir.path}/laporan_$safe.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

/// Build a comprehensive multi-section PDF report with cover page,
/// profit & loss statement, top products, categories, and payment breakdown.
Future<File> exportFullReportPdf({
  required String period,
  required Map<String, dynamic> summary,
  required Map<String, dynamic>? profitLossData,
  required List<Map<String, dynamic>> topProducts,
  required List<Map<String, dynamic>> categories,
  required Map<String, int> payments,
  String storeName = 'NUSA Kasir',
}) async {
  final omzet = summary['omzet'] as int? ?? 0;
  final count = summary['count'] as int? ?? 0;
  final avg = summary['avg'] as int? ?? 0;

  final pdf = pw.Document(title: 'Laporan Lengkap NUSA Kasir', author: 'NUSA Kasir');

  final now = DateTime.now();
  final dateStr =
      '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  const primaryColor = PdfColors.red600;
  final headerStyle = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
  final headerCellStyle =
      pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  final cellStyle = pw.TextStyle(fontSize: 10);
  final headerBg = pw.BoxDecoration(color: PdfColors.grey200);

  // Pre-compute payment method data
  final payTotal = payments.values.fold(0, (int s, int v) => s + v);
  final paySorted = payments.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final payData = paySorted
      .map((e) => [
            e.key,
            formatRupiah(e.value),
            payTotal > 0
                ? '${(e.value / payTotal * 100).toStringAsFixed(1)}%'
                : '0%',
          ])
      .toList();

  // ── Page 1: Cover + Summary + Profit & Loss ──
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 16),
        child: pw.Column(children: [
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Text(
              'Dicetak oleh NUSA Kasir v${NusaConfig.appVersion} • $dateStr',
              textAlign: pw.TextAlign.center,
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ]),
      ),
      build: (ctx) => [
        // ── Cover Section ──
        pw.Center(
          child: pw.Column(children: [
            pw.SizedBox(height: 30),
            pw.Container(
              width: 56,
              height: 56,
              decoration: const pw.BoxDecoration(
                color: primaryColor,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text('N',
                    style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(storeName,
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Laporan Keuangan Lengkap',
                style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFEE2E2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text('Periode: $period',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor)),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Dibuat: $dateStr',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500)),
            pw.SizedBox(height: 30),
            pw.Divider(),
          ]),
        ),

        // ── Ringkasan ──
        pw.SizedBox(height: 20),
        pw.Text('Ringkasan', style: headerStyle),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          _fullStatCard('Omzet', formatRupiah(omzet), PdfColors.green700),
          pw.SizedBox(width: 8),
          _fullStatCard('Transaksi', count.toString(), primaryColor),
          pw.SizedBox(width: 8),
          _fullStatCard('Rata-rata', formatRupiah(avg), PdfColors.blue700),
        ]),

        // ── Profit & Loss ──
        if (profitLossData != null && profitLossData.isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text('Laba / Rugi', style: headerStyle),
          pw.SizedBox(height: 12),
          _buildPlTable(profitLossData),
        ],
      ],
    ),
  );

  // ── Page 2: Products + Categories + Payments ──
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 16),
        child: pw.Column(children: [
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Text(
              'Dicetak oleh NUSA Kasir v${NusaConfig.appVersion} • $dateStr',
              textAlign: pw.TextAlign.center,
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ]),
      ),
      build: (ctx) => [
        // ── Top 5 Products ──
        pw.Text('5 Produk Terlaris', style: headerStyle),
        pw.SizedBox(height: 8),
        if (topProducts.isEmpty)
          _emptyText()
        else
          pw.Table.fromTextArray(
            headers: const ['#', 'Produk', 'Kategori', 'Qty', 'Revenue'],
            data: topProducts
                .asMap()
                .entries
                .map((e) => [
                      (e.key + 1).toString(),
                      e.value['name'].toString(),
                      e.value['category'].toString(),
                      (e.value['qty'] as int).toString(),
                      formatRupiah(e.value['revenue'] as int),
                    ])
                .toList(),
            headerStyle: headerCellStyle,
            cellStyle: cellStyle,
            headerDecoration: headerBg,
            cellAlignments: {
              0: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),

        // ── Sales by Category ──
        pw.SizedBox(height: 24),
        pw.Text('Penjualan per Kategori', style: headerStyle),
        pw.SizedBox(height: 8),
        if (categories.isEmpty)
          _emptyText()
        else
          pw.Table.fromTextArray(
            headers: const ['Kategori', 'Qty', 'Revenue', '%'],
            data: _withPct(categories),
            headerStyle: headerCellStyle,
            cellStyle: cellStyle,
            headerDecoration: headerBg,
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),

        // ── Payment Method Breakdown ──
        pw.SizedBox(height: 24),
        pw.Text('Metode Pembayaran', style: headerStyle),
        pw.SizedBox(height: 8),
        if (payments.isEmpty || payments.values.every((v) => v == 0))
          _emptyText()
        else
          pw.Column(children: [
            pw.Table.fromTextArray(
              headers: const ['Metode', 'Total', '%'],
              data: payData,
              headerStyle: headerCellStyle,
              cellStyle: cellStyle,
              headerDecoration: headerBg,
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 6),
            pw.Text('Total: ${formatRupiah(payTotal)}',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600)),
          ]),
      ],
    ),
  );

  final dir = await getTemporaryDirectory();
  final stamp =
      '${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}';
  final file = File('${dir.path}/laporan_lengkap_$stamp.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

// ── PDF Helpers ──────────────────────────────────────────────────────────

pw.Widget _fullStatCard(String label, String value, PdfColor accent) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: accent)),
        ],
      ),
    ),
  );
}

pw.Widget _emptyText() => pw.Text('Belum ada data',
    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500));

List<List<String>> _withPct(List<Map<String, dynamic>> categories) {
  final totalRev =
      categories.fold<int>(0, (s, c) => s + ((c['revenue'] as int?) ?? 0));
  return categories.map((c) {
    final rev = (c['revenue'] as int?) ?? 0;
    final pct = totalRev > 0
        ? '${(rev / totalRev * 100).toStringAsFixed(1)}%'
        : '0%';
    return [
      c['category'].toString(),
      (c['qty'] as int?)?.toString() ?? '0',
      formatRupiah(rev),
      pct,
    ];
  }).toList();
}

pw.Widget _buildPlTable(Map<String, dynamic> d) {
  final pendapatan = d['pendapatan'] as int? ?? 0;
  final hpp = d['hpp'] as int? ?? 0;
  final labaKotor = d['labaKotor'] as int? ?? 0;
  final expenses = d['expenses'] as int? ?? 0;
  final payroll = d['payroll'] as int? ?? 0;
  final waste = d['waste'] as int? ?? 0;
  final liqIn = d['liquidityIn'] as int? ?? 0;
  final liqOut = d['liquidityOut'] as int? ?? 0;
  final totalBeban = d['totalBeban'] as int? ?? 0;
  final labaBersih = d['labaBersih'] as int? ?? 0;

  final rows = <pw.TableRow>[];

  void addRow(String label, String value,
      {bool bold = false, PdfColor? color}) {
    rows.add(pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? PdfColors.black)),
      ),
    ]));
  }

  void addDivider() {
    rows.add(pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Divider(),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Divider(),
      ),
    ]));
  }

  addRow('Pendapatan Penjualan', formatRupiah(pendapatan), bold: true);
  addRow('HPP (Harga Pokok Penjualan)', '- ${formatRupiah(hpp)}',
      color: PdfColors.red600);
  addDivider();
  addRow('Laba Kotor', formatRupiah(labaKotor),
      bold: true,
      color: labaKotor >= 0 ? PdfColors.green700 : PdfColors.red600);
  addRow('Pengeluaran Operasional', '- ${formatRupiah(expenses)}',
      color: PdfColors.red600);
  addRow('Payroll / Gaji', '- ${formatRupiah(payroll)}',
      color: PdfColors.red600);
  addRow('Waste / Barang Rusak', '- ${formatRupiah(waste)}',
      color: PdfColors.red600);
  addRow('Likuiditas Keluar', '- ${formatRupiah(liqOut)}',
      color: PdfColors.red600);
  addRow('Likuiditas Masuk', '+ ${formatRupiah(liqIn)}',
      color: PdfColors.green700);
  addDivider();
  addRow('Total Beban', '- ${formatRupiah(totalBeban)}',
      bold: true, color: PdfColors.red600);
  addDivider();
  addRow('Laba/Rugi Bersih', formatRupiah(labaBersih),
      bold: true,
      color: labaBersih >= 0 ? PdfColors.green700 : PdfColors.red600);

  return pw.Table(
    columnWidths: {
      0: pw.FlexColumnWidth(65),
      1: pw.FlexColumnWidth(35),
    },
    children: rows,
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey200),
    ),
  );
}
