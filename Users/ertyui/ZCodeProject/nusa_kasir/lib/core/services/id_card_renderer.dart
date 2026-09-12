import 'dart:io';
import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

/// Helper: baca file foto lokal → MemoryImage untuk PDF (null kalau gagal).
pw.MemoryImage? photoToImage(String? path) {
  if (path == null || path.isEmpty) return null;
  try {
    final f = File(path);
    if (!f.existsSync()) return null;
    return pw.MemoryImage(f.readAsBytesSync());
  } catch (_) {
    return null;
  }
}

/// Renderer kartu ID fisik CR80 Standar ATM / KTP (85.6 × 54 mm).
/// Desain presisi tinggi: photo area proporsional besar, chip gold/smart card visual,
/// typography bold & clean, serta barcode code128 tajam & lebar.
class IdCardRenderer {
  /// Ukuran kartu fisik standar CR80.
  static final PdfPageFormat cardSize = PdfPageFormat(
    85.6 * PdfPageFormat.mm,
    54 * PdfPageFormat.mm,
    marginAll: 0,
  );

  static const PdfColor _primaryRed = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor _slate900 = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _slate800 = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _slate500 = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _goldChip = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);

  /// Kartu Member Toko — Desain Premium ATM/Member Card
  static pw.Widget memberCard({
    required String storeName,
    required String name,
    required String level,
    required int points,
    String? barcode,
    String? phone,
    pw.MemoryImage? photoBytes,
  }) {
    final hasBarcode = barcode != null && barcode.isNotEmpty;
    final isVip = level == 'Platinum' || level == 'Gold';
    final cardBg = isVip ? _slate900 : const PdfColor.fromInt(0xFFF8FAFC);
    final textMain = isVip ? _white : _slate900;
    final textSub = isVip ? const PdfColor.fromInt(0xFF94A3B8) : _slate500;
    final borderCol = isVip ? const PdfColor.fromInt(0xFF334155) : _slate200;

    return pw.Container(
      width: cardSize.width,
      height: cardSize.height,
      decoration: pw.BoxDecoration(
        color: cardBg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: borderCol, width: 1),
      ),
      child: pw.Stack(
        children: [
          // Top Accent Line
          pw.Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: pw.Container(
              height: 4,
              decoration: pw.BoxDecoration(
                color: isVip ? _goldChip : _primaryRed,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(10),
                  topRight: pw.Radius.circular(10),
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 8,
                          height: 8,
                          decoration: pw.BoxDecoration(
                            color: isVip ? _goldChip : _primaryRed,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          storeName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: textMain,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: isVip ? _goldChip : _primaryRed,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        '$level MEMBER'.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: isVip ? _slate900 : _white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Main Info Row: Photo + Customer details + Chip
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Photo (Large 42x42)
                      pw.Container(
                        width: 42,
                        height: 42,
                        decoration: pw.BoxDecoration(
                          color: isVip ? _slate800 : _slate200,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                            color: isVip ? _goldChip : _slate200,
                            width: 1.2,
                          ),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 7,
                          verticalRadius: 7,
                          child: photoBytes != null
                              ? pw.Image(photoBytes, fit: pw.BoxFit.cover)
                              : pw.Center(
                                  child: pw.Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      color: isVip ? _goldChip : _primaryRed,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      pw.SizedBox(width: 10),

                      // Details
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              name,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: textMain,
                              ),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              phone != null && phone.isNotEmpty ? phone : 'Customer Loyalty',
                              style: pw.TextStyle(fontSize: 7.5, color: textSub),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                              decoration: pw.BoxDecoration(
                                color: (isVip ? _goldChip : _primaryRed).shade(0.15),
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                '$points POIN TERKUMPUL',
                                style: pw.TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isVip ? _goldChip : _primaryRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Barcode Section (Clean & sharp)
                if (hasBarcode)
                  pw.Container(
                    height: 24,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: pw.BoxDecoration(
                      color: _white,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: _slate200, width: 0.5),
                    ),
                    child: pw.BarcodeWidget(
                      data: barcode,
                      barcode: bc.Barcode.code128(),
                      drawText: true,
                      textStyle: const pw.TextStyle(fontSize: 6, color: _slate900),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Karyawan — Desain KTP / Physical Access Card
  static pw.Widget employeeCard({
    required String storeName,
    required String name,
    required String role,
    required int id,
    String? barcode,
    String? phone,
    pw.MemoryImage? photoBytes,
  }) {
    final hasBarcode = barcode != null && barcode.isNotEmpty;

    return pw.Container(
      width: cardSize.width,
      height: cardSize.height,
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _slate200, width: 1),
      ),
      child: pw.Stack(
        children: [
          // Left Vertical Header Band (KTP/ID Style)
          pw.Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(
              width: 6,
              decoration: const pw.BoxDecoration(
                color: _primaryRed,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(10),
                  bottomLeft: pw.Radius.circular(10),
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header: Store Name & Official ID Badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          storeName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _slate900,
                          ),
                        ),
                        pw.Text(
                          'KARTU IDENTITAS STAF',
                          style: pw.TextStyle(
                            fontSize: 5.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _slate500,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: pw.BoxDecoration(
                        color: _primaryRed,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        role.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Body: Photo (Large 42x42) + Details
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Photo Frame
                      pw.Container(
                        width: 42,
                        height: 42,
                        decoration: pw.BoxDecoration(
                          color: _slate200,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: _primaryRed, width: 1.2),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 7,
                          verticalRadius: 7,
                          child: photoBytes != null
                              ? pw.Image(photoBytes, fit: pw.BoxFit.cover)
                              : pw.Center(
                                  child: pw.Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _primaryRed,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      pw.SizedBox(width: 10),

                      // Info Block
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              name,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: _slate900,
                              ),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              phone != null && phone.isNotEmpty ? phone : 'Staff ID #$id',
                              style: pw.TextStyle(fontSize: 7.5, color: _slate500),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'ID KARYAWAN: $id',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: _slate900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Barcode Section (Crisp code128 for scanner gun)
                if (hasBarcode)
                  pw.Container(
                    height: 24,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: pw.BoxDecoration(
                      color: _white,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: _slate200, width: 0.5),
                    ),
                    child: pw.BarcodeWidget(
                      data: barcode,
                      barcode: bc.Barcode.code128(),
                      drawText: true,
                      textStyle: pw.TextStyle(fontSize: 6, color: _slate900),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Satu kartu per halaman PDF (share per-orang).
  static Future<File> renderSingle({
    required pw.Widget card,
    required String fileName,
  }) async {
    final pdf = pw.Document(title: fileName, author: 'NUSA Kasir');
    pdf.addPage(
      pw.Page(
        pageFormat: cardSize,
        margin: pw.EdgeInsets.zero,
        build: (_) => card,
      ),
    );
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/$fileName.pdf');
    await out.writeAsBytes(await pdf.save());
    return out;
  }

  /// Batch cetak A4 — tata letak grid 8 kartu (2 kolom × 4 baris) dengan tanda potong.
  static Future<File> renderBatchA4({
    required List<pw.Widget> cards,
    required String title,
  }) async {
    final pdf = pw.Document(title: title, author: 'NUSA Kasir');
    const perPage = 8;
    for (var i = 0; i < cards.length; i += perPage) {
      final chunk = cards.sublist(
        i,
        (i + perPage < cards.length) ? i + perPage : cards.length,
      );
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.GridView(
            crossAxisCount: 2,
            childAspectRatio: 85.6 / 54,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: chunk,
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/$title.pdf');
    await out.writeAsBytes(await pdf.save());
    return out;
  }

  /// Batch render per-halaman untuk backward compatibility.
  static Future<File> renderBatch({
    required List<List<pw.Widget>> pages,
    required String fileName,
  }) async {
    final allCards = pages.expand((p) => p).toList();
    return renderBatchA4(cards: allCards, title: fileName);
  }
}
