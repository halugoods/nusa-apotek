import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/shared/widgets/pin_keypad.dart';

/// Result of a PIN dialog authentication attempt.
class PinResult {
  final bool success;
  final bool remember;
  /// If NFC was used, the employee ID from the tag.
  final int? nfcEmployeeId;
  PinResult({required this.success, required this.remember, this.nfcEmployeeId});
}

/// Unified PIN authentication dialog -- used everywhere.
///
/// Two modes:
/// - **Direct PIN match**: pass `correctPin` -- dialog compares locally.
/// - **Verify callback**: pass `onVerify` -- dialog calls your async function
///   with the entered PIN. Return `true` for success.
///
/// Also supports fingerprint (`onFingerprint`), NFC (`onNfc`), and barcode.
///
/// **v2.2.47**: Restructured to fullscreen card layout matching login pinpad.
/// `showRemember` defaults to `false` (no "Ingat PIN selama 8 jam").
class PinDialog extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? employeeName;
  final String? employeeRole;
  final String? correctPin;
  final Future<bool> Function(String pin)? onVerify;
  final bool allowOverride;
  final bool showRemember;
  final int pinLength;
  final bool showFingerprint;
  final bool showNfc;
  final bool showBarcode;
  final Future<bool> Function()? onFingerprint;
  final Future<String?> Function()? onNfc;
  final Future<String?> Function(String code)? onBarcode;

  const PinDialog({
    super.key,
    this.title,
    this.subtitle,
    this.employeeName,
    this.employeeRole,
    this.correctPin,
    this.onVerify,
    this.allowOverride = true,
    this.showRemember = false,
    this.pinLength = 6,
    this.showFingerprint = false,
    this.showNfc = false,
    this.showBarcode = false,
    this.onFingerprint,
    this.onNfc,
    this.onBarcode,
  });

  /// Show the dialog. Returns [PinResult] (success/failure) or null if cancelled.
  /// [pinLength] defaults to the PIN length stored in Settings (4 or 6).
  /// [showRemember] defaults to `false` -- no "Ingat PIN selama 8 jam" in dialogs.
  static Future<PinResult?> show({
    required BuildContext context,
    String? title,
    String? subtitle,
    String? employeeName,
    String? employeeRole,
    String? correctPin,
    Future<bool> Function(String pin)? onVerify,
    bool allowOverride = true,
    bool showRemember = false,
    int? pinLength,
    bool showFingerprint = false,
    bool showNfc = false,
    bool showBarcode = false,
    Future<bool> Function()? onFingerprint,
    Future<String?> Function()? onNfc,
    Future<String?> Function(String code)? onBarcode,
  }) async {
    // Resolve stored PIN length (4/6) -- never hardcode 6.
    var resolvedLength = pinLength ?? 6;
    if (pinLength == null) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        resolvedLength = await container.read(settingsRepoProvider).getPinLength();
      } catch (_) {
        resolvedLength = 6;
      }
    }

    return Navigator.of(context).push<PinResult>(
      MaterialPageRoute<PinResult>(
        builder: (_) => _PinPadFullScreen(
        title: title,
        subtitle: subtitle,
        employeeName: employeeName,
        employeeRole: employeeRole,
        correctPin: correctPin,
        onVerify: onVerify,
        allowOverride: allowOverride,
        showRemember: showRemember,
        pinLength: resolvedLength,
        showFingerprint: showFingerprint,
        showNfc: showNfc,
        showBarcode: showBarcode,
        onFingerprint: onFingerprint,
        onNfc: onNfc,
        onBarcode: onBarcode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Fullscreen card pinpad -- EXACT same layout as login_screen.dart pinpad.
/// Lock icon 72px gradient OUTSIDE card, card radius 20, title "Masuk" font 20.
class _PinPadFullScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final String? employeeName;
  final String? employeeRole;
  final String? correctPin;
  final Future<bool> Function(String pin)? onVerify;
  final bool allowOverride;
  final bool showRemember;
  final int pinLength;
  final bool showFingerprint;
  final bool showNfc;
  final bool showBarcode;
  final Future<bool> Function()? onFingerprint;
  final Future<String?> Function()? onNfc;
  final Future<String?> Function(String code)? onBarcode;

  const _PinPadFullScreen({
    this.title,
    this.subtitle,
    this.employeeName,
    this.employeeRole,
    this.correctPin,
    this.onVerify,
    this.allowOverride = true,
    this.showRemember = false,
    required this.pinLength,
    this.showFingerprint = false,
    this.showNfc = false,
    this.showBarcode = false,
    this.onFingerprint,
    this.onNfc,
    this.onBarcode,
  });

  @override
  State<_PinPadFullScreen> createState() => _PinPadFullScreenState();
}

class _PinPadFullScreenState extends State<_PinPadFullScreen> {
  String? _error;
  bool _remember = false;
  final _keypadKey = GlobalKey<_PinDialogKeypadState>();

  /// Title text -- defaults to "Masuk" when employeeName is provided.
  String get _displayTitle => widget.title ?? 'Masuk';

  /// Subtitle text -- falls back to login-style subtitle when only employeeName provided.
  String? get _displaySubtitle {
    if (widget.subtitle != null) return widget.subtitle;
    if (widget.employeeName != null) {
      return 'Masukkan PIN ${widget.employeeName}';
    }
    return null;
  }

  Future<void> _verify(String pin) async {
    if (pin.isEmpty) return;

    bool ok = false;

    // Mode 1: direct PIN match
    if (widget.correctPin != null) {
      ok = pin == widget.correctPin;
    }
    // Mode 2: verify callback
    else if (widget.onVerify != null) {
      ok = await widget.onVerify!(pin);
    }

    // Owner/Manager override
    if (!ok && widget.allowOverride) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final db = container.read(databaseProvider);
        final overrideEmp =
            await AttendanceRepository(db).findOverrideEmployee();
        if (overrideEmp != null && pin == overrideEmp.pin) {
          ok = true;
        }
      } catch (_) {}
    }

    if (ok) {
      if (mounted) {
        Navigator.of(context).pop(
            PinResult(success: true, remember: _remember));
      }
    } else {
      setState(() {
        _error = 'PIN salah';
        _keypadKey.currentState?.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? NusaConfig.darkBackground : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),

                // -- Lock icon (gradient circle, depth) -- EXACT like login
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        NusaConfig.activePrimary,
                        NusaConfig.activeDark,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(height: 32),

                // -- Card container (depth) -- EXACT like login
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        _displayTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? NusaConfig.darkTextPrimary
                              : const Color(0xFF151717),
                        ),
                      ),
                      if (_displaySubtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _displaySubtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ],
                      if (widget.employeeRole != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.employeeRole!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // -- Keypad --
                      _PinDialogKeypad(
                        key: _keypadKey,
                        pinLength: widget.pinLength,
                        error: _error,
                        showFingerprint: widget.showFingerprint,
                        showNfc: widget.showNfc,
                        showBarcode: widget.showBarcode,
                        onFingerprint: widget.onFingerprint,
                        onNfc: widget.onNfc,
                        onNfcSuccess: (id) {
                          Navigator.of(context).pop(PinResult(
                              success: true,
                              remember: _remember,
                              nfcEmployeeId: int.tryParse(id)));
                        },
                        onBarcode: widget.onBarcode,
                        onBarcodeSuccess: (id) {
                          Navigator.of(context).pop(PinResult(
                              success: true,
                              remember: _remember,
                              nfcEmployeeId: id));
                        },
                        onComplete: _verify,
                      ),

                      // -- Remember checkbox --
                      if (widget.showRemember) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _remember = !_remember),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _remember,
                                  onChanged: (v) =>
                                      setState(() => _remember = v ?? false),
                                  activeColor: NusaConfig.activePrimary,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ingat PIN selama 8 jam',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? NusaConfig.darkTextSecondary
                                      : NusaConfig.textSecondary,
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
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Internal keypad holder that exposes [clear].
// ─────────────────────────────────────────────────

class _PinDialogKeypad extends StatefulWidget {
  final int pinLength;
  final String? error;
  final bool showFingerprint;
  final bool showNfc;
  final bool showBarcode;
  final Future<bool> Function()? onFingerprint;
  final Future<String?> Function()? onNfc;
  final Future<String?> Function(String code)? onBarcode;
  final ValueChanged<String> onComplete;
  final ValueChanged<String>? onNfcSuccess;
  final ValueChanged<int>? onBarcodeSuccess;

  const _PinDialogKeypad({
    super.key,
    required this.pinLength,
    this.error,
    this.showFingerprint = false,
    this.showNfc = false,
    this.showBarcode = false,
    this.onFingerprint,
    this.onNfc,
    this.onBarcode,
    required this.onComplete,
    this.onNfcSuccess,
    this.onBarcodeSuccess,
  });

  @override
  State<_PinDialogKeypad> createState() => _PinDialogKeypadState();
}

class _PinDialogKeypadState extends State<_PinDialogKeypad> {
  int _resetCount = 0;

  void clear() {
    setState(() => _resetCount++);
  }

  Future<String?> _onNfcHandler() async {
    if (widget.onNfc != null) {
      final result = await widget.onNfc!();
      if (result != null && mounted) {
        widget.onNfcSuccess?.call(result);
      }
      return result;
    }
    return null;
  }

  Future<String?> _onBarcodeHandler(String code) async {
    if (widget.onBarcode != null) {
      final result = await widget.onBarcode!(code);
      if (result != null && mounted) {
        widget.onBarcodeSuccess?.call(int.tryParse(result) ?? -1);
      }
      return result;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PinKeypad(
      key: ValueKey('dialog_pad_$_resetCount'),
      length: widget.pinLength,
      error: widget.error,
      showFingerprint: widget.showFingerprint,
      showNfc: widget.showNfc,
      showBarcode: widget.showBarcode,
      showCancel: false,
      onFingerprint: widget.onFingerprint,
      onFingerprintSuccess: () => Navigator.of(context)
          .pop(PinResult(success: true, remember: true)),
      onNfc: _onNfcHandler,
      onBarcode: _onBarcodeHandler,
      onComplete: widget.onComplete,
      onCancel: () => Navigator.of(context).pop(null),
    );
  }
}
