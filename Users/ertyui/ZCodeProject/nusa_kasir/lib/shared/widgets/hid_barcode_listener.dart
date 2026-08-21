import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listener barcode eksternal (HID / USB / Bluetooth scanner keyboard wedge)
/// — v2.2.43. Scanner bertingkah seperti keyboard: ia "mengetik" karakter cepat
/// lalu kirim Enter. Komponen ini menangkap input itu di level Focus (TANPA
/// TextInput connection → keypad layar TIDAK muncul), supaya scan barcode jalan
/// OTOMATIS di mana pun layar berada, tidak perlu tap field pencarian dulu.
///
/// Karakter yang didukung: alfanumerik (0-9, A-Z, a-z) + simbol umum barcode
/// (`-`, `+`, `/`, `_`). Buffer ~64 karakter; timer 3 detik — jika tanpa Enter
/// (mis. scanner hanya dengan enter di akhir) maka di-flush otomatis.
///
/// Pakai:
/// ```dart
/// HidBarcodeListener(
///   onBarcode: (code) => _handleScan(code),
///   child: Scaffold(...), // atau konten layar
/// )
/// ```
class HidBarcodeListener extends StatefulWidget {
  /// Dipanggil saat satu barcode selesai (selesai oleh Enter / timeout).
  final ValueChanged<String> onBarcode;

  /// Konten yang dibungkus. Fokus ditaruh di node ini (bukan di field pencarian)
  /// agar scanner HID jalan tanpa user men-tap apa pun.
  final Widget child;

  const HidBarcodeListener({
    super.key,
    required this.onBarcode,
    required this.child,
  });

  @override
  State<HidBarcodeListener> createState() => _HidBarcodeListenerState();
}

class _HidBarcodeListenerState extends State<HidBarcodeListener> {
  final FocusNode _focus = FocusNode();
  final StringBuffer _buf = StringBuffer();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _push(String ch) {
    _timer?.cancel();
    if (_buf.length >= 64) _buf.clear();
    _buf.write(ch);
    // Reset timer: barcode berikutnya yang tanpa Enter akan di-flush setelah
    // jeda 3 detik penuh (bukan langsung).
    _timer = Timer(const Duration(milliseconds: 3000), _flush);
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_buf.isEmpty) return;
    final code = _buf.toString();
    _buf.clear();
    widget.onBarcode(code);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Enter / NumpadEnter → selesaikan barcode.
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _flush();
      return KeyEventResult.handled;
    }
    // Backspace → hapus karakter terakhir buffer (perbaikan scan salah).
    if (key == LogicalKeyboardKey.backspace) {
      final s = _buf.toString();
      if (s.isNotEmpty) _buf.clear();
      if (s.length > 1) _buf.write(s.substring(0, s.length - 1));
      return KeyEventResult.handled;
    }

    // Karakter yang bisa muncul di barcode.
    // KeyCode (bukan logicalKey) karena scanner HID kadang kirim key dengan
    // logicalKey = unlabeled untuk simbol. Cek char dari keyLabel / keyId.
    final label = event.character;
    if (label != null && label.isNotEmpty) {
      final ch = label[0];
      if (RegExp(r'^[0-9A-Za-z\-+/_]$').hasMatch(ch)) {
        _push(ch);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      // Jangan biarkan Focus berebut fokus dengan field teks yang memang
      // di-fokus user. `descendantsAreFocusable` tetap true; field tetap bisa
      // di-tap. Fokus global kita hanya menangkap karakter yang tidak dipakai
      // field (Enter yang dipakai field pencarian sudah punya onSubmit sendiri,
      // tapi scan di field pencarian juga sudah didukung byBarcode).
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}