import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_product_image.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Interactive elements on the promotional canvas.
enum PromoElement {
  none,
  storeHeader,
  promoBadge,
  productImage,
  productTitle,
  priceBadge,
  callToAction,
}

/// Canvas aspect ratio modes.
enum CanvasRatio {
  feedSquare, // 1:1 Feed
  storyPortrait, // 9:16 Story / Status
}

/// Design theme preset.
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
];

/// Studio Desain Promosi (Canva-like interactive promo builder).
/// Works offline on both NUSA Pro & NUSA Lite.
class PromoDesignStudioScreen extends ConsumerStatefulWidget {
  const PromoDesignStudioScreen({super.key});

  @override
  ConsumerState<PromoDesignStudioScreen> createState() => _PromoDesignStudioScreenState();
}

class _PromoDesignStudioScreenState extends ConsumerState<PromoDesignStudioScreen> {
  final GlobalKey _canvasKey = GlobalKey();

  // State: Canvas Settings
  CanvasRatio _ratio = CanvasRatio.feedSquare;
  DesignTheme _activeTheme = kPromoThemes[0];
  String _fontFamily = 'Poppins';
  bool _loading = false;

  // Selected product
  Product? _selectedProduct;
  List<Product> _allProducts = [];

  // Editable element content
  String _storeName = 'Nusa Kasir';
  String _promoTag = 'PROMO SPESIAL';
  String _ctaText = 'Pesan Sekarang • Hubungi Kasir';

  // Interactive Touch offsets (Canva-like dragging)
  PromoElement _activeElement = PromoElement.none;
  Offset _storeHeaderOffset = Offset.zero;
  Offset _promoBadgeOffset = Offset.zero;
  Offset _productImageOffset = Offset.zero;
  Offset _productTitleOffset = Offset.zero;
  Offset _priceBadgeOffset = Offset.zero;
  Offset _callToActionOffset = Offset.zero;

