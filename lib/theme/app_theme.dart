import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color bg = Color(0xffe9eaec);
  static const Color bgCard = Color(0xffffffff);
  static const Color bgSurface = Color(0xfff4f4f8);
  static const Color border = Color(0xffe8e8f4);
  static const Color borderMid = Color(0xffc2bbfc);
  static const Color accent = Color(0xff6a53fe);
  static const Color accentTeal = Color(0xff8674fe);
  static const Color accentGold = Color(0xffffb13b);
  static const Color textPrimary = Color(0xff1f1e18);
  static const Color textSecondary = Color(0xff5f5f59);
  static const Color textMuted = Color(0xffa4a6a6);
  static const Color trustHigh = Color(0xff6a53fe);

  static ThemeData get darkTheme => lightTheme;

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xfff1f1ff),
        onPrimaryContainer: textPrimary,
        secondary: textPrimary,
        onSecondary: Colors.white,
        tertiary: accentGold,
        surface: bgCard,
        onSurface: textPrimary,
        surfaceContainerHighest: bgSurface,
        onSurfaceVariant: textMuted,
        outline: borderMid,
        outlineVariant: border,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: Color(0x1f6a53fe),
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: borderMid),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
