import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/shared/widgets/animated_builder.dart'
    show NusaAnimatedBuilder;

/// A standalone numeric keypad — EDC/ATM physical-keypad style.
///
/// Renders:
///   - Dot indicators (4 or 6 circular dots)
///   - 3×4 keypad grid: [1][2][3] / [4][5][6] / [7][8][9] / [··][0][⌫]
///   - Shake animation on error
///   - Optional fingerprint button in bottom-left
///   - Optional "Batal" cancel text below
///
/// Embed anywhere — not a dialog, not full-screen.
///
/// ```dart
/// PinKeypad(
///   length: 6,
///   error: _error,
///   showFingerprint: true,
///   onFingerprint: () async => false,
///   onComplete: (pin) { /* verify */ },
///   onCancel: () { /* dismiss */ },
/// )
/// ```
class PinKeypad extends StatefulWidget {
  final int length;
  final String? error;
  final bool showFingerprint;
  final bool showNfc;
  final bool showCancel;
  final Future<bool> Function()? onFingerprint;
  final VoidCallback? onFingerprintSuccess;
  final ValueChanged<String>? onComplete;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onChanged;
  final Future<String?> Function()? onNfc;

  PinKeypad({
    super.key,
    this.length = 6,
    this.error,
    this.showFingerprint = false,
    this.showNfc = false,
    this.showCancel = false,
    this.onFingerprint,
    this.onFingerprintSuccess,
    this.onComplete,
    this.onCancel,
    this.onChanged,
    this.onNfc,
  }) : assert(length == 4 || length == 6);

  @override
  State<PinKeypad> createState() => PinKeypadState();
}

