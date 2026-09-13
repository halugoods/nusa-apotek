import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/image_saver_util.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_product_image.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Jenis elemen bawaan pada kanvas promosi.
enum PromoElement {
  none,
  storeHeader,
  promoBadge,
  productImage,
  productTitle,
  priceBadge,
  strikethroughPrice,
  callToAction,
  couponCard,
  customElement,
}

/// Pilihan rasio kanvas promosi.
enum CanvasRatio {
  square1_1, // 1:1 Persegi (Feed IG / WhatsApp)
  story9_16, // 9:16 Story / Status / Reels / TikTok
  landscape16_9, // 16:9 Banner Web / YouTube / Landscape
  portrait4_5, // 4:5 Potret Feed IG
  standard4_3, // 4:3 Standar Katalog / Tablet
  banner3_1, // 3:1 Header Banner / Spanduk
  banner2_1, // 2:1 Banner E-Commerce / Shopee
}

extension CanvasRatioExt on CanvasRatio {
  double get aspectRatio {
    switch (this) {
      case CanvasRatio.square1_1:
        return 1.0;
      case CanvasRatio.story9_16:
        return 9.0 / 16.0;
      case CanvasRatio.landscape16_9:
        return 16.0 / 9.0;
      case CanvasRatio.portrait4_5:
        return 4.0 / 5.0;
      case CanvasRatio.standard4_3:
        return 4.0 / 3.0;
      case CanvasRatio.banner3_1:
        return 3.0 / 1.0;
      case CanvasRatio.banner2_1:
        return 2.0 / 1.0;
    }
  }

  String get label {
    switch (this) {
      case CanvasRatio.square1_1:
        return '1:1 Persegi (Feed IG / WA)';
      case CanvasRatio.story9_16:
        return '9:16 Story (Status / Reels)';
      case CanvasRatio.landscape16_9:
        return '16:9 Wide (Banner Web)';
      case CanvasRatio.portrait4_5:
        return '4:5 Potret (Feed IG)';
      case CanvasRatio.standard4_3:
        return '4:3 Katalog Standar';
      case CanvasRatio.banner3_1:
        return '3:1 Spanduk Banner';
      case CanvasRatio.banner2_1:
        return '2:1 Banner E-Commerce';
    }
  }

  String get shortLabel {
    switch (this) {
      case CanvasRatio.square1_1:
        return '1:1 Feed';
      case CanvasRatio.story9_16:
        return '9:16 Story';
      case CanvasRatio.landscape16_9:
        return '16:9 Wide';
      case CanvasRatio.portrait4_5:
        return '4:5 Potret';
      case CanvasRatio.standard4_3:
        return '4:3 Standar';
      case CanvasRatio.banner3_1:
        return '3:1 Spanduk';
      case CanvasRatio.banner2_1:
        return '2:1 Banner';
    }
  }

  IconData get icon {
    switch (this) {
      case CanvasRatio.square1_1:
        return Icons.crop_square_rounded;
      case CanvasRatio.story9_16:
        return Icons.stay_current_portrait_rounded;
      case CanvasRatio.landscape16_9:
        return Icons.stay_current_landscape_rounded;
      case CanvasRatio.portrait4_5:
        return Icons.portrait_rounded;
      case CanvasRatio.standard4_3:
        return Icons.aspect_ratio_rounded;
      case CanvasRatio.banner3_1:
      case CanvasRatio.banner2_1:
        return Icons.view_headline_rounded;
    }
  }
}

/// Tipe template konten desain.
enum DesignContentType {
  productPromo, // Produk pilihan & harga diskon
  couponVoucher, // Kupon voucher potongan harga
  flashSale, // Diskon heboh / flash sale
  buy1Get1, // Beli 1 gratis 1 / paket bundling
  storeNotice, // Pengumuman toko / event spesial
}

/// Model elemen kustom tambahan pada kanvas.
enum CustomElementType { text, badge, sticker, image }

class CustomCanvasElement {
  final String id;
  CustomElementType type;
  String text;
  Offset offset;
  double size;
  Color color;
  Color? bgColor;
  String? imagePath;
  Uint8List? imageBytes;
  double rotation;

  CustomCanvasElement({
    required this.id,
    required this.type,
    this.text = '',
    this.offset = Offset.zero,
    this.size = 14.0,
    this.color = Colors.black87,
    this.bgColor,
    this.imagePath,
    this.imageBytes,
    this.rotation = 0.0,
  });
}

/// Preset tema visual desain promosi.
class DesignTheme {
  final String id;
  final String name;
  final List<Color> bgGradient;
  final Color primaryAccent;
  final Color textColor;
  final Color secondaryTextColor;
  final Color cardBg;

  const DesignTheme({
    required this.id,
    required this.name,
    required this.bgGradient,
    required this.primaryAccent,
    required this.textColor,
    required this.secondaryTextColor,
    required this.cardBg,
  });
}

