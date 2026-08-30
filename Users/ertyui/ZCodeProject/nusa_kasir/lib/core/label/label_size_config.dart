import 'package:nusa_kasir/core/label/label_renderer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// SATU sumber kebenaran untuk UKURAN label fisik cetak barcode
/// (v2.2.57+121) — width × height dalam mm.
///
/// User bisa memilih ukuran kertas label printer (default 40×30mm — pas label
/// harga umum). Ukuran dipakai oleh:
///   - TSPL: perintah `SIZE w,h` (jalur Thermal Label)
///   - PDF A4: grid label dihitung ulang per ukuran (jalur PDF)
///   - Preview: mengikuti pilihan user (preview = hasil cetak)
///
/// Jalur Thermal Struk TIDAK terpengaruh — label struk selalu selebar kertas
/// (58/80mm) karena dicetak beruntun di kertas struk.
///
/// Pola penyimpanan sama seperti [LabelFontConfig] (SecureStore, murni
/// pengaturan perangkat — tidak butuh AppDatabase).
class LabelSizeConfig {
  /// Lebar label (mm). Default 40.
  final double widthMm;

  /// Tinggi label (mm). Default 30.
  final double heightMm;

  const LabelSizeConfig({
    this.widthMm = LabelRenderer.defaultWidthMm,
    this.heightMm = LabelRenderer.defaultHeightMm,
  });

  LabelSizeConfig copyWith({double? widthMm, double? heightMm}) {
    return LabelSizeConfig(
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
    );
  }

  static double _clampW(double v) => v.clamp(20.0, 120.0);
  static double _clampH(double v) => v.clamp(10.0, 120.0);

  /// Baca konfigurasi dari SecureStore.
  static Future<LabelSizeConfig> load() async {
    return LabelSizeConfig(
      widthMm: _clampW(await SecureStore.getLabelWidthMm()),
      heightMm: _clampH(await SecureStore.getLabelHeightMm()),
    );
  }

  /// Simpan ke SecureStore (tidak perlu DB — murni pengaturan perangkat,
  /// dipakai jalur print tanpa AppDatabase).
  Future<void> save() async {
    await SecureStore.setLabelWidthMm(_clampW(widthMm));
    await SecureStore.setLabelHeightMm(_clampH(heightMm));
  }
}
