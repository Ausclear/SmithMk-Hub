import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SmithMkColors {
  // Backgrounds - NEAR BLACK, NO BLUE WHATSOEVER
  static const Color background = Color(0xFF0A0A0A);      // #0a0a0a - near black
  static const Color cardSurface = Color(0xFF111111);      // #111111 - card surface
  static const Color elevatedSurface = Color(0xFF1A1A1A);  // elevated
  static const Color glassOverlay = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFE8E8ED);
  static const Color textSecondary = Color(0xFF8B8B9E);
  static const Color textTertiary = Color(0xFF55556A);

  // Accents - AMBER/GOLD ONLY
  static const Color accentPrimary = Color(0xFFFFC107);
  static const Color gold = Color(0xFFC4A96B);
  static const Color accentPurple = Color(0xFF9C27B0);

  // Semantic
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);

  // Device states
  static const Color lightOn = Color(0xFFFFC107);
  static const Color lightOff = Color(0xFF55556A);
  static const Color heatingActive = Color(0xFFFF6B35);
  static const Color coolingActive = Color(0xFF48CAE4);
  static const Color securityArmed = Color(0xFF4ADE80);
  static const Color blindOpen = Color(0xFF9C27B0);
}

class SmithMkTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SmithMkColors.background,
      colorScheme: const ColorScheme.dark(
        surface: SmithMkColors.background,
        primary: SmithMkColors.accentPrimary,
        secondary: SmithMkColors.gold,
        error: SmithMkColors.error,
        onSurface: SmithMkColors.textPrimary,
        onPrimary: SmithMkColors.background,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(fontSize: 56, fontWeight: FontWeight.w300, color: SmithMkColors.textPrimary),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontSize: 18, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: SmithMkColors.textPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: SmithMkColors.textSecondary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: SmithMkColors.textTertiary),
        labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SmithMkColors.cardSurface,
        indicatorColor: SmithMkColors.accentPrimary.withValues(alpha: 0.15),
      ),
    );
  }
}
