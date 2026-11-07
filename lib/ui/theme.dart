import 'package:flutter/material.dart';

/// Palette « cuir & cognac » : bruns profonds, ambres chauds, crème.
abstract final class Palette {
  // Fonds
  static const espresso = Color(0xFF110A06);
  static const chocolate = Color(0xFF1D120B);
  static const walnut = Color(0xFF3B2516);
  static const saddle = Color(0xFF7A3E1C);

  // Accents cuir
  static const cognac = Color(0xFFC2692B);
  static const terracotta = Color(0xFFB54F2D);
  static const amber = Color(0xFFF0A257);
  static const honey = Color(0xFFF7C57E);
  static const ember = Color(0xFFFF8E45);

  // Textes
  static const cream = Color(0xFFF8ECDD);
  static const sand = Color(0xFFDDC6AD);
  static const taupe = Color(0xFFA98F79);
  static const dusk = Color(0xFF7D6555);

  // États
  static const sage = Color(0xFFADC893);
  static const rose = Color(0xFFE5826F);
  static const frost = Color(0xFFA3C9D8);

  /// Dégradé principal des éléments actifs (miel → braise).
  static const warm = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [honey, ember]);

  /// Texte sombre posé sur le dégradé chaud.
  static const onWarm = Color(0xFF2B1608);

  // Cuir (style « cuir »)
  static const leatherTop = Color(0xFF4A2B18);
  static const leatherBottom = Color(0xFF2C190E);
  static const thread = Color(0xFFEAD3AE);

  /// Cuir fauve des éléments actifs (remplace la lueur du style verre).
  static const tan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6B27A), Color(0xFFC88A4E), Color(0xFFA5622D)],
    stops: [0, 0.55, 1],
  );

  /// Laiton des boutons d'interrupteur et de la poignée du thermostat.
  static const brass = RadialGradient(
    center: Alignment(-0.35, -0.45),
    colors: [Color(0xFFFFF0C2), Color(0xFFE2BC6A), Color(0xFFA77A2C), Color(0xFF6E4C17)],
    stops: [0, 0.35, 0.8, 1],
  );
}

/// Styles typographiques (police Outfit embarquée).
abstract final class AppText {
  static const _family = 'Outfit';

  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 56,
    fontWeight: FontWeight.w300,
    height: 1.0,
    letterSpacing: -1.6,
    color: Palette.cream,
  );

  static const clock = TextStyle(
    fontFamily: _family,
    fontSize: 42,
    fontWeight: FontWeight.w300,
    height: 1.0,
    letterSpacing: -1.2,
    color: Palette.cream,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const greeting = TextStyle(
    fontFamily: _family,
    fontSize: 30,
    fontWeight: FontWeight.w500,
    height: 1.1,
    letterSpacing: -0.4,
    color: Palette.cream,
  );

  static const title = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.2,
    color: Palette.cream,
  );

  static const subtitle = TextStyle(
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: Palette.cream,
  );

  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: Palette.sand,
  );

  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.2,
    color: Palette.taupe,
  );

  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: Palette.dusk,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.amber,
    onPrimary: Palette.onWarm,
    secondary: Palette.cognac,
    onSecondary: Palette.cream,
    surface: Palette.chocolate,
    onSurface: Palette.cream,
    error: Palette.rose,
    onError: Palette.onWarm,
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Outfit',
    scaffoldBackgroundColor: Palette.espresso,
    canvasColor: Palette.chocolate,
    textTheme: const TextTheme(
      displayLarge: AppText.display,
      headlineMedium: AppText.greeting,
      titleLarge: AppText.title,
      titleMedium: AppText.subtitle,
      bodyMedium: AppText.body,
      bodyLarge: AppText.body,
      labelLarge: AppText.label,
      bodySmall: AppText.caption,
    ),
    iconTheme: const IconThemeData(color: Palette.sand, size: 22),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Palette.amber,
      selectionColor: Palette.amber.withValues(alpha: 0.35),
      selectionHandleColor: Palette.amber,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.18),
      labelStyle: AppText.label,
      floatingLabelStyle: AppText.label.copyWith(color: Palette.amber),
      hintStyle: AppText.body.copyWith(color: Palette.dusk),
      helperStyle: AppText.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: Palette.amber, width: 1.4)),
      errorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: Palette.rose)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: Palette.rose, width: 1.4)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF22A1A10),
      contentTextStyle: AppText.body.copyWith(color: Palette.cream),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Palette.amber.withValues(alpha: 0.25)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF0241710),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      titleTextStyle: AppText.title,
      contentTextStyle: AppText.body,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.amber, textStyle: AppText.subtitle.copyWith(fontSize: 15)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: const Color(0xF02A1A10), borderRadius: BorderRadius.circular(10)),
      textStyle: AppText.label.copyWith(color: Palette.cream),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Palette.amber.withValues(alpha: 0.35)),
      radius: const Radius.circular(8),
    ),
  );
}
