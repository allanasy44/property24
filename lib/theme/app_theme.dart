import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color _lightBg = Color(0xffe9eaec);
  static const Color _lightBgCard = Color(0xffffffff);
  static const Color _lightBgSurface = Color(0xfff4f4f8);
  static const Color _lightBorder = Color(0xffe8e8f4);
  static const Color _lightBorderMid = Color(0xffc2bbfc);
  static const Color _lightTextPrimary = Color(0xff1f1e18);
  static const Color _lightTextSecondary = Color(0xff5f5f59);
  static const Color _lightTextMuted = Color(0xffa4a6a6);
  static const Color _darkBg = Color(0xff0d0f13);
  static const Color _darkBgCard = Color(0xff171b22);
  static const Color _darkBgSurface = Color(0xff202631);
  static const Color _darkBorder = Color(0xff303846);
  static const Color _darkBorderMid = Color(0xff465164);
  static const Color _darkTextPrimary = Color(0xfff5f7fa);
  static const Color _darkTextSecondary = Color(0xffb7c0cd);
  static const Color _darkTextMuted = Color(0xff8994a3);
  static const Color _darkSecondary = Color(0xff55c6b7);
  static bool _darkMode = false;

  static void setDarkMode(bool value) => _darkMode = value;

  static Color get bg => _darkMode ? _darkBg : _lightBg;
  static Color get bgCard => _darkMode ? _darkBgCard : _lightBgCard;
  static Color get bgSurface => _darkMode ? _darkBgSurface : _lightBgSurface;
  static Color get border => _darkMode ? _darkBorder : _lightBorder;
  static Color get borderMid => _darkMode ? _darkBorderMid : _lightBorderMid;
  static const Color accent = Color(0xff6a53fe);
  static const Color accentTeal = Color(0xff55c6b7);
  static const Color accentGold = Color(0xffffb13b);
  static Color get textPrimary =>
      _darkMode ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary =>
      _darkMode ? _darkTextSecondary : _lightTextSecondary;
  static Color get textMuted => _darkMode ? _darkTextMuted : _lightTextMuted;
  static const Color trustHigh = accent;

  static ThemeData get darkTheme {
    const background = _darkBg;
    const card = _darkBgCard;
    const surface = _darkBgSurface;
    const darkText = _darkTextPrimary;
    const mutedText = _darkTextSecondary;
    const darkBorder = _darkBorder;
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: darkText,
      displayColor: darkText,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xff2b255b),
        onPrimaryContainer: Color(0xffe8e4ff),
        secondary: _darkSecondary,
        onSecondary: Color(0xff071311),
        tertiary: accentGold,
        surface: card,
        onSurface: darkText,
        surfaceContainerHighest: surface,
        onSurfaceVariant: mutedText,
        outline: Color(0xff748092),
        outlineVariant: darkBorder,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dialogBackgroundColor: card,
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: darkText),
        actionTextColor: _darkSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: mutedText,
        textColor: darkText,
        tileColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
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
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText),
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
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: mutedText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: darkText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
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
      bodyColor: _lightTextPrimary,
      displayColor: _lightTextPrimary,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xfff1f1ff),
        onPrimaryContainer: _lightTextPrimary,
        secondary: accentTeal,
        onSecondary: Colors.white,
        tertiary: accentGold,
        surface: _lightBgCard,
        onSurface: _lightTextPrimary,
        surfaceContainerHighest: _lightBgSurface,
        onSurfaceVariant: _lightTextMuted,
        outline: _lightBorderMid,
        outlineVariant: _lightBorder,
      ),
      scaffoldBackgroundColor: _lightBg,
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
          color: _lightTextSecondary,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: _lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _lightBgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _lightBorder),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _lightBgSurface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: _lightBorder),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _lightBorder),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: _lightBgSurface,
        selectedColor: Color(0x1f6a53fe),
        side: BorderSide(color: _lightBorder),
        labelStyle: TextStyle(color: _lightTextPrimary),
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
          side: const BorderSide(color: _lightBorderMid),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
