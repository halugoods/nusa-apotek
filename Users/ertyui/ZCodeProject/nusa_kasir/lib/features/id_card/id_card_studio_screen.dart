import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/config/nusa_config.dart';
import '../../core/providers.dart';
import '../../core/services/id_card_renderer.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/top_toast.dart';

enum IdCardType { employee, customer }
enum IdCardExportFormat { pdfSingle, pdfBatchA4, imagePng, imageJpg }
enum SelectedElement { none, storeName, roleBadge, photo, personName, subInfo, barcode }

class IdCardStudioScreen extends ConsumerStatefulWidget {
  final IdCardType initialType;
  const IdCardStudioScreen({super.key, this.initialType = IdCardType.employee});

  @override
  ConsumerState<IdCardStudioScreen> createState() => _IdCardStudioScreenState();
}

class _IdCardStudioScreenState extends ConsumerState<IdCardStudioScreen> {
  late IdCardType _cardType;
  bool _loading = false;

  List<Employee> _employees = [];
  List<Customer> _customers = [];
  final Set<int> _selectedIds = {};

  String _storeName = 'NUSA Store';
  final GlobalKey _previewRepaintKey = GlobalKey();

  // Active element selector in touch canvas
  SelectedElement _activeElement = SelectedElement.none;

  // Customizer styling states per-element
  int _selectedTemplateIdx = 0;
  String _fontFamily = 'Poppins';
  Color _cardAccentColor = NusaConfig.activePrimary;

  // Standalone element properties & offsets (Drag-to-Move relative dx, dy in dp)
  Offset _storeNameOffset = Offset.zero;
  double _storeNameFontSize = 11.0;
  Color _storeNameColor = Colors.white;

  Offset _roleBadgeOffset = Offset.zero;
  double _roleBadgeFontSize = 9.0;
  Color _roleBadgeColor = NusaConfig.activePrimary;

  Offset _photoOffset = Offset.zero;
  double _photoSize = 48.0;
  bool _photoCircular = false;
  bool _showPhoto = true;

  Offset _personNameOffset = Offset.zero;
  double _personNameFontSize = 13.5;
  Color _personNameColor = Colors.white;

  Offset _subInfoOffset = Offset.zero;
  double _subInfoFontSize = 9.5;
  Color _subInfoColor = Colors.white70;

  Offset _barcodeOffset = Offset.zero;
  double _barcodeHeight = 32.0;
  double _barcodeWidthScale = 1.0;
  bool _showBarcode = true;
  bool _barcodeShowText = true;

