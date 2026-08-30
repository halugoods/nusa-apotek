import 'dart:io';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/label/label_commands.dart';
import 'package:nusa_kasir/core/label/label_font_config.dart';
import 'package:nusa_kasir/core/label/label_renderer.dart';
import 'package:nusa_kasir/core/label/label_size_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/shared/widgets/hid_barcode_listener.dart';
import 'package:nusa_kasir/shared/widgets/nusa_product_image.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Alur Cetak Label Barcode (v2.2.57+116) — 3 langkah:
///   1. Pilih produk (checkbox, "Pilih Semua")
///   2. Pilih ISI label (Nama / Harga / Barcode) + UKURAN FONT (v2.2.57+116:
///      slider nama & harga — user bisa sesuaikan sendiri, berlaku ke SEMUA
///      jalur cetak supaya preview = hasil cetak)
///   3. Pilih JALUR cetak — KLIK jalur → muncul PREVIEW ACTUAL jalur tsb
///      (bukan preview generik) + tombol cetak di dalam preview:
///      a. Thermal Label (TSPL) — preview bitmap 203 DPI (isi persis yang
///         dikirim ke printer label)
///      b. Thermal Struk 58mm (ESC/POS) — preview di atas kertas struk
///      c. PDF A4 grid — preview lembar A4 (grid 4×8 label seperti aslinya),
///         tombol cetak = buka PDF → share/unduh/print via Android
///
/// Isi label & ukuran diteruskan ke [LabelRenderer] — render SAMA untuk semua
/// jalur (konsistensi, pratinjau = hasil cetak).
class LabelPrintSheet extends ConsumerStatefulWidget {
  const LabelPrintSheet({super.key, this.initialProducts});

  /// Produk yang sudah dipilih sebelumnya (dari toolbar — bisa kosong).
  final List<Product>? initialProducts;

  /// Tampilkan sebagai halaman penuh.
  static Future<void> show(
    BuildContext context, {
    List<Product>? products,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabelPrintSheet(initialProducts: products),
      ),
    );
  }

  @override
  ConsumerState<LabelPrintSheet> createState() => _LabelPrintSheetState();
}

class _LabelPrintSheetState extends ConsumerState<LabelPrintSheet> {
  // ── Step 1: pilih produk ──
  List<Product> _all = [];
  final Set<int> _selectedIds = {};

  // ── Step 1 (v2.2.57+121): cari & auto-scan barcode ──
  // Searchbar: filter by nama / barcode live. Auto-scan: scanner eksternal
  // (HID) / barcode diketik + Enter → produk ketemu → auto-centang.
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _scannerActive = true;

  // ── Step 2: isi label ──
  bool _showName = true;
  bool _showPrice = true;
  bool _showBarcode = true;

  // ── Step 2 (v2.2.57+116): ukuran font label ──
  // Skala font nama & harga (1.0–3.0) — tersimpan di SecureStore via
  // [LabelFontConfig] (pola sama seperti ReceiptConfig di struk).
  double _nameScale = 1.0;
  double _priceScale = 1.0;

  // ── Step 3: jalur cetak ──
  // Jalur yang sedang dibuka preview-nya (null = semua tertutup).
  // 0 = TSPL, 1 = Struk thermal, 2 = PDF A4.
  int? _expandedPath;
  bool _printing = false;
  String _status = '';

  // ── Qty cetak per produk + ukuran label (v2.2.57+121) ──
  // Berlaku ke SEMUA jalur: TSPL (perintah PRINT n), struk thermal (n×
  // bitmap beruntun), PDF A4 (n× duplikat di grid).
  int _qty = 1;

  // Ukuran label fisik (mm) yang sedang dipilih — didukung oleh getter
  // [_labelW]/[_labelH] (dipakai renderer, TSPL SIZE, PDF grid, preview).
  double _labelWmm = LabelRenderer.defaultWidthMm; // 40
  double _labelHmm = LabelRenderer.defaultHeightMm; // 30

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadFontConfig();
    _loadLabelSize();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLabelSize() async {
    final cfg = await LabelSizeConfig.load();
    if (mounted) {
      setState(() {
        _labelWmm = cfg.widthMm;
        _labelHmm = cfg.heightMm;
      });
    }
  }

  Future<void> _loadFontConfig() async {
    final cfg = await LabelFontConfig.load();
    if (mounted) {
      setState(() {
        _nameScale = cfg.nameScale;
        _priceScale = cfg.priceScale;
      });
    }
  }

