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

/// Renderer kartu ID (karyawan & member) siap cetak — format kartu fisik
/// standar 85.6×54 mm (CR80). Satu PDF bisa berisi 1 kartu (share) atau
/// banyak (cetak batch). Barcode code128 dipakai untuk semua kartu supaya
/// konsisten dengan scan HID/kamera di app.
///
/// v2.2.45 (B11): Batch 3 backlog — template kartu ID karyawan + member.
class IdCardRenderer {
  /// Ukuran kartu fisik standar CR80.
  static final PdfPageFormat cardSize = PdfPageFormat(
    85.6 * PdfPageFormat.mm,
    54 * PdfPageFormat.mm,
    marginAll: 0,
  );

  static const PdfColor _primary = PdfColor.fromInt(0xFFE63946);
  static const PdfColor _dark = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _bg = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);

  /// Kartu member — foto opsional, barcode di bawah.
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
    return pw.Container(
      width: cardSize.width,
      height: cardSize.height,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header: logo dot + store name
          pw.Row(
            children: [
              pw.Container(
                width: 14,
                height: 14,
                decoration: pw.BoxDecoration(
                  color: _primary,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _dark,
                  ),
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: level == 'Platinum'
                      ? const PdfColor.fromInt(0xFF7C3AED)
                      : level == 'Gold'
                          ? const PdfColor.fromInt(0xFFD97706)
                          : const PdfColor.fromInt(0xFF6B7280),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  level,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          // Body: photo + name + points
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Photo
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: photoBytes != null
                    ? pw.Image(photoBytes, width: 34, height: 34, fit: pw.BoxFit.cover)
                    : pw.Container(
                        width: 34,
                        height: 34,
                        color: const PdfColor.fromInt(0xFFE5E7EB),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                      ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      phone != null && phone.isNotEmpty
                          ? phone
                          : 'Member NUSA',
                      style: pw.TextStyle(fontSize: 8, color: _muted),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$points poin',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasBarcode) ...[
            pw.Spacer(),
            pw.Center(
              child: pw.BarcodeWidget(
                data: barcode,
                barcode: bc.Barcode.code128(),
                width: 90,
                height: 16,
                drawText: true,
                textStyle: pw.TextStyle(
                  fontSize: 6,
                  color: _dark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kartu karyawan — foto wajib, barcode id-card di bawah.
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
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header: logo dot + store name + role badge
          pw.Row(
            children: [
              pw.Container(
                width: 14,
                height: 14,
                decoration: pw.BoxDecoration(
                  color: _primary,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _dark,
                  ),
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: _primary,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  role,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: photoBytes != null
                    ? pw.Image(photoBytes, width: 34, height: 34, fit: pw.BoxFit.cover)
                    : pw.Container(
                        width: 34,
                        height: 34,
                        color: const PdfColor.fromInt(0xFFE5E7EB),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                      ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      phone != null && phone.isNotEmpty ? phone : 'Karyawan',
                      style: pw.TextStyle(fontSize: 8, color: _muted),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'ID: $id',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasBarcode) ...[
            pw.Spacer(),
            pw.Center(
              child: pw.BarcodeWidget(
                data: barcode,
                barcode: bc.Barcode.code128(),
                width: 90,
                height: 16,
                drawText: true,
                textStyle: pw.TextStyle(fontSize: 6, color: _dark),
              ),
            ),
          ],
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
    final safe = fileName.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${dir.path}/${safe}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Banyak kartu dalam satu halaman PDF (cetak batch). [cards] berisi
  /// kartu per halaman (list of widgets per page).
  static Future<File> renderBatch({
    required List<List<pw.Widget>> pages,
    required String fileName,
  }) async {
    final pdf = pw.Document(title: fileName, author: 'NUSA Kasir');
    for (final cards in pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 12,
            marginRight: 12,
            marginTop: 12,
            marginBottom: 12,
          ),
          build: (ctx) => pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards,
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${dir.path}/${safe}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