const List<DesignTheme> kPromoThemes = [
  DesignTheme(
    id: 'clean_blue',
    name: 'Modern Clean',
    bgGradient: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
    primaryAccent: Color(0xFF2563EB),
    textColor: Color(0xFF0F172A),
    secondaryTextColor: Color(0xFF475569),
    cardBg: Colors.white,
  ),
  DesignTheme(
    id: 'fire_orange',
    name: 'Diskon Heboh',
    bgGradient: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
    primaryAccent: Color(0xFFEA580C),
    textColor: Color(0xFF431407),
    secondaryTextColor: Color(0xFF7C2D12),
    cardBg: Colors.white,
  ),
  DesignTheme(
    id: 'dark_gold',
    name: 'Dark Luxury',
    bgGradient: [Color(0xFF0F172A), Color(0xFF1E293B)],
    primaryAccent: Color(0xFFF59E0B),
    textColor: Color(0xFFF8FAFC),
    secondaryTextColor: Color(0xFF94A3B8),
    cardBg: Color(0xFF1E293B),
  ),
  DesignTheme(
    id: 'warm_coffee',
    name: 'Warm Aesthetic',
    bgGradient: [Color(0xFFFEFCE8), Color(0xFFFEF08A)],
    primaryAccent: Color(0xFFB45309),
    textColor: Color(0xFF451A03),
    secondaryTextColor: Color(0xFF78350F),
    cardBg: Colors.white,
  ),
  DesignTheme(
    id: 'mint_fresh',
    name: 'Mint Fresh',
    bgGradient: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
    primaryAccent: Color(0xFF16A34A),
    textColor: Color(0xFF14532D),
    secondaryTextColor: Color(0xFF166534),
    cardBg: Colors.white,
  ),
  DesignTheme(
    id: 'cyber_purple',
    name: 'Cyber Neon',
    bgGradient: [Color(0xFF2E1065), Color(0xFF0F172A)],
    primaryAccent: Color(0xFFA855F7),
    textColor: Colors.white,
    secondaryTextColor: Color(0xFFCBD5E1),
    cardBg: Color(0xFF3B0764),
  ),
  DesignTheme(
    id: 'bold_red',
    name: 'Super Sale',
    bgGradient: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
    primaryAccent: Color(0xFFDC2626),
    textColor: Color(0xFF450A0A),
    secondaryTextColor: Color(0xFF991B1B),
    cardBg: Colors.white,
  ),
];

/// Studio Desain (Canva Mini untuk UMKM).
/// Berjalan mandiri dan offline di NUSA Pro maupun NUSA Lite.
class PromoDesignStudioScreen extends ConsumerStatefulWidget {
  const PromoDesignStudioScreen({super.key});

  @override
  ConsumerState<PromoDesignStudioScreen> createState() =>
      _PromoDesignStudioScreenState();
}

