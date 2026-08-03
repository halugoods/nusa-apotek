import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Themed card wrapper using NusaConfig tokens.
/// Default: 16px radius, surface bg, subtle border + shadow.
class NusaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const NusaCard(this.child, {this.padding, this.borderRadius, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: padding ?? const EdgeInsets.all(NusaConfig.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(NusaConfig.radiusLG),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? NusaConfig.darkCardShadow : Color(0x0A111827),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(NusaConfig.radiusLG),
        child: card,
      );
    }
    return card;
  }
}
