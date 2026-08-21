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

/// Unified PIN authentication dialog — used everywhere.
///
/// Two modes:
/// - **Direct PIN match**: pass `correctPin` — dialog compares locally.
/// - **Verify callback**: pass `onVerify` — dialog calls your async function
///   with the entered PIN. Return `true` for success.
///
/// Also supports fingerprint (`onFingerprint`) and NFC (`onNfc`).
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

  PinDialog({
    super.key,
    this.title,
    this.subtitle,
    this.employeeName,
    this.employeeRole,
    this.correctPin,
    this.onVerify,
    this.allowOverride = true,
    this.showRemember = true,
    this.pinLength = 6,
    this.showFingerprint = false,
    this.showNfc = false,
    this.showBarcode = false,
    this.onFingerprint,
    this.onNfc,
    this.onBarcode,
  });

  /// Show the dialog. Returns [PinResult] (success/failure) or null if cancelled.
  /// [pinLength] defaults to the PIN length stored in Settings (4 or 6) — callers
  /// that hardcode 6 would leave 4-digit PIN users stuck. Pass an explicit value
  /// only to override.
  static Future<PinResult?> show({
    required BuildContext context,
    String? title,
    String? subtitle,
    String? employeeName,
    String? employeeRole,
    String? correctPin,
    Future<bool> Function(String pin)? onVerify,
    bool allowOverride = true,
    bool showRemember = true,
    int? pinLength,
    bool showFingerprint = false,
    bool showNfc = false,
    bool showBarcode = false,
    Future<bool> Function()? onFingerprint,
    Future<String?> Function()? onNfc,
    Future<String?> Function(String code)? onBarcode,
  }) async {
    // Resolve stored PIN length (4/6) — never hardcode 6.
    var resolvedLength = pinLength ?? 6;
    if (pinLength == null) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        resolvedLength = await container.read(settingsRepoProvider).getPinLength();
      } catch (_) {
        resolvedLength = 6;
      }
    }
    return showDialog<PinResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String? error;
        bool remember = false;
        final keypadKey = GlobalKey<_PinDialogKeypadState>();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              Navigator.of(ctx).pop<PinResult>(null);
            }
          },
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return Dialog(
                insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Title section ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_outline,
                              color: NusaConfig.activePrimary, size: 26),
                        ),
                        if (title != null) ...[
                          SizedBox(height: 14),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : NusaConfig.textPrimary,
                            ),
                          ),
                        ],
                        if (employeeName != null && title == null) ...[
                          SizedBox(height: 14),
                          Text(
                            employeeName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : NusaConfig.textPrimary,
                            ),
                          ),
                        ],
                        if (subtitle != null) ...[
                          SizedBox(height: 4),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? NusaConfig.darkTextSecondary
                                  : NusaConfig.textSecondary,
                            ),
                          ),
                        ],
                        if (employeeRole != null && title == null) ...[
                          SizedBox(height: 2),
                          Text(
                            employeeRole,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? NusaConfig.darkTextSecondary
                                  : NusaConfig.textSecondary,
                            ),
                          ),
                        ],
                      ]),
                    ),

                    // ── Keypad ──
                    SizedBox(height: 12),
                    _PinDialogKeypad(
                      key: keypadKey,
                      pinLength: resolvedLength,
                      error: error,
                      showFingerprint: showFingerprint,
                      showNfc: showNfc,
                      showBarcode: showBarcode,
                      onFingerprint: onFingerprint,
                      onNfc: onNfc,
                      onNfcSuccess: (employeeId) {
                        Navigator.of(ctx).pop(PinResult(
                            success: true, remember: remember, nfcEmployeeId: int.tryParse(employeeId)));
                      },
                      onBarcode: onBarcode,
                      onBarcodeSuccess: (employeeId) {
                        Navigator.of(ctx).pop(PinResult(
                            success: true, remember: remember, nfcEmployeeId: employeeId));
                      },
                      onComplete: (pin) async {
                        if (pin.isEmpty) return;

                        bool ok = false;

                        // Mode 1: direct PIN match
                        if (correctPin != null) {
                          ok = pin == correctPin;
                        }
                        // Mode 2: verify callback
                        else if (onVerify != null) {
                          ok = await onVerify(pin);
                        }

                        // Owner/Manager override — accept an active Owner or
                        // Manager PIN when the cashier's PIN is unavailable.
                        // Grants the PIN-gated action WITHOUT switching session.
                        if (!ok && allowOverride) {
                          try {
                            final container = ProviderScope.containerOf(ctx,
                                listen: false);
                            final db = container.read(databaseProvider);
                            final overrideEmp = await AttendanceRepository(db)
                                .findOverrideEmployee();
                            if (overrideEmp != null && pin == overrideEmp.pin) {
                              ok = true;
                            }
                          } catch (_) {
                            // Override lookup failed — keep the result as-is.
                          }
                        }

                        if (ok) {
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop(
                                PinResult(success: true, remember: remember));
                          }
                        } else {
                          setSt(() {
                            error = 'PIN salah';
                            keypadKey.currentState?.clear();
                          });
                        }
                      },
                    ),

                    // ── Remember checkbox ──
                    if (showRemember)
                      Padding(
                        padding: EdgeInsets.only(left: 24, top: 4, bottom: 12),
                        child: GestureDetector(
                          onTap: () => setSt(() => remember = !remember),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22, height: 22,
                                child: Checkbox(
                                  value: remember,
                                  onChanged: (v) => setSt(() => remember = v ?? false),
                                  activeColor: NusaConfig.activePrimary,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Ingat PIN selama 8 jam',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? NusaConfig.darkTextSecondary
                                        : NusaConfig.textSecondary,
                                  )),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }
}

/// Internal keypad holder that exposes [clear].
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

  _PinDialogKeypad({
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
