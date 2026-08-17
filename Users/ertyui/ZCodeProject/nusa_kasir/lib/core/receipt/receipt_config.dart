import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';

/// SATU sumber kebenaran untuk semua pengaturan struk (v2.2.29).
///
/// Sebelumnya config tersebar di 16+ key SecureStore + kolom DB settings,
/// dimirror manual di tiap layar (sering lupa satu key → preview beda dengan
/// print). Sekarang semua dibaca/ditulis lewat satu objek [ReceiptConfig].
///
/// [ReceiptConfig] HANYA berisi pengaturan template — TIDAK bercampur dengan
/// data transaksi (lihat [ReceiptData]).
class ReceiptConfig {
  /// Ukuran kertas: '58' atau '80' (mm). Default 58.
  final String paperWidth;

  /// Jenis font: 'standar' (Font A, universal) | 'kompak' (Font B, ramping).
  final String fontType;

  /// Ukuran header image (px, 12–48). Default 24.
  final int headerPx;

  /// Ketebalan header image: 'thin' | 'medium' | 'bold'.
  final String headerWeight;

  /// Teks header custom (fallback: nama toko saat kosong).
  final String header;

  /// Teks footer struk (bisa multi-baris).
  final String footer;

  /// Path file logo toko (null = tanpa logo).
  final String? logoPath;

  /// Lebar logo saat print — persen dari lebar kertas (1–100).
  final int logoWidthPercent;

  /// Posisi logo: 'left' | 'center' | 'right'. Default center.
  final String logoAlign;

  // ── Toggle info yang dirender di struk ──
  final bool showLogo;
  final bool showCashier;
  final bool showInvoice;
  final bool showDate;

  const ReceiptConfig({
    this.paperWidth = '58',
    this.fontType = 'standar',
    this.headerPx = 24,
    this.headerWeight = 'medium',
    this.header = '',
    this.footer = '',
    this.logoPath,
    this.logoWidthPercent = 60,
    this.logoAlign = 'center',
    this.showLogo = true,
    this.showCashier = true,
    this.showInvoice = true,
    this.showDate = true,
  });

  ReceiptConfig copyWith({
    String? paperWidth,
    String? fontType,
    int? headerPx,
    String? headerWeight,
    String? header,
    String? footer,
    String? logoPath,
    int? logoWidthPercent,
    String? logoAlign,
    bool? showLogo,
    bool? showCashier,
    bool? showInvoice,
    bool? showDate,
  }) {
    return ReceiptConfig(
      paperWidth: paperWidth ?? this.paperWidth,
      fontType: fontType ?? this.fontType,
      headerPx: headerPx ?? this.headerPx,
      headerWeight: headerWeight ?? this.headerWeight,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      logoPath: logoPath ?? this.logoPath,
      logoWidthPercent: logoWidthPercent ?? this.logoWidthPercent,
      logoAlign: logoAlign ?? this.logoAlign,
      showLogo: showLogo ?? this.showLogo,
      showCashier: showCashier ?? this.showCashier,
      showInvoice: showInvoice ?? this.showInvoice,
      showDate: showDate ?? this.showDate,
    );
  }

  /// Nama toko — bukan bagian config tersimpan; diteruskan saat render
  /// (fallback header + footer "Terima Kasih!"). Dibaca di [load].
  /// Diteruskan via parameter render, bukan disimpan di sini.
  // (tidak disimpan — lihat ReceiptRenderer.render(config, data, storeName))

  /// Baca SELURUH config struk dari SecureStore + DB settings → satu objek.
  /// Ini pengganti mirroring manual (settings_screen, receipt_sheet, dll).
  static Future<ReceiptConfig> load(AppDatabase db) async {
    final repo = SettingsRepository(db);
    final toggles = await repo.getReceiptToggles();
    final logoPath =
        await repo.getStoreLogoPath() ?? await SecureStore.getPrinterLogoPath();
    String paper = await repo.getReceiptPaperSize();
    if (paper == '58' || paper == '80') paper = '${paper}mm'; // normalize
    return ReceiptConfig(
      paperWidth: paper.replaceAll('mm', ''),
      fontType: await SecureStore.getReceiptFontType(),
      headerPx: await SecureStore.getReceiptHeaderPx(),
      headerWeight: await SecureStore.getReceiptHeaderWeight(),
      header: await repo.getReceiptHeader() ?? '',
      footer: await repo.getReceiptFooter() ?? '',
      logoPath: logoPath,
      logoWidthPercent: await SecureStore.getReceiptLogoWidthPercent(),
      logoAlign: await SecureStore.getReceiptLogoAlign(),
      showLogo: toggles['showLogo'] ?? true,
      showCashier: toggles['showCashier'] ?? true,
      showInvoice: toggles['showInvoice'] ?? true,
      showDate: toggles['showDate'] ?? true,
    );
  }

