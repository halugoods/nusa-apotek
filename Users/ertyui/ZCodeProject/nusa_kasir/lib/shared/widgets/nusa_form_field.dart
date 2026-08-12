import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Reusable form field — eliminates 7x duplicated InputDecoration across the app.
/// Uses NusaConfig tokens for consistent styling.
class NusaFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? hintText;
  final Widget? prefixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final int? maxLines;

  NusaFormField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.hintText,
    this.prefixIcon,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill;
    final borderClr = isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder;
    final textClr = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final hintClr = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textClr,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          letterSpacing: 0.5,
        ),
        hintText: hintText,
        hintStyle: TextStyle(color: hintClr),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderClr),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderClr),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: NusaConfig.activePrimary, width: 1.5),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// Reusable dropdown form field matching NusaFormField style.
class NusaDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  NusaDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill;
    final borderClr = isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder;

    return DropdownButtonFormField<T>(
      value: value,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
          letterSpacing: 0.5,
        ),
        hintStyle: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderClr),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderClr),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: NusaConfig.activePrimary, width: 1.5),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
