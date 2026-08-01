/// Salon: Appointment booking calendar with stylist slot view.
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  String _bulan(int m) => const ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'][m];
  String _hariPendek(int w) => const ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][w];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    return ScreenScaffold(
      'Booking',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text('${_bulan(now.month)} ${now.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
          ]),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 14,
            itemBuilder: (ctx, i) {
              final d = now.add(Duration(days: i));
              final isToday = i == 0;
              return Container(
                width: 56, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isToday ? NusaConfig.primaryColor : (isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? null : Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_hariPendek(d.weekday), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
                  Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: isToday ? Colors.white : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary))),
                ]),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_available, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(height: 16),
            Text('Belum ada booking', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ])),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: NusaConfig.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Booking Baru'),
      ),
    );
  }
}
