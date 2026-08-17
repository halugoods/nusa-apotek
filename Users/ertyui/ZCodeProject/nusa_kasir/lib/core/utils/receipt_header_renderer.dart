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

/// Render HANYA bagian atas struk (nama toko / header custom) menjadi PNG
/// hitam-putih — dipakai PRINT bit-image (ESC *) dan PREVIEW (Image.memory),
/// jadi preview SELALU sama persis dengan yang tercetak (satu renderer).
///
/// Logo dicetak bit-image terpisah (ESC * + reset) oleh ReceiptPrinter —
/// fungsi ini hanya menggambar nama toko / header custom sebagai satu gambar.
///
/// Ukuran huruf header = [headerPx] (12–48px, default 24). Ketebalan =
/// [headerWeight]: 'thin' (w300 + letterSpacing 2 — ringan) | 'medium'
/// (w500) | 'bold' (w700 + letterSpacing 1.5 — tegas). Perbedaan visual
/// NYATA antar ketebalan (spec M: bukan sekadar 400/500/700).
///
/// Invoice/tanggal/kasir/pelanggan TIDAK dirender di sini — sejak v2.2.27
/// info tersebut dicetak sebagai teks ESC/POS biasa (cepat, huruf normal),
/// image hanya nama toko/header.
Future<Uint8List> renderReceiptHeaderPng({
  required String paperWidth,
  required String storeName,
  String customHeader = '',
  int headerPx = receiptHeaderDefaultPx,
  String headerWeight = 'medium',
  Color color = const Color(0xFF000000),
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
    double? ls,
    Color c = const Color(0xFF000000),
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
          color: c,
          height: 1.35,
          letterSpacing: ls,
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

  // ── Header (nama toko / header custom) — ukuran slider 12–48px ──
  // Ketebalan mengikuti setting thin/medium/bold (default medium).
  // thin = w300 + letterSpacing 2 (huruf ringan renggang), bold = w700 +
  // letterSpacing 1.5 (huruf tegas tebal) — perbedaan visual BERANI.
  final headerText = (customHeader.isNotEmpty ? customHeader : storeName).trim();
  if (headerText.isNotEmpty) {
    final hSize = headerPx.clamp(receiptHeaderMinPx, receiptHeaderMaxPx).toDouble();
    final (weight, ls) = switch (headerWeight) {
      'thin' => (FontWeight.w300, 2.0),
      'bold' => (FontWeight.w700, 1.5),
      _ => (FontWeight.w500, 0.5),
    };
    final t = tp(headerText, hSize, w: weight, ls: ls, c: color, maxW: maxTextW);
    y += draw(t, (paperW - t.width) / 2, y);
  }

  y += 6;

  final picture = recorder.endRecording();
  final image = await picture.toImage(paperW.round(), y.ceil().clamp(24, 6000));
  picture.dispose();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}
