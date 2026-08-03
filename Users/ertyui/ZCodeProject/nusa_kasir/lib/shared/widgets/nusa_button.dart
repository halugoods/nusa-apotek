import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NusaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  const NusaButton(this.label, {this.onPressed, this.fullWidth = true, super.key});
  @override
  Widget build(BuildContext c) => SizedBox(width: fullWidth ? double.infinity : null,
    child: ElevatedButton(
      onPressed: onPressed == null ? null : () {
        HapticFeedback.mediumImpact();
        onPressed!();
      },
      child: Text(label)));
}