  /// Baca config HANYA dari SecureStore (tanpa DB) — dipakai jalur PRINT
  /// (ReceiptPrinter) yang tidak punya AppDatabase. ReceiptConfig.save()
  /// menulis mirror ke SecureStore, jadi nilai di sini SELALU up-to-date
  /// dengan Pengaturan Struk.
  static Future<ReceiptConfig> loadFromStore() async {
    return ReceiptConfig(
      paperWidth: await SecureStore.getPaperSize(),
      fontType: await SecureStore.getReceiptFontType(),
      headerPx: await SecureStore.getReceiptHeaderPx(),
      headerWeight: await SecureStore.getReceiptHeaderWeight(),
      header: await SecureStore.getReceiptHeader() ?? '',
      footer: await SecureStore.getPrinterFooter(),
      logoPath: await SecureStore.getPrinterLogoPath(),
      logoWidthPercent: await SecureStore.getReceiptLogoWidthPercent(),
      logoAlign: await SecureStore.getReceiptLogoAlign(),
      showLogo: await SecureStore.getReceiptShowLogo(),
      showCashier: await SecureStore.getReceiptShowCashier(),
      showInvoice: await SecureStore.getReceiptShowInvoice(),
      showDate: await SecureStore.getReceiptShowDate(),
    );
  }

  /// Simpan SELURUH config ke DB + SecureStore — satu titik tulis.
  /// Pengganti blok mirror manual di settings_screen (8+ key).
  Future<void> save(AppDatabase db) async {
    final repo = SettingsRepository(db);
    await repo.setReceiptHeader(header.trim());
    await repo.setReceiptFooter(footer.trim());
    await repo.setReceiptPaperSize('${paperWidth}mm');
    await repo.setReceiptToggles({
      'showLogo': showLogo,
      'showCashier': showCashier,
      'showInvoice': showInvoice,
      'showDate': showDate,
    });
    // ── Sync ke SecureStore (single source untuk printing) ──
    await SecureStore.setPaperSize(paperWidth);
    await SecureStore.setPrinterFooter(footer.trim());
    await SecureStore.setReceiptHeader(header.trim());
    await SecureStore.setReceiptFontType(fontType);
    await SecureStore.setReceiptHeaderPx(headerPx);
    await SecureStore.setReceiptHeaderWeight(headerWeight);
    await SecureStore.setReceiptLogoWidthPercent(logoWidthPercent);
    await SecureStore.setReceiptLogoAlign(logoAlign);
    await SecureStore.setReceiptShowLogo(showLogo);
    await SecureStore.setReceiptShowCashier(showCashier);
    await SecureStore.setReceiptShowInvoice(showInvoice);
    await SecureStore.setReceiptShowDate(showDate);
    if (logoPath != null && logoPath!.isNotEmpty) {
      await repo.setStoreLogoPath(logoPath!);
      await SecureStore.setPrinterLogoPath(logoPath);
    } else {
      await SecureStore.setPrinterLogoPath(null);
    }
  }

  /// Data sample REALISTIS untuk preview di Pengaturan Struk (spec W).
  /// Angka persis dari spesifikasi: item Dimsum Original (2×15.000, diskon
  /// 3.000), Dimsum Mentai, Dimsum Keju (3×18.000 diskon 2.700), Es Teh,
  /// Air Mineral; TOTAL 112.300, Disc. total 5.700, Tunai 120.000,
  /// Kembalian 7.700.
  static ReceiptConfig sample() {
    return const ReceiptConfig(
      paperWidth: '58',
      fontType: 'standar',
      headerPx: 24,
      headerWeight: 'medium',
      header: '',
      footer: 'TERIMA KASIH\nSudah berbelanja di NUSA STORE\nSimpan struk ini sebagai bukti transaksi',
      logoWidthPercent: 60,
      logoAlign: 'center',
      showLogo: true,
      showCashier: true,
      showInvoice: true,
      showDate: true,
    );
  }
}
