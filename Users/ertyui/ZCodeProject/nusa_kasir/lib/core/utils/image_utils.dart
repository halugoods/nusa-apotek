import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Picks a photo from the gallery and saves it as a downscaled JPG.
///
/// Uses [ImagePicker] with `maxWidth`/`maxHeight`/`imageQuality` so the
/// system downscales BEFORE the full bitmap ever hits our process — this
/// avoids the OOM crashes that `file_picker withData:true` caused on
/// low-RAM devices (Samsung A14 50MP photos ≈ 200MB decoded bitmap).
///
/// Returns the absolute path of the saved JPG, or null if the user
/// cancelled or something failed. Never throws — callers just check null.
Future<String?> pickAndSaveImage({
  required int maxSize,
  required String prefix,
}) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSize.toDouble(),
      maxHeight: maxSize.toDouble(),
      imageQuality: 80,
    );
    if (picked == null) return null; // user cancelled

    final dir = await getApplicationDocumentsDirectory();
    final destName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = p.join(dir.path, destName);

    final file = File(picked.path);
    if (!await file.exists()) return null;

    // Extra safety: if the system-provided file is somehow still huge,
    // decode + re-encode capped at maxSize before writing.
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final scaled = (decoded.width > maxSize || decoded.height > maxSize)
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxSize : null,
              height: decoded.height > decoded.width ? maxSize : null,
            )
          : decoded;
      final jpg = img.encodeJpg(scaled, quality: 80);
      await File(destPath).writeAsBytes(jpg, flush: true);
    } else {
      // Not a decodable image — fall back to copying the raw bytes.
      await File(destPath).writeAsBytes(bytes, flush: true);
    }

    // Clean up the picker's temp file if it differs from our destination.
    try {
      if (file.path != destPath && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    return destPath;
  } catch (_) {
    return null;
  }
}

/// Decode a downscaled [ImageProvider] from a local file path.
///
/// [targetWidth] limits the decode size (via `cacheWidth`) so we never
/// allocate a full-resolution bitmap for a small on-screen thumbnail.
ImageProvider fileImage(String path, {int targetWidth = 400}) {
  final f = FileImage(File(path));
  if (targetWidth > 0) {
    return ResizeImage(f, width: targetWidth);
  }
  return f;
}

/// Opens the native crop tool (UCrop) for the image at [sourcePath].
///
/// CROP ANTI-FC (v2.2.35): panggil HANYA pada file yang SUDAH di-downscale
/// (mis. hasil `pickAndSaveImage` ≤1024px) — file 50MP asli yang dibuka
/// UCrop akan meletupkan RAM di device murah (Samsung A14) dan memaksa app
/// close. Aspect 1:1 dikunci (foto produk ditampilkan persegi di semua UI).
///
/// Returns the cropped file path, or null if the user cancelled or the crop
/// failed. NEVER throws — caller tetap memakai file asli bila gagal, app
/// tidak boleh tutup gara-gara crop.
Future<String?> cropAndSaveImage(String sourcePath) async {
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          toolbarTitle: 'Potong Foto',
          toolbarColor: const Color(0xFF4F46E5),
          statusBarColor: const Color(0xFF4F46E5),
          activeControlsWidgetColor: const Color(0xFF4F46E5),
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Potong Foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return null; // user cancelled
    final outPath = cropped.path;
    if (!File(outPath).existsSync()) return null;

    // UCrop output kadang resolusi besar lagi — downscale ulang biar tetap
    // ringan & seragam (1:1, ≤1024px).
    final dir = await getApplicationDocumentsDirectory();
    final destName =
        'crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = p.join(dir.path, destName);
    try {
      final bytes = await File(outPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final scaled = (decoded.width > 1024 || decoded.height > 1024)
            ? img.copyResize(decoded, width: 1024, height: 1024)
            : decoded;
        await File(destPath).writeAsBytes(
          img.encodeJpg(scaled, quality: 82),
          flush: true,
        );
      } else {
        await File(destPath).writeAsBytes(bytes, flush: true);
      }
    } catch (_) {
      // Gagal re-encode — pakai file hasil UCrop langsung.
      return outPath;
    }
    try {
      if (File(outPath).existsSync()) await File(outPath).delete();
    } catch (_) {}
    return destPath;
  } catch (_) {
    return null;
  }
}
