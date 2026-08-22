import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listener barcode eksternal (HID / USB / Bluetooth scanner keyboard wedge)
/// — v2.2.45. Scanner bertingkah seperti keyboard: ia "mengetik" karakter
/// cepat lalu kirim Enter. Komponen ini menangkap input itu di level Focus
/// TANPA TextInput connection → keypad layar TIDAK muncul.
///
/// KOREKSI v2.2.45 (bug "form sheet tak bisa diketik"):
/// Versi lama meng-`handled` SEMUA karakter alfanumerik → di form sheet, saat
/// field teks fokus, walk leaf→root melewati node ini dan karakter typing
/// user ikut di-handle → tak pernah sampai ke field. Itu akar "ngetik ketahan".
///
/// Sekarang:
///  1. **Pembeda scan vs ketik manual** — scanner HID mengirim karakter jauh
///     lebih cepat daripada manusia. Karakter pertama scan di-"pending"
///     (di-`ignored` → tetap masuk ke field kalau ada field fokus, tidak
///     mengganggu typing). Kalau karakter KEDUA datang < ~60ms → baru dianggap
///     scan: pending + karakter itu masuk buffer, sisanya di-handle. Ketikan
///     manual (jeda > 60ms) terus di-`ignored` → diteruskan ke field/IME.
///  2. **TIDAK merebut fokus dari field** — user tap field → field fokus →
///     typing jalan normal. Listener tetap menangkap scan karena Focus ini
///     adalah ANCESTOR dari field-field di dalamnya (walk leaf→root melewati
///     node ini).
///  3. **Scan tanpa field fokus tetap jalan** — saat tidak ada field fokus,
///     node ini memegang fokus utama (autofocus + re-request saat fokus
///     jatuh ke null) → scan tertangkap dari detik pertama.
///  4. **Enter menyelesaikan buffer** — scanner mengirim Enter di akhir.
///     Buffer kosong = Enter dari user (submit form) → diabaikan.
///  5. **Backspace** hanya di-handle kalau buffer terisi; kalau kosong
///     diteruskan ke field (hapus karakter normal).
///
/// Karakter yang didukung: alfanumerik (0-9, A-Z, a-z) + simbol umum barcode
/// (`-`, `+`, `/`, `_`). Buffer ~64 karakter; timer 3 detik — jika tanpa
/// Enter maka di-flush otomatis.
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

  /// Ambil fokus utama saat listener dipasang (post-frame) dan re-request
  /// saat fokus jatuh ke null. Default true — scan jalan di mana pun, termasuk
  /// layar tanpa field teks. Tetap AMAN untuk form: field teks yang di-tap
  /// user selalu menang merebut fokus, dan ketikan tidak pernah di-handle
  /// (lihat deteksi burst di atas).
  final bool autofocus;

  const HidBarcodeListener({
    super.key,
    required this.onBarcode,
    required this.child,
    this.autofocus = true,
  });

  @override
  State<HidBarcodeListener> createState() => _HidBarcodeListenerState();
}

class _HidBarcodeListenerState extends State<HidBarcodeListener> {
  final FocusNode _focus = FocusNode();
  final StringBuffer _buf = StringBuffer();
  Timer? _timer;

  /// Interval antar karakter scanner HID (ms). Manusia mengetik ≥ 120ms;
  /// scanner mengirim 5-30ms. Ambang 60ms membedakan keduanya dengan aman.
  static const int _burstThresholdMs = 60;

  /// Waktu karakter terakhir diterima (untuk deteksi burst).
  DateTime? _lastKeyAt;

  /// Karakter pertama yang "mengintip" — belum bisa dipastikan scan atau
  /// ketikan. Disimpan lalu di-`ignored`; kalau karakter berikutnya datang
  /// < threshold → ini scan, pending ikut masuk buffer (barcode TIDAK
  /// kehilangan karakter pertama).
  String? _pendingFirst;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      // Scan jalan dari detik pertama walau belum ada field yang di-tap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
      // Kalau fokus jatuh ke null (mis. user tap area non-field), ambil lagi
      // supaya scan berikutnya tetap tertangkap. Field teks selalu menang
      // karena requestFocus field mengalahkan node ini.
      FocusManager.instance.addListener(_onFocusManagerChanged);
    }
  }

  @override
  void dispose() {
    if (widget.autofocus) {
      FocusManager.instance.removeListener(_onFocusManagerChanged);
    }
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusManagerChanged() {
    if (!mounted) return;
    if (FocusManager.instance.primaryFocus == null && widget.autofocus) {
      _focus.requestFocus();
    }
  }

  void _push(String ch) {
    _timer?.cancel();
    if (_buf.length >= 64) _buf.clear();
    _buf.write(ch);
    // Reset timer: barcode yang tanpa Enter akan di-flush setelah jeda 3 dtk.
    _timer = Timer(const Duration(milliseconds: 3000), _flush);
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_buf.isEmpty) return;
    final code = _buf.toString();
    _buf.clear();
    _pendingFirst = null;
    _lastKeyAt = null;
    widget.onBarcode(code);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Enter / NumpadEnter → selesaikan barcode (hanya kalau ada buffer).
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_buf.isNotEmpty) {
        _flush();
        return KeyEventResult.handled;
      }
      // Buffer kosong = Enter dari user (mis. submit form) — biarkan lewat.
      _pendingFirst = null;
      return KeyEventResult.ignored;
    }
    // Backspace → hapus karakter terakhir buffer (perbaikan scan salah).
    if (key == LogicalKeyboardKey.backspace) {
      if (_buf.isNotEmpty) {
        final s = _buf.toString();
        if (s.length > 1) {
          _buf.clear();
          _buf.write(s.substring(0, s.length - 1));
        } else {
          _buf.clear();
        }
        return KeyEventResult.handled;
      }
      // Buffer kosong = Backspace dari user (edit field) — biarkan lewat.
      return KeyEventResult.ignored;
    }

    final label = event.character;
    if (label != null && label.isNotEmpty) {
      final ch = label[0];
      if (RegExp(r'^[0-9A-Za-z\-+/_]$').hasMatch(ch)) {
        // ── Sedang dalam scan (buffer terisi) → lanjutkan buffer apa pun
        // kecepatannya (toleransi scanner lambat di tengah barcode).
        if (_buf.isNotEmpty) {
          _push(ch);
          return KeyEventResult.handled;
        }

        final now = DateTime.now();
        final gapMs = _lastKeyAt == null
            ? 9999
            : now.difference(_lastKeyAt!).inMilliseconds;
        _lastKeyAt = now;

        if (gapMs <= _burstThresholdMs) {
          // Karakter kedua datang cepat → ini scan. Masukkan karakter
          // pertama yang tadi di-ignored ke buffer supaya barcode utuh.
          if (_pendingFirst != null) {
            _push(_pendingFirst!);
            _pendingFirst = null;
          }
          _push(ch);
          return KeyEventResult.handled;
        }

        // Jeda normal (ketikan user / karakter pertama scan): pending dulu,
        // tetap di-ignored → karakter sampai ke field kalau ada field fokus.
        _pendingFirst = ch;
        return KeyEventResult.ignored;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      // Tidak memakai autofocus milik Focus sendiri — kita request fokus
      // manual (post-frame) + re-request saat primary focus null, supaya
      // field teks yang di-tap user tetap menang tanpa perlombaan.
      autofocus: false,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
