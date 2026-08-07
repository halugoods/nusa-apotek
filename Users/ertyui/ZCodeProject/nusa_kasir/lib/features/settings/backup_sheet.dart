import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/services/backup_crypto.dart';
import "package:nusa_kasir/shared/widgets/top_toast.dart";
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void showBackupSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    builder: (_) => _BackupSheetBody(rootContext: context, ref: ref),
  );
}

class _BackupSheetBody extends StatelessWidget {
  final BuildContext rootContext;
  final WidgetRef ref;
  const _BackupSheetBody({required this.rootContext, required this.ref});

  Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'nusa_kasir.sqlite');
  }

  /// Check if a file is an image we should include in backup.
  bool _isImageFile(String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext != '.jpg' && ext != '.jpeg' && ext != '.png' && ext != '.webp') {
      return false;
    }
    return name.startsWith('product_') ||
        name.startsWith('photo_') ||
        name.startsWith('qris_');
  }

  /// Backup: pack SQLite + all images into a single NUS1 archive.
  Future<void> _backup(BuildContext ctx) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dir.path, 'nusa_kasir.sqlite'));
      if (!await dbFile.exists()) {
        if (ctx.mounted) TopToast.error(ctx, 'Database tidak ditemukan');
        return;
      }

      // Pack SQLite + images into NUS1 archive
      final archiveFiles = <String, Uint8List>{};
      archiveFiles['nusa_kasir.sqlite'] = await dbFile.readAsBytes();

      final dirContents = dir.listSync();
      for (final entity in dirContents) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (_isImageFile(name)) {
            archiveFiles[name] = await entity.readAsBytes();
          }
        }
      }

      final packed = BackupCrypto.packFiles(archiveFiles);

      // Write archive to temp for sharing
      final outDir = await getTemporaryDirectory();
      final ts = DateTime.now();
      final name =
          'nusa_kasir_full_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}.nus1';
      final out = File(p.join(outDir.path, name));
      await out.writeAsBytes(packed, flush: true);

      if (ctx.mounted) Navigator.of(ctx).pop();
      await Share.shareXFiles(
        [XFile(out.path)],
        subject: 'Backup NUSA Kasir (Full)',
        text: 'File backup lengkap NUSA Kasir — termasuk database + semua gambar',
      );
    } catch (e) {
      if (ctx.mounted) TopToast.error(ctx, 'Gagal backup: $e');
    }
  }

  /// Restore: accept both .sqlite (legacy) and .nus1 (archive with images).
  Future<void> _restore(BuildContext ctx) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'db', 'nus1'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) return;
      final ext = p.extension(result.files.single.name).toLowerCase();

      final dir = await getApplicationDocumentsDirectory();
      final db = ref.read(databaseProvider);
      await db.close();

      if (ext == '.nus1') {
        // NUS1 archive: extract SQLite + images
        final unpacked = BackupCrypto.unpackFiles(bytes);
        for (final entry in unpacked.entries) {
          if (entry.key == 'nusa_kasir.sqlite') {
            final dbFile = File(p.join(dir.path, 'nusa_kasir.sqlite'));
            await dbFile.writeAsBytes(entry.value, flush: true);
          } else if (_isImageFile(entry.key)) {
            final imgFile = File(p.join(dir.path, entry.key));
            await imgFile.writeAsBytes(entry.value, flush: true);
          }
        }
      } else {
        // Legacy .sqlite — just copy the DB; images may be lost
        final dbFile = File(p.join(dir.path, 'nusa_kasir.sqlite'));
        await dbFile.writeAsBytes(bytes, flush: true);
      }

      ref.invalidate(databaseProvider);
      if (ctx.mounted) Navigator.of(ctx).pop();
      if (rootContext.mounted) GoRouter.of(rootContext).go('/home');
    } catch (e) {
      if (ctx.mounted) TopToast.error(ctx, 'Gagal restore: $e');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Backup & Restore',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.backup),
                title: Text('Backup Lengkap (Database + Gambar)'),
                subtitle: Text(
                    'Simpan database & semua gambar dalam satu file .nus1'),
                onTap: () => _backup(context),
              ),
              ListTile(
                leading: Icon(Icons.restore),
                title: Text('Restore Backup'),
                subtitle: Text(
                    'Pilih file backup (.nus1 atau .sqlite)'),
                onTap: () => _restore(context),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      );
}
