import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Hasil satu scan yang ditangani pemanggil (resolve barcode → produk).
/// Kembalikan null bila barcode tidak dikenali (chip merah "tidak ditemukan"),
/// atau kembalikan label hijau bila sukses (mis. nama produk).
typedef ScanResolver = Future<String?> Function(String barcode);

/// Scanner barcode KONTINU — layar penuh, TIDAK menutup setelah 1 scan.
///
/// - [DetectionSpeed.noDuplicates]: kode yang sama tidak nge-fire berulang
///   selama masih terlihat di frame; angkat-turun barcode = scan lagi.
/// - **Cooldown 1 detik** per kode (user-specified) supaya scan beruntun
///   cepat tidak double-count.
/// - Resolve dilakukan lewat [resolver] (async, per scan) — pemanggil
///   (POS / Catat Pembelian) yang memasukkan ke keranjang; scanner tetap
///   terbuka untuk scan berikutnya.
/// - Chip hasil scan terakhir: hijau (✓ produk) / merah (tidak ditemukan) +
///   hitungan "N produk ter-scan". Tombol Tutup untuk keluar.
class ContinuousBarcodeScanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final ScanResolver resolver;

  const ContinuousBarcodeScanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.resolver,
  });

  @override
  State<ContinuousBarcodeScanner> createState() =>
      _ContinuousBarcodeScannerState();
}

class _ContinuousBarcodeScannerState extends State<ContinuousBarcodeScanner> {
  // Owned: dibuat dengan DetectionSpeed.noDuplicates + format umum.
  // MobileScannerController v6: detectionSpeed & formats hanya bisa diatur
  // lewat constructor (tidak ada setter runtime).
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );

  String? _lastCode;
  String? _lastLabel;
  bool _lastOk = false;
  int _count = 0;
  DateTime _lastHandledAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Cooldown 1 detik — kode yang sama tidak diproses dua kali dalam
    // jarak 1 detik (mencegah double-count scan beruntun yang cepat).
    final now = DateTime.now();
    if (_lastCode == raw &&
        now.difference(_lastHandledAt).inMilliseconds < 1000) {
      return;
    }
    _lastCode = raw;
    _lastHandledAt = now;

    String? label;
    try {
      label = await widget.resolver(raw);
    } catch (_) {
      label = null;
    }
    if (!mounted) return;
    setState(() {
      _lastOk = label != null;
      _lastLabel = label;
      if (label != null) _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera penuh layar — scan berulang tanpa menutup.
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              debugPrint('[Scanner] error: $error');
              return Container(
                color: Colors.black,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      size: 48,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kamera tidak tersedia atau izin kamera ditolak.\n'
                      'Periksa izin di pengaturan perangkat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Tutup'),
                      style: FilledButton.styleFrom(
                        backgroundColor: NusaConfig.activePrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay panduan + UI atas.
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: judul + tombol tutup.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          tooltip: 'Tutup scanner',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Area panduan scan (bisa dipindai berulang).
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'Arahkan kamera ke barcode —\nscan berulang tanpa menutup',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ),
                const Spacer(),

                // Chip hasil scan terakhir + hitungan.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        if (_lastLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_lastOk
                                          ? Colors.greenAccent
                                          : Colors.redAccent)
                                      .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _lastOk
                                    ? Colors.greenAccent.withValues(alpha: 0.5)
                                    : Colors.redAccent.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _lastOk
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  size: 15,
                                  color: _lastOk
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _lastLabel!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _lastOk
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text(
                            'Belum ada scan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        const Spacer(),
                        if (_count > 0)
                          Text(
                            '$_count produk ter-scan',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Ruang bawah biar tidak nempel ke gesture bar.
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Buka scanner kontinu lewat push route (full screen).
Future<void> pushContinuousScanner(
  BuildContext context, {
  required String title,
  required String subtitle,
  required ScanResolver resolver,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ContinuousBarcodeScanner(
        title: title,
        subtitle: subtitle,
        resolver: resolver,
      ),
    ),
  );
}
