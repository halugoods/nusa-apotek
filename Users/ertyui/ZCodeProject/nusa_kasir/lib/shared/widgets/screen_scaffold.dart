import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/hid_barcode_listener.dart';

/// Clean screen shell — custom header + body, dark/light adaptive.
/// Responsive: tablet/landscape gets wider layout with max-width constraint.
class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// v2.2.43: bila diisi, body dibungkus [HidBarcodeListener] — scanner
  /// barcode EKSTERNAL (HID) jalan otomatis di layar ini tanpa user men-tap
  /// kolom pencarian dulu, dan TANPA membuka keyboard layar. Layar yang punya
  /// menu scan (produk/stok/pembelian) pass handler scan-nya di sini.
  final ValueChanged<String>? onBarcode;

  const ScreenScaffold(
    this.title,
    this.body, {
    super.key,
    this.actions,
    this.floatingActionButton,
    this.onBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop == true;
    final textColor = theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final borderColor = isDark ? NusaConfig.darkBorder : Color(0xFFF3F4F6);
    final dividerColor = isDark ? NusaConfig.darkDivider : Color(0xFFE5E7EB);
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    Widget content = Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(canPop ? 4 : (isWide ? 24 : 20), 8, isWide ? 24 : 16, 8),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                if (canPop)
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(Icons.chevron_left,
                          size: 22, color: textColor),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...?actions,
              ],
            ),
          ),
        ),
        Container(height: 1, color: dividerColor),
        // Body — centered + max-width on wide screens
        Expanded(
          child: isWide
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: body,
                  ),
                )
              : body,
        ),
      ],
    );

    // Scan barcode eksternal: wrap konten dengan listener HID.
    if (onBarcode != null) {
      content = HidBarcodeListener(onBarcode: onBarcode!, child: content);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: content,
      ),
      floatingActionButton: floatingActionButton != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: floatingActionButton,
            )
          : null,
    );
  }
}
