import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Default ukuran header (px) — dipakai UI slider & reset.
const int receiptHeaderMinPx = 12;
const int receiptHeaderMaxPx = 48;
const int receiptHeaderDefaultPx = 24;

/// Lebar kertas dalam PIXEL untuk render header image.
/// 58mm → 384, 80mm → 576 (standar ESC/POS raster bit-image).
int receiptPaperWidthPx(String paperWidth) =>
    paperWidth == '80' ? 576 : 384;

/// Render HANYA bagian atas struk (logo + header) menjadi PNG hitam-putih —
/// dipakai PRINT bit-image (ESC *) dan PREVIEW (Image.memory), jadi preview
/// SELALU sama persis dengan yang tercetak (satu renderer).
///
/// Logo dicetak bit-image terpisah (ESC * + reset) oleh ReceiptPrinter —
/// fungsi ini hanya menggambar nama toko / header custom + info header
/// (invoice, tanggal, kasir, pelanggan, tipe pesanan) sebagai satu gambar.
///
/// Ukuran huruf header = [headerPx] (12–48px, default 24). Semua baris info
/// memakai ukuran yang lebih kecil (12px) supaya tetap muat satu baris.
Future<Uint8List> renderReceiptHeaderPng({
  required String paperWidth,
  required String storeName,
  String customHeader = '',
  String invoice = '',
  String dateStr = '',
  String? cashierName,
  String? customerName,
  String? orderType,
  String? tableName,
  int headerPx = receiptHeaderDefaultPx,
}) async {
  final paperW = receiptPaperWidthPx(paperWidth).toDouble();
  final padH = paperW * 0.05;
  const padTop = 10.0;
  final maxTextW = paperW - padH * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  double y = padTop;

  TextPainter tp(String text, double size, {
    FontWeight? w,
    Color color = const Color(0xFF000000),
    TextAlign align = TextAlign.center,
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

  // ── Header (nama toko / header custom) — ukuran dari slider 12–48px ──
  final headerText = (customHeader.isNotEmpty ? customHeader : storeName).trim();
  if (headerText.isNotEmpty) {
    final hSize = headerPx.clamp(receiptHeaderMinPx, receiptHeaderMaxPx).toDouble();
    final t = tp(headerText, hSize, w: FontWeight.w800, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
  }

  // ── Info header (invoice, tanggal, kasir, pelanggan, tipe) — kecil ──
  const infoSize = 12.0;
  double gap = 1.0;
  if (invoice.isNotEmpty) {
    final t = tp(invoice, infoSize, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
    gap = 1.0;
  }
  if (dateStr.isNotEmpty) {
    final t = tp(dateStr, infoSize, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
    gap = 1.0;
  }
  if (cashierName != null && cashierName.isNotEmpty) {
    final t = tp('Kasir: $cashierName', infoSize, align: TextAlign.left, maxW: maxTextW);
    y += draw(t, padH, y);
    gap = 1.0;
  }
  if (customerName != null && customerName.isNotEmpty) {
    final t = tp('Pelanggan: $customerName', infoSize, align: TextAlign.left, maxW: maxTextW);
    y += draw(t, padH, y);
    gap = 1.0;
  }
  if (orderType != null && orderType.isNotEmpty) {
    final label = tableName != null && tableName.isNotEmpty
        ? '$orderType - $tableName'
        : orderType;
    final t = tp(label, infoSize, w: FontWeight.w700, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
    gap = 1.0;
  }

  y += gap + 6;

  final picture = recorder.endRecording();
  final image = await picture.toImage(paperW.round(), y.ceil().clamp(24, 6000));
  picture.dispose();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}
