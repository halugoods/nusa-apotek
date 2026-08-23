import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Foto produk dengan fallback otomatis ke BASE64.
///
/// Backup/restore cloud membawa foto produk sebagai BASE64 (kolom
/// `image_base64`) di dalam DB. File lokal (`imagePath`) TIDAK ikut cloud,
/// jadi setelah restore di device/login ulang, path bisa menunjuk ke file yang
/// tidak ada. Widget ini menampilkan foto dari:
///   1. file lokal jika `imagePath` ada & file-nya benar-benar ada, atau
///   2. `imageBase64` (decode on the fly) jika file hilang tapi base64 ada, atau
///   3. placeholder (child) jika keduanya tidak ada.
///
/// Menggantikan pola `Image.file(File(p.imagePath!))` yang selama ini HANYA
/// membaca file lokal — sumber regresi "foto produk tidak ke-restore".
class NusaProductImage extends StatelessWidget {
  final String? imagePath;
  final String? imageBase64;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool circle;

  const NusaProductImage({
    super.key,
    this.imagePath,
    this.imageBase64,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.circle = false,
  });

  ImageProvider? _resolveProvider() {
    // 1. File lokal ada → prioritas utama (paling cepat, tanpa decode).
    if (imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync()) {
      return FileImage(File(imagePath!));
    }
    // 2. Fallback base64 dari DB (kalau path basi / belum di-hydrate).
    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(imageBase64!));
      } catch (_) {
        return null; // base64 rusak → placeholder
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _resolveProvider();
    Widget img;
    if (provider != null) {
      img = Image(
        image: provider,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      img = placeholder;
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    if (circle) {
      return ClipOval(child: img);
    }
    return img;
  }
}