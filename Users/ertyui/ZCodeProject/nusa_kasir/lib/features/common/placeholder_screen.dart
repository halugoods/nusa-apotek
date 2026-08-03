import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    return ScreenScaffold(
      title,
      Center(
        child: Text('Segera hadir',
            style: TextStyle(
                color: isDark ? NusaConfig.darkTextSecondary : Colors.grey)),
      ),
    );
  }
}
