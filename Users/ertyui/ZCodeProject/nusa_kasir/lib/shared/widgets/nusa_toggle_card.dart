import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Toggle card with ON/OFF switch — replaces duplicated toggle sections.
/// Used for: Barcode, Toko Online, Varian, Grosir toggles.
class NusaToggleCard extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? expandedChild;
  final IconData? icon;

  NusaToggleCard({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.expandedChild,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(NusaConfig.spaceMD),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                    SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: value ? NusaConfig.accentGreen : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                    ),
                  ),
                  SizedBox(width: 4),
                  Switch(
                    value: value,
                    activeColor: NusaConfig.activePrimary,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ],
          ),
          if (value && expandedChild != null) ...[
            SizedBox(height: 12),
            expandedChild!,
          ],
        ],
      ),
    );
  }
}
