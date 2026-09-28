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

  static ThemeData get darkTheme {
    const background = Color(0xff111318);
    const card = Color(0xff1a1d24);
    const surface = Color(0xff222631);
    const darkText = Color(0xfff4f5f7);
    const mutedText = Color(0xffb6bbc5);
    const darkBorder = Color(0xff343a47);
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: darkText,
      displayColor: darkText,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xff302870),
        onPrimaryContainer: Color(0xffeeeaff),
        secondary: accentTeal,
        onSecondary: Colors.white,
        tertiary: accentGold,
        surface: card,
        onSurface: darkText,
        surfaceContainerHighest: surface,
        onSurfaceVariant: mutedText,
        outline: Color(0xff5d6676),
        outlineVariant: darkBorder,
      ),
      scaffoldBackgroundColor: background,
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
          color: mutedText,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: darkBorder),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: darkBorder),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: accent),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surface,
        selectedColor: Color(0x4d6a53fe),
        side: BorderSide(color: darkBorder),
        labelStyle: TextStyle(color: darkText),
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
          foregroundColor: Color(0xffc9c2ff),
          side: const BorderSide(color: Color(0xff8075d8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

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
