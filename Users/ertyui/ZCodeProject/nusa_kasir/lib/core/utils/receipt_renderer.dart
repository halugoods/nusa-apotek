import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:nusa_kasir/core/utils/format_rupiah.dart';

/// Satu baris item struk untuk renderer — kaya (bisa per-kg, punya note),
/// beda dari `ReceiptLine` (printer) yang hanya name/qty/price.
class ReceiptRenderLine {
  const ReceiptRenderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.originalPrice,
    this.note,
    this.isPerKg = false,
    this.weightKg,
  });

  final String name;
  final int qty;
  final int price;

  /// Harga jual sebelum diskon (null = tanpa diskon). Saat diisi, struk
  /// mencetak baris potongan NOMINAL per item ("Diskon: -Rp 5.000").
  final int? originalPrice;
  final String? note;
  final bool isPerKg;
  final double? weightKg;

  int get subtotal => isPerKg ? (price * weightKg!).ceil() : qty * price;
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int get discountTotal =>
      hasDiscount
          ? (originalPrice! - price) * (isPerKg ? weightKg!.ceil() : qty)
          : 0;

  String get qtyLabel {
    if (isPerKg && weightKg != null) {
      final kg = weightKg!.toStringAsFixed(1);
      return kg.endsWith('.0') ? kg.substring(0, kg.length - 2) : kg;
    }
    return '$qty';
  }
}

/// Semua data yang renderer butuhkan — murni data (tidak ada widget),
/// sehingga bisa dipakai print (bit-image), preview, dan share/PDF.
class ReceiptRenderConfig {
  const ReceiptRenderConfig({
    required this.storeName,
    required this.lines,
    required this.total,
    this.paymentMethod,
    this.cashierName,
    this.invoice = '',
    this.dateStr = '',
    this.discount = 0,
    this.cashGiven,
    this.cashReturn,
    this.downPayment = 0,
    this.remainingDue = 0,
    this.customerName,
    this.paperWidth = '58',
    this.orderType,
    this.tableName,
    this.itemNotes,
    this.header = '',
    this.footer = '',
    this.logoBytes,
    this.showLogo = true,
    this.headerSizePx = 24,
    this.itemsSizePx = 12,
    this.footerSizePx = 12,
    this.logoWidthPercent = 60,
  });

  final String storeName;
  final List<ReceiptRenderLine> lines;
  final int total;
  final String? paymentMethod;
  final String? cashierName;
  final String invoice;
  final String dateStr;
  final int discount;
  final int? cashGiven;
  final int? cashReturn;
  final int downPayment;
  final int remainingDue;
  final String? customerName;
  final String paperWidth; // '58' | '80'
  final String? orderType;
  final String? tableName;
  final List<String?>? itemNotes;

  // Pengaturan struk
  final String header; // teks header custom (kosong → nama toko)
  final String footer; // teks footer custom (kosong → 'Terima Kasih!')
  final Uint8List? logoBytes;
  final bool showLogo;
  final int headerSizePx; // 12..48
  final int itemsSizePx; // 12..48
  final int footerSizePx; // 12..48
  final int logoWidthPercent; // 1..100 dari lebar kertas

  int get paperWidthPx => paperWidth == '80' ? 576 : 384;
}

/// Default ukuran slider (px) — dipakai UI dan reset.
const int receiptHeaderDefaultPx = 24;
const int receiptItemsDefaultPx = 12;
const int receiptFooterDefaultPx = 12;
const int receiptMinPx = 12;
const int receiptMaxPx = 48;
const int receiptLogoDefaultPercent = 60;