class PinKeypadState extends State<PinKeypad>
    with SingleTickerProviderStateMixin {
  String _digits = '';
  bool _nfcScanning = false;
  bool _biometricAvailable = false;
  IconData _biometricIcon = Icons.fingerprint;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _pickBiometricIcon();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeCtrl,
      curve: Curves.easeInOut,
    ));

    // ── NFC auto-start: no button click needed ──
    // When PinKeypad shows with NFC enabled, immediately start the NFC
    // session in the background. The user just taps their card — no
    // separate button click required. The "Dekatkan kartu NFC" text
    // below the keypad serves as a hint, not a button.
    if (widget.showNfc && widget.onNfc != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoStartNfc();
      });
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PinKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wrong PIN (error null → non-null): vibrate, shake, reset dots to 0.
    // Re-typed digits are cleared by the host via key change; this is the
    // single source of truth for the shake + dot reset on every attempt.
    if (oldWidget.error == null && widget.error != null) {
      HapticFeedback.heavyImpact();
      _triggerShake();
      setState(() => _digits = '');
    }
    // NFC auto-start when showNfc becomes true after initial availability check.
    // On activation screen, _nfcAvailable starts false and becomes true async —
    // this catches that transition and auto-starts the NFC session.
    if (!oldWidget.showNfc && widget.showNfc && widget.onNfc != null) {
      _autoStartNfc();
    }
  }

  /// Public API — read current digits (for manual submit flows).
  String get text => _digits;

  /// Clear the input (e.g. after wrong PIN).
  void clear() {
    if (!mounted) return;
    setState(() => _digits = '');
  }

  Future<void> _checkBiometric() async {
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _biometricAvailable = enabled);
  }

  /// Face-enabled devices show a face icon; everything else the
  /// fingerprint symbol. Picked async so it matches the device HW.
  Future<void> _pickBiometricIcon() async {
    final icon = await BiometricService.getUnlockIcon();
    if (mounted) setState(() => _biometricIcon = icon);
  }

  void _onDigit(String d) {
    if (_digits.length >= widget.length) return;
    setState(() => _digits += d);
    // Defer parent notification to AFTER the tap gesture completes.
    // Calling the parent's setState (e.g. login error clear) synchronously
    // here rebuilds the whole screen mid-tap, which can swallow the InkWell
    // tap on slow devices — the reported "kadang ketekan kadang engga".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged?.call(_digits);
    });
    if (_digits.length == widget.length) {
      widget.onComplete?.call(_digits);
    }
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged?.call(_digits);
    });
  }

  void _triggerShake() {
    _shakeCtrl.forward(from: 0);
  }

  Future<void> _onFingerprintTap() async {
    if (widget.onFingerprint == null) return;
    final ok = await widget.onFingerprint!();
    if (ok && mounted) {
      widget.onFingerprintSuccess?.call();
    }
  }

  Future<void> _onNfcTap() async {
    if (widget.onNfc == null || _nfcScanning) return;
    setState(() => _nfcScanning = true);
    try {
      final result = await widget.onNfc!();
      if (result != null && mounted) {
        widget.onComplete?.call(result);
      }
    } finally {
      if (mounted) setState(() => _nfcScanning = false);
    }
  }

  /// Auto-start NFC session when PinKeypad appears with NFC enabled.
  /// User just taps their card — no separate button click required.
  void _autoStartNfc() {
    _onNfcTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.length;
    final len = _digits.length;
    final hasError = widget.error != null;

    // Shake the keypad whenever an error is shown (wrong PIN).
    if (hasError && !_shakeCtrl.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerShake());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Dot indicators + error (shake only this block) ──
        // The keypad grid stays OUTSIDE the animation: on slow devices the
        // rebuild-per-frame of an animated parent made the buttons swallow
        // taps ("kadang ketekan kadang engga"). Only the dots + error text
        // shake now, so buttons are never rebuilt mid-animation.
        NusaAnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Dot indicators ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) {
                  final filled = i < len;
                  return Container(
                    width: 18,
                    height: 18,
                    margin: EdgeInsets.symmetric(horizontal: count == 6 ? 10 : 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasError
                            ? NusaConfig.activePrimary
                            : filled
                                ? NusaConfig.activePrimary
                                : isDark
                                    ? NusaConfig.darkBorder
                                    : NusaConfig.dividerColor,
                        width: 2,
                      ),
                      color: filled ? NusaConfig.activePrimary : Colors.transparent,
                    ),
                  );
                }),
              ),

              // ── Error text ──────────────────────────────
              if (hasError) ...[
                SizedBox(height: 10),
                Text(
                  widget.error!,
                  style: TextStyle(
                    color: NusaConfig.activePrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 24),

        // ── NFC scanning indicator ─────────────────
        if (widget.showNfc && _nfcScanning) ...[
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: NusaConfig.accentPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NusaConfig.accentPurple.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: NusaConfig.accentPurple),
              ),
              SizedBox(width: 12),
              Text('Dekatkan kartu NFC...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NusaConfig.accentPurple)),
            ]),
          ),
        ],

        // ── Keypad grid ─────────────────────────────
        _buildKeypadRow(['1', '2', '3'], isDark),
        _buildKeypadRow(['4', '5', '6'], isDark),
        _buildKeypadRow(['7', '8', '9'], isDark),
        Row(
          children: [
            Expanded(
              child: _bottomLeftCell(),
            ),
            Expanded(
              child: _keyButton(
                text: '0',
                onTap: () => _onDigit('0'),
                isDark: isDark,
              ),
            ),
            Expanded(
              child: _keyButton(
                child: Icon(Icons.backspace_outlined,
                    color: NusaConfig.activePrimary, size: 24),
                onTap: _onDelete,
              ),
            ),
          ],
        ),

        // ── NFC: static hint card (below keypad) ───
        // Always visible when NFC is enabled — serves as a persistent
        // reminder. Tappable only when NOT scanning (retry after timeout).
        // The scanning indicator is above the keypad (spinner + "Dekatkan...").
        if (widget.showNfc) ...[
          SizedBox(height: 10),
          AbsorbPointer(
            absorbing: _nfcScanning,
            child: GestureDetector(
              onTap: _nfcScanning ? null : _onNfcTap,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
                  ),
                  color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: NusaConfig.accentPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.nfc, size: 18, color: NusaConfig.accentPurple),
                    ),
                    SizedBox(width: 10),
                    Text('Tap Kartu NFC',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],

        // ── Cancel (card style) ──────────────────────
        if (widget.showCancel) ...[
          SizedBox(height: 8),
          Card(
            elevation: 1,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: isDark ? NusaConfig.darkSurface : Colors.white,
            child: InkWell(
              onTap: widget.onCancel,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
        // Bottom padding so NFC / cancel card doesn't stick to edge
        SizedBox(height: 8),
      ],
    );
  }

  Widget _bottomLeftCell() {
    // FP takes priority but only when biometric hardware+enabled confirms it
    if (widget.showFingerprint && _biometricAvailable) {
      return _keyButton(
        child: Icon(_biometricIcon,
            color: NusaConfig.activePrimary, size: 28),
        onTap: _onFingerprintTap,
      );
    }
    // NFC icon removed from keypad grid — shown only below as "Tap Kartu NFC" card
    return SizedBox.shrink();
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: digits.map((d) {
          return Expanded(
            child: _keyButton(
              text: d,
              onTap: () => _onDigit(d),
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _keyButton({
    String? text,
    Widget? child,
    VoidCallback? onTap,
    bool isDark = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Material(
        color: text != null
            ? (isDark ? NusaConfig.darkSurface2 : Colors.white)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: text != null ? 2 : 0,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            // 60px — larger tap target than before (52px); keypad taps
            // were being missed on low-end devices.
            height: 60,
            alignment: Alignment.center,
            decoration: isDark && text != null
                ? BoxDecoration(
                    border: Border.all(
                        color: NusaConfig.darkBorder, width: 1),
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            child: child ??
                Text(
                  text!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : Color(0xFF1A1A1A),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
