import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Encoder perintah cetak label — TSPL & ESC/POS.
///
/// TSPL (jalur 1): perintah TSPL/TSPL2 STANDAR (kompatibel semua merk label
/// printer — Rongta, HPRT, Godex, BluePrint, Zebra TSPL mode, dll). Label
/// dirender ke bitmap monokrom di [LabelRenderer], lalu dikirim sebagai
/// image raster `TSPL BITMAP` + `PRINT`. Tidak bergantung perintah khusus
/// merk — hanya TSPL inti (SIZE, GAP, CLS, BITMAP, PRINT) yang dipahami
/// semua merk label printer.
///
/// ESC/POS (jalur 2): printer struk thermal 58mm — bit-image raster ESC/POS
/// `GS v 0`. Struk label beruntun: teks nama + harga, barcode bit-image,
/// lalu feed + cut.
class LabelCommands {
  /// Konversi bitmap monokrom [black] (true=hitam) ke bytes TSPL image
  /// raster. TSPL BITMAP memakai format: 1 byte = 8 piksel per baris,
  /// MSB = piksel kiri. Lebar dibulatkan ke kelipatan 8 (wajib TSPL).
  static Uint8List _tsplRaster(List<bool> black, int width, int height) {
    final rowBytes = (width + 7) ~/ 8;
    final out = Uint8List(rowBytes * height);
    for (var y = 0; y < height; y++) {
      final rowStart = y * width;
      final outStart = y * rowBytes;
      for (var x = 0; x < width; x++) {
        if (black[rowStart + x]) {
          final byteIdx = x >> 3;
          final bit = 7 - (x & 7);
          out[outStart + byteIdx] |= (1 << bit);
        }
      }
    }
    return out;
  }

  /// Bangun bytes TSPL untuk SATU label dari [bitmap] (img.Image monokrom).
  ///
  /// Perintah standar (dalam mm — satuan paling kompatibel lintas merk):
  ///   SIZE w,h     → ukuran label (mm)
  ///   GAP d        → jarak antar label (mm)
  ///   CLS          → clear buffer
  ///   BITMAP x,y,w,h,0,data → image raster (tanpa native barcode — semua
  ///                    merk label printer paham BITMAP)
  ///   PRINT n      → cetak n label (v2.2.57+121: [copies] = qty cetak)
  ///
  /// [labelWidthMm]/[labelHeightMm] = ukuran label fisik (default 40×30).
  /// [gapMm] = jarak antar label (default 2).
  /// [copies] (v2.2.57+121) = berapa lembar label dicetak (default 1).
  static Uint8List buildTspl(
    img.Image bitmap, {
    required double labelWidthMm,
    required double labelHeightMm,
    double gapMm = 2,
    int copies = 1,
  }) {
    final black = LabelMono.toList(bitmap);
    final raster = _tsplRaster(black, bitmap.width, bitmap.height);
    final buf = StringBuffer();
    final n = copies > 0 ? copies : 1;

    buf.write('SIZE ${_mm(labelWidthMm)}, ${_mm(labelHeightMm)}\r\n');
    buf.write('GAP ${_mm(gapMm)}, 0\r\n');
    buf.write('CLS\r\n');
    buf.write(
      'BITMAP 0,0,${bitmap.width},${bitmap.height},0,',
    );
    buf.write('\r\n');
    buf.write('PRINT $n\r\n');

    // Gabung header text + raster bytes + terminasi.
    final head = Uint8List.fromList(buf.toString().codeUnits);
    final out = Uint8List(head.length + raster.length + 4);
    out.setRange(0, head.length, head);
    out.setRange(head.length, head.length + raster.length, raster);
    out.setRange(head.length + raster.length, out.length, [13, 10, 0x1A, 0]);
    return out;
  }

  static String _mm(double mm) => mm.toStringAsFixed(1);

  /// Bangun bytes ESC/POS untuk SATU label struk 58mm dari [bitmap].
  ///
  /// Struk label beruntun: bit-image raster (GS v 0) dari [bitmap] yang SUDAH
  /// berisi barcode+nama+harga (renderLabelBitmap), lalu feed + potong.
  ///
  /// v2.2.57+115: nama & harga TIDAK lagi dicetak sebagai teks ESC/POS di
  /// sini — dulu ini bikin nama/harga DOBEL (teks + di dalam bitmap).
  /// [name]/[price] dipertahankan sebagai parameter untuk kompatibilitas
  /// pemanggil, tapi tidak dipakai.
  static Uint8List buildEscPosLabel({
    required img.Image bitmap,
    required String name,
    required int price,
    required bool showName,
    required bool showPrice,
  }) {
    final out = <int>[];
    // Reset printer.
    out.addAll(const [0x1B, 0x40]);

    // Bit-image raster (GS v 0) — kompatibel ESC/POS umum (Epson/Star/Xprinter).
    // Bitmap = SATU label lengkap (barcode + nama + harga) yang dirender
    // LabelRenderer — konsisten dengan preview & PDF.
    out.addAll(_gsV0Raster(bitmap));

    // Feed + cut. Feed 4 baris supaya label terpisah rapi.
    out.addAll(const [0x1B, 0x64, 0x04]);
    out.addAll(const [0x1D, 0x56, 0x00]);
    return Uint8List.fromList(out);
  }

  /// Bit-image raster ESC/POS: GS v 0 m xL xH yL yH d1...dk.
  /// x = byte per baris (lebar/8), y = tinggi baris. Monokrom, MSB kiri.
  /// [width] harus kelipatan 8 (renderer sudah round-up).
  static List<int> _gsV0Raster(img.Image image) {
    final width = image.width;
    final height = image.height;
    final rowBytes = (width + 7) ~/ 8;
    final data = Uint8List(4 + rowBytes * height);
    data[0] = 0x1D;
    data[1] = 0x76;
    data[2] = 0x30;
    data[3] = 0x00; // m
    data[4] = rowBytes & 0xFF;
    data[5] = (rowBytes >> 8) & 0xFF;
    data[6] = height & 0xFF;
    data[7] = (height >> 8) & 0xFF;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        final isBlack = (img.getRed(p) + img.getGreen(p) + img.getBlue(p)) < 384;
        if (isBlack) {
          final byteIdx = x >> 3;
          final bit = 7 - (x & 7);
          data[8 + y * rowBytes + byteIdx] |= (1 << bit);
        }
      }
    }
    return data.toList();
  }
}

/// Helper mono — konversi [img.Image] ke daftar piksel hitam (untuk TSPL).
class LabelMono {
  /// true = piksel hitam.
  static List<bool> toList(img.Image image) {
    final width = image.width;
    final black = List<bool>.filled(width * image.height, false);
    for (var y = 0; y < image.height; y++) {
      final rowStart = y * width;
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        black[rowStart + x] = (img.getRed(p) + img.getGreen(p) + img.getBlue(p)) < 384;
      }
    }
    return black;
  }
}
