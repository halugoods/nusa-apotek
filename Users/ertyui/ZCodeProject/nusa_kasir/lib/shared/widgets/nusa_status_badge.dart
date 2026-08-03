import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Single source of truth for stock status badges.
/// Used across Products, POS, Stock screens.
class NusaStatusBadge extends StatelessWidget {
  final int stock;
  final int minStock;

  const NusaStatusBadge({super.key, required this.stock, required this.minStock});

  bool get _outOfStock => stock <= 0;
  bool get _lowStock => !_outOfStock && stock <= minStock;

  String get _label {
    if (_outOfStock) return 'Habis';
    if (_lowStock) return 'Menipis';
    return '${stock}x';
  }

  Color get _bg {
    if (_outOfStock) return NusaConfig.stockOut;
    if (_lowStock) return NusaConfig.stockLow;
    return NusaConfig.stockActive;
  }

  Color get _fg {
    if (_outOfStock) return NusaConfig.stockOutText;
    if (_lowStock) return NusaConfig.stockLowText;
    return NusaConfig.stockActiveText;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(NusaConfig.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _fg,
          letterSpacing: -0.01,
        ),
      ),
    );
  }

  /// Static helper for simple text-only badge
  static String label(int stock, int minStock) {
    if (stock <= 0) return 'Habis';
    if (stock <= minStock) return 'Menipis';
    return 'Aktif';
  }
}
