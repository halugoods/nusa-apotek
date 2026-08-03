import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Pill "Tambah" button — used uniformly on POS & Storefront product cards.
/// Set [fullWidth] to stretch inside a card foot; leave false for compact rows.
class NusaAddButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool fullWidth;
  final double height;
  NusaAddButton({
    required this.onTap,
    this.fullWidth = false,
    this.height = 36,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btn = ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add, size: 18),
        SizedBox(width: 4),
        Text('Tambah'),
      ]),
    );
    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: btn,
    );
  }
}

/// Full-width / compact quantity stepper (−  qty  +) — uniform across POS & Storefront.
class NusaQtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool fullWidth;
  final double height;
  NusaQtyStepper({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
    this.fullWidth = false,
    this.height = 36,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stepper = Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.activeSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NusaConfig.activePrimary.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(children: [
        _btn(Icons.remove, onDecrement),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            child: Text('$qty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w800, color: NusaConfig.activePrimary)),
          ),
        ),
        _btn(Icons.add, onIncrement),
      ]),
    );
    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: stepper,
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: height,
        height: height,
        child: Center(child: Icon(icon, size: 18, color: NusaConfig.activePrimary)),
      ),
    ),
  );
}