/// Render struk menjadi PNG (bitmap hitam-putih) via Flutter canvas.
///
/// SEMUA bagian (logo, header, rincian, total, footer) digambar jadi piksel
/// di HP, lalu hasilnya dipakai:
///   - print  → `generator.image()` (ESC * bit-image — printer cuma menggambar,
///              tidak menafsirkan perbesaran → ukuran bebas & pasti tercetak)
///   - preview → `Image.memory(png)`
///   - share/PDF → PNG yang sama
/// Artinya preview SELALU sama dengan print (satu renderer).
Future<Uint8List> renderReceiptPng(ReceiptRenderConfig cfg) async {
  final paperW = cfg.paperWidthPx.toDouble();
  final padH = paperW * 0.06; // padding kiri/kanan
  const padTop = 10.0;
  final maxTextW = paperW - padH * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final black = Paint()..color = const Color(0xFF000000);

  double y = padTop;

  TextPainter tp(String text, double size, {
    FontWeight? w,
    Color color = const Color(0xFF000000),
    TextAlign align = TextAlign.left,
    double? maxW,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          fontWeight: w,
          color: color,
          height: 1.35,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: null,
    )..layout(maxWidth: maxW ?? double.infinity);
    return t;
  }

  double draw(TextPainter t, double x, double yy) {
    t.paint(canvas, Offset(x, yy));
    return t.height;
  }

  void hr() {
    // Garis putus-putus penuh selebar kertas.
    final dashW = 6.0;
    final gap = 3.0;
    double x = padH;
    while (x < paperW - padH) {
      canvas.drawRect(Rect.fromLTWH(x, y, math.min(dashW, paperW - padH - x), 1.4), black);
      x += dashW + gap;
    }
    y += 6;
  }

  // ── Logo ──
  if (cfg.showLogo && cfg.logoBytes != null && cfg.logoBytes!.isNotEmpty) {
    try {
      final codec = await ui.instantiateImageCodec(cfg.logoBytes!);
      final frame = await codec.getNextFrame();
      final logo = frame.image;
      final targetW = math.min(
        logo.width.toDouble(),
        paperW * (cfg.logoWidthPercent.clamp(1, 100) / 100),
      );
      final targetH = logo.height * (targetW / logo.width);
      final dst = Rect.fromLTWH(
        (paperW - targetW) / 2,
        y,
        targetW,
        targetH,
      );
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        dst,
        Paint(),
      );
      logo.dispose();
      y += targetH + 8;
    } catch (_) {
      // Logo gagal decode → lewati, struk tetap jalan.
    }
  }

  // ── Header ──
  final headerText = (cfg.header.isNotEmpty ? cfg.header : cfg.storeName)
      .trim();
  if (headerText.isNotEmpty) {
    final t = tp(
      headerText,
      cfg.headerSizePx.toDouble(),
      w: FontWeight.w800,
      align: TextAlign.center,
      maxW: maxTextW,
    );
    y += draw(t, (paperW - t.width) / 2, y);
  }
  if (cfg.invoice.isNotEmpty) {
    final t = tp(cfg.invoice, cfg.itemsSizePx.toDouble(), align: TextAlign.center, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
  }
  if (cfg.dateStr.isNotEmpty) {
    final t = tp(cfg.dateStr, cfg.itemsSizePx.toDouble(), align: TextAlign.center, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
  }
  y += 4;

  // Info baris (kasir / pelanggan / tipe)
  if (cfg.cashierName != null && cfg.cashierName!.isNotEmpty) {
    final t = tp('Kasir: ${cfg.cashierName}', cfg.itemsSizePx.toDouble(), maxW: maxTextW);
    y += draw(t, padH, y);
  }
  if (cfg.customerName != null && cfg.customerName!.isNotEmpty) {
    final t = tp('Pelanggan: ${cfg.customerName}', cfg.itemsSizePx.toDouble(), maxW: maxTextW);
    y += draw(t, padH, y);
  }
  if (cfg.orderType != null && cfg.orderType!.isNotEmpty) {
    final label = cfg.tableName != null && cfg.tableName!.isNotEmpty
        ? '${cfg.orderType} - ${cfg.tableName}'
        : cfg.orderType!;
    final t = tp(label, cfg.itemsSizePx.toDouble(), w: FontWeight.w700, align: TextAlign.center, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
  }

  hr();

  // ── Items ──
  final itemsSize = cfg.itemsSizePx.toDouble();
  final smallSize = math.max(9.0, itemsSize - 2);
  for (int i = 0; i < cfg.lines.length; i++) {
    final line = cfg.lines[i];
    final note = (cfg.itemNotes != null && i < cfg.itemNotes!.length)
        ? cfg.itemNotes![i]
        : line.note;

    // Nama item — wrap ke beberapa baris.
    final nameT = tp(line.name, itemsSize, maxW: maxTextW);
    y += draw(nameT, padH, y);

    // Baris qty × harga ... subtotal (sejajar kanan).
    final qtyLabel = line.isPerKg ? '${line.qtyLabel} kg' : '${line.qtyLabel} x';
    final qtyTxt = '$qtyLabel ${formatRupiah(line.price)}';
    final discSuffix = line.hasDiscount
        ? '( -${formatRupiah(line.discountTotal)} ) '
        : '';
    final rightTxt = '$discSuffix${formatRupiah(line.subtotal)}';

    final qT = tp(qtyTxt, smallSize, color: const Color(0xFF6B7280));
    final rT = tp(rightTxt, smallSize, w: FontWeight.w600);
    final rowY = y;
    qT.paint(canvas, Offset(padH, rowY));
    rT.paint(canvas, Offset(paperW - padH - rT.width, rowY));
    y += math.max(qT.height, rT.height);

    // Note item (indent, italic, kecil).
    if (note != null && note.isNotEmpty) {
      final nT = tp(
        '> $note',
        math.max(8.0, smallSize - 1),
        color: const Color(0xFF9CA3AF),
        maxW: maxTextW - 12,
      );
      y += draw(nT, padH + 12, y);
    }
  }

  hr();

  // ── TOTAL ──
  final totalSize = math.max(14.0, itemsSize + 4);
  final totT = tp('TOTAL', totalSize, w: FontWeight.w800);
  final totV = tp(formatRupiah(cfg.total), totalSize, w: FontWeight.w800);
  totT.paint(canvas, Offset(padH, y));
  totV.paint(canvas, Offset(paperW - padH - totV.width, y));
  y += math.max(totT.height, totV.height);

  if (cfg.discount > 0) {
    final dT = tp('Diskon', smallSize);
    final dV = tp('-${formatRupiah(cfg.discount)}', smallSize);
    dT.paint(canvas, Offset(padH, y));
    dV.paint(canvas, Offset(paperW - padH - dV.width, y));
    y += dT.height;
  }

  // Pembayaran
  if (cfg.downPayment > 0) {
    final l1 = tp('Bayar (${cfg.paymentMethod})', smallSize);
    final v1 = tp(formatRupiah(cfg.downPayment), smallSize);
    l1.paint(canvas, Offset(padH, y));
    v1.paint(canvas, Offset(paperW - padH - v1.width, y));
    y += l1.height;

    final l2 = tp('Sisa Piutang', smallSize);
    final v2 = tp(formatRupiah(cfg.remainingDue), smallSize);
    l2.paint(canvas, Offset(padH, y));
    v2.paint(canvas, Offset(paperW - padH - v2.width, y));
    y += l2.height;
  } else if (cfg.paymentMethod != null && cfg.paymentMethod!.isNotEmpty) {
    final l1 = tp('Bayar (${cfg.paymentMethod})', smallSize);
    final v1 = tp(formatRupiah(cfg.cashGiven ?? cfg.total), smallSize);
    l1.paint(canvas, Offset(padH, y));
    v1.paint(canvas, Offset(paperW - padH - v1.width, y));
    y += l1.height;
  }
  if (cfg.cashReturn != null && cfg.cashReturn! > 0 && cfg.downPayment <= 0) {
    final l = tp('Kembali', smallSize);
    final v = tp(formatRupiah(cfg.cashReturn!), smallSize);
    l.paint(canvas, Offset(padH, y));
    v.paint(canvas, Offset(paperW - padH - v.width, y));
    y += l.height;
  }

  hr();

  // ── Footer ──
  final footerText = (cfg.footer.isNotEmpty ? cfg.footer : 'Terima Kasih!')
      .trim();
  if (footerText.isNotEmpty) {
    final t = tp(
      footerText,
      cfg.footerSizePx.toDouble(),
      w: FontWeight.w700,
      align: TextAlign.center,
      maxW: maxTextW,
    );
    y += draw(t, (paperW - t.width) / 2, y);
  }
  final storeT = tp(cfg.storeName, smallSize, align: TextAlign.center, maxW: maxTextW);
  y += draw(storeT, (paperW - storeT.width) / 2, y);

  y += 10;

  final picture = recorder.endRecording();
  final image = await picture.toImage(paperW.round(), y.ceil().clamp(24, 6000));
  picture.dispose();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}
