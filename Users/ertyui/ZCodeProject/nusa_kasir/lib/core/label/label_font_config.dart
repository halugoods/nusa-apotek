import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// SATU sumber kebenaran untuk ukuran font cetak label barcode (v2.2.57+116).
///
/// User bisa menyesuaikan ukuran font NAMA produk & HARGA di label. Nilai
/// tersimpan sebagai SKALA (1.0–3.0) terhadap font dasar:
///   - Bitmap (TSPL / struk thermal): font 5×7 digambar dengan perbesaran
///     [scale] → makin besar, makin jelas (mis. 2.0 = 10×14 px per char).
///   - PDF A4: fontSize = 7.5 × [scale] (nama) / 8 × [scale] (harga).
///
/// Konfigurasi ini berlaku ke SEMUA jalur cetak (TSPL / ESC-POS / PDF) supaya
/// preview = hasil cetak — pola sama seperti [ReceiptConfig] di struk.
class LabelFontConfig {
  /// Skala font nama produk (1.0–3.0). Default 1.0 = ukuran standar.
  final double nameScale;

  /// Skala font harga (1.0–3.0). Default 1.0 = ukuran standar.
  final double priceScale;

  const LabelFontConfig({
    this.nameScale = 1.0,
    this.priceScale = 1.0,
  });

  LabelFontConfig copyWith({double? nameScale, double? priceScale}) {
    return LabelFontConfig(
      nameScale: nameScale ?? this.nameScale,
      priceScale: priceScale ?? this.priceScale,
    );
  }

  static double _clamp(double v) => v.clamp(1.0, 3.0);

  /// Baca konfigurasi dari SecureStore.
  static Future<LabelFontConfig> load() async {
    return LabelFontConfig(
      nameScale: _clamp(await SecureStore.getLabelNameFontScale()),
      priceScale: _clamp(await SecureStore.getLabelPriceFontScale()),
    );
  }

  /// Simpan ke SecureStore (tidak perlu DB — murni pengaturan perangkat,
  /// dipakai jalur print tanpa AppDatabase).
  Future<void> save() async {
    await SecureStore.setLabelNameFontScale(_clamp(nameScale));
    await SecureStore.setLabelPriceFontScale(_clamp(priceScale));
  }
}
