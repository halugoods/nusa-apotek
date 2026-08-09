import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/dev/variant_data.dart';
import 'package:nusa_kasir/core/dev/variant_provider.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Developer-only screen: pick which variant to test.
/// Shows 8 cards — tap one to apply that variant and enter the app.
///
/// If the app is already activated, navigates to /home; otherwise /activation.
class VariantPickerScreen extends ConsumerWidget {
  const VariantPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NusaConfig.darkBackground : Color(0xFF0A0A1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Text(
                  'NUSA',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Developer Edition',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Pilih varian untuk testing',
                  style: TextStyle(fontSize: 14, color: Colors.white38),
                ),
                SizedBox(height: 32),

                // ── 8 Variant Cards ──
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: VariantData.all.length,
                  itemBuilder: (_, i) => _VariantCard(
                    variant: VariantData.all[i],
                    onTap: () => _onSelect(context, ref, VariantData.all[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSelect(BuildContext context, WidgetRef ref, VariantData variant) async {
    ref.read(variantProvider.notifier).select(variant);
    // If the app is already activated, go home; otherwise go to activation.
    try {
      final activated = await SecureStore.getActivation() != null;
      if (activated && context.mounted) {
        context.go('/home');
      } else if (context.mounted) {
        context.go('/activation');
      }
    } catch (_) {
      if (context.mounted) context.go('/activation');
    }
  }
}

class _VariantCard extends StatelessWidget {
  final VariantData variant;
  final VoidCallback onTap;

  const _VariantCard({required this.variant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = variant.catEmoji.entries.firstOrNull;
    final emoji = label?.value ?? '📦';
    final catName = label?.key ?? variant.name;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: variant.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: variant.primary.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: 28)),
              SizedBox(height: 8),
              Text(
                variant.name.replaceFirst('NUSA ', ''),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                catName,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
