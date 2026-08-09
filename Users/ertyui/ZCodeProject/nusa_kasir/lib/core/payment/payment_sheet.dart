import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Bottom sheet for selecting a license package (1Bulan or Lifetime).
/// Returns the selected package id ('1bulan' | 'lifetime') or null if dismissed.
class PaymentSheet extends ConsumerStatefulWidget {
  final String googleId;
  final VoidCallback? onPackageSelected;

  const PaymentSheet({
    required this.googleId,
    this.onPackageSelected,
    super.key,
  });

  /// Show the payment modal. Returns the URL to open in WebView.
  static Future<String?> show(
    BuildContext context, {
    required String googleId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(googleId: googleId),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  String _selected = 'lifetime';

  static const _packages = [
    _PackageInfo(
      id: '1bulan',
      label: '1 Bulan',
      price: 'Rp49.000',
      desc: '30 hari akses penuh',
      priceNum: NusaConfig.price1Bulan,
    ),
    _PackageInfo(
      id: 'lifetime',
      label: 'Lifetime',
      price: 'Rp249.000',
      desc: 'Akses seumur hidup + FREE Kartu NFC 2pcs',
      priceNum: NusaConfig.priceLifetime,
      isBest: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _packages.firstWhere((p) => p.id == _selected);
    final bg = isDark ? Color(0xFF1A1A2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Color(0xFF1F2937);
    final textSecondary = isDark ? Color(0xFFCBD5E1) : Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),

          // Title
          Text(
            'Pilih Paket Lisensi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            NusaConfig.appSubtitle,
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          SizedBox(height: 20),

          // Package cards
          ..._packages.map((pkg) => _buildCard(pkg, isDark, textPrimary, textSecondary)),

          SizedBox(height: 20),

          // Price summary + CTA
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NusaConfig.activePrimary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 12, color: textSecondary)),
                    SizedBox(height: 2),
                    Text(
                      selected.price,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final url = NusaConfig.paymentLink(widget.googleId, _selected);
                      Navigator.pop(context, url);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NusaConfig.activePrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      elevation: 0,
                    ),
                    child: Text(
                      'Bayar Sekarang',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8),
          Text(
            'Pembayaran aman via Midtrans',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_PackageInfo pkg, bool isDark, Color textPrimary, Color textSecondary) {
    final selected = pkg.id == _selected;
    return GestureDetector(
      onTap: () => setState(() => _selected = pkg.id),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? NusaConfig.activePrimary.withOpacity(0.06)
              : (isDark ? Colors.white.withOpacity(0.03) : Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? NusaConfig.activePrimary : (isDark ? Colors.white10 : Color(0xFFE5E7EB)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 22, height: 22,
              margin: EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? NusaConfig.activePrimary : (isDark ? Colors.white30 : Color(0xFFD1D5DB)),
                  width: selected ? 6 : 2,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(pkg.label,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                      if (pkg.isBest) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: NusaConfig.successSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Best Value',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: NusaConfig.successText)),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(pkg.desc,
                    style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
            Text(pkg.price,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _PackageInfo {
  final String id, label, price, desc;
  final double priceNum;
  final bool isBest;
  const _PackageInfo({
    required this.id,
    required this.label,
    required this.price,
    required this.desc,
    required this.priceNum,
    this.isBest = false,
  });
}
