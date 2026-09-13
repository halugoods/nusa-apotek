import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Helper penyimpanan gambar ke direktori Galeri publik (Pictures / Download).
class ImageSaverUtil {
  /// Menyimpan bytes gambar ke folder Pictures/Nusa publik di Android,
  /// atau fallback ke Documents/Pictures jika di OS lain.
  static Future<String> saveImageToGallery(
    Uint8List bytes, {
    required String filename,
  }) async {
    Directory? targetDir;

    if (Platform.isAndroid) {
      // Prioritas 1: /storage/emulated/0/Pictures/Nusa (Terbaca otomatis oleh Galeri Android)
      final picturesDir = Directory('/storage/emulated/0/Pictures/Nusa');
      try {
        if (!picturesDir.existsSync()) {
          picturesDir.createSync(recursive: true);
        }
        if (picturesDir.existsSync()) {
          targetDir = picturesDir;
        }
      } catch (e) {
        debugPrint('[ImageSaverUtil] Gagal buat Pictures/Nusa: $e');
      }

      // Prioritas 2: /storage/emulated/0/Download/Nusa
      if (targetDir == null) {
        final downloadDir = Directory('/storage/emulated/0/Download/Nusa');
        try {
          if (!downloadDir.existsSync()) {
            downloadDir.createSync(recursive: true);
          }
          if (downloadDir.existsSync()) {
            targetDir = downloadDir;
          }
        } catch (e) {
          debugPrint('[ImageSaverUtil] Gagal buat Download/Nusa: $e');
        }
      }
    }

    // Fallback: getExternalStorageDirectory atau getApplicationDocumentsDirectory
    if (targetDir == null) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final customDir = Directory('${ext.path}/Pictures');
          if (!customDir.existsSync()) customDir.createSync(recursive: true);
          targetDir = customDir;
        }
      } catch (_) {}
    }

    if (targetDir == null) {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final safeFilename = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final file = File('${targetDir.path}/$safeFilename');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[ImageSaverUtil] Gambar tersimpan di: ${file.path}');
    return file.path;
  }
}
