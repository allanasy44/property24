import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color bg = Color(0xff08110d);
  static const Color bgCard = Color(0xff101c17);
  static const Color bgSurface = Color(0xff15251e);
  static const Color border = Color(0xff263a31);
  static const Color borderMid = Color(0xff365247);
  static const Color accent = Color(0xff19b66a);
  static const Color accentTeal = Color(0xff33d6c2);
  static const Color accentGold = Color(0xffffc857);
  static const Color textPrimary = Color(0xfff4fbf7);
  static const Color textSecondary = Color(0xffaebdb5);
  static const Color textMuted = Color(0xff72847a);
  static const Color trustHigh = Color(0xff35d07f);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: 'DM Sans',
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentTeal,
        tertiary: accentGold,
        surface: bgCard,
        onSurface: textPrimary,
        surfaceContainerHighest: bgSurface,
        outline: border,
        outlineVariant: borderMid,
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
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: Color(0x3319b66a),
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderMid),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: 'DM Sans',
      bodyColor: const Color(0xff102019),
      displayColor: const Color(0xff102019),
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        primary: accent,
        secondary: const Color(0xff12324a),
        tertiary: accentGold,
      ),
      scaffoldBackgroundColor: const Color(0xfff5f7f3),
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
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff5f7f3),
        foregroundColor: Color(0xff102019),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xffdce8df)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xffdce8df)),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xffdce8df)),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }
}