  // Element sizes & sliders
  double _productImageSize = 130.0;
  double _titleFontSize = 18.0;
  double _priceFontSize = 20.0;
  bool _imageCircular = false;

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
            _selectedProduct = prods.first;
          }
        });
      }
    } catch (_) {}
  }

  void _resetOffsets() {
    setState(() {
      _storeHeaderOffset = Offset.zero;
      _promoBadgeOffset = Offset.zero;
      _productImageOffset = Offset.zero;
      _productTitleOffset = Offset.zero;
      _priceBadgeOffset = Offset.zero;
      _callToActionOffset = Offset.zero;
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
      backgroundColor: isDark ? NusaConfig.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Studio Desain Promosi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
        foregroundColor: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Pilih Produk',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: _showProductPicker,
          ),
          IconButton(
            tooltip: 'Bagikan',
            icon: const Icon(Icons.share_outlined),
            onPressed: _loading ? null : () => _exportImage(isShare: true),
          ),
          IconButton(
            tooltip: 'Simpan Gambar',
            icon: const Icon(Icons.download_rounded),
            onPressed: _loading ? null : () => _exportImage(isShare: false),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar: Ratio switch + Theme selector
            _buildTopControls(isDark),

            // Middle: Interactive Canvas Viewport
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildCanvas(isDark),
                ),
              ),
            ),

            // Bottom: Active Element Property Inspector
            _buildInspectorPanel(isDark),
          ],
        ),
      ),
    );
  }

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
              // Ratio Selector
              Container(
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ratioButton(
                      label: '1:1 Feed',
                      selected: _ratio == CanvasRatio.feedSquare,
                      onTap: () => setState(() {
                        _ratio = CanvasRatio.feedSquare;
                        _resetOffsets();
                      }),
                      isDark: isDark,
                    ),
                    _ratioButton(
                      label: '9:16 Story',
                      selected: _ratio == CanvasRatio.storyPortrait,
                      onTap: () => setState(() {
                        _ratio = CanvasRatio.storyPortrait;
                        _resetOffsets();
                      }),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Font Picker
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _fontFamily,
                      isDense: true,
                      dropdownColor: isDark ? NusaConfig.darkSurface : Colors.white,
                      items: ['Poppins', 'Roboto', 'Inter', 'Courier'].map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
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
            ],
          ),
          const SizedBox(height: 8),
          // Theme Presets Bar
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kPromoThemes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                        : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratioButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? NusaConfig.activePrimary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(bool isDark) {
    final double aspectRatio = _ratio == CanvasRatio.feedSquare ? 1.0 : (9.0 / 16.0);
    final double maxWidth = _ratio == CanvasRatio.feedSquare ? 330.0 : 250.0;

    final prod = _selectedProduct;
    final sellPrice = prod?.sellPrice ?? 25000;
    final discount = prod?.discountPercent ?? 0;
    final originalPrice = discount > 0 ? (sellPrice / (1 - (discount / 100))).round() : 0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RepaintBoundary(
        key: _canvasKey,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _activeTheme.bgGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                children: [
                  // Decorative Corner Accent
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activeTheme.primaryAccent.withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  // Main Content Layout
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top: Store Header & Tagline
                        Column(
                          children: [
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _activeTheme.secondaryTextColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Promo Badge
                            _wrapInteractive(
                              element: PromoElement.promoBadge,
                              offset: _promoBadgeOffset,
                              onPan: (d) => setState(() => _promoBadgeOffset += d),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _activeTheme.primaryAccent,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _activeTheme.primaryAccent.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _promoTag,
                                  style: _getFontStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Middle: Product Image
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
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(_imageCircular ? 100 : 16),
                              child: prod != null && (prod.imagePath != null || prod.imageBase64 != null)
                                  ? NusaProductImage(
                                      imagePath: prod.imagePath,
                                      imageBase64: prod.imageBase64,
                                      width: _productImageSize,
                                      height: _productImageSize,
                                      fit: BoxFit.cover,
                                      placeholder: Center(
                                        child: Icon(
                                          Icons.fastfood_rounded,
                                          size: _productImageSize * 0.45,
                                          color: _activeTheme.primaryAccent,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        size: _productImageSize * 0.45,
                                        color: _activeTheme.primaryAccent,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Bottom: Product Details, Price & CTA
                        Column(
                          children: [
                            // Product Title
                            _wrapInteractive(
                              element: PromoElement.productTitle,
                              offset: _productTitleOffset,
                              onPan: (d) => setState(() => _productTitleOffset += d),
                              child: Text(
                                prod?.name ?? 'Nama Produk Pilihan',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _getFontStyle(
                                  fontSize: _titleFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: _activeTheme.textColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Price Row (Promo + Strikethrough)
                            _wrapInteractive(
                              element: PromoElement.priceBadge,
                              offset: _priceBadgeOffset,
                              onPan: (d) => setState(() => _priceBadgeOffset += d),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _currencyFormat.format(sellPrice),
                                    style: _getFontStyle(
                                      fontSize: _priceFontSize,
                                      fontWeight: FontWeight.w900,
                                      color: _activeTheme.primaryAccent,
                                    ),
                                  ),
                                  if (originalPrice > sellPrice) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      _currencyFormat.format(originalPrice),
                                      style: _getFontStyle(
                                        fontSize: _priceFontSize * 0.6,
                                        fontWeight: FontWeight.w500,
                                        color: _activeTheme.secondaryTextColor,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // CTA Banner
                            _wrapInteractive(
                              element: PromoElement.callToAction,
                              offset: _callToActionOffset,
                              onPan: (d) => setState(() => _callToActionOffset += d),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _activeTheme.cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _activeTheme.primaryAccent.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _ctaText,
                                  textAlign: TextAlign.center,
                                  style: _getFontStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: _activeTheme.secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapInteractive({
    required PromoElement element,
    required Offset offset,
    required ValueChanged<Offset> onPan,
    required Widget child,
  }) {
    final isSelected = _activeElement == element;

    return Transform.translate(
      offset: offset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeElement = isSelected ? PromoElement.none : element;
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

  Widget _buildInspectorPanel(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? NusaConfig.darkBorder : const Color(0xFFE2E8F0)),
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
                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                ),
              ),
              if (_activeElement != PromoElement.none)
                TextButton(
                  onPressed: _resetOffsets,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reset Posisi', style: TextStyle(fontSize: 11)),
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
        return 'Edit: Ukuran Harga';
      case PromoElement.callToAction:
        return 'Edit: Teks Ajakan (CTA)';
      case PromoElement.none:
        return 'Sentuh elemen di kanvas untuk menggeser / mengubah ukuran';
    }
  }

  Widget _buildActiveControls(bool isDark) {
    switch (_activeElement) {
      case PromoElement.productImage:
        return Row(
          children: [
            const Text('Ukuran:', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _productImageSize,
                min: 80,
                max: 200,
                activeColor: NusaConfig.activePrimary,
                onChanged: (v) => setState(() => _productImageSize = v),
              ),
            ),
            IconButton(
              tooltip: 'Bentuk Lingkaran / Kotak',
              icon: Icon(
                _imageCircular ? Icons.circle_outlined : Icons.crop_square_rounded,
                size: 20,
              ),
              onPressed: () => setState(() => _imageCircular = !_imageCircular),
            ),
          ],
        );

      case PromoElement.productTitle:
        return Row(
          children: [
            const Text('Font:', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _titleFontSize,
                min: 12,
                max: 26,
                activeColor: NusaConfig.activePrimary,
                onChanged: (v) => setState(() => _titleFontSize = v),
              ),
            ),
            Text('${_titleFontSize.round()}pt', style: const TextStyle(fontSize: 11)),
          ],
        );

      case PromoElement.priceBadge:
        return Row(
          children: [
            const Text('Font:', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: _priceFontSize,
                min: 14,
                max: 30,
                activeColor: NusaConfig.activePrimary,
                onChanged: (v) => setState(() => _priceFontSize = v),
              ),
            ),
            Text('${_priceFontSize.round()}pt', style: const TextStyle(fontSize: 11)),
          ],
        );

      case PromoElement.promoBadge:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _promoTag)
                  ..selection = TextSelection.collapsed(offset: _promoTag.length),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Teks badge...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) {
                  if (v.isNotEmpty) setState(() => _promoTag = v.toUpperCase());
                },
              ),
            ),
          ],
        );

      case PromoElement.callToAction:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _ctaText)
                  ..selection = TextSelection.collapsed(offset: _ctaText.length),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Teks CTA...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) {
                  if (v.isNotEmpty) setState(() => _ctaText = v);
                },
              ),
            ),
          ],
        );

      default:
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: _showProductPicker,
              icon: const Icon(Icons.shopping_bag_outlined, size: 16),
              label: Text(
                _selectedProduct?.name ?? 'Pilih Produk',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Geser elemen langsung dengan jari untuk mengatur tata letak.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                ),
              ),
            ),
          ],
        );
    }
  }

  void _showProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(ctx).padding.bottom),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Pilih Produk untuk Promosi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _allProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada produk di database',
                          style: TextStyle(
                            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _allProducts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final p = _allProducts[idx];
                          final isSelected = p.id == _selectedProduct?.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: NusaProductImage(
                                  imagePath: p.imagePath,
                                  imageBase64: p.imageBase64,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  placeholder: const Center(
                                    child: Icon(Icons.fastfood_rounded, size: 20),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _currencyFormat.format(p.sellPrice),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: NusaConfig.activePrimary,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, color: NusaConfig.activePrimary)
                                : null,
                            onTap: () {
                              setState(() => _selectedProduct = p);
                              Navigator.pop(ctx);
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

  Future<void> _exportImage({required bool isShare}) async {
    setState(() => _loading = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Kanvas belum siap');
      }

      final image = await boundary.toImage(pixelRatio: 3.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal konversi gambar');
      }

      final dir = await getTemporaryDirectory();
      final filename = 'Promo_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      if (isShare) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Promo ${_selectedProduct?.name ?? 'Produk'} - $_storeName',
          ),
        );
        TopToast.success(context, 'Membuka menu bagikan');
      } else {
        TopToast.success(context, 'Gambar promosi berhasil disimpan');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
