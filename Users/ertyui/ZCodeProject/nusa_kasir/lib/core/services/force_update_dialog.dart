import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/update_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Popup UPDATE WAJIB (v2.2.57) — tampil saat build app < min_build produk
/// di server. BLOCKING: tidak bisa ditutup/diskip, app tidak bisa dipakai
/// sampai diupdate.
///
/// Tombol download SELALU buka browser eksternal (LaunchMode.externalApplication)
/// — bukan unduh in-app — sesuai keputusan desain v2.2.57.
class ForceUpdateDialog {
  static Future<void> show(BuildContext context, ForceUpdateInfo info) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 36,
                    color: NusaConfig.activePrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Update Wajib',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Versi baru NUSA (v${info.minVersion}) sudah tersedia. '
                  'Aplikasi harus diupdate dulu sebelum bisa dipakai lagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                // v2.2.57+115: versi APK asli dari PackageInfo.
                FutureBuilder<String>(
                  future: SecureStore.installedVersionAndBuild(),
                  builder: (context, snap) {
                    final installed = snap.data ?? '';
                    return Text(
                      installed.isNotEmpty
                          ? 'Versi kamu: $installed'
                          : 'Versi kamu: v${NusaConfig.appVersion} '
                              '(build ${NusaConfig.appBuildNumber})',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openBrowser(ctx, info.downloadUrl),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('Update Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NusaConfig.activePrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Download dibuka di browser — instal lalu buka ulang aplikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openBrowser(BuildContext ctx, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Link update belum tersedia. Hubungi admin.')),
      );
      return;
    }
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Gagal membuka browser.')),
        );
      }
    }
  }
}
