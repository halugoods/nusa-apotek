import 'package:flutter/material.dart';
import 'package:nusa_kasir/shared/widgets/pin_keypad.dart';

/// PIN input — now backed by [PinKeypad] (EDC/ATM-style keypad).
///
/// Keeps the same API for backwards compatibility:
/// - [PinInputState.text] — read current digits
/// - [PinInputState.clear] — reset
/// - [autoSubmit] — auto-trigger [onComplete] when full
/// - [length] — 4 or 6 digits
///
/// When [autoSubmit] is true (default), [onComplete] fires automatically
/// when all [length] digits are entered. When false, read [PinInputState.text].
class PinInput extends StatefulWidget {
  final void Function(String pin)? onComplete;
  final String? error;
  final bool autofocus;
  final VoidCallback? onChanged;
  final bool autoSubmit;
  final int length;

  const PinInput({
    super.key,
    this.onComplete,
    this.error,
    this.autofocus = true,
    this.onChanged,
    this.autoSubmit = true,
    this.length = 6,
  }) : assert(length == 4 || length == 6);

  @override
  PinInputState createState() => PinInputState();
}

class PinInputState extends State<PinInput> {
  String _text = '';
  int _rebuildKey = 0;

  /// The current digit text (e.g. "1234").
  String get text => _text;

  /// Clear the input.
  void clear() {
    if (!mounted) return;
    setState(() {
      _text = '';
      _rebuildKey++;
    });
  }

  void _onChanged(String digits) {
    setState(() => _text = digits);
    widget.onChanged?.call();
  }

  void _onComplete(String digits) {
    if (widget.autoSubmit && widget.onComplete != null) {
      widget.onComplete!(digits);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinKeypad(
      key: ValueKey('pin_input_$_rebuildKey'),
      length: widget.length,
      error: widget.error,
      showFingerprint: false,
      showCancel: false, // consumers handle their own cancel
      onChanged: _onChanged,
      onComplete: _onComplete,
    );
  }
}
