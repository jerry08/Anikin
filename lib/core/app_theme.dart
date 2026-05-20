import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ThemeColorPalette { anikin, sakura, ocean, forest, sunset }

class AppTheme {
  const AppTheme._();

  static const _palettes = <ThemeColorPalette, _ThemePalette>{
    ThemeColorPalette.anikin: _ThemePalette(
      label: 'Anikin',
      lightPrimary: Color(0xFF512BD4),
      lightSecondary: Color(0xFF4287F5),
      darkPrimary: Color(0xFFB7A5FF),
      darkSecondary: Color(0xFF93B8FF),
      tertiary: Color(0xFFF7B548),
    ),
    ThemeColorPalette.sakura: _ThemePalette(
      label: 'Sakura',
      lightPrimary: Color(0xFFB4235B),
      lightSecondary: Color(0xFF7C5CFF),
      darkPrimary: Color(0xFFFFB1C8),
      darkSecondary: Color(0xFFC9BCFF),
      tertiary: Color(0xFFFFC36A),
    ),
    ThemeColorPalette.ocean: _ThemePalette(
      label: 'Ocean',
      lightPrimary: Color(0xFF006B8F),
      lightSecondary: Color(0xFF008C7A),
      darkPrimary: Color(0xFF7DDCFF),
      darkSecondary: Color(0xFF82E6D4),
      tertiary: Color(0xFFFFC857),
    ),
    ThemeColorPalette.forest: _ThemePalette(
      label: 'Forest',
      lightPrimary: Color(0xFF2E7D32),
      lightSecondary: Color(0xFF00796B),
      darkPrimary: Color(0xFFA6DFA2),
      darkSecondary: Color(0xFF8FDCD1),
      tertiary: Color(0xFFFFCA28),
    ),
    ThemeColorPalette.sunset: _ThemePalette(
      label: 'Sunset',
      lightPrimary: Color(0xFFC2410C),
      lightSecondary: Color(0xFF9D4EDD),
      darkPrimary: Color(0xFFFFB088),
      darkSecondary: Color(0xFFD9B3FF),
      tertiary: Color(0xFF7DDCFF),
    ),
  };

  static const surfaceDark = Color(0xFF141414);
  static const surfaceDarkHigh = Color(0xFF212121);
  static const surfaceDarkHighest = Color(0xFF2B2B2B);

  static String paletteLabel(ThemeColorPalette palette) {
    return _palette(palette).label;
  }

  static Color palettePrimary(
    ThemeColorPalette palette,
    Brightness brightness,
  ) {
    final colors = _palette(palette);
    return brightness == Brightness.dark
        ? colors.darkPrimary
        : colors.lightPrimary;
  }

  static Color paletteSecondary(
    ThemeColorPalette palette,
    Brightness brightness,
  ) {
    final colors = _palette(palette);
    return brightness == Brightness.dark
        ? colors.darkSecondary
        : colors.lightSecondary;
  }

  static SystemUiOverlayStyle edgeToEdgeOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData dark(ThemeColorPalette palette) {
    final colors = _palette(palette);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Lato',
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.darkPrimary,
        brightness: Brightness.dark,
        primary: colors.darkPrimary,
        secondary: colors.darkSecondary,
        tertiary: colors.tertiary,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        centerTitle: false,
        systemOverlayStyle: edgeToEdgeOverlayStyle(Brightness.dark),
      ),
      cardTheme: CardThemeData(
        color: surfaceDarkHigh,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDarkHigh,
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDarkHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  static ThemeData light(ThemeColorPalette palette) {
    final colors = _palette(palette);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Lato',
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.lightPrimary,
        primary: colors.lightPrimary,
        secondary: colors.lightSecondary,
        tertiary: colors.tertiary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        systemOverlayStyle: edgeToEdgeOverlayStyle(Brightness.light),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  static _ThemePalette _palette(ThemeColorPalette palette) {
    return _palettes[palette] ?? _palettes[ThemeColorPalette.anikin]!;
  }
}

class _ThemePalette {
  const _ThemePalette({
    required this.label,
    required this.lightPrimary,
    required this.lightSecondary,
    required this.darkPrimary,
    required this.darkSecondary,
    required this.tertiary,
  });

  final String label;
  final Color lightPrimary;
  final Color lightSecondary;
  final Color darkPrimary;
  final Color darkSecondary;
  final Color tertiary;
}
