import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Unified "restore from cloud backup" flow shared by LoginScreen and
/// ActivationScreen.
///
/// Rules:
///   - Local DB sudah punya karyawan  → restore TIDAK perlu (return false).
///   - Ada backup di cloud            → tampilkan dialog preview "Data
///     Ditemukan" (nama toko / pemilik / waktu) → restore + restart app.
///   - Tidak ada backup / offline     → return false, caller bebas menuju
///     /setup (setup hanya jadi fallback TERAKHIR, bukan pertama).
///
/// Returns true when a restore was performed (app will restart), false when
/// the caller should continue normally (setup / pin).
class RestoreBackupFlow {
  /// Probe the local DB for employees. Returns null when the DB is broken
  /// (restore should still run — local data is gone anyway).
  static Future<bool?> _hasLocalEmployees() async {
    try {
      final db = AppDatabase();
      final count =
          await db.select(db.employees).get().then((r) => r.length);
      await db.close();
      return count > 0;
    } catch (_) {
      return null;
    }
  }

  /// Check cloud + show preview dialog + restore + restart.
  /// Returns true if restore was performed (app restarts).
  static Future<bool> runIfNeeded(WidgetRef ref, BuildContext context) async {
    // 1. Local sudah punya data → nothing to restore.
    final localOk = await _hasLocalEmployees();
    if (localOk == true) return false;

    // 2. Probe backup cloud (anon auth ensured inside repo).
    final repo = ref.read(activationRepoProvider);
    final hasBak = await repo.hasBackup();
    if (!hasBak) return false;

    // 3. Preview metadata (nama toko / pemilik / waktu backup).
    final meta = await repo.getBackupMetadata();
    final storeName = meta?['storeName'] as String? ?? '';
    final ownerName = meta?['ownerName'] as String? ?? '';
    final backupTimeStr = meta?['backupTime'] as String?;
    DateTime? backupTime;
    if (backupTimeStr != null) {
      backupTime = DateTime.tryParse(backupTimeStr);
    }

    if (!context.mounted) return false;

    // 4. Dialog konfirmasi — user tahu data APA yang dipulihkan.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: NusaConfig.activePrimary, size: 28),
              const SizedBox(width: 10),
              const Text('Data Ditemukan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data toko tersimpan di cloud. Ingin membukanya sekarang?',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                ),
              ),
              if (storeName.isNotEmpty || ownerName.isNotEmpty || backupTime != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkBackground : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (storeName.isNotEmpty)
                        _metaRow('Nama Toko', storeName, isDark),
                      if (ownerName.isNotEmpty)
                        _metaRow('Pemilik', ownerName, isDark),
                      if (backupTime != null)
                        _metaRow(
                          'Terakhir Backup',
                          '${backupTime.day}/${backupTime.month}/${backupTime.year} '
                          '${backupTime.hour.toString().padLeft(2, '0')}:${backupTime.minute.toString().padLeft(2, '0')}',
                          isDark,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                side: BorderSide(color: isDark ? NusaConfig.darkBorder : const Color(0xFFEDEDEF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NusaConfig.activePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Buka Toko Ini'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return false;

    // 5. Tutup koneksi drift yang sedang terbuka SEBELUM restore — kalau tidak,
    //    restoreDirect() menulis .pending + restart, tapi kalau restart gagal,
    //    fallback /login membaca DB lama yang masih kosong (drift lama masih
    //    terbuka) → PIN gagal + produk kosong. Tutup + invalidate dulu supaya
    //    koneksi berikutnya membaca DB hasil restore (v2.2.37).
    try {
      final db = ref.read(databaseProvider);
      await db.close();
    } catch (_) {}
    ref.invalidate(databaseProvider);

    // 6. Restore: v2.2.37 restoreDirect() swap LANGSUNG ke sqlite live (tanpa
    //    restart) — aman karena drift sudah ditutup di atas. Data langsung
    //    berlaku: login berikutnya membaca DB hasil restore, produk langsung
    //    tampil, PIN sesuai.
    final ok = await repo.restoreDirect();
    if (ok && context.mounted) {
      TopToast.success(context, 'Data berhasil dipulihkan');
      // Tidak perlu Restart.restartApp() lagi — DB sudah live. Cukup kembali
      // ke layar login supaya user masuk dengan PIN dari data hasil restore.
      if (context.canPop()) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      if (context.mounted) context.go('/login');
      return true;
    }
    if (context.mounted) {
      TopToast.error(context, 'Gagal memulihkan data dari cloud');
    }
    return false;
  }

  static Widget _metaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