  Future<void> _loadProducts() async {
    final repo = ref.read(productRepoProvider);
    // Label tanpa barcode tidak berguna → hanya produk ber-barcode.
    final all = await repo.getProducts();
    final withBarcode = all.where((p) {
      final b = p.barcode;
      return b != null && b.trim().isNotEmpty;
    }).toList();
    if (mounted) {
      setState(() {
        _all = withBarcode;
        if (widget.initialProducts != null) {
          for (final p in widget.initialProducts!) {
            if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
              _selectedIds.add(p.id);
            }
          }
        }
      });
    }
  }

  List<Product> get _selected =>
      _all.where((p) => _selectedIds.contains(p.id)).toList();

  /// Produk yang TAMPAK di daftar pilih (v2.2.57+121) — filter live oleh
  /// [_query] (nama / barcode). Kosong = tampil semua.
  List<Product> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) {
      final name = p.name.toLowerCase();
      final barcode = (p.barcode ?? '').toLowerCase();
      return name.contains(q) || barcode.contains(q);
    }).toList();
  }

  // ── Render ──

  double get _labelW => _labelWmm;
  double get _labelH => _labelHmm;

  /// Render label bitmap untuk SATU produk (dipakai TSPL + ESC/POS + preview).
  /// Ukuran font nama & harga memakai [_nameScale]/[_priceScale] — SAMA untuk
  /// preview dan print (konsistensi render).
  ///
  /// [fullWidthBarcode] (v2.2.57+116): barcode direntang selebar label —
  /// dipakai jalur struk thermal (barcode rata kiri-kanan kertas struk).
  img.Image _renderFor(Product p, int dpi, {bool fullWidthBarcode = false}) {
    return LabelRenderer.renderLabelBitmap(
      barcode: p.barcode ?? '',
      name: p.name,
      price: p.sellPrice,
      showName: _showName,
      showPrice: _showPrice,
      showBarcode: _showBarcode,
      widthPx: LabelRenderer.mmToPx(_labelW, dpi: dpi).round(),
      heightPx: LabelRenderer.mmToPx(_labelH, dpi: dpi).round(),
      nameFontScale: _nameScale,
      priceFontScale: _priceScale,
      fullWidthBarcode: fullWidthBarcode,
    );
  }

  /// Lebar kertas struk (mm) dari pengaturan — 58 atau 80.
  /// Label struk dirender selebar kertas (full-width barcode) supaya barcode
  /// rata kiri-kanan di kertas struk (v2.2.57+116).
  Future<double> _paperMm() async {
    final w = await SecureStore.getPaperSize(); // '58' | '80'
    return w == '80' ? 80.0 : 58.0;
  }

  /// Render bitmap label untuk jalur STRUK: selebar kertas [paperMm] (bukan
  /// lebar label 40mm), tinggi proporsional, barcode FULL lebar. Preview dan
  /// print pakai render yang SAMA → hasil cetak = preview.
  Future<img.Image> _renderForStruk(Product p, int dpi) async {
    final paperMm = await _paperMm();
    return LabelRenderer.renderLabelBitmap(
      barcode: p.barcode ?? '',
      name: p.name,
      price: p.sellPrice,
      showName: _showName,
      showPrice: _showPrice,
      showBarcode: _showBarcode,
      widthPx: LabelRenderer.mmToPx(paperMm, dpi: dpi).round(),
      // Tinggi label struk proporsional: 40×30 → lebar kertas × 0.75.
      heightPx: LabelRenderer.mmToPx(paperMm * (_labelH / _labelW), dpi: dpi)
          .round(),
      nameFontScale: _nameScale,
      priceFontScale: _priceScale,
      fullWidthBarcode: true,
    );
  }

  // ── Koneksi printer (pola printer_settings_sheet) ──

  /// Pastikan izin + Bluetooth aktif, lalu siapkan koneksi printer.
  Future<ReceiptPrinter> _readyPrinter() async {
    await ReceiptPrinter.ensureBluetoothReady();
    return ReceiptPrinter();
  }

  /// Connect ke printer yang alamatnya tersimpan ("Name|MAC").
  Future<bool> _connectStored(String storedAddr) async {
    if (storedAddr.isEmpty || !storedAddr.contains('|')) return false;
    final printer = await _readyPrinter();
    try {
      final devices = await printer.discover();
      final mac = storedAddr.split('|').last;
      for (final d in devices) {
        if (d.address == mac) {
          await printer.connect(d);
          return true;
        }
      }
    } finally {
      await printer.dispose();
    }
    return false;
  }

  /// Printer label belum tersimpan → minta user pilih dari hasil scan,
  /// simpan ke SecureStore, langsung connect.
  Future<bool> _pickLabelPrinter() async {
    final printer = await _readyPrinter();
    List<PrinterDevice> devices;
    try {
      devices = await printer.discover();
    } finally {
      await printer.dispose();
    }
    if (devices.isEmpty) {
      if (mounted) {
        TopToast.error(
            context,
            'Tidak ada printer ditemukan. '
            'Pairing dulu di pengaturan Bluetooth Android.');
      }
      return false;
    }
    if (!mounted) return false;
    final picked = await showModalBottomSheet<PrinterDevice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _printerPickerSheet(devices),
    );
    if (picked == null) return false;
    final p = ReceiptPrinter();
    try {
      await p.connect(picked);
    } finally {
      await p.dispose();
    }
    await SecureStore.setLabelPrinterAddress(
        '${picked.name}|${picked.address}');
    return true;
  }

  Widget _printerPickerSheet(List<PrinterDevice> devices) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Printer Label',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Printer ini akan disimpan khusus untuk cetak label '
            '(terpisah dari printer struk).',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...devices.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.print_outlined, color: NusaConfig.activePrimary),
              title: Text(d.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(d.address, style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(context, d),
            ),
          ),
        ],
      ),
    );
  }

  // ── Jalur 1: TSPL (thermal label) ──

  /// Auto-scan barcode (v2.2.57+121) — scanner eksternal HID/keyboard wedge:
  /// barcode diketuk cepat + Enter → produk dicari (normalisasi konsisten
  /// dengan POS), ketemu → langsung AUTO-CENTANG + scroll ke item di daftar.
  /// Produk yang tidak ada di [_all] (tanpa barcode) tidak dianggap error.
  Future<void> _handleExternalBarcode(String raw) async {
    final repo = ref.read(productRepoProvider);
    final norm = ProductRepository.normalizeBarcode(raw);
    if (norm.isEmpty) return;
    final product = await repo.byBarcode(norm);
    if (product == null || !mounted) return;
    // Auto-select: centang produk hasil scan (langsung siap cetak).
    setState(() {
      _selectedIds.add(product.id);
      _query = '';
      _searchCtrl.clear();
      _scannerActive = false; // jeda 1.2 dtk supaya scan beruntun rapi
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _scannerActive = true);
    });
    TopToast.success(
      context,
      '${product.name} dipilih — ${_selectedIds.length} produk siap cetak',
    );
  }

  /// Enter di kolom cari — jalur manual scan (ketik barcode lalu Enter),
  /// konsisten dengan POS. Ketemu → auto-centang + focus kolom tetap untuk
  /// scan beruntun.
  Future<void> _handleSearchSubmit(String raw) async {
    if (_scannerActive) return; // HID listener yang handle scan eksternal
    final repo = ref.read(productRepoProvider);
    final norm = ProductRepository.normalizeBarcode(raw);
    if (norm.isEmpty) return;
    final product = await repo.byBarcode(norm);
    if (product == null) {
      if (mounted) {
        TopToast.error(context, 'Barcode tidak ditemukan di daftar produk');
      }
      return;
    }
    setState(() {
      _selectedIds.add(product.id);
      _query = '';
      _searchCtrl.clear();
    });
    if (mounted) {
      TopToast.success(context, '${product.name} dipilih');
    }
  }

  /// Auto-scan jalur print label (v2.2.57+121) — produk dari scan barcode
  /// (HID eksternal ATAU Enter kolom cari) DITAMBAHKAN ke pilihan, bukan
  /// menggantikan. Setiap produk dicetak [_qty]×.
  ///
  /// Dipakai [HidBarcodeListener] di build (selalu aktif) dan [_searchCtrl]
  /// (onSubmitted).
  void _handleScanInput(String raw) {
    if (!_scannerActive) return;
    _handleExternalBarcode(raw);
  }

  Future<bool> _printTspl() async {
    if (_selected.isEmpty) return false;
    var connected = false;
    final stored = await SecureStore.getLabelPrinterAddress();
    if (stored != null && stored.isNotEmpty) {
      connected = await _connectStored(stored);
    } else {
      connected = await _pickLabelPrinter();
    }
    if (!connected) {
      if (mounted) {
        TopToast.error(
            context, 'Printer label tidak ditemukan / belum tersambung');
      }
      return false;
    }
    final buf = BytesBuilder();
    for (final p in _selected) {
      buf.add(
        LabelCommands.buildTspl(
          _renderFor(p, LabelDpi.dpi203),
          labelWidthMm: _labelW,
          labelHeightMm: _labelH,
          gapMm: 2,
          copies: _qty,
        ),
      );
    }
    final sent = await BluetoothUtils.sendBytes(buf.toBytes());
    if (!sent && mounted) {
      TopToast.error(context, 'Gagal mengirim ke printer label');
    }
    return sent;
  }

  // ── Jalur 2: ESC/POS thermal struk ──

  Future<bool> _printEscPos() async {
    if (_selected.isEmpty) return false;
    final stored = await SecureStore.getPrinterAddress();
    if (stored == null || stored.isEmpty) {
      if (mounted) {
        TopToast.error(
            context, 'Atur printer struk dulu di Pengaturan → Printer Struk');
      }
      return false;
    }
    final ok = await _connectStored(stored);
    if (!ok) {
      if (mounted) {
        TopToast.error(context,
            'Printer struk tidak ditemukan. Cek Pengaturan → Printer Struk.');
      }
      return false;
    }
    final buf = BytesBuilder();
    for (final p in _selected) {
      final bitmap = await _renderForStruk(p, LabelDpi.dpi203);
      // v2.2.57+121: qty cetak → kirim bitmap yang sama n× beruntun
      // (feed+cut antar label, konsisten dengan qty di TSPL).
      for (var i = 0; i < _qty; i++) {
        buf.add(
          LabelCommands.buildEscPosLabel(
            bitmap: bitmap,
            name: p.name,
            price: p.sellPrice,
            showName: _showName,
            showPrice: _showPrice,
          ),
        );
      }
    }
    final sent = await BluetoothUtils.sendBytes(buf.toBytes());
    if (!sent && mounted) {
      TopToast.error(context, 'Gagal mengirim ke printer struk');
    }
    return sent;
  }

  // ── Jalur 3: PDF A4 grid ──

  Future<File?> _buildPdf() async {
    if (_selected.isEmpty) return null;
    final doc = pw.Document(title: 'Label Barcode', author: 'NUSA Kasir');
    // Grid: label 40×30mm, margin 8mm, gap 4mm → ~4 kolom × 8 baris per A4.
    // Angka SAMA dengan preview _A4GridPreview (konsistensi layout).
    // v2.2.57+121: ukuran label bisa dipilih user → kolom/baris dihitung
    // ulang; qty cetak → tiap produk masuk [_qty]× ke grid.
    const pageW = 210.0, pageH = 297.0;
    const marginMm = 8.0, gapMm = 4.0;
    final cols =
        ((pageW - 2 * marginMm + gapMm) / (_labelW + gapMm)).floor();
    final rows =
        ((pageH - 2 * marginMm + gapMm) / (_labelH + gapMm)).floor();
    final perPage = cols * rows;

    // Daftar label dengan duplikasi qty — urutan: semua produk × qty,
    // lalu dibagi per halaman.
    final expanded = <Product>[
      for (final p in _selected)
        for (var i = 0; i < _qty; i++) p,
    ];

    for (var i = 0; i < expanded.length; i += perPage) {
      final end = i + perPage > expanded.length ? expanded.length : i + perPage;
      final pageItems = expanded.sublist(i, end);
      final widgets = pageItems
          .map(
            (p) => LabelRenderer.pdfLabel(
              barcode: p.barcode ?? '',
              name: p.name,
              price: p.sellPrice,
              showName: _showName,
              showPrice: _showPrice,
              showBarcode: _showBarcode,
              widthMm: _labelW,
              heightMm: _labelH,
              nameFontScale: _nameScale,
              priceFontScale: _priceScale,
            ),
          )
          .toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: marginMm * PdfPageFormat.mm,
            marginRight: marginMm * PdfPageFormat.mm,
            marginTop: marginMm * PdfPageFormat.mm,
            marginBottom: marginMm * PdfPageFormat.mm,
          ),
          build: (_) => pw.Wrap(
            spacing: gapMm * PdfPageFormat.mm,
            runSpacing: gapMm * PdfPageFormat.mm,
            children: widgets,
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/label_barcode_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<bool> _sharePdf() async {
    try {
      final file = await _buildPdf();
      if (file == null) return false;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Label Barcode'),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Jalankan aksi cetak untuk jalur [path] dengan spinner + status.
  Future<void> _runPrint(int path) async {
    if (_selected.isEmpty) {
      TopToast.error(context, 'Pilih produk dulu');
      return;
    }
    setState(() {
      _printing = true;
      _status = 'Mencetak ${_selected.length} label…';
    });
    final ok = switch (path) {
      0 => await _printTspl(),
      1 => await _printEscPos(),
      _ => await _sharePdf(),
    };
    if (mounted) {
      setState(() {
        _printing = false;
        _status = ok
            ? 'Selesai — ${_selected.length} label dikirim.'
            : 'Gagal mencetak. Periksa printer & Bluetooth.';
      });
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    // v2.2.57+121: HidBarcodeListener menangkap scanner eksternal (HID/USB/
    // Bluetooth keyboard wedge) di layar ini — scan barcode langsung
    // auto-centang produk tanpa mengetik. Keypad layar TIDAK muncul karena
    // listener bekerja di level Focus (pola sama dengan POS).
    return HidBarcodeListener(
      onBarcode: _handleScanInput,
      child: ScreenScaffold('Cetak Label Barcode', _buildBody()),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepHeader('1', 'Pilih Produk (ber-barcode)'),
        // ── Search + auto-scan barcode (v2.2.57+121) ──
        // Ketik nama/barcode untuk filter daftar; scan barcode (scanner
        // eksternal atau ketik + Enter) → produk auto-centang.
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _handleSearchSubmit,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari nama atau scan barcode…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _query = '';
                      _searchCtrl.clear();
                    }),
                  ),
            filled: true,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Scan barcode (scanner eksternal / ketik + Enter) → produk '
                'langsung dipilih',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _selectAllRow(),
        const SizedBox(height: 8),
        if (_filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _all.isEmpty
                    ? 'Tidak ada produk dengan barcode.\nTambahkan barcode di Form Produk dulu.'
                    : 'Tidak ada produk cocok "$_query".',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
        else
          _productList(),
        const SizedBox(height: 20),

        _stepHeader('2', 'Isi Label & Ukuran Font'),
        _checkRow(
          value: _showName,
          onChanged: (v) => setState(() => _showName = v),
          label: 'Nama Produk',
        ),
        _checkRow(
          value: _showPrice,
          onChanged: (v) => setState(() => _showPrice = v),
          label: 'Harga',
        ),
        _checkRow(
          value: _showBarcode,
          onChanged: (v) => setState(() => _showBarcode = v),
          label: 'Barcode',
        ),
        const SizedBox(height: 12),
        // ── Ukuran font label (v2.2.57+116) ──
        // User bisa sesuaikan ukuran font nama & harga — berlaku ke SEMUA
        // jalur cetak (TSPL / struk / PDF), preview ikut berubah live.
        Text(
          'Ukuran Font Label',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? NusaConfig.darkTextPrimary
                : NusaConfig.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Atur besar tulisan nama & harga. Berlaku untuk semua jalur cetak.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
        ),
        _fontSlider(
          label: 'Nama Produk',
          value: _nameScale,
          onChanged: (v) {
            setState(() => _nameScale = v);
            LabelFontConfig(nameScale: v, priceScale: _priceScale).save();
          },
        ),
        _fontSlider(
          label: 'Harga',
          value: _priceScale,
          onChanged: (v) {
            setState(() => _priceScale = v);
            LabelFontConfig(nameScale: _nameScale, priceScale: v).save();
          },
        ),
        const SizedBox(height: 16),
        // ── Qty cetak per produk (v2.2.57+121) ──
        // Berapa lembar label untuk SETIAP produk yang dipilih — berlaku ke
        // semua jalur (TSPL PRINT n, struk bitmap beruntun, PDF duplikat).
        Row(
          children: [
            Icon(
              Icons.print_outlined,
              size: 18,
              color: NusaConfig.activePrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Qty Cetak per Produk',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? NusaConfig.darkTextPrimary
                      : NusaConfig.textPrimary,
                ),
              ),
            ),
            _qtyStepper(
              value: _qty,
              onChanged: (v) => setState(() => _qty = v),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tiap produk yang dipilih dicetak $_qty× (total ${_selected.length * _qty} label).',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        // ── Ukuran label (v2.2.57+121) ──
        // Ukuran thermal label umum di pasaran (Rongta/HPRT/Godex/Xprinter).
        // Berlaku ke jalur TSPL (SIZE) & PDF (grid) — struk tetap selebar
        // kertas. Tersimpan di SecureStore.
        Text(
          'Ukuran Label',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? NusaConfig.darkTextPrimary
                : NusaConfig.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cocokkan dengan kode/ukuran di kemasan stiker label Anda '
          '(default 40×30mm untuk printer label).',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _labelSizes.map((s) {
            final selected = (_labelWmm == s.$2 && _labelHmm == s.$3);
            return ChoiceChip(
              label: Text('${_sizeLabel(s.$1, s.$2, s.$3)}'),
              selected: selected,
              onSelected: (_) => setState(() {
                _labelWmm = s.$2;
                _labelHmm = s.$3;
                LabelSizeConfig(widthMm: s.$2, heightMm: s.$3).save();
              }),
              selectedColor: NusaConfig.activePrimary,
              labelStyle: TextStyle(
                fontSize: 12,
                color: selected
                    ? Colors.white
                    : Theme.of(context).brightness == Brightness.dark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        _stepHeader('3', 'Cara Cetak'),
        Text(
          'Klik jalur cetak untuk lihat preview hasilnya, lalu tekan Cetak.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        _pathCard(
          path: 0,
          icon: Icons.print_outlined,
          title: 'Thermal Label (TSPL)',
          subtitle: 'Printer label khusus — Rongta/HPRT/Godex/BluePrint',
          preview: _selected.isEmpty
              ? null
              : _LabelBitmapPreview(
                  product: _selected.first,
                  sheet: this,
                  dpi: LabelDpi.dpi203,
                  // v2.2.57+121: ukuran label mengikuti pilihan user.
                  paperNote:
                      'Printer label ${_mmLabel(_labelW, _labelH)} • $_qty× • bitmap 203 DPI',
                ),
        ),
        _pathCard(
          path: 1,
          icon: Icons.receipt_long_outlined,
          title: 'Thermal Struk 58mm',
          subtitle: 'Printer struk yang sudah dipakai — label beruntun',
          preview: _selected.isEmpty
              ? null
              : _StrukPreview(
                  product: _selected.first,
                  sheet: this,
                ),
        ),        _pathCard(
          path: 2,
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF A4 (grid)',
          subtitle: 'Banyak label sekaligus, siap dipotong / dicetak printer umum',
          preview: _selected.isEmpty
              ? null
              : _A4GridPreview(
                  products: _selected,
                  sheet: this,
                ),
        ),
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _stepHeader(String num, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _selectAllRow() {
    return Row(
      children: [
        Checkbox(
          value: _filtered.isNotEmpty && _selectedIds.length == _all.length,
          onChanged: (v) => setState(() {
            if (v == true) {
              _selectedIds.addAll(_all.map((p) => p.id));
            } else {
              _selectedIds.clear();
            }
          }),
        ),
        const SizedBox(width: 8),
        Text(
          'Pilih Semua (${_selectedIds.length}/${_all.length})',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _productList() {
    // v2.2.57+121: tampilkan [_filtered] (filter live by nama/barcode).
    return Column(
      children: _filtered.map((p) {
        final sel = _selectedIds.contains(p.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? NusaConfig.activePrimary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: sel,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedIds.add(p.id);
                  } else {
                    _selectedIds.remove(p.id);
                  }
                }),
              ),
              NusaProductImage(
                imagePath: p.imagePath,
                width: 34,
                height: 34,
                borderRadius: BorderRadius.circular(6),
                placeholder: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.barcode}  •  ${formatRupiah(p.sellPrice)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Stepper qty cetak per produk (v2.2.57+121) — 1–999.
  Widget _qtyStepper({required int value, required ValueChanged<int> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? NusaConfig.darkSurface2
            : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: value < 999 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  /// Opsi ukuran label (v2.2.57+121) — (kode, lebar mm, tinggi mm).
  /// 0 = default thermal label 40×30mm (tanpa kode); sisanya = kode stiker
  /// label umum yang beredar (0,5×3,4cm = 5×34mm, dst) — user tinggal cocokkan
  /// kode di kemasan stiker dengan pilihan di sini.
  static const List<(int, double, double)> _labelSizes = [
    (0, 40, 30), // default thermal label
    (99, 5, 34),
    (100, 38, 100),
    (101, 50, 100),
    (102, 50, 50),
    (103, 32, 64),
    (104, 25, 76),
    (105, 25, 38),
    (106, 25, 25),
    (107, 19, 50),
    (108, 19, 38),
    (109, 13, 38),
    (110, 16, 22),
    (111, 13, 19),
    (112, 9, 13),
    (119, 102, 152),
    (120, 78, 118),
    (121, 38, 76),
    (122, 17, 85),
    (123, 12, 30),
    (124, 40, 57),
    (125, 17, 58),
    (126, 17, 100),
    (127, 25, 100),
  ];

  /// Label chip: kode (bila ada) + ukuran mm, mis. "105 · 25×38 mm".
  String _sizeLabel(int code, double w, double h) {
    final a = w == w.roundToDouble() ? w.toInt().toString() : w.toString();
    final b = h == h.roundToDouble() ? h.toInt().toString() : h.toString();
    return code == 0 ? '$a×$b mm' : '$code · $a×$b mm';
  }

  /// Label polos ukuran mm, mis. "40×30 mm" (dipakai caption preview).
  String _mmLabel(double w, double h) {
    final a = w == w.roundToDouble() ? w.toInt().toString() : w.toString();
    final b = h == h.roundToDouble() ? h.toInt().toString() : h.toString();
    return '$a×$b mm';
  }

  Widget _checkRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
  }) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? value)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  /// Slider ukuran font label (v2.2.57+116): 1.0× – 3.0×.
  Widget _fontSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(1.0, 3.0),
              min: 1.0,
              max: 3.0,
              divisions: 16,
              activeColor: NusaConfig.activePrimary,
              label: '${value.toStringAsFixed(1)}×',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${value.toStringAsFixed(1)}×',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? NusaConfig.darkTextPrimary
                    : NusaConfig.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu jalur cetak — KLIK untuk buka/tutup preview ACTUAL jalur tsb.
  /// Preview + tombol cetak muncul di dalam kartu saat terbuka.
  Widget _pathCard({
    required int path,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget? preview,
  }) {
    final expanded = _expandedPath == path;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expanded
              ? NusaConfig.activePrimary.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.grey.withValues(alpha: 0.06),
            leading: Icon(icon, color: NusaConfig.activePrimary),
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
            trailing: AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down),
            ),
            onTap: () {
              if (_selected.isEmpty) {
                TopToast.error(context, 'Pilih produk dulu');
                return;
              }
              setState(() {
                _expandedPath = expanded ? null : path;
                _status = '';
              });
            },
          ),
          if (expanded && preview != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkSurface2.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  preview,
                  const SizedBox(height: 12),
                  // Tombol cetak — ada DI DALAM preview (permintaan user).
                  FilledButton.icon(
                    onPressed: _printing
                        ? null
                        : () => _runPrint(path),
                    icon: _printing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            path == 2
                                ? Icons.share_outlined
                                : Icons.print_outlined,
                            size: 18,
                          ),
                    label: Text(
                      _printing
                          ? 'Mencetak…'
                          : path == 2
                              ? 'Buka PDF — Print / Simpan'
                              : 'Cetak ${_selected.length} Label',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path == 2
                        ? 'PDF dibuat dari render yang sama dengan preview — '
                            'share sheet Android bisa langsung Print ke printer umum.'
                        : 'Dikirim via Bluetooth ke printer yang tersimpan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Preview bitmap label — render ACTUAL via [LabelRenderer.renderLabelBitmap]
/// (SAMA dengan yang dikirim ke printer TSPL/struk). Dipakai jalur TSPL.
class _LabelBitmapPreview extends StatelessWidget {
  final Product product;
  final _LabelPrintSheetState sheet;
  final int dpi;
  final String paperNote;

  const _LabelBitmapPreview({
    required this.product,
    required this.sheet,
    required this.dpi,
    required this.paperNote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bitmap = sheet._renderFor(product, dpi);
    final pngBytes = Uint8List.fromList(img.encodePng(bitmap));
    final previewH = 140.0;
    final aspect = bitmap.width / bitmap.height;

    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.memory(
              pngBytes,
              height: previewH,
              width: previewH * aspect,
              gaplessPlayback: true,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          paperNote,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Preview jalur struk thermal — render ACTUAL selebar kertas (58/80mm,
/// barcode full-width) di atas visual kertas struk, lalu garis potong.
/// Preview = hasil cetak (render sama dengan _printEscPos).
class _StrukPreview extends StatefulWidget {
  final Product product;
  final _LabelPrintSheetState sheet;

  const _StrukPreview({required this.product, required this.sheet});

  @override
  State<_StrukPreview> createState() => _StrukPreviewState();
}

class _StrukPreviewState extends State<_StrukPreview> {
  img.Image? _bitmap;
  String? _paper;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StrukPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product ||
        oldWidget.sheet._nameScale != widget.sheet._nameScale ||
        oldWidget.sheet._priceScale != widget.sheet._priceScale ||
        oldWidget.sheet._showName != widget.sheet._showName ||
        oldWidget.sheet._showPrice != widget.sheet._showPrice ||
        oldWidget.sheet._showBarcode != widget.sheet._showBarcode) {
      _load();
    }
  }

  Future<void> _load() async {
    final bmp = await widget.sheet._renderForStruk(widget.product, LabelDpi.dpi203);
    final paper = await widget.sheet._paperMm();
    if (!mounted) return;
    setState(() {
      _bitmap = bmp;
      _paper = paper == 80 ? '80' : '58';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bitmap = _bitmap;
    if (bitmap == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final pngBytes = Uint8List.fromList(img.encodePng(bitmap));
    // Visual kertas struk: selebar bitmap (full paper width).
    final paperW = 190.0;
    final bitmapW = paperW;
    final bitmapH = bitmapW * bitmap.height / bitmap.width;

    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: paperW,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Image.memory(
                  pngBytes,
                  width: bitmapW,
                  height: bitmapH,
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 6),
                // Garis potong putus-putus (dari cutter printer struk).
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: _DashedLinePainter(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '✂ potong',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kertas ${_paper ?? '58'}mm • label selebar kertas • bit-image ESC/POS'
          '${widget.sheet._qty > 1 ? ' • ${widget.sheet._qty}×' : ''}',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Preview PDF A4 — replika lembar A4 yang akurat dengan layout yang SAMA
/// dengan PDF asli (grid 4×8, margin 8mm, gap 4mm, label 40×30mm).
/// Konten label (barcode/nama/harga) dirender sungguhan, bukan mockup —
/// skala per-lembar supaya terlihat seperti hasil cetak.
class _A4GridPreview extends StatelessWidget {
  final List<Product> products;
  final _LabelPrintSheetState sheet;

  const _A4GridPreview({required this.products, required this.sheet});

  static const _pageWmm = 210.0, _pageHmm = 297.0;
  static const _marginMm = 8.0, _gapMm = 4.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelW = sheet._labelW, labelH = sheet._labelH;
    // Hitung grid SAMA seperti _buildPdf (konsistensi preview = hasil).
    final cols =
        ((_pageWmm - 2 * _marginMm + _gapMm) / (labelW + _gapMm)).floor();
    final rows =
        ((_pageHmm - 2 * _marginMm + _gapMm) / (labelH + _gapMm)).floor();
    final perPage = cols * rows;
    final pages = ((products.length + perPage - 1) / perPage).ceil();
    final shown = products.take(perPage).toList();
    // Ukuran logis lembar; FittedBox mengecilkan agar muat selebar kartu.
    const sheetW = 380.0;
    final scale = sheetW / _pageWmm;
    final sheetH = _pageHmm * scale;

    return Column(
      children: [
        Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Container(
              width: sheetW,
              height: sheetH,
              padding: EdgeInsets.all(_marginMm * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: (i % cols) * (labelW + _gapMm) * scale,
                      top: (i ~/ cols) * (labelH + _gapMm) * scale,
                      width: labelW * scale,
                      height: labelH * scale,
                      child: _MiniLabel(
                        product: shown[i],
                        sheet: sheet,
                        scale: scale,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Lembar A4 • $cols×$rows label • '
          '${products.length} label → $pages ${pages > 1 ? 'halaman' : 'halaman'} '
          '(${labelW.toStringAsFixed(0)}×${labelH.toStringAsFixed(0)}mm)',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Satu label mini di dalam preview lembar A4 — konten ACTUAL (barcode
/// CODE128 + nama + harga) dirender sesuai isi label & ukuran font.
/// Layout = persis [LabelRenderer.pdfLabel] (preview = hasil PDF):
/// barcode selebar 90% label × tinggi 22% label, lalu nama (maks 2 baris),
/// lalu harga — semua center.
class _MiniLabel extends StatelessWidget {
  final Product product;
  final _LabelPrintSheetState sheet;
  final double scale;

  const _MiniLabel({
    required this.product,
    required this.sheet,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final showBarcode = sheet._showBarcode;
    final showName = sheet._showName;
    final showPrice = sheet._showPrice;
    final barcode = product.barcode ?? '';
    // Ukuran barcode SAMA dengan pdfLabel: lebar 90% label, tinggi 22%.
    final barW = sheet._labelW * scale * 0.9;
    final barH = sheet._labelH * scale * 0.22;
    final bars = showBarcode && barcode.trim().isNotEmpty
        ? LabelRenderer.barcodeBars(barcode, barW, barH)
        : const <bc.BarcodeElement>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
      ),
      padding: EdgeInsets.all(2 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barcode: SizedBox UKURAN PASTI = ruang koordinat bars →
          // painter tidak mungkin meluber keluar kotak (fix v2.2.57+116).
          if (bars.isNotEmpty)
            SizedBox(
              width: barW,
              height: barH,
              child: CustomPaint(
                painter: _BarPainter(bars),
                size: Size(barW, barH),
              ),
            ),
          if (bars.isNotEmpty && showName) SizedBox(height: 1.5 * scale),
          if (showName && product.name.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 1 * scale),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 7.5 * sheet._nameScale * scale / 2.6,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                  height: 1.1,
                ),
              ),
            ),
          if (showName && showPrice) SizedBox(height: 0.8 * scale),
          if (showPrice)
            Text(
              'Rp ${_fmtPrice(product.sellPrice)}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 8 * sheet._priceScale * scale / 2.6,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Painter barcode CODE128 dari [LabelRenderer.barcodeBars] (rendered SAMA
/// dengan print — bukan gambar placeholder).
class _BarPainter extends CustomPainter {
  final List<bc.BarcodeElement> bars;
  _BarPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    for (final el in bars) {
      if (el is bc.BarcodeBar && el.black) {
        canvas.drawRect(
          Rect.fromLTWH(el.left, el.top, el.width, el.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) =>
      oldDelegate.bars != bars;
}

/// Garis putus-putus (potongan kertas struk).
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashW = 6.0, gapW = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashW, 0), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
