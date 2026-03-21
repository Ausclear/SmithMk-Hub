import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// SmithMk Smart Home Hub — Design Bible
///
/// Source: Premium smart home UI/UX research document.
/// This is the BIBLE. Do not deviate unless Mark says otherwise.
///
/// Key principles:
/// - Dark-first: #121212 base, NOT pure black, NOT navy blue
/// - Single accent: warm amber/gold (#FFB300) — sparingly
/// - Inactive: 30-50% opacity of accent OR neutral #4A4A4A
/// - Cards: #1E1E1E to #252525 with 1px border at 10-15% white opacity
/// - Typography: Inter or system font, Medium-to-Bold only, NEVER thin on dark
/// - Text: off-white #E0E0E0-#EEEEEE, NOT pure white
/// - Icons: line for inactive, filled for active (SF Symbols approach)
/// - Animations: 200-500ms, spring physics (Curves.easeInOutCubicEmphasized)
/// - Spacing: 24-32px inside cards, 16-24px gaps between cards
/// - Luxury = restraint. Progressive disclosure. Generous spacing.

class SmithMkColors {
  // ─── BACKGROUNDS ───
  // "Material Design recommends #121212 (dark grey) rather than #000000"
  // "Several platforms use a blue-black tint (#0D1117 to #141B2D)"
  // Mark's rule: NO navy blue. Using neutral dark grey.
  static const Color background = Color(0xFF121212);
  static const Color cardSurface = Color(0xFF1E1E1E);      // "secondary surfaces #1E1E1E to #252525"
  static const Color cardSurfaceAlt = Color(0xFF252525);    // elevated cards
  static const Color glassBorder = Color(0x26FFFFFF);       // "1px borders at 10-15% white opacity"

  // ─── TEXT — off-white, NOT pure white ───
  // "Text should be off-white (#E0E0E0–#EEEEEE)"
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF707070);

  // ─── ACCENT — warm amber/gold, SINGLE accent ───
  // "warm amber/gold (#FFB300–#F4C430) as the sole accent colour"
  // "Use it sparingly — active toggles, slider thumbs, scene pulses, status indicators"
  static const Color accent = Color(0xFFFFB300);            // Primary amber
  static const Color gold = Color(0xFFC4A96B);              // Gold for branding/labels

  // ─── INACTIVE ───
  // "Inactive states should drop to 30-50% opacity of accent or shift to #4A4A4A"
  static const Color inactive = Color(0xFF4A4A4A);

  // ─── STATUS (minimal use — dots only) ───
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFF87171);

  // ─── FUNCTIONAL TEMPERATURE COLOURS (thermostat arc only) ───
  static const Color tempCool = Color(0xFF48CAE4);
  static const Color tempAmber = Color(0xFFFFB300);
  static const Color tempHot = Color(0xFFFF5722);
  static const Color heatingMode = Color(0xFFFF6B35);
}

class SmithMkTheme {
  static ThemeData get darkTheme {
    // "No premium platform uses a custom typeface... use Inter"
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SmithMkColors.background,
      colorScheme: const ColorScheme.dark(
        surface: SmithMkColors.background,
        primary: SmithMkColors.accent,
        secondary: SmithMkColors.gold,
        error: SmithMkColors.error,
        onSurface: SmithMkColors.textPrimary,
        onPrimary: SmithMkColors.background,
      ),
      textTheme: baseTextTheme.copyWith(
        // "Bold/Semibold for headings (28-34pt)"
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: 32, fontWeight: FontWeight.w700, color: SmithMkColors.textPrimary,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary,
        ),
        // "Medium for subheadings (20-24pt)"
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary,
        ),
        // "Regular for body (15-17pt)"
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w400, color: SmithMkColors.textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w400, color: SmithMkColors.textSecondary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w500, color: SmithMkColors.textTertiary,
        ),
        // Labels
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 11, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary, letterSpacing: 0.8,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SmithMkColors.cardSurface,
        indicatorColor: SmithMkColors.accent.withValues(alpha: 0.15),
      ),
    );
  }
}
