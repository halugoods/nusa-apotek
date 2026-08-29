import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/label/label_commands.dart';
import 'package:nusa_kasir/core/label/label_renderer.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/shared/widgets/nusa_product_image.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Alur Cetak Label Barcode (v2.2.57+115, Area B) — 3 langkah:
///   1. Pilih produk (checkbox, "Pilih Semua")
///   2. Pilih ISI label (checkbox: Nama / Harga / Barcode — bebas kombinasi)
///   3. Pilih JALUR cetak:
///      a. Thermal Label (TSPL) — printer label khusus, kompatibel semua merk
///      b. Thermal Struk 58mm (ESC/POS) — printer struk yang sudah dimiliki
///      c. PDF A4 grid — unduh/share, siap dipotong
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

  // ── Step 2: isi label ──
  bool _showName = true;
  bool _showPrice = true;
  bool _showBarcode = true;

  // ── Step 3: jalur cetak ──
  bool _printing = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
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

  // ── Render ──

  double get _labelW => LabelRenderer.defaultWidthMm; // 40
  double get _labelH => LabelRenderer.defaultHeightMm; // 30

  /// Render label bitmap untuk SATU produk (dipakai TSPL + ESC/POS).
  img.Image _renderFor(Product p, int dpi) {
    return LabelRenderer.renderLabelBitmap(
      barcode: p.barcode ?? '',
      name: p.name,
      price: p.sellPrice,
      showName: _showName,
      showPrice: _showPrice,
      showBarcode: _showBarcode,
      widthPx: LabelRenderer.mmToPx(_labelW, dpi: dpi).round(),
      heightPx: LabelRenderer.mmToPx(_labelH, dpi: dpi).round(),
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
      buf.add(
        LabelCommands.buildEscPosLabel(
          bitmap: _renderFor(p, LabelDpi.dpi203),
          name: p.name,
          price: p.sellPrice,
          showName: _showName,
          showPrice: _showPrice,
        ),
      );
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
    const pageW = 210.0, pageH = 297.0;
    const marginMm = 8.0, gapMm = 4.0;
    final cols =
        ((pageW - 2 * marginMm + gapMm) / (_labelW + gapMm)).floor();
    final rows =
        ((pageH - 2 * marginMm + gapMm) / (_labelH + gapMm)).floor();
    final perPage = cols * rows;

    for (var i = 0; i < _selected.length; i += perPage) {
      final end =
          i + perPage > _selected.length ? _selected.length : i + perPage;
      final pageItems = _selected.sublist(i, end);
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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold('Cetak Label Barcode', _buildBody());
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepHeader('1', 'Pilih Produk (ber-barcode)'),
        _selectAllRow(),
        const SizedBox(height: 8),
        if (_all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Tidak ada produk dengan barcode.\nTambahkan barcode di Form Produk dulu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ),
          )
        else
          _productList(),
        const SizedBox(height: 20),

        _stepHeader('2', 'Isi Label'),
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
        const SizedBox(height: 20),

        _stepHeader('3', 'Cara Cetak'),
        _pathCard(
          icon: Icons.print_outlined,
          title: 'Thermal Label (TSPL)',
          subtitle: 'Printer label khusus — Rongta/HPRT/Godex/BluePrint',
          onTap: _printTspl,
        ),
        _pathCard(
          icon: Icons.receipt_long_outlined,
          title: 'Thermal Struk 58mm',
          subtitle: 'Printer struk yang sudah dipakai — label beruntun',
          onTap: _printEscPos,
        ),
        _pathCard(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF A4 (grid)',
          subtitle: 'Banyak label sekaligus, siap dipotong',
          onTap: _sharePdf,
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
          value: _all.isNotEmpty && _selectedIds.length == _all.length,
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
    return Column(
      children: _all.map((p) {
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
                    color: Colors.grey.withOpacity(0.15),
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

  Widget _pathCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<bool> Function() onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey.withOpacity(0.06),
        leading: Icon(icon, color: NusaConfig.activePrimary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: _printing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: () async {
          if (_selected.isEmpty) {
            TopToast.error(context, 'Pilih produk dulu');
            return;
          }
          setState(() {
            _printing = true;
            _status = 'Mencetak ${_selected.length} label…';
          });
          final ok = await onTap();
          if (mounted) {
            setState(() {
              _printing = false;
              _status = ok
                  ? 'Selesai — ${_selected.length} label dikirim.'
                  : 'Gagal mencetak. Periksa printer & Bluetooth.';
            });
          }
        },
      ),
    );
  }
}
