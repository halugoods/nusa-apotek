import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/image_storage_service.dart';
import 'package:nusa_kasir/core/utils/bluetooth_utils.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Bottom sheet for managing Bluetooth thermal printer settings:
/// - Scan & connect to BT printers
/// - Logo upload (appears at top of receipt)
/// - Custom footer text
/// - Cash drawer auto-open toggle
/// - Test print
/// - Auto-print toggle (print automatically after transaction)
/// - Paper size selector (58mm / 80mm)
/// - Reprint last receipt
class PrinterSettingsSheet extends StatefulWidget {
  final String? currentAddress;
  final void Function(PrinterDevice device) onPrinterSelected;

  PrinterSettingsSheet({
    super.key,
    this.currentAddress,
    required this.onPrinterSelected,
  });

  static void show({
    required BuildContext context,
    String? currentAddress,
    required void Function(PrinterDevice device) onPrinterSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PrinterSettingsSheet(
        currentAddress: currentAddress,
        onPrinterSelected: onPrinterSelected,
      ),
    );
  }

  @override
  State<PrinterSettingsSheet> createState() => _PrinterSettingsSheetState();
}

class _PrinterSettingsSheetState extends State<PrinterSettingsSheet> {
  List<PrinterDevice> _devices = [];
  bool _scanning = false;
  String? _connecting;
  bool _autoPrint = false;
  String _paperSize = '58';
  bool _testPrinting = false;
  String? _connectedAddr;
  String? _storedAddr;
  bool _btEnabled = true; // assume true until checked

  // New settings
  bool _cashDrawerEnabled = false;
  String _footerText = '';
  String? _logoPath;
  bool _reprinting = false;

  // Kitchen printer (FnB)
  bool _kitchenPrinterEnabled = false;
  List<PrinterDevice> _kitchenDevices = [];
  bool _kitchenScanning = false;
  String? _kitchenConnecting;
  String? _kitchenConnectedAddr;
  String? _kitchenStoredAddr;

