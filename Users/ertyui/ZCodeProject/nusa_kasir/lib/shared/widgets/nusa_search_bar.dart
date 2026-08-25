import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Search bar standar NUSA (v2.2.54) — replika style search bar menu Kasir:
/// pill radius 20 TANPA outline, bayangan lembut yang menyala warna primary
/// saat fokus, ikon `search_rounded` 22, tombol scanner ungu (opsional),
/// tombol clear otomatis saat ada teks.
///
/// Satu sumber kebenaran styling — semua layar pencarian memakai widget ini
/// supaya konsisten di 8 varian (audit v2.2.54: sebelumnya 20 lokasi dengan
/// 4 pola berbeda).
///
/// Scanner HID: [textInputAction] default [TextInputAction.newline] +
/// [onSubmit] dipanggil dengan isi field — pola yang sama dengan Kasir agar
/// scan beruntun tidak menutup keyboard.
class NusaSearchBar extends StatefulWidget {
  const NusaSearchBar({
    super.key,
    this.controller,
    this.hint = 'Cari...',
    this.onChanged,
    this.onSubmit,
    this.showScanner = false,
    this.onScan,
    this.suffix,
    this.autofocus = false,
    this.textInputAction = TextInputAction.newline,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  /// Dipanggil saat user submit (enter / scanner HID suffix) dengan isi field.
  final ValueChanged<String>? onSubmit;

  /// Tampilkan tombol scanner barcode di kanan (warna primary).
  final bool showScanner;
  final VoidCallback? onScan;

  /// Widget tambahan setelah tombol scanner (mis. CustomerPickerButton kecil).
  final Widget? suffix;
  final bool autofocus;
  final TextInputAction textInputAction;
  final bool enabled;

  @override
  State<NusaSearchBar> createState() => _NusaSearchBarState();
}

class _NusaSearchBarState extends State<NusaSearchBar> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();
  FocusNode? _focusNode;
  bool _searching = false;

  FocusNode get _effectiveFocus => _focusNode ??= FocusNode()
    ..addListener(() {
      if (mounted) setState(() => _searching = _focusNode!.hasFocus);
    });

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = _ctrl.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusXL),
        boxShadow: [
          if (_searching)
            BoxShadow(
              color: NusaConfig.activePrimary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 3),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: TextField(
        controller: _ctrl,
        focusNode: _effectiveFocus,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmit,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color:
                isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color:
                isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showScanner && widget.onScan != null) ...[
                IconButton(
                  onPressed: widget.onScan,
                  icon: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 22,
                    color: NusaConfig.activePrimary,
                  ),
                  tooltip: 'Scan barcode',
                ),
              ],
              if (hasText)
                IconButton(
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged?.call('');
                  },
                  icon: Icon(
                    Icons.clear_rounded,
                    size: 20,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
