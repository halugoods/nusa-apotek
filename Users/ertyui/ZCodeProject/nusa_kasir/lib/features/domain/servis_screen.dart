/// Bengkel & Service HP: Service ticket management (status, sparepart needed, cost est).
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class ServisScreen extends StatelessWidget {
  const ServisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Tiket Servis',
      Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _statusChip('Diagnosa', NusaConfig.warning, 0, isDark),
              _statusChip('Estimasi', NusaConfig.info, 0, isDark),
              _statusChip('Perbaikan', NusaConfig.accentPurple, 0, isDark),
              _statusChip('Selesai', NusaConfig.success, 0, isDark),
            ]),
          ),
        ),
        Expanded(
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.build_circle_outlined, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(height: 16),
            Text('Belum ada tiket servis', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ])),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: NusaConfig.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tiket Baru'),
      ),
    );
  }

  Widget _statusChip(String label, Color color, int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Container(width: 22, height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        ),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
        side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