class _PromoDesignStudioScreenState
    extends ConsumerState<PromoDesignStudioScreen> {
  final GlobalKey _canvasKey = GlobalKey();

  // Mode Konten & Aspek Rasio
  DesignContentType _contentType = DesignContentType.productPromo;
  CanvasRatio _ratio = CanvasRatio.square1_1;
  DesignTheme _activeTheme = kPromoThemes[0];
  String _fontFamily = 'Poppins';
  bool _loading = false;
  bool _isExporting = false;

  // Custom Background Gambar dari Galeri
  Uint8List? _customBgImageBytes;
  double _bgScale = 1.0;
  double _bgRotation = 0.0;
  Offset _bgOffset = Offset.zero;
  double _bgBaseScale = 1.0;
  double _bgBaseRotation = 0.0;
  Offset _bgBaseOffset = Offset.zero;

  // Selected product & Data Toko
  Product? _selectedProduct;
  List<Product> _allProducts = [];
  String? _customProductImagePath;
  Uint8List? _customProductImageBytes;

  // Konten Elemen
  String _storeName = 'Nusa Kasir';
  String _promoTag = 'PROMO SPESIAL';
  String _productTitle = 'Nama Produk Pilihan';
  String _ctaText = 'Pesan Sekarang • Hubungi Kasir';

  // Harga & Harga Coret
  bool _showStrikethrough = true;
  double _sellPrice = 25000;
  double _originalPrice = 35000;
  double _priceFontSize = 22.0;
  double _strikethroughFontSize = 13.0;

  // Kupon Voucher Data
  String _couponCode = 'DISKON20K';
  String _couponDiscount = 'POTONGAN Rp 20.000';
  String _couponValidUntil = 'Berlaku s/d 30 September 2026';
  String _couponTerms = 'Min. Pembelian Rp 50.000 • Semua Produk';

  // Flash Sale / Event Headline
  String _eventHeadline = 'FLASH SALE HARI INI';
  String _eventSubHeadline = 'Diskon Terbesar Hingga 70%';

  // Pengaturan Visibilitas Elemen Default (CRUD Hapus/Sembunyi)
  bool _showStoreHeader = true;
  bool _showPromoBadge = true;
  bool _showProductImage = true;
  bool _showProductTitle = true;
  bool _showPriceBadge = true;
  bool _showCallToAction = true;
  bool _showCouponCard = true;

  // Pengaturan Ukuran Elemen Default
  double _storeHeaderFontSize = 11.0;
  double _promoBadgeFontSize = 11.0;
  double _productImageSize = 130.0;
  double _titleFontSize = 18.0;
  double _ctaFontSize = 10.0;
  bool _imageCircular = false;

  // Interactive Touch Offsets
  PromoElement _activeElement = PromoElement.none;
  Offset _storeHeaderOffset = Offset.zero;
  Offset _promoBadgeOffset = Offset.zero;
  Offset _productImageOffset = Offset.zero;
  Offset _productTitleOffset = Offset.zero;
  Offset _priceBadgeOffset = Offset.zero;
  Offset _callToActionOffset = Offset.zero;
  Offset _couponCardOffset = Offset.zero;

  // Daftar Elemen Kustom Tambahan (CRUD Tambah/Hapus/Resize)
  final List<CustomCanvasElement> _customElements = [];
  int? _selectedCustomIndex;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final db = ref.read(databaseProvider);
      final store = await SettingsRepository(db).getStoreName();
      if (store.isNotEmpty) {
        _storeName = store;
      }
      final prods = await ProductRepository(db).getProducts();
      if (mounted) {
        setState(() {
          _allProducts = prods;
          if (prods.isNotEmpty) {
            _applyProduct(prods.first);
          }
        });
      }
    } catch (_) {}
  }

  void _applyProduct(Product p) {
    _selectedProduct = p;
    _productTitle = p.name;
    _sellPrice = p.sellPrice.toDouble();
    if (p.discountPercent > 0) {
      _originalPrice =
          (p.sellPrice / (1 - (p.discountPercent / 100))).roundToDouble();
      _showStrikethrough = true;
    } else {
      _originalPrice = (_sellPrice * 1.25).roundToDouble();
      _showStrikethrough = true;
    }
    _customProductImagePath = null;
    _customProductImageBytes = null;
  }

  void _resetOffsets() {
    setState(() {
      _storeHeaderOffset = Offset.zero;
      _promoBadgeOffset = Offset.zero;
      _productImageOffset = Offset.zero;
      _productTitleOffset = Offset.zero;
      _priceBadgeOffset = Offset.zero;
      _callToActionOffset = Offset.zero;
      _couponCardOffset = Offset.zero;
    });
  }

  void _resetBackgroundGesture() {
    setState(() {
      _bgScale = 1.0;
      _bgRotation = 0.0;
      _bgOffset = Offset.zero;
    });
  }

  TextStyle _getFontStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
    switch (_fontFamily) {
      case 'Roboto':
        return GoogleFonts.roboto(textStyle: style);
      case 'Inter':
        return GoogleFonts.inter(textStyle: style);
      case 'Courier':
        return GoogleFonts.sourceCodePro(textStyle: style);
      default:
        return GoogleFonts.poppins(textStyle: style);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? NusaConfig.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Studio Desain',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
        foregroundColor:
            isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Tambah Elemen',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showAddElementSheet(isDark),
          ),
          IconButton(
            tooltip: 'Ganti Template / Konten',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => _showTemplateSelector(isDark),
          ),
          IconButton(
            tooltip: 'Bagikan',
            icon: const Icon(Icons.share_outlined),
            onPressed: _loading ? null : () => _exportImage(isShare: true),
          ),
          IconButton(
            tooltip: 'Simpan ke Galeri',
            icon: const Icon(Icons.download_rounded),
            onPressed: _loading ? null : () => _exportImage(isShare: false),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar: Rasio Kanvas Accordion/Dropdown + Font & Background Pickers
            _buildTopControls(isDark),

            // Middle: Kanvas Interaktif
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: _buildCanvas(isDark),
                ),
              ),
            ),

            // Bottom: Inspector Properti Elemen Aktif & CRUD
            _buildInspectorPanel(isDark),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP CONTROLS: RATIO, THEME, FONT, BG
  // ─────────────────────────────────────────────────────────────

  Widget _buildTopControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? NusaConfig.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Dropdown / Picker Rasio Kanvas Lengkap
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _showRatioPicker(isDark),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? NusaConfig.darkSurface2
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : const Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_ratio.icon,
                            size: 16, color: NusaConfig.activePrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _ratio.shortLabel,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Font Picker
              Expanded(
                flex: 2,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkSurface2
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? NusaConfig.darkBorder
                          : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _fontFamily,
                      isDense: true,
                      dropdownColor:
                          isDark ? NusaConfig.darkSurface : Colors.white,
                      items: ['Poppins', 'Roboto', 'Inter', 'Courier'].map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : NusaConfig.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _fontFamily = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Custom Background Galeri
              IconButton(
                tooltip: 'Custom Background Galeri',
                style: IconButton.styleFrom(
                  backgroundColor: _customBgImageBytes != null
                      ? NusaConfig.activePrimary.withValues(alpha: 0.15)
                      : (isDark
                          ? NusaConfig.darkSurface2
                          : const Color(0xFFF1F5F9)),
                ),
                icon: Icon(
                  Icons.wallpaper_rounded,
                  size: 18,
                  color: _customBgImageBytes != null
                      ? NusaConfig.activePrimary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                onPressed: () => _pickCustomBackground(isDark),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Presets Tema Warna Horizontal
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kPromoThemes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final t = kPromoThemes[idx];
                final isSelected = t.id == _activeTheme.id;
                return ChoiceChip(
                  label: Text(t.name),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _activeTheme = t),
                  selectedColor: t.primaryAccent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? t.primaryAccent
                        : (isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRatioPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pilih Aspek Rasio Kanvas',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: CanvasRatio.values.map((r) {
                      final isSel = r == _ratio;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? NusaConfig.activePrimary
                                    .withValues(alpha: 0.15)
                                : (isDark
                                    ? NusaConfig.darkSurface2
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(r.icon,
                              color: isSel
                                  ? NusaConfig.activePrimary
                                  : (isDark ? Colors.white70 : Colors.black87),
                              size: 18),
                        ),
                        title: Text(r.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? NusaConfig.activePrimary : null,
                            )),
                        trailing: isSel
                            ? Icon(Icons.check_circle_rounded,
                                color: NusaConfig.activePrimary, size: 20)
                            : null,
                        onTap: () {
                          setState(() {
                            _ratio = r;
                            _resetOffsets();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INTERACTIVE CANVAS (WITH 2-FINGER GESTURE BACKGROUND)
  // ─────────────────────────────────────────────────────────────

  Widget _buildCanvas(bool isDark) {
    final mq = MediaQuery.of(context);
    final maxWidth = math.min(mq.size.width - 32, 380.0);
    final aspectRatio = _ratio.aspectRatio;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RepaintBoundary(
        key: _canvasKey,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              gradient: _customBgImageBytes == null
                  ? LinearGradient(
                      colors: _activeTheme.bgGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _customBgImageBytes != null ? Colors.black : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Custom Background Layer dengan 2-Finger Zoom, Rotate 360°, & Pan
                  if (_customBgImageBytes != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (details) {
                          _bgBaseScale = _bgScale;
                          _bgBaseRotation = _bgRotation;
                          _bgBaseOffset = _bgOffset;
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            _bgScale =
                                (_bgBaseScale * details.scale).clamp(0.2, 8.0);
                            _bgRotation = _bgBaseRotation + details.rotation;
                            _bgOffset = _bgBaseOffset + details.focalPointDelta;
                          });
                        },
                        child: Transform(
                          transform: Matrix4.identity()
                            ..translate(_bgOffset.dx, _bgOffset.dy)
                            ..rotateZ(_bgRotation)
                            ..scale(_bgScale),
                          alignment: Alignment.center,
                          child: Image.memory(
                            _customBgImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                  // Overlay gradient gelap tipis jika background kustom aktif agar teks terbaca
                  if (_customBgImageBytes != null)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),

                  // Decorative Corner Accent jika background default
                  if (_customBgImageBytes == null)
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _activeTheme.primaryAccent
                              .withValues(alpha: 0.12),
                        ),
                      ),
                    ),

                  // 2. Konten Utama Template
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: _buildTemplateContent(isDark),
                  ),

                  // 3. Elemen Kustom Tambahan (CRUD)
                  for (int i = 0; i < _customElements.length; i++)
                    _buildCustomElementWidget(_customElements[i], i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateContent(bool isDark) {
    switch (_contentType) {
      case DesignContentType.couponVoucher:
        return _buildCouponVoucherLayout(isDark);
      case DesignContentType.flashSale:
        return _buildFlashSaleLayout(isDark);
      case DesignContentType.buy1Get1:
        return _buildBuy1Get1Layout(isDark);
      case DesignContentType.storeNotice:
        return _buildStoreNoticeLayout(isDark);
      case DesignContentType.productPromo:
        return _buildProductPromoLayout(isDark);
    }
  }

  // Layout Template 1: Produk Pilihan & Diskon
  Widget _buildProductPromoLayout(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top: Store Header & Tagline
        Column(
          children: [
            if (_showStoreHeader)
              _wrapInteractive(
                element: PromoElement.storeHeader,
                offset: _storeHeaderOffset,
                onPan: (d) => setState(() => _storeHeaderOffset += d),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 14,
                      color: _activeTheme.primaryAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _storeName.toUpperCase(),
                      style: _getFontStyle(
                        fontSize: _storeHeaderFontSize,
                        fontWeight: FontWeight.w700,
                        color: _customBgImageBytes != null
                            ? Colors.white
                            : _activeTheme.secondaryTextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            // Promo Badge
            if (_showPromoBadge)
              _wrapInteractive(
                element: PromoElement.promoBadge,
                offset: _promoBadgeOffset,
                onPan: (d) => setState(() => _promoBadgeOffset += d),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeTheme.primaryAccent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            _activeTheme.primaryAccent.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _promoTag,
                    style: _getFontStyle(
                      fontSize: _promoBadgeFontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Middle: Foto Produk Utama (Dukung NusaProductImage, R2 Cloud, dan Custom Upload)
        if (_showProductImage)
          _wrapInteractive(
            element: PromoElement.productImage,
            offset: _productImageOffset,
            onPan: (d) => setState(() => _productImageOffset += d),
            child: Container(
              width: _productImageSize,
              height: _productImageSize,
              decoration: BoxDecoration(
                shape: _imageCircular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: _imageCircular ? null : BorderRadius.circular(16),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_imageCircular ? 100 : 16),
                child: _buildProductImageWidget(),
              ),
            ),
          ),

        // Bottom: Detail Produk, Harga Coret & CTA
        Column(
          children: [
            // Judul Produk
            if (_showProductTitle)
              _wrapInteractive(
                element: PromoElement.productTitle,
                offset: _productTitleOffset,
                onPan: (d) => setState(() => _productTitleOffset += d),
                child: Text(
                  _productTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _getFontStyle(
                    fontSize: _titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: _customBgImageBytes != null
                        ? Colors.white
                        : _activeTheme.textColor,
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // Harga Promo & Harga Coret
            if (_showPriceBadge)
              _wrapInteractive(
                element: PromoElement.priceBadge,
                offset: _priceBadgeOffset,
                onPan: (d) => setState(() => _priceBadgeOffset += d),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _currencyFormat.format(_sellPrice),
                      style: _getFontStyle(
                        fontSize: _priceFontSize,
                        fontWeight: FontWeight.w900,
                        color: _activeTheme.primaryAccent,
                      ),
                    ),
                    if (_showStrikethrough && _originalPrice > _sellPrice) ...[
                      const SizedBox(width: 8),
                      Text(
                        _currencyFormat.format(_originalPrice),
                        style: _getFontStyle(
                          fontSize: _strikethroughFontSize,
                          fontWeight: FontWeight.w600,
                          color: _customBgImageBytes != null
                              ? Colors.white70
                              : _activeTheme.secondaryTextColor,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Call to Action
            if (_showCallToAction)
              _wrapInteractive(
                element: PromoElement.callToAction,
                offset: _callToActionOffset,
                onPan: (d) => setState(() => _callToActionOffset += d),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _activeTheme.cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _activeTheme.primaryAccent.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _ctaText,
                    textAlign: TextAlign.center,
                    style: _getFontStyle(
                      fontSize: _ctaFontSize,
                      fontWeight: FontWeight.w600,
                      color: _activeTheme.textColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Layout Template 2: Kupon Voucher Diskon
  Widget _buildCouponVoucherLayout(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Store Header
        if (_showStoreHeader)
          _wrapInteractive(
            element: PromoElement.storeHeader,
            offset: _storeHeaderOffset,
            onPan: (d) => setState(() => _storeHeaderOffset += d),
            child: Text(
              _storeName.toUpperCase(),
              style: _getFontStyle(
                fontSize: _storeHeaderFontSize,
                fontWeight: FontWeight.w800,
                color: _customBgImageBytes != null
                    ? Colors.white
                    : _activeTheme.textColor,
                letterSpacing: 1.5,
              ),
            ),
          ),

        // Voucher Ticket Card
        if (_showCouponCard)
          _wrapInteractive(
            element: PromoElement.couponCard,
            offset: _couponCardOffset,
            onPan: (d) => setState(() => _couponCardOffset += d),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _activeTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _activeTheme.primaryAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _activeTheme.primaryAccent.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _activeTheme.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'VOUCHER DISKON SPESIAL',
                      style: _getFontStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _activeTheme.primaryAccent,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _couponDiscount,
                    textAlign: TextAlign.center,
                    style: _getFontStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _activeTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _couponCode,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _couponValidUntil,
                    style: _getFontStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: _activeTheme.secondaryTextColor,
                    ),
                  ),
                  Text(
                    _couponTerms,
                    textAlign: TextAlign.center,
                    style: _getFontStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: _activeTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // CTA
        if (_showCallToAction)
          _wrapInteractive(
            element: PromoElement.callToAction,
            offset: _callToActionOffset,
            onPan: (d) => setState(() => _callToActionOffset += d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _activeTheme.primaryAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Gunakan di Kasir Sekarang',
                style: _getFontStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Layout Template 3: Flash Sale / Diskon Kilat
  Widget _buildFlashSaleLayout(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            Text(
              _storeName.toUpperCase(),
              style: _getFontStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _customBgImageBytes != null
                    ? Colors.white70
                    : _activeTheme.secondaryTextColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _eventHeadline,
                    style: _getFontStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Middle Giant Discount Tag
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _activeTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DISKON HINGGA',
                style: _getFontStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _activeTheme.secondaryTextColor,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '70%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                  height: 1.0,
                ),
              ),
              Text(
                _eventSubHeadline,
                textAlign: TextAlign.center,
                style: _getFontStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _activeTheme.textColor,
                ),
              ),
            ],
          ),
        ),

        // CTA
        Text(
          '⏰ Periode Terbatas • Serbu Sekarang!',
          style: _getFontStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _customBgImageBytes != null
                ? Colors.white
                : _activeTheme.textColor,
          ),
        ),
      ],
    );
  }

  // Layout Template 4: Buy 1 Get 1
  Widget _buildBuy1Get1Layout(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _storeName.toUpperCase(),
          style: _getFontStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _customBgImageBytes != null
                ? Colors.white70
                : _activeTheme.secondaryTextColor,
            letterSpacing: 1.2,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _activeTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BELI 1 GRATIS 1',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _activeTheme.primaryAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Beli varian apapun, dapatkan gratis 1 produk pilihan!',
                textAlign: TextAlign.center,
                style: _getFontStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: _activeTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Syarat & ketentuan berlaku di outlet',
          style: _getFontStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: _customBgImageBytes != null
                ? Colors.white70
                : _activeTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  // Layout Template 5: Pengumuman Toko
  Widget _buildStoreNoticeLayout(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _storeName.toUpperCase(),
          style: _getFontStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _customBgImageBytes != null
                ? Colors.white
                : _activeTheme.textColor,
            letterSpacing: 1.5,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _activeTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _activeTheme.primaryAccent.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(Icons.campaign_rounded,
                  size: 36, color: _activeTheme.primaryAccent),
              const SizedBox(height: 6),
              Text(
                'PENGUMUMAN TOKO',
                style: _getFontStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _activeTheme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kami siap melayani kebutuhan Anda setiap hari dengan kualitas terbaik dan harga terjangkau.',
                textAlign: TextAlign.center,
                style: _getFontStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _activeTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Buka Setiap Hari: 08:00 - 21:00',
          style: _getFontStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: _customBgImageBytes != null
                ? Colors.white
                : _activeTheme.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProductImageWidget() {
    // 1. Jika ada custom image dari galeri
    if (_customProductImageBytes != null) {
      return Image.memory(
        _customProductImageBytes!,
        width: _productImageSize,
        height: _productImageSize,
        fit: BoxFit.cover,
      );
    }
    if (_customProductImagePath != null &&
        File(_customProductImagePath!).existsSync()) {
      return Image.file(
        File(_customProductImagePath!),
        width: _productImageSize,
        height: _productImageSize,
        fit: BoxFit.cover,
      );
    }

    final prod = _selectedProduct;
    return NusaProductImage(
      imagePath: prod?.imagePath,
      imageBase64: prod?.imageBase64,
      productId: prod?.id,
      width: _productImageSize,
      height: _productImageSize,
      fit: BoxFit.cover,
      tintColor: _activeTheme.primaryAccent,
      placeholder: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: _productImageSize * 0.45,
          color: _activeTheme.primaryAccent,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INTERACTIVE ELEMENT WRAPPER (NO BLUE BORDER ON EXPORT)
  // ─────────────────────────────────────────────────────────────

  Widget _wrapInteractive({
    required PromoElement element,
    required Offset offset,
    required ValueChanged<Offset> onPan,
    required Widget child,
  }) {
    // Saat proses ekspor / simpan gambar, sembunyikan semua border seleksi!
    final isSelected = !_isExporting && _activeElement == element;

    return Transform.translate(
      offset: offset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeElement = isSelected ? PromoElement.none : element;
            _selectedCustomIndex = null;
          });
        },
        onPanUpdate: (d) => onPan(d.delta),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                )
              : null,
          padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }

  Widget _buildCustomElementWidget(CustomCanvasElement el, int index) {
    final isSelected =
        !_isExporting && _selectedCustomIndex == index && _activeElement == PromoElement.customElement;

    return Positioned(
      left: 20 + el.offset.dx,
      top: 40 + el.offset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeElement = PromoElement.customElement;
            _selectedCustomIndex = index;
          });
        },
        onPanUpdate: (d) {
          setState(() {
            el.offset += d.delta;
          });
        },
        child: Transform.rotate(
          angle: el.rotation,
          child: Container(
            decoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                  )
                : null,
            padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
            child: _renderCustomElementInner(el),
          ),
        ),
      ),
    );
  }

  Widget _renderCustomElementInner(CustomCanvasElement el) {
    switch (el.type) {
      case CustomElementType.text:
        return Text(
          el.text,
          style: _getFontStyle(
            fontSize: el.size,
            fontWeight: FontWeight.w700,
            color: el.color,
          ),
        );
      case CustomElementType.badge:
      case CustomElementType.sticker:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: el.bgColor ?? _activeTheme.primaryAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            el.text,
            style: _getFontStyle(
              fontSize: el.size,
              fontWeight: FontWeight.w800,
              color: el.color,
            ),
          ),
        );
      case CustomElementType.image:
        if (el.imageBytes != null) {
          return Image.memory(el.imageBytes!, width: el.size, height: el.size);
        }
        return Icon(Icons.star_rounded, size: el.size, color: el.color);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM INSPECTOR PANEL (CRUD, RESIZE, DELETE, EDIT TEXT)
  // ─────────────────────────────────────────────────────────────

  Widget _buildInspectorPanel(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? NusaConfig.darkBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getInspectorLabel(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
              ),
              Row(
                children: [
                  if (_activeElement != PromoElement.none) ...[
                    // Tombol Hapus Elemen Aktif (CRUD)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Hapus',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: _deleteActiveElement,
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _resetOffsets,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Reset Posisi',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildActiveControls(isDark),
        ],
      ),
    );
  }

  String _getInspectorLabel() {
    switch (_activeElement) {
      case PromoElement.storeHeader:
        return 'Edit: Nama Toko';
      case PromoElement.promoBadge:
        return 'Edit: Badge Promo';
      case PromoElement.productImage:
        return 'Edit: Foto Produk';
      case PromoElement.productTitle:
        return 'Edit: Judul Produk';
      case PromoElement.priceBadge:
      case PromoElement.strikethroughPrice:
        return 'Edit: Harga & Harga Coret';
      case PromoElement.callToAction:
        return 'Edit: Tombol CTA';
      case PromoElement.couponCard:
        return 'Edit: Kupon Voucher';
      case PromoElement.customElement:
        return 'Edit: Elemen Kustom';
      case PromoElement.none:
        return 'Sentuh elemen kanvas untuk mengatur ukuran / menghapus';
    }
  }

  Widget _buildActiveControls(bool isDark) {
    if (_activeElement == PromoElement.none) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: const Text('Pilih Produk', style: TextStyle(fontSize: 11)),
              onPressed: _showProductPicker,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Elemen', style: TextStyle(fontSize: 11)),
              onPressed: () => _showAddElementSheet(isDark),
            ),
          ),
        ],
      );
    }

    switch (_activeElement) {
      case PromoElement.storeHeader:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _storeName)
                      ..selection =
                          TextSelection.collapsed(offset: _storeName.length),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Nama toko...',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      if (v.isNotEmpty) setState(() => _storeName = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Ukuran Font:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _storeHeaderFontSize,
                    min: 8,
                    max: 24,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => _storeHeaderFontSize = v),
                  ),
                ),
                Text('${_storeHeaderFontSize.round()}pt',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        );

      case PromoElement.productImage:
        return Column(
          children: [
            Row(
              children: [
                const Text('Ukuran Foto:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _productImageSize,
                    min: 60,
                    max: 260,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => _productImageSize = v),
                  ),
                ),
                Text('${_productImageSize.round()}px',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.image_search_rounded, size: 16),
                  label: const Text('Ganti Foto Galeri', style: TextStyle(fontSize: 11)),
                  onPressed: _pickCustomProductPhoto,
                ),
                IconButton(
                  tooltip: 'Bentuk Lingkaran / Kotak',
                  icon: Icon(
                    _imageCircular
                        ? Icons.circle_outlined
                        : Icons.crop_square_rounded,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _imageCircular = !_imageCircular),
                ),
              ],
            ),
          ],
        );

      case PromoElement.productTitle:
        return Column(
          children: [
            TextField(
              controller: TextEditingController(text: _productTitle)
                ..selection =
                    TextSelection.collapsed(offset: _productTitle.length),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Judul produk...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.isNotEmpty) setState(() => _productTitle = v);
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Ukuran Font:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _titleFontSize,
                    min: 12,
                    max: 32,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => _titleFontSize = v),
                  ),
                ),
                Text('${_titleFontSize.round()}pt',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        );

      case PromoElement.priceBadge:
      case PromoElement.strikethroughPrice:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: _sellPrice.round().toString()),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Harga Promo',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      final val = double.tryParse(v);
                      if (val != null) setState(() => _sellPrice = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: _originalPrice.round().toString()),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Harga Coret',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      final val = double.tryParse(v);
                      if (val != null) setState(() => _originalPrice = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Font Promo:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _priceFontSize,
                    min: 14,
                    max: 36,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => _priceFontSize = v),
                  ),
                ),
                Text('${_priceFontSize.round()}pt',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _showStrikethrough,
                  onChanged: (v) =>
                      setState(() => _showStrikethrough = v ?? true),
                ),
                const Text('Tampilkan Coret', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _strikethroughFontSize,
                    min: 10,
                    max: 24,
                    activeColor: Colors.grey,
                    onChanged: (v) =>
                        setState(() => _strikethroughFontSize = v),
                  ),
                ),
              ],
            ),
          ],
        );

      case PromoElement.promoBadge:
        return Column(
          children: [
            TextField(
              controller: TextEditingController(text: _promoTag)
                ..selection =
                    TextSelection.collapsed(offset: _promoTag.length),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Teks badge...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.isNotEmpty) setState(() => _promoTag = v.toUpperCase());
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Ukuran Font:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _promoBadgeFontSize,
                    min: 8,
                    max: 22,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => _promoBadgeFontSize = v),
                  ),
                ),
                Text('${_promoBadgeFontSize.round()}pt',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        );

      case PromoElement.callToAction:
        return Column(
          children: [
            TextField(
              controller: TextEditingController(text: _ctaText)
                ..selection =
                    TextSelection.collapsed(offset: _ctaText.length),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Teks ajakan...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.isNotEmpty) setState(() => _ctaText = v);
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Ukuran Font:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _ctaFontSize,
                    min: 8,
                    max: 20,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => _ctaFontSize = v),
                  ),
                ),
                Text('${_ctaFontSize.round()}pt',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        );

      case PromoElement.customElement:
        if (_selectedCustomIndex == null ||
            _selectedCustomIndex! >= _customElements.length) {
          return const SizedBox.shrink();
        }
        final el = _customElements[_selectedCustomIndex!];
        return Column(
          children: [
            if (el.type == CustomElementType.text ||
                el.type == CustomElementType.badge ||
                el.type == CustomElementType.sticker)
              TextField(
                controller: TextEditingController(text: el.text)
                  ..selection =
                      TextSelection.collapsed(offset: el.text.length),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Teks elemen...',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => setState(() => el.text = v),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Ukuran:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: el.size,
                    min: 10,
                    max: 120,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: (v) => setState(() => el.size = v),
                  ),
                ),
                Text('${el.size.round()}',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        );

      case PromoElement.couponCard:
        return Column(
          children: [
            TextField(
              controller: TextEditingController(text: _couponDiscount),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Nominal Potongan',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => setState(() => _couponDiscount = v),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: _couponCode),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Kode Voucher',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => setState(() => _couponCode = v),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _deleteActiveElement() {
    setState(() {
      if (_activeElement == PromoElement.customElement &&
          _selectedCustomIndex != null) {
        _customElements.removeAt(_selectedCustomIndex!);
        _selectedCustomIndex = null;
        _activeElement = PromoElement.none;
        TopToast.success(context, 'Elemen kustom dihapus');
      } else {
        // Hide default elements
        switch (_activeElement) {
          case PromoElement.storeHeader:
            _showStoreHeader = false;
            break;
          case PromoElement.promoBadge:
            _showPromoBadge = false;
            break;
          case PromoElement.productImage:
            _showProductImage = false;
            break;
          case PromoElement.productTitle:
            _showProductTitle = false;
            break;
          case PromoElement.priceBadge:
            _showPriceBadge = false;
            break;
          case PromoElement.callToAction:
            _showCallToAction = false;
            break;
          case PromoElement.couponCard:
            _showCouponCard = false;
            break;
          default:
            break;
        }
        _activeElement = PromoElement.none;
        TopToast.success(context, 'Elemen berhasil disembunyikan');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // CRUD TAMBAH ELEMEN BARU (BOTTOM SHEET)
  // ─────────────────────────────────────────────────────────────

  void _showAddElementSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tambah Elemen ke Kanvas',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.title_rounded, color: Colors.blueAccent),
                  title: const Text('Tambah Teks Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Teks promosi, tagline, atau keterangan tambahan', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addNewTextElement();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_offer_rounded, color: Colors.orange),
                  title: const Text('Tambah Stiker / Badge Promo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Flash Sale, Best Seller, Gratis Ongkir, Halal, dll.', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addNewBadgeElement();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_rounded, color: Colors.green),
                  title: const Text('Tambah Gambar / Logo dari Galeri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Logo toko, ikon produk, atau foto tambahan', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addNewImageElement();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.visibility_rounded, color: Colors.teal),
                  title: const Text('Tampilkan Kembali Semua Elemen Bawaan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showStoreHeader = true;
                      _showPromoBadge = true;
                      _showProductImage = true;
                      _showProductTitle = true;
                      _showPriceBadge = true;
                      _showCallToAction = true;
                      _showCouponCard = true;
                    });
                    TopToast.success(context, 'Semua elemen bawaan ditampilkan kembali');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addNewTextElement() {
    setState(() {
      _customElements.add(
        CustomCanvasElement(
          id: 'text_${DateTime.now().millisecondsSinceEpoch}',
          type: CustomElementType.text,
          text: 'Teks Baru Tambahan',
          size: 14.0,
          color: _activeTheme.textColor,
          offset: Offset(math.Random().nextDouble() * 40, math.Random().nextDouble() * 60),
        ),
      );
      _activeElement = PromoElement.customElement;
      _selectedCustomIndex = _customElements.length - 1;
    });
    TopToast.success(context, 'Teks kustom ditambahkan');
  }

  void _addNewBadgeElement() {
    setState(() {
      _customElements.add(
        CustomCanvasElement(
          id: 'badge_${DateTime.now().millisecondsSinceEpoch}',
          type: CustomElementType.badge,
          text: '★ BEST SELLER',
          size: 11.0,
          color: Colors.white,
          bgColor: _activeTheme.primaryAccent,
          offset: Offset(math.Random().nextDouble() * 40, math.Random().nextDouble() * 60),
        ),
      );
      _activeElement = PromoElement.customElement;
      _selectedCustomIndex = _customElements.length - 1;
    });
    TopToast.success(context, 'Badge promo ditambahkan');
  }

  Future<void> _addNewImageElement() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image);
      if (res != null && res.files.single.path != null) {
        final path = res.files.single.path!;
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        setState(() {
          _customElements.add(
            CustomCanvasElement(
              id: 'img_${DateTime.now().millisecondsSinceEpoch}',
              type: CustomElementType.image,
              size: 60.0,
              imagePath: path,
              imageBytes: bytes,
              offset: const Offset(20, 20),
            ),
          );
          _activeElement = PromoElement.customElement;
          _selectedCustomIndex = _customElements.length - 1;
        });
        TopToast.success(context, 'Gambar kustom ditambahkan');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal memilih gambar: $e');
    }
  }

  Future<void> _pickCustomProductPhoto() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image);
      if (res != null && res.files.single.path != null) {
        final path = res.files.single.path!;
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        setState(() {
          _customProductImagePath = path;
          _customProductImageBytes = bytes;
        });
        TopToast.success(context, 'Foto produk diperbarui dari galeri');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal mengambil gambar: $e');
    }
  }

  Future<void> _pickCustomBackground(bool isDark) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_rounded,
                      color: Colors.blueAccent),
                  title: const Text('Pilih Foto Background dari Galeri',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Bisa di-zoom & rotate 360° pakai 2 jari langsung di kanvas'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final res = await FilePicker.pickFiles(type: FileType.image);
                      if (res != null && res.files.single.path != null) {
                        final path = res.files.single.path!;
                        final bytes = await File(path).readAsBytes();
                        if (!mounted) return;
                        setState(() {
                          _customBgImageBytes = bytes;
                          _resetBackgroundGesture();
                        });
                        TopToast.success(context, 'Background terpasang. Gunakan 2 jari di kanvas untuk zoom & putar');
                      }
                    } catch (e) {
                      if (mounted) TopToast.error(context, 'Gagal mengambil gambar background: $e');
                    }
                  },
                ),
                if (_customBgImageBytes != null) ...[
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded, color: Colors.orange),
                    title: const Text('Reset Posisi & Rotasi Background'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _resetBackgroundGesture();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('Hapus Background Galeri (Kembali ke Warna)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _customBgImageBytes = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTemplateSelector(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Tipe Konten Desain',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.inventory_2_rounded, color: Colors.blueAccent),
                  title: const Text('Produk Pilihan & Diskon', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Menampilkan foto, harga promo & harga coret'),
                  selected: _contentType == DesignContentType.productPromo,
                  onTap: () {
                    setState(() => _contentType = DesignContentType.productPromo);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.confirmation_number_rounded, color: Colors.teal),
                  title: const Text('Kupon Voucher Diskon', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Voucher potongan harga belanja dengan kode kupon'),
                  selected: _contentType == DesignContentType.couponVoucher,
                  onTap: () {
                    setState(() => _contentType = DesignContentType.couponVoucher);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bolt_rounded, color: Colors.redAccent),
                  title: const Text('Diskon Kilat / Flash Sale', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Banner potongan persen heboh untuk event terbatas'),
                  selected: _contentType == DesignContentType.flashSale,
                  onTap: () {
                    setState(() => _contentType = DesignContentType.flashSale);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.layers_rounded, color: Colors.purple),
                  title: const Text('Beli 1 Gratis 1 (Buy 1 Get 1)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Penawaran paket hemat bundling toko'),
                  selected: _contentType == DesignContentType.buy1Get1,
                  onTap: () {
                    setState(() => _contentType = DesignContentType.buy1Get1);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.campaign_rounded, color: Colors.amber),
                  title: const Text('Pengumuman / Event Toko', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Jam buka khusus, grand opening, info libur'),
                  selected: _contentType == DesignContentType.storeNotice,
                  onTap: () {
                    setState(() => _contentType = DesignContentType.storeNotice);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pilih Produk untuk Promosi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _allProducts.isEmpty
                    ? const Center(child: Text('Belum ada produk'))
                    : ListView.separated(
                        itemCount: _allProducts.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final p = _allProducts[idx];
                          final isSel = p.id == _selectedProduct?.id;
                          return ListTile(
                            leading: SizedBox(
                              width: 42,
                              height: 42,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: NusaProductImage(
                                  imagePath: p.imagePath,
                                  imageBase64: p.imageBase64,
                                  productId: p.id,
                                  placeholder: Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.inventory_2_rounded, size: 18),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(_currencyFormat.format(p.sellPrice),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: NusaConfig.activePrimary,
                                    fontWeight: FontWeight.w700)),
                            trailing: isSel
                                ? Icon(Icons.check_circle_rounded, color: NusaConfig.activePrimary)
                                : null,
                            onTap: () {
                              setState(() {
                                _applyProduct(p);
                                _contentType = DesignContentType.productPromo;
                              });
                              Navigator.pop(ctx);
                              TopToast.success(context, 'Produk ${p.name} diterapkan ke kanvas');
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EKSPOR & SIMPAN GAMBAR KE GALERI (NO BLUE BORDER)
  // ─────────────────────────────────────────────────────────────

  Future<void> _exportImage({required bool isShare}) async {
    setState(() {
      _loading = true;
      _isExporting = true;
      _activeElement = PromoElement.none;
      _selectedCustomIndex = null;
    });

    // PENTING: Tunggu 1 frame agar kanvas selesai digambar ulang tanpa border seleksi biru
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary =
          _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Kanvas belum siap');
      }

      final image = await boundary.toImage(pixelRatio: 3.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal konversi byte gambar');
      }

      final bytes = byteData.buffer.asUint8List();

      if (!mounted) return;

      if (isShare) {
        final dir = await getTemporaryDirectory();
        final filename = 'Promo_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Promo $_productTitle - $_storeName',
          ),
        );
        if (mounted) TopToast.success(context, 'Membuka menu bagikan gambar');
      } else {
        // Simpan langsung ke Galeri publik Android (Pictures/Nusa)
        final savedPath = await ImageSaverUtil.saveImageToGallery(
          bytes,
          filename: 'Desain_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        if (mounted) TopToast.success(context, 'Gambar promosi berhasil disimpan di Galeri: $savedPath');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isExporting = false;
        });
      }
    }
  }
}
