import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Reusable form field — label DI ATAS field (state design baru, konsisten
/// dengan NusaInput di pelanggan/supplier), bukan labelText di dalam border.
class NusaFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  NusaFormField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.maxLines,
    this.onChanged,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill;
    final borderClr = isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder;
    final textClr = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final hintClr = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;

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
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          maxLines: maxLines,
          onChanged: onChanged,
          textInputAction: textInputAction,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textClr,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintClr, fontSize: 15),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderClr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderClr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: NusaConfig.activePrimary, width: 1.5),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Reusable dropdown form field — label DI ATAS field, match NusaFormField.
class NusaDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? prefixIcon;

  NusaDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill;
    final borderClr = isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder;

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
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Pilih…',
            hintStyle: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderClr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderClr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: NusaConfig.activePrimary, width: 1.5),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
