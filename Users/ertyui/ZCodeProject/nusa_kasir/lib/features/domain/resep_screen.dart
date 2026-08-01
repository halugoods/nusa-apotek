/// Apotek: Prescription management — doctor, patient, dosage, batch tracking.
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class ResepScreen extends StatelessWidget {
  const ResepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Resep Obat',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _statCard('Hari ini', '0', NusaConfig.info, isDark),
            const SizedBox(width: 10),
            _statCard('Proses', '0', NusaConfig.warning, isDark),
            const SizedBox(width: 10),
            _statCard('Selesai', '0', NusaConfig.success, isDark),
          ]),
        ),
        Expanded(
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.medication_liquid, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(height: 16),
            Text('Belum ada resep', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ])),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: NusaConfig.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Resep Baru'),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
        ]),
      ),
    );
  }
}
