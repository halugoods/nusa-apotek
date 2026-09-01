import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_data.dart';
import 'package:nusa_kasir/core/receipt/receipt_renderer.dart';
import 'package:nusa_kasir/core/utils/receipt_header_renderer.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart' show receiptPreviewSize;

/// ─────────────────────────────────────────────────────────────────────────
/// SATU WIDGET PREVIEW STRUK (v2.2.29) — dipakai di SEMUA halaman
/// (Pengaturan Struk, checkout ReceiptSheet, riwayat Transaksi). Render
/// struktur [buildReceiptParts] yang SAMA dengan printer → preview SELALU
/// match print (spec: "Preview terlihat A, Print menghasilkan B" TIDAK
/// BOLEH terjadi).
///
/// Data AKTUAL transaksi (dari ReceiptData), bukan mockup — sample hanya
/// untuk preview di Pengaturan Struk.
/// ─────────────────────────────────────────────────────────────────────────
class ReceiptPreview extends StatefulWidget {
  final ReceiptConfig config;
  final ReceiptData data;
  final String storeName;
  final bool dark;

  /// Lebar container (default ikut kertas: 80mm→330, 58mm→250). Preview
  /// TIDAK dipaksa muat — boleh scroll vertikal (spec I).
  final double? width;

  const ReceiptPreview({
    super.key,
    required this.config,
    required this.data,
    this.storeName = 'NUSA Kasir',
    this.dark = false,
    this.width,
  });

  @override
  State<ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<ReceiptPreview> {
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  @override
  void didUpdateWidget(covariant ReceiptPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.logoPath != widget.config.logoPath ||
        oldWidget.config.showLogo != widget.config.showLogo) {
      _loadLogo();
    }
  }

  Future<void> _loadLogo() async {
    final path = widget.config.logoPath;
    if (path == null || path.isEmpty || !widget.config.showLogo) {
      if (_logoBytes != null && mounted) setState(() => _logoBytes = null);
      return;
    }
    try {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        if (mounted) setState(() => _logoBytes = bytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isWide = config.paperWidth == '80';
    final previewW = widget.width ?? (isWide ? 330.0 : 250.0);

    final textColor = widget.dark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final subtleColor = widget.dark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    final dividerColor = widget.dark
        ? Colors.grey.shade600
        : Colors.grey.shade300;
    final bgColor = widget.dark ? NusaConfig.darkSurface2 : Colors.white;

    final itemFontSize = receiptPreviewSize(1, kompak: config.fontType == 'kompak');
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: itemFontSize,
      height: 1.5,
      color: textColor,
    );
    final monoBold = mono.copyWith(fontWeight: FontWeight.bold);
    final monoGrey = mono.copyWith(color: subtleColor);
    final monoBig = mono.copyWith(fontSize: itemFontSize * 1.05, fontWeight: FontWeight.bold);

    final parts = buildReceiptParts(
      config: config,
      data: widget.data,
      storeName: widget.storeName,
      logoBytes: _logoBytes,
    );

    return Container(
      width: previewW,
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.dark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: parts.map((p) => _buildPart(p, mono, monoBold, monoGrey, monoBig, dividerColor)).toList(),
      ),
    );
  }

  Widget _buildPart(
    ReceiptPart part,
    TextStyle mono,
    TextStyle monoBold,
    TextStyle monoGrey,
    TextStyle monoBig,
    Color dividerColor,
  ) {
    final config = widget.config;
    final isWide = config.paperWidth == '80';
    final previewW = widget.width ?? (isWide ? 330.0 : 250.0);
    // Skala print px → preview px (58mm: 384→~226; 80mm: 576→~302).
    final contentW = previewW - 28;
    final scale = contentW / receiptPaperWidthPx(config.paperWidth);

    switch (part) {
      case ReceiptPartText(:final text, :final bold, :final center):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text(
            text,
            textAlign: center ? TextAlign.center : TextAlign.left,
            style: bold ? monoBold : mono,
          ),
        );

      case ReceiptPartRow(:final label, :final amount, :final bold):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: bold ? monoBold : mono,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(amount, style: bold ? monoBold : mono),
            ],
          ),
        );

      case ReceiptPartHr():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: CustomPaint(
            painter: ReceiptDashPainter(color: dividerColor),
            child: const SizedBox(width: double.infinity, height: 2),
          ),
        );

      case ReceiptPartImage(:final png, :final paperPx, :final align):
        // v2.2.30: lebar preview = min(lebar persen, ukuran NATIVE logo) —
        // JANGAN upscale logo kecil. Printer thermal hanya bisa DOWNSCALE
        // (copyResize saat native > paperPx), jadi preview harus sama: logo
        // kecil dicetak kecil apa adanya, bukan digelembungkan ke 60% kertas.
        var width = (paperPx * scale).clamp(16.0, contentW);
        try {
          final decoded = img.decodeImage(png);
          if (decoded != null && decoded.width > 0) {
            final native = (decoded.width * scale).clamp(16.0, contentW);
            if (native < width) width = native;
          }
        } catch (_) {}
        final alignment = switch (align) {
          'left' => Alignment.centerLeft,
          'right' => Alignment.centerRight,
          _ => Alignment.center,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Align(
            alignment: alignment,
            child: Image.memory(
              png,
              filterQuality: FilterQuality.none,
              width: width,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );

      case ReceiptPartHeader(:final config):
        return _HeaderImage(
          config: config,
          storeName: widget.storeName,
          dark: widget.dark,
          width: contentW,
        );

      case ReceiptPartItem(:final name, :final qtyPrice, :final subtotal, :final productDisc, :final manualDisc, :final note):
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: mono),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(qtyPrice, style: monoGrey, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(subtotal, style: mono),
                  ],
                ),
              ),
              // Disc. Produk — diskon dari menu Produk
              if (productDisc != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('Disc. Produk $productDisc', style: monoGrey),
                ),
              // Disc. Manual — diskon dari "Ubah Diskon" manual di kasir
              if (manualDisc != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('Disc. Manual $manualDisc', style: monoGrey),
                ),
              if (note != null && note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('↳ $note', style: monoGrey),
                ),
            ],
          ),
        );
    }
  }
}

/// Header image struk (nama toko / header custom) — renderer SAMA dengan
/// printer (renderReceiptHeaderPng). Warna mengikuti mode terang/gelap.
class _HeaderImage extends StatelessWidget {
  final ReceiptConfig config;
  final String storeName;
  final bool dark;
  final double width;

  const _HeaderImage({
    required this.config,
    required this.storeName,
    required this.dark,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: renderReceiptHeaderPng(
        paperWidth: config.paperWidth,
        storeName: storeName,
        customHeader: config.header,
        headerPx: config.headerPx,
        headerWeight: config.headerWeight,
        color: dark ? Colors.white : Colors.black,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Center(
            child: Image.memory(
              snap.data!,
              filterQuality: FilterQuality.none,
              width: width,
              fit: BoxFit.fitWidth,
            ),
          ),
        );
      },
    );
  }
}

/// SATU dashed painter bersama (menggantikan _DashPainter ×3 lama).
class ReceiptDashPainter extends CustomPainter {
  final Color color;
  const ReceiptDashPainter({this.color = const Color(0xFFD1D5DB)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const dashW = 3.0;
    const gapW = 2.0;
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
