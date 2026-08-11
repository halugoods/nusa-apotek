import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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