  // Accordion expansion states
  bool _expandTemplates = true;
  bool _expandStyling = false;
  bool _expandTargets = true;
  bool _expandExport = true;

  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Modern Dark Slate',
      'bgGradient': [Color(0xFF0F172A), Color(0xFF1E293B)],
      'accent': Color(0xFFDC2626),
      'textColor': Colors.white,
      'isDark': true,
    },
    {
      'name': 'Clean Classic Light',
      'bgGradient': [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
      'accent': Color(0xFFDC2626),
      'textColor': Color(0xFF0F172A),
      'isDark': false,
    },
    {
      'name': 'Corporate Emerald',
      'bgGradient': [Color(0xFF064E3B), Color(0xFF022C22)],
      'accent': Color(0xFF10B981),
      'textColor': Colors.white,
      'isDark': true,
    },
    {
      'name': 'Royal Gold VIP',
      'bgGradient': [Color(0xFF18181B), Color(0xFF27272A)],
      'accent': Color(0xFFF59E0B),
      'textColor': Colors.white,
      'isDark': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _cardType = widget.initialType;
    _cardAccentColor = NusaConfig.activePrimary;
    _roleBadgeColor = NusaConfig.activePrimary;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final settingsRepo = ref.read(settingsRepoProvider);
    final sn = await settingsRepo.getStoreName();
    if (sn.isNotEmpty) _storeName = sn;

    final empRepo = AttendanceRepository(db);
    final custRepo = CustomerRepository(db);

    final emps = await empRepo.getEmployees();
    final custs = await custRepo.getCustomers();

    if (mounted) {
      setState(() {
        _employees = emps;
        _customers = custs;
        _selectedIds.clear();
        if (_cardType == IdCardType.employee && _employees.isNotEmpty) {
          _selectedIds.add(_employees.first.id);
        } else if (_cardType == IdCardType.customer && _customers.isNotEmpty) {
          _selectedIds.add(_customers.first.id);
        }
        _loading = false;
      });
    }
  }

  void _selectAll(bool select) {
    setState(() {
      if (!select) {
        _selectedIds.clear();
      } else {
        if (_cardType == IdCardType.employee) {
          _selectedIds.addAll(_employees.map((e) => e.id));
        } else {
          _selectedIds.addAll(_customers.map((c) => c.id));
        }
      }
    });
  }

  void _resetLayout() {
    setState(() {
      _storeNameOffset = Offset.zero;
      _roleBadgeOffset = Offset.zero;
      _photoOffset = Offset.zero;
      _personNameOffset = Offset.zero;
      _subInfoOffset = Offset.zero;
      _barcodeOffset = Offset.zero;
      _photoSize = 48.0;
      _barcodeHeight = 32.0;
      _activeElement = SelectedElement.none;
    });
    TopToast.info(context, 'Posisi elemen kanvas di-reset ke default');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Studio Kartu ID (CR80)',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: isDark ? NusaConfig.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        actions: [
          IconButton(
            tooltip: 'Reset Posisi Kanvas',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _resetLayout,
          ),
          IconButton(
            tooltip: 'Panduan Ukuran CR80',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showDimensionInfo(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return isWide ? _buildWideLayout(isDark) : _buildMobileLayout(isDark);
              },
            ),
    );
  }

  Widget _buildWideLayout(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Interactive Canvas + Standalone Customizer + Export
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLiveInteractiveCanvas(isDark),
                const SizedBox(height: 16),
                _buildActiveElementToolbar(isDark),
                const SizedBox(height: 16),
                _buildCustomizerAccordion(isDark),
                const SizedBox(height: 16),
                _buildExportAccordion(isDark),
              ],
            ),
          ),
        ),
        // Vertical Divider
        Container(width: 1, color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        // Right Column: Target Selector List with Checkbox
        Expanded(
          flex: 4,
          child: _buildTargetSelectorPanel(isDark),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeSegmented(isDark),
          const SizedBox(height: 16),
          _buildLiveInteractiveCanvas(isDark),
          const SizedBox(height: 12),
          _buildActiveElementToolbar(isDark),
          const SizedBox(height: 16),
          _buildTargetSelectorAccordion(isDark),
          const SizedBox(height: 16),
          _buildCustomizerAccordion(isDark),
          const SizedBox(height: 16),
          _buildExportAccordion(isDark),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // INTERACTIVE TOUCH CANVAS (CR80 Landscape 85.6 × 54 mm)
  // Aspect ratio = 85.6 / 54 ≈ 1.585
  // ─────────────────────────────────────────────────

  Widget _buildLiveInteractiveCanvas(bool isDark) {
    final tpl = _templates[_selectedTemplateIdx];
    final bgGradient = tpl['bgGradient'] as List<Color>;
    final accent = _cardAccentColor;
    final cardIsDark = tpl['isDark'] as bool;

    // Active target item data
    String name = 'NAMA LENGKAP';
    String roleOrLevel = _cardType == IdCardType.employee ? 'KASIR' : 'GOLD MEMBER';
    String subInfo = _cardType == IdCardType.employee ? 'NIP: EMP-001' : 'Poin: 150 Poin';
    String barcode = 'NUSA-8829102';
    String? photoPath;

    if (_cardType == IdCardType.employee && _employees.isNotEmpty) {
      final active = _employees.firstWhere(
        (e) => _selectedIds.contains(e.id),
        orElse: () => _employees.first,
      );
      name = active.name;
      roleOrLevel = active.role.toUpperCase();
      subInfo = 'NIP: EMP-${active.id} • ${active.phone ?? 'Aktif'}';
      barcode = active.barcode ?? 'EMP-${active.id}';
      photoPath = active.photoPath;
    } else if (_cardType == IdCardType.customer && _customers.isNotEmpty) {
      final active = _customers.firstWhere(
        (c) => _selectedIds.contains(c.id),
        orElse: () => _customers.first,
      );
      name = active.name;
      roleOrLevel = '${active.level} MEMBER'.toUpperCase();
      final phoneStr = active.phone;
      subInfo = 'Poin: ${active.points} • ${(phoneStr != null && phoneStr.isNotEmpty) ? phoneStr : 'Member Toko'}';
      barcode = active.barcode ?? 'CUST-${active.id}';
    }

    final defaultTextClr = tpl['textColor'] as Color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: NusaConfig.activePrimary),
                const SizedBox(width: 6),
                Text(
                  'KANVAS INTERAKTIF (TOUCH & DRAG)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'CR80 • 85.6 × 54 mm',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: RepaintBoundary(
            key: _previewRepaintKey,
            child: AspectRatio(
              aspectRatio: 85.6 / 54.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bgGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: cardIsDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.5),
                  child: Stack(
                    children: [
                      // Top decorative line
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4.5,
                          color: accent,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Header Row: Store Name & Role Badge ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _wrapInteractiveElement(
                                  element: SelectedElement.storeName,
                                  offset: _storeNameOffset,
                                  onPanUpdate: (d) => setState(() => _storeNameOffset += d),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _storeName.toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontSize: _storeNameFontSize,
                                          fontWeight: FontWeight.w800,
                                          color: cardIsDark ? _storeNameColor : defaultTextClr,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _wrapInteractiveElement(
                                  element: SelectedElement.roleBadge,
                                  offset: _roleBadgeOffset,
                                  onPanUpdate: (d) => setState(() => _roleBadgeOffset += d),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _roleBadgeColor,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      roleOrLevel,
                                      style: TextStyle(
                                        fontFamily: _fontFamily,
                                        fontSize: _roleBadgeFontSize,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // ── Center Row: Profile Photo + Names & SubInfo ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (_showPhoto)
                                  _wrapInteractiveElement(
                                    element: SelectedElement.photo,
                                    offset: _photoOffset,
                                    onPanUpdate: (d) => setState(() => _photoOffset += d),
                                    child: Container(
                                      width: _photoSize,
                                      height: _photoSize,
                                      decoration: BoxDecoration(
                                        color: cardIsDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : const Color(0xFFE2E8F0),
                                        shape: _photoCircular ? BoxShape.circle : BoxShape.rectangle,
                                        borderRadius: _photoCircular ? null : BorderRadius.circular(10),
                                        border: Border.all(color: accent, width: 1.5),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(_photoCircular ? 99 : 8.5),
                                        child: photoPath != null && File(photoPath).existsSync()
                                            ? Image.file(File(photoPath), fit: BoxFit.cover)
                                            : Center(
                                                child: Text(
                                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                  style: TextStyle(
                                                    fontFamily: _fontFamily,
                                                    fontSize: _photoSize * 0.4,
                                                    fontWeight: FontWeight.w800,
                                                    color: accent,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _wrapInteractiveElement(
                                        element: SelectedElement.personName,
                                        offset: _personNameOffset,
                                        onPanUpdate: (d) => setState(() => _personNameOffset += d),
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontFamily: _fontFamily,
                                            fontSize: _personNameFontSize,
                                            fontWeight: FontWeight.w800,
                                            color: cardIsDark ? _personNameColor : defaultTextClr,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      _wrapInteractiveElement(
                                        element: SelectedElement.subInfo,
                                        offset: _subInfoOffset,
                                        onPanUpdate: (d) => setState(() => _subInfoOffset += d),
                                        child: Text(
                                          subInfo,
                                          style: TextStyle(
                                            fontFamily: _fontFamily,
                                            fontSize: _subInfoFontSize,
                                            color: cardIsDark ? _subInfoColor : defaultTextClr.withValues(alpha: 0.75),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // ── Bottom Row: Barcode 128 ──
                            if (_showBarcode)
                              _wrapInteractiveElement(
                                element: SelectedElement.barcode,
                                offset: _barcodeOffset,
                                onPanUpdate: (d) => setState(() => _barcodeOffset += d),
                                child: Container(
                                  height: _barcodeHeight,
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                  child: BarcodeWidget(
                                    barcode: Barcode.code128(),
                                    data: barcode,
                                    drawText: _barcodeShowText,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
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
        ),
      ],
    );
  }

  Widget _wrapInteractiveElement({
    required SelectedElement element,
    required Offset offset,
    required ValueChanged<Offset> onPanUpdate,
    required Widget child,
  }) {
    final isSelected = _activeElement == element;

    return Transform.translate(
      offset: offset,
      child: GestureDetector(
        onTap: () => setState(() => _activeElement = isSelected ? SelectedElement.none : element),
        onPanUpdate: (details) => onPanUpdate(details.delta),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                )
              : null,
          padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // STANDALONE ACTIVE ELEMENT TOOLBAR
  // ─────────────────────────────────────────────────

  Widget _buildActiveElementToolbar(bool isDark) {
    if (_activeElement == SelectedElement.none) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: NusaConfig.activePrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sentuh elemen kartu di atas untuk membuka editor mandiri & kontrol ukuran.',
                style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.tune_rounded, size: 16, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Editor Elemen: ${_elementTitle(_activeElement)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blueAccent),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _activeElement = SelectedElement.none),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildElementControls(isDark),
        ],
      ),
    );
  }

  String _elementTitle(SelectedElement el) {
    switch (el) {
      case SelectedElement.storeName: return 'Nama Toko';
      case SelectedElement.roleBadge: return 'Badge Role / Member';
      case SelectedElement.photo: return 'Foto Profil';
      case SelectedElement.personName: return 'Nama Lengkap';
      case SelectedElement.subInfo: return 'NIP / Poin / Sub-Info';
      case SelectedElement.barcode: return 'Barcode Code128';
      case SelectedElement.none: return '';
    }
  }

  Widget _buildElementControls(bool isDark) {
    switch (_activeElement) {
      case SelectedElement.storeName:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ukuran Font: ${_storeNameFontSize.toStringAsFixed(1)}pt', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _storeNameFontSize,
                    min: 8.0,
                    max: 18.0,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setState(() => _storeNameFontSize = v),
                  ),
                ),
              ],
            ),
          ],
        );
      case SelectedElement.roleBadge:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ukuran Font: ${_roleBadgeFontSize.toStringAsFixed(1)}pt', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _roleBadgeFontSize,
                    min: 7.0,
                    max: 14.0,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setState(() => _roleBadgeFontSize = v),
                  ),
                ),
              ],
            ),
          ],
        );
      case SelectedElement.photo:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ukuran Foto: ${_photoSize.toInt()}px', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _photoSize,
                    min: 32.0,
                    max: 72.0,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setState(() => _photoSize = v),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bentuk Lingkaran', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _photoCircular,
                  activeColor: Colors.blueAccent,
                  onChanged: (v) => setState(() => _photoCircular = v),
                ),
              ],
            ),
          ],
        );
      case SelectedElement.personName:
        return Row(
          children: [
            Expanded(
              child: Text('Ukuran Font: ${_personNameFontSize.toStringAsFixed(1)}pt', style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Slider(
                value: _personNameFontSize,
                min: 10.0,
                max: 20.0,
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => _personNameFontSize = v),
              ),
            ),
          ],
        );
      case SelectedElement.subInfo:
        return Row(
          children: [
            Expanded(
              child: Text('Ukuran Font: ${_subInfoFontSize.toStringAsFixed(1)}pt', style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Slider(
                value: _subInfoFontSize,
                min: 7.0,
                max: 14.0,
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => _subInfoFontSize = v),
              ),
            ),
          ],
        );
      case SelectedElement.barcode:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tinggi Bar: ${_barcodeHeight.toInt()}px', style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _barcodeHeight,
                    min: 20.0,
                    max: 50.0,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setState(() => _barcodeHeight = v),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tampilkan Teks Nomor', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _barcodeShowText,
                  activeColor: Colors.blueAccent,
                  onChanged: (v) => setState(() => _barcodeShowText = v),
                ),
              ],
            ),
          ],
        );
      case SelectedElement.none:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────
  // ACCORDIONS: TEMPLATES & EXPORT
  // ─────────────────────────────────────────────────

  Widget _buildCustomizerAccordion(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expandTemplates,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          'Desain & Tema Kartu',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Pilih template visual, aksen warna, dan keluarga font',
          style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text('Template Kartu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final tpl = _templates[idx];
                      final isSelected = _selectedTemplateIdx == idx;
                      return ChoiceChip(
                        label: Text(tpl['name'] as String),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedTemplateIdx = idx;
                              _cardAccentColor = tpl['accent'] as Color;
                              _roleBadgeColor = tpl['accent'] as Color;
                            });
                          }
                        },
                        selectedColor: NusaConfig.activePrimary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? NusaConfig.activePrimary : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Font Family Dropdown
                Text('Keluarga Font', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _fontFamily,
                      isExpanded: true,
                      dropdownColor: isDark ? NusaConfig.darkSurface : Colors.white,
                      items: ['Poppins', 'Roboto', 'Inter', 'Courier'].map((f) {
                        return DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontFamily: f, fontSize: 13)));
                      }).toList(),
                      onChanged: (v) => setState(() => _fontFamily = v ?? 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Toggles Barcode & Photo
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Foto Profil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _showPhoto,
                        activeColor: NusaConfig.activePrimary,
                        onChanged: (v) => setState(() => _showPhoto = v),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Barcode 128', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _showBarcode,
                        activeColor: NusaConfig.activePrimary,
                        onChanged: (v) => setState(() => _showBarcode = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportAccordion(bool isDark) {
    final count = _selectedIds.length;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expandExport,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          'Opsi Cetak & Ekspor ($count Kartu Terpilih)',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Ekspor PDF A4 Batch (8 kartu), PDF CR80 pas, atau Gambar PNG/JPG',
          style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _exportActionButton(
                      icon: Icons.grid_view_rounded,
                      title: 'PDF Batch A4',
                      subtitle: 'Grid 2×4 (8 kartu/lbr)',
                      color: const Color(0xFF2563EB),
                      onTap: () => _exportPdfBatch(isDark),
                    ),
                    _exportActionButton(
                      icon: Icons.credit_card_rounded,
                      title: 'PDF Single CR80',
                      subtitle: 'Ukuran Pas Cetak ID Card',
                      color: const Color(0xFF059669),
                      onTap: () => _exportPdfSingle(isDark),
                    ),
                    _exportActionButton(
                      icon: Icons.image_rounded,
                      title: 'Simpan PNG',
                      subtitle: 'Gambar Resolusi Tinggi',
                      color: const Color(0xFFD97706),
                      onTap: () => _exportImage(isDark, isJpg: false),
                    ),
                    _exportActionButton(
                      icon: Icons.share_rounded,
                      title: 'Bagikan JPG',
                      subtitle: 'Share via WhatsApp / Email',
                      color: const Color(0xFF9333EA),
                      onTap: () => _exportImage(isDark, isJpg: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final disabled = _selectedIds.isEmpty;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: disabled ? Colors.grey.withValues(alpha: 0.3) : color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: disabled ? Colors.grey : color, size: 24),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: disabled ? Colors.grey : color)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: disabled ? Colors.grey : color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // TARGET SELECTOR PANEL (CHECKBOX ACCORDION / LIST)
  // ─────────────────────────────────────────────────

  Widget _buildTypeSegmented(bool isDark) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _cardType = IdCardType.employee;
                _selectedIds.clear();
                if (_employees.isNotEmpty) _selectedIds.add(_employees.first.id);
              }),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cardType == IdCardType.employee ? NusaConfig.activePrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Kartu Staf & Karyawan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _cardType == IdCardType.employee ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _cardType = IdCardType.customer;
                _selectedIds.clear();
                if (_customers.isNotEmpty) _selectedIds.add(_customers.first.id);
              }),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cardType == IdCardType.customer ? NusaConfig.activePrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Kartu Member & Pelanggan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _cardType == IdCardType.customer ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelectorAccordion(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expandTargets,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          _cardType == IdCardType.employee
              ? 'Daftar Karyawan (${_selectedIds.length}/${_employees.length})'
              : 'Daftar Member (${_selectedIds.length}/${_customers.length})',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Pilih siapa saja yang ingin dicetak kartu ID-nya',
          style: TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildTargetList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelectorPanel(bool isDark) {
    return Container(
      color: isDark ? NusaConfig.darkSurface : Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeSegmented(isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _cardType == IdCardType.employee
                    ? 'PILIH KARYAWAN (${_selectedIds.length})'
                    : 'PILIH MEMBER (${_selectedIds.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _selectAll(true),
                    child: const Text('Pilih Semua', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => _selectAll(false),
                    child: const Text('Batal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildTargetList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetList(bool isDark) {
    if (_cardType == IdCardType.employee) {
      if (_employees.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Belum ada data karyawan.')),
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: _employees.length,
        itemBuilder: (context, idx) {
          final emp = _employees[idx];
          final isSelected = _selectedIds.contains(emp.id);
          return CheckboxListTile(
            value: isSelected,
            activeColor: NusaConfig.activePrimary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: CircleAvatar(
              radius: 18,
              backgroundColor: NusaConfig.activePrimary.withValues(alpha: 0.15),
              child: Text(
                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w700, color: NusaConfig.activePrimary),
              ),
            ),
            title: Text(emp.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Role: ${emp.role} • NIP: EMP-${emp.id}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.add(emp.id);
                } else {
                  _selectedIds.remove(emp.id);
                }
              });
            },
          );
        },
      );
    } else {
      if (_customers.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Belum ada data pelanggan/member.')),
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: _customers.length,
        itemBuilder: (context, idx) {
          final cust = _customers[idx];
          final isSelected = _selectedIds.contains(cust.id);
          return CheckboxListTile(
            value: isSelected,
            activeColor: NusaConfig.activePrimary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: CircleAvatar(
              radius: 18,
              backgroundColor: NusaConfig.activePrimary.withValues(alpha: 0.15),
              child: Text(
                cust.name.isNotEmpty ? cust.name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w700, color: NusaConfig.activePrimary),
              ),
            ),
            title: Text(cust.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Member ${cust.level} • Poin: ${cust.points}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.add(cust.id);
                } else {
                  _selectedIds.remove(cust.id);
                }
              });
            },
          );
        },
      );
    }
  }

  // ─────────────────────────────────────────────────
  // EXPORT ENGINE: PDF & IMAGE GENERATORS
  // ─────────────────────────────────────────────────

  Future<void> _exportPdfBatch(bool isDark) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _loading = true);
    try {
      final cards = <pw.Widget>[];
      if (_cardType == IdCardType.employee) {
        final targets = _employees.where((e) => _selectedIds.contains(e.id)).toList();
        for (final emp in targets) {
          pw.MemoryImage? photo;
          if (emp.photoPath != null && File(emp.photoPath!).existsSync()) {
            photo = photoToImage(emp.photoPath);
          }
          cards.add(IdCardRenderer.employeeCard(
            storeName: _storeName,
            name: emp.name,
            role: emp.role,
            id: emp.id,
            barcode: emp.barcode ?? 'EMP-${emp.id}',
            phone: emp.phone,
            photoBytes: photo,
          ));
        }
      } else {
        final targets = _customers.where((c) => _selectedIds.contains(c.id)).toList();
        for (final cust in targets) {
          cards.add(IdCardRenderer.memberCard(
            storeName: _storeName,
            name: cust.name,
            level: cust.level,
            points: cust.points,
            barcode: cust.barcode ?? 'CUST-${cust.id}',
            phone: cust.phone,
          ));
        }
      }

      final file = await IdCardRenderer.renderBatchA4(
        cards: cards,
        title: 'Kartu_ID_Batch_A4_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Kartu ID Batch A4 - $_storeName',
        ),
      );
      TopToast.success(context, 'PDF Batch A4 berhasil dibuat (${cards.length} kartu)');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor PDF: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdfSingle(bool isDark) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _loading = true);
    try {
      late pw.Widget card;
      String fileName = 'Kartu_ID';
      if (_cardType == IdCardType.employee) {
        final active = _employees.firstWhere((e) => _selectedIds.contains(e.id), orElse: () => _employees.first);
        fileName = 'Kartu_CR80_${active.name.replaceAll(' ', '_')}';
        pw.MemoryImage? photo;
        if (active.photoPath != null && File(active.photoPath!).existsSync()) {
          photo = photoToImage(active.photoPath);
        }
        card = IdCardRenderer.employeeCard(
          storeName: _storeName,
          name: active.name,
          role: active.role,
          id: active.id,
          barcode: active.barcode ?? 'EMP-${active.id}',
          phone: active.phone,
          photoBytes: photo,
        );
      } else {
        final active = _customers.firstWhere((c) => _selectedIds.contains(c.id), orElse: () => _customers.first);
        fileName = 'Kartu_Member_${active.name.replaceAll(' ', '_')}';
        card = IdCardRenderer.memberCard(
          storeName: _storeName,
          name: active.name,
          level: active.level,
          points: active.points,
          barcode: active.barcode ?? 'CUST-${active.id}',
          phone: active.phone,
        );
      }

      final file = await IdCardRenderer.renderSingle(card: card, fileName: fileName);

      if (!mounted) return;
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Kartu CR80 - $_storeName',
        ),
      );
      TopToast.success(context, 'PDF Single CR80 siap dicetak');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal ekspor PDF: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportImage(bool isDark, {required bool isJpg}) async {
    try {
      final boundary = _previewRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final ext = isJpg ? 'jpg' : 'png';
      final file = File('${dir.path}/Kartu_ID_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Kartu ID CR80 - $_storeName',
        ),
      );
      TopToast.success(context, 'Gambar $ext berhasil dibuat');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal membuat gambar: $e');
    }
  }

  void _showDimensionInfo(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.credit_card_rounded, color: NusaConfig.activePrimary),
            const SizedBox(width: 8),
            const Text('Standar Kartu CR80'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Dimensi Fisik: 85.6 mm × 54.0 mm', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('• Format Standar: Kartu ATM / Debit / KTP / ID Card karyawan.'),
            SizedBox(height: 8),
            Text('• Kompatibel dengan printer thermal kartu ID, mesin cetak PVC, atau cetak A4 glossy.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
