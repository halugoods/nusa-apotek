/// Laundry: Status pesanan — New, Washing, Drying, Ironing, Ready, Delivered.
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class LaundryStatusScreen extends StatelessWidget {
  const LaundryStatusScreen({super.key});

  static const _stages = [
    {'label': 'Baru', 'icon': Icons.receipt_long, 'color': NusaConfig.accentPurple},
    {'label': 'Cuci', 'icon': Icons.local_laundry_service, 'color': NusaConfig.info},
    {'label': 'Kering', 'icon': Icons.air, 'color': NusaConfig.accentGreen},
    {'label': 'Setrika', 'icon': Icons.iron, 'color': NusaConfig.warning},
    {'label': 'Siap', 'icon': Icons.check_circle, 'color': NusaConfig.success},
    {'label': 'Diambil', 'icon': Icons.delivery_dining, 'color': NusaConfig.primaryColor},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Status Laundry',
      ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _stages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final stage = _stages[i];
          final color = stage['color'] as Color;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
            ),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(stage['icon'] as IconData, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(stage['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('0 pesanan', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
              ])),
              const Icon(Icons.chevron_right),
            ]),
          );
        },
      ),
    );
  }
}