  final _footerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _storedAddr = widget.currentAddress;
    if (_storedAddr != null && _storedAddr!.contains('|')) {
      _connectedAddr = _storedAddr!.split('|').last;
    }
    _loadSettings();
    _scan();
  }

  @override
  void dispose() {
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final auto = await SecureStore.getAutoPrint();
    final paper = await SecureStore.getPaperSize();
    final drawer = await SecureStore.getCashDrawerEnabled();
    final footer = await SecureStore.getPrinterFooter();
    final logo = await SecureStore.getPrinterLogoPath();
    final kitchenEnabled = await SecureStore.getKitchenPrinterEnabled();
    final kitchenAddr = await SecureStore.getKitchenPrinterAddress();
    if (mounted) {
      setState(() {
        _autoPrint = auto;
        _paperSize = paper;
        _cashDrawerEnabled = drawer;
        _footerText = footer;
        _footerCtrl.text = footer;
        _logoPath = logo;
        _kitchenPrinterEnabled = kitchenEnabled;
        if (kitchenAddr != null && kitchenAddr.contains('|')) {
          _kitchenStoredAddr = kitchenAddr;
          _kitchenConnectedAddr = kitchenAddr.split('|').last;
        }
      });
      ReceiptPrinter.setCashDrawer(enabled: drawer);
      ReceiptPrinter.setFooter(footer);
      if (logo != null) ReceiptPrinter.loadLogo(logo);
    }
  }

  Future<void> _setAutoPrint(bool v) async {
    await SecureStore.setAutoPrint(v);
    if (mounted) setState(() => _autoPrint = v);
  }

  Future<void> _setPaperSize(String v) async {
    await SecureStore.setPaperSize(v);
    if (mounted) setState(() => _paperSize = v);
  }

  Future<void> _setCashDrawer(bool v) async {
    await SecureStore.setCashDrawerEnabled(v);
    ReceiptPrinter.setCashDrawer(enabled: v);
    if (mounted) setState(() => _cashDrawerEnabled = v);
  }

  Future<void> _saveFooter() async {
    final text = _footerCtrl.text.trim();
    await SecureStore.setPrinterFooter(text);
    ReceiptPrinter.setFooter(text);
    if (mounted) setState(() => _footerText = text);
    TopToast.success(context, 'Footer tersimpan');
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(result.files.single.name);
      final destName = 'printer_logo_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(dir.path, destName);
      await File(destPath).writeAsBytes(bytes);

      await ReceiptPrinter.loadLogo(destPath);
      await SecureStore.setPrinterLogoPath(destPath);
      if (mounted) {
        setState(() => _logoPath = destPath);
        TopToast.success(context, 'Logo disimpan');
      }

      // Upload to cloud
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          ImageStorageService(Supabase.instance.client, uid)
              .uploadImage('settings', destPath);
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal menyimpan logo');
    }
  }

  Future<void> _removeLogo() async {
    _logoPath = null;
    await ReceiptPrinter.loadLogo(null);
    await SecureStore.setPrinterLogoPath(null);
    if (mounted) {
      setState(() {});
      TopToast.success(context, 'Logo dihapus');
    }
  }

  Future<void> _scan() async {
    // 1. Check runtime permissions first (Android 12+ critical)
    final hasPerms = await BluetoothUtils.hasBluetoothPermissions();
    if (!hasPerms) {
      if (mounted) {
        final grant = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Izin Bluetooth Diperlukan'),
            content: Text(
              'Aplikasi memerlukan izin Bluetooth untuk menemukan printer thermal.\n\n'
              'Anda akan diminta memberikan izin. Silakan pilih "Izinkan" pada dialog berikutnya.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Lanjutkan'),
              ),
            ],
          ),
        );
        if (grant == true) {
          final granted = await BluetoothUtils.requestBluetoothPermissions();
          if (mounted) setState(() {});
          if (!granted) return; // user denied
        } else {
          return; // user chose "Nanti"
        }
      }
    }

    // 2. Check Bluetooth state
    final btOn = await BluetoothUtils.isBluetoothEnabled();
    if (mounted) setState(() => _btEnabled = btOn);

    if (!btOn) {
      // Show dialog asking user to enable Bluetooth
      if (mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Bluetooth Diperlukan'),
            content: Text(
              'Bluetooth belum aktif. Printer thermal membutuhkan Bluetooth untuk terhubung.\n\n'
              'Aktifkan Bluetooth sekarang?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Aktifkan'),
              ),
            ],
          ),
        );
        if (enable == true) {
          await BluetoothUtils.requestBluetoothEnable();
          // Wait a moment for BT to turn on, then check again
          await Future.delayed(Duration(seconds: 1));
          final btOnAfter = await BluetoothUtils.isBluetoothEnabled();
          if (mounted) setState(() => _btEnabled = btOnAfter);
        }
      }
      if (!_btEnabled) return;
    }

    setState(() => _scanning = true);
    final printer = ReceiptPrinter();
    try {
      final devices = await printer.discover();
      if (mounted) setState(() => _devices = devices);
    } finally {
      await printer.dispose();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() => _connecting = device.address);
    final printer = ReceiptPrinter();
    try {
      await printer.connect(device);
      widget.onPrinterSelected(device);
      if (mounted) {
        setState(() {
          _connectedAddr = device.address;
          _storedAddr = '${device.name}|${device.address}';
        });
        TopToast.success(context, 'Terhubung ke ${device.name}');
      }
    } catch (_) {
      if (mounted) {
        TopToast.error(context, 'Gagal menyambung ke printer');
      }
    } finally {
      await printer.dispose();
      if (mounted) setState(() => _connecting = null);
    }
  }

  Future<void> _testPrint() async {
    if (_storedAddr == null || !_storedAddr!.contains('|')) {
      TopToast.error(context, 'Hubungkan printer terlebih dahulu');
      return;
    }

    setState(() => _testPrinting = true);
    final printer = ReceiptPrinter();
    try {
      if (!await ReceiptPrinter.ensureBluetoothReady()) {
        if (mounted) TopToast.error(context, 'Bluetooth tidak siap. Periksa izin pengaturan.');
        return;
      }
      final devices = await printer.discover();
      if (devices.isEmpty) {
        if (mounted) TopToast.error(context, 'Tidak ada printer ditemukan');
        return;
      }

      final savedAddr = _storedAddr!.split('|').last;
      final found = devices.where((d) => d.address == savedAddr);
      if (found.isEmpty) {
        if (mounted) {
          TopToast.error(context, 'Printer tidak ditemukan. Silakan pindai ulang.');
        }
        return;
      }

      await printer.connect(found.first);
      final ok = await printer.printTest('NUSA Kasir', paperWidth: _paperSize);
      if (mounted) {
        if (ok) {
          TopToast.success(context, 'Test print berhasil dikirim');
        } else {
          TopToast.error(context, 'Gagal mengirim test print');
        }
      }
    } catch (_) {
      if (mounted) {
        TopToast.error(context, 'Gagal mencetak: pastikan printer menyala dan terhubung');
      }
    } finally {
      await printer.dispose();
      if (mounted) setState(() => _testPrinting = false);
    }
  }

  Future<void> _reprintLast() async {
    if (ReceiptPrinter.lastPrint == null) {
      TopToast.error(context, 'Belum ada struk terakhir');
      return;
    }
    if (_storedAddr == null || !_storedAddr!.contains('|')) {
      TopToast.error(context, 'Hubungkan printer terlebih dahulu');
      return;
    }
    setState(() => _reprinting = true);
    final printer = ReceiptPrinter();
    try {
      if (!await ReceiptPrinter.ensureBluetoothReady()) {
        if (mounted) TopToast.error(context, 'Bluetooth tidak siap. Periksa izin pengaturan.');
        return;
      }
      final devices = await printer.discover();
      final savedAddr = _storedAddr!.split('|').last;
      final found = devices.where((d) => d.address == savedAddr);
      if (found.isEmpty) {
        if (mounted) TopToast.error(context, 'Printer tidak ditemukan');
        return;
      }
      await printer.connect(found.first);
      final ok = await printer.printLastReceipt();
      if (mounted) {
        if (ok) {
          TopToast.success(context, 'Struk terakhir dicetak ulang');
        } else {
          TopToast.error(context, 'Gagal cetak ulang');
        }
      }
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal cetak ulang');
    } finally {
      await printer.dispose();
      if (mounted) setState(() => _reprinting = false);
    }
  }

  // ── Kitchen printer (FnB) ──

  Future<void> _setKitchenPrinterEnabled(bool v) async {
    await SecureStore.setKitchenPrinterEnabled(v);
    if (mounted) setState(() => _kitchenPrinterEnabled = v);
    if (v) _kitchenScan();
  }

  Future<void> _kitchenScan() async {
    // Reuse the same Bluetooth permission/state flow
    final hasPerms = await BluetoothUtils.hasBluetoothPermissions();
    if (!hasPerms) {
      if (mounted) {
        final grant = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Izin Bluetooth Diperlukan'),
            content: Text('Aplikasi memerlukan izin Bluetooth untuk menemukan printer dapur.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Nanti')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Lanjutkan')),
            ],
          ),
        );
        if (grant == true) {
          await BluetoothUtils.requestBluetoothPermissions();
        } else {
          return;
        }
      }
    }

    final btOn = await BluetoothUtils.isBluetoothEnabled();
    if (!btOn) return;

    setState(() => _kitchenScanning = true);
    final printer = ReceiptPrinter();
    try {
      final devices = await printer.discover();
      if (mounted) setState(() => _kitchenDevices = devices);
    } finally {
      await printer.dispose();
      if (mounted) setState(() => _kitchenScanning = false);
    }
  }

  Future<void> _kitchenConnect(PrinterDevice device) async {
    setState(() => _kitchenConnecting = device.address);
    final printer = ReceiptPrinter();
    try {
      await printer.connect(device);
      // Store as "name|address" format matching main printer
      final addr = '${device.name}|${device.address}';
      await SecureStore.setKitchenPrinterAddress(addr);
      if (mounted) {
        setState(() {
          _kitchenConnectedAddr = device.address;
          _kitchenStoredAddr = addr;
          _kitchenConnecting = null;
        });
        TopToast.success(context, 'Terhubung ke printer dapur: ${device.name}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _kitchenConnecting = null);
        TopToast.error(context, 'Gagal menyambung ke printer dapur');
      }
    } finally {
      await printer.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final subColor = isDark ? Color(0xFF94A3B8) : Color(0xFF6B7280);
    final borderColor = isDark ? Color(0xFF3A3A52) : Color(0xFFF3F4F6);
    final accentRed = Color(0xFFE63946);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDark ? Color(0xFF3A3A52) : Color(0xFFE5E7EB),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Printer Bluetooth',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    SizedBox(height: 4),
                    Text(
                      'Atur printer thermal untuk mencetak struk',
                      style: TextStyle(fontSize: 13, color: subColor),
                    ),
                  ],
                ),
              ),
              if (_connectedAddr != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: NusaConfig.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('Terhubung',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NusaConfig.accentGreen)),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),

          // ── Scrollable settings area ──
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Auto-print toggle ──
                  _settingRow(
                    icon: Icons.auto_awesome,
                    title: 'Cetak Otomatis',
                    subtitle: 'Langsung cetak struk setelah transaksi',
                    borderColor: borderColor,
                    subColor: subColor,
                    textColor: textColor,
                    trailing: Switch(
                      value: _autoPrint,
                      activeColor: accentRed,
                      onChanged: _setAutoPrint,
                    ),
                  ),
                  SizedBox(height: 8),

                  // ── Cash drawer toggle ──
                  _settingRow(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Buka Laci Uang Otomatis',
                    subtitle: 'Buka cash drawer setelah cetak struk',
                    borderColor: borderColor,
                    subColor: subColor,
                    textColor: textColor,
                    trailing: Switch(
                      value: _cashDrawerEnabled,
                      activeColor: accentRed,
                      onChanged: _setCashDrawer,
                    ),
                  ),
                  SizedBox(height: 8),

                  // ── Paper size selector ──
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.view_agenda_outlined, size: 20, color: subColor),
                        SizedBox(width: 10),
                        Text('Ukuran Kertas',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textColor)),
                        Spacer(),
                        _paperChip('58mm', selected: _paperSize == '58', isDark: isDark),
                        SizedBox(width: 6),
                        _paperChip('80mm', selected: _paperSize == '80', isDark: isDark),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // ── Logo ──
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined, size: 20, color: subColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Logo Struk',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                              Text(_logoPath != null ? 'Logo tersimpan' : 'Opsional — tampil di atas struk',
                                  style: TextStyle(fontSize: 11, color: subColor)),
                            ],
                          ),
                        ),
                        if (_logoPath != null)
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: _removeLogo,
                            tooltip: 'Hapus logo',
                          ),
                        TextButton(
                          onPressed: _pickLogo,
                          child: Text(_logoPath != null ? 'Ganti' : 'Pilih',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // ── Footer ──
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.text_fields, size: 20, color: subColor),
                          SizedBox(width: 10),
                          Text('Footer Struk',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                        ]),
                        SizedBox(height: 8),
                        TextField(
                          controller: _footerCtrl,
                          maxLines: 2,
                          onChanged: (_) => _saveFooter(),
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Contoh: Jam operasional 08:00–22:00',
                            hintStyle: TextStyle(fontSize: 12, color: subColor),
                            isDense: true,
                            contentPadding: EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: accentRed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // ── Buttons row ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _scanning ? null : _scan,
                          icon: _scanning
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.bluetooth_searching, size: 18),
                          label: Text(_scanning ? 'Memindai...' : 'Pindai'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_testPrinting || _connectedAddr == null) ? null : _testPrint,
                          icon: _testPrinting
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.print, size: 18),
                          label: Text(_testPrinting ? 'Mencetak...' : 'Test Print'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _connectedAddr != null ? accentRed : subColor,
                            side: BorderSide(color: _connectedAddr != null ? accentRed : borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Reprint button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_reprinting || _connectedAddr == null || ReceiptPrinter.lastPrint == null) ? null : _reprintLast,
                      icon: _reprinting
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.replay, size: 18),
                      label: Text(_reprinting ? 'Mencetak...' : 'Cetak Ulang Struk Terakhir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentRed,
                        side: BorderSide(color: accentRed.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // ── Kitchen printer (FnB only) ──
                  if (NusaConfig.isFnbVariant) ...[
                    Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                        color: accentRed.withValues(alpha: 0.04),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(Icons.kitchen_outlined, size: 20, color: accentRed),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Printer Dapur',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor)),
                                    SizedBox(height: 2),
                                    Text('Cetak pesanan langsung ke dapur',
                                        style: TextStyle(fontSize: 11, color: subColor)),
                                  ],
                                ),
                              ),
                              if (_kitchenConnectedAddr != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('Terhubung',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: NusaConfig.accentGreen)),
                                ),
                            ],
                          ),
                          SizedBox(height: 10),

                          // Enable toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Aktifkan Printer Dapur',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                            value: _kitchenPrinterEnabled,
                            activeColor: accentRed,
                            onChanged: _setKitchenPrinterEnabled,
                          ),

                          // Show scanner + device list only when enabled
                          if (_kitchenPrinterEnabled) ...[
                            SizedBox(height: 6),

                            // Scan button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _kitchenScanning ? null : _kitchenScan,
                                icon: _kitchenScanning
                                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.bluetooth_searching, size: 16),
                                label: Text(_kitchenScanning ? 'Memindai...' : 'Pindai Printer Dapur',
                                    style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textColor,
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),

                            // Kitchen device list
                            if (_kitchenDevices.isNotEmpty)
                              ..._kitchenDevices.map((d) {
                                final isConnecting = _kitchenConnecting == d.address;
                                final isCurrent = _kitchenConnectedAddr == d.address;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    onTap: isConnecting ? null : () => _kitchenConnect(d),
                                    child: Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isCurrent ? accentRed : borderColor),
                                        color: isCurrent ? accentRed.withValues(alpha: 0.06) : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.print, size: 18, color: isCurrent ? accentRed : subColor),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(d.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textColor)),
                                                Text(d.address, style: TextStyle(fontSize: 10, color: subColor)),
                                              ],
                                            ),
                                          ),
                                          if (isCurrent) Icon(Icons.check_circle, size: 18, color: accentRed),
                                          if (isConnecting) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                          if (!isCurrent && !isConnecting)
                                            Text('Pilih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentRed)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            if (_kitchenDevices.isEmpty && !_kitchenScanning && _kitchenPrinterEnabled)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: subColor),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tidak ada printer ditemukan. Pastikan printer dapur menyala dan dalam mode pairing.',
                                        style: TextStyle(fontSize: 11, color: subColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Empty state with BT guidance ──
                  if (_devices.isEmpty && !_scanning)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.print_disabled, size: 48, color: subColor),
                          SizedBox(height: 8),
                          Text('Tidak ada printer ditemukan',
                              style: TextStyle(fontSize: 14, color: subColor)),
                          SizedBox(height: 4),
                          Text(
                            _btEnabled
                                ? 'Pastikan printer menyala, dalam mode pairing,\ndan izin Bluetooth sudah diizinkan di Pengaturan'
                                : 'Bluetooth saat ini mati. Nyalakan untuk memindai printer',
                            style: TextStyle(fontSize: 11, color: subColor),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          if (!_btEnabled) ...[
                            SizedBox(
                              width: 200,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await BluetoothUtils.requestBluetoothEnable();
                                  await Future.delayed(Duration(seconds: 2));
                                  _scan();
                                },
                                icon: Icon(Icons.bluetooth, size: 16),
                                label: Text('Nyalakan Bluetooth'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: NusaConfig.activePrimary,
                                  side: BorderSide(color: NusaConfig.activePrimary.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextButton(
                              onPressed: () => BluetoothUtils.openBluetoothSettings(),
                              child: Text('Buka Pengaturan Bluetooth',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          if (_btEnabled) ...[
                            TextButton(
                              onPressed: () => BluetoothUtils.openAppSettings(),
                              child: Text('Periksa Izin Aplikasi',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Device list
                  if (_devices.isNotEmpty)
                    ..._devices.map((d) {
                      final isConnecting = _connecting == d.address;
                      final isCurrent = _connectedAddr == d.address;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: isConnecting ? null : () => _connect(d),
                          child: Container(
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isCurrent ? accentRed : borderColor),
                              color: isCurrent ? accentRed.withValues(alpha: 0.06) : null,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.print, size: 22, color: isCurrent ? accentRed : subColor),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                                      Text(d.address, style: TextStyle(fontSize: 11, color: subColor)),
                                    ],
                                  ),
                                ),
                                if (isCurrent) Icon(Icons.check_circle, size: 20, color: Color(0xFFE63946)),
                                if (isConnecting) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                if (!isCurrent && !isConnecting)
                                  Text('Hubungkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentRed)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color borderColor,
    required Color subColor,
    required Color textColor,
    required Widget trailing,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: subColor),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: subColor)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _paperChip(String label, {required bool selected, required bool isDark}) {
    return GestureDetector(
      onTap: () => _setPaperSize(label == '58mm' ? '58' : '80'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Color(0xFFE63946).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Color(0xFFE63946)
                : (isDark ? Color(0xFF3A3A52) : Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Color(0xFFE63946) : (isDark ? Color(0xFF94A3B8) : Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }
}
