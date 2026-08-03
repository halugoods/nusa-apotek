import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Theme-aware text input — adapts to light/dark using NusaConfig tokens.
class NusaInput extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType? type;
  final bool monospace;
  final bool obscure;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;

  NusaInput(
    this.label, {
    super.key,
    this.controller,
    this.type,
    this.monospace = false,
    this.obscure = false,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill;
    final border = isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder;
    final textColor = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          obscureText: obscure,
          maxLines: maxLines ?? 1,
          style: monospace
              ? TextStyle(fontFamily: 'monospace', fontSize: 15, color: textColor)
              : TextStyle(fontSize: 15, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            hintStyle: TextStyle(
              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
              fontSize: 15,
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: NusaConfig.activePrimary, width: 1.5),
            ),
            filled: true,
            fillColor: fill,
          ),
        ),
      ],
    );
  }
}
