import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

class NusaTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor;
    final surface = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;
    final textPri =
        isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final textSec =
        isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
    final textTer =
        isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;
    final divider =
        isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor;
    final primary = NusaConfig.activePrimary;
    final cardShadow =
        isDark ? NusaConfig.darkCardShadow : Color(0x0A111827);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
        brightness: brightness,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displaySmall: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: textPri),
        titleLarge: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: textPri),
        titleMedium: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2,
            color: textPri),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: textPri),
        bodySmall: GoogleFonts.inter(fontSize: 13, color: textSec),
        labelSmall: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textTer),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: primary.withValues(alpha: 0.28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.symmetric(vertical: 16),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: cardShadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: surface,
        insetPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        backgroundColor: surface,
      ),
    );
  }
}
