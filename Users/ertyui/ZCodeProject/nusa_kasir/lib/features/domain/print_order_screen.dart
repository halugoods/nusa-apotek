/// Fotocopy: Print/copy order management — pages, copies, paper size, binding.
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class PrintOrderScreen extends StatelessWidget {
  const PrintOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Order Cetak',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(avatar: const Icon(Icons.copy_all, size: 18), label: const Text('Fotocopy'), onPressed: () {},
              backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
            ActionChip(avatar: const Icon(Icons.colorize, size: 18), label: const Text('Print Warna'), onPressed: () {},
              backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
            ActionChip(avatar: const Icon(Icons.print, size: 18), label: const Text('Print B/W'), onPressed: () {},
              backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
            ActionChip(avatar: const Icon(Icons.book, size: 18), label: const Text('Jilid'), onPressed: () {},
              backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
            ActionChip(avatar: const Icon(Icons.layers, size: 18), label: const Text('Laminating'), onPressed: () {},
              backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
            ActionChip(avatar: const Icon(Icons.document_scanner, size: 18), label: const Text('Scan'), onPressed: () {},
              backgroundColor: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor)),
          ]),
        ),
        Expanded(
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.print_outlined, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(height: 16),
            Text('Pilih jenis layanan untuk mulai', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
          ])),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: NusaConfig.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Order Baru'),
      ),
    );
  }
}
