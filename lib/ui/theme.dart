import 'package:flutter/material.dart';

/// Couleurs de l'interface, désignées par leur rôle. Les widgets n'utilisent que ces
/// rôles, jamais de couleur en dur : le thème clair et le thème sombre restent cohérents.
@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.active,
    required this.onActive,
    required this.heat,
    required this.success,
    required this.danger,
    required this.glazing,
    required this.shutter,
  });

  /// Fond de l'écran.
  final Color background;

  /// Tuiles, panneaux et barre de navigation.
  final Color surface;

  /// Boutons neutres, rails et zones en retrait à l'intérieur d'une tuile.
  final Color surfaceMuted;
  final Color border;

  final Color text;
  final Color textMuted;

  /// Texte non essentiel (contraste réduit).
  final Color textFaint;

  /// Actions principales et élément sélectionné.
  final Color accent;
  final Color onAccent;

  /// Fond de l'entrée de navigation sélectionnée.
  final Color accentSoft;

  /// Fond d'une tuile dont l'appareil est allumé, et couleur du texte posé dessus.
  final Color active;
  final Color onActive;

  final Color heat;
  final Color success;
  final Color danger;

  /// Vitre et tablier des volets.
  final Color glazing;
  final Color shutter;

  static const light = AppColors(
    background: Color(0xFFF5F0E8),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFE8DD),
    border: Color(0xFFE3D9CB),
    text: Color(0xFF2A1D14),
    textMuted: Color(0xFF6B5A4C),
    textFaint: Color(0xFF94826F),
    accent: Color(0xFFC2571A),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF8E3D0),
    active: Color(0xFFF6B55F),
    onActive: Color(0xFF2A1D14),
    heat: Color(0xFFCC4415),
    success: Color(0xFF2F7D4F),
    danger: Color(0xFFB93A2B),
    glazing: Color(0xFFCFE4EE),
    shutter: Color(0xFFB7A48F),
  );

  static const dark = AppColors(
    background: Color(0xFF16100C),
    surface: Color(0xFF231A14),
    surfaceMuted: Color(0xFF30251D),
    border: Color(0xFF3D3027),
    text: Color(0xFFF7EEE3),
    textMuted: Color(0xFFBCA996),
    textFaint: Color(0xFF8E7C6B),
    accent: Color(0xFFF0A257),
    onAccent: Color(0xFF2A1708),
    accentSoft: Color(0xFF45301F),
    active: Color(0xFFF0A257),
    onActive: Color(0xFF2A1708),
    heat: Color(0xFFFF8A5C),
    success: Color(0xFF86C99A),
    danger: Color(0xFFF08C7D),
    glazing: Color(0xFF3B5563),
    shutter: Color(0xFF75624F),
  );

  static AppColors of(Brightness brightness) => brightness == Brightness.dark ? dark : light;
}

/// Styles de texte (police Outfit embarquée). Tailles généreuses : l'interface
/// doit se lire à distance sur une tablette murale.
@immutable
class AppText {
  AppText._(AppColors c)
    : pageTitle = _style(28, FontWeight.w600, c.text, height: 1.15, spacing: -0.3),
      sectionTitle = _style(19, FontWeight.w600, c.text, height: 1.2),
      itemTitle = _style(17, FontWeight.w600, c.text, height: 1.25),
      body = _style(16, FontWeight.w400, c.text, height: 1.4),
      secondary = _style(15, FontWeight.w400, c.textMuted, height: 1.3),
      caption = _style(13, FontWeight.w500, c.textMuted, height: 1.25),
      button = _style(16, FontWeight.w600, c.text, height: 1.2),
      number = _style(24, FontWeight.w600, c.text, height: 1.1, tabular: true),
      display = _style(52, FontWeight.w600, c.text, height: 1, spacing: -1, tabular: true),
      clock = _style(36, FontWeight.w600, c.text, height: 1, spacing: -0.5, tabular: true);

  /// Titre de page.
  final TextStyle pageTitle;

  /// Titre de section ou de panneau.
  final TextStyle sectionTitle;

  /// Nom d'un appareil ou d'une pièce sur une tuile.
  final TextStyle itemTitle;
  final TextStyle body;

  /// Ligne d'état sous un nom (« Allumée · 80 % »).
  final TextStyle secondary;
  final TextStyle caption;
  final TextStyle button;

  /// Valeur chiffrée courante (consigne, pourcentage).
  final TextStyle number;

  /// Grande valeur chiffrée.
  final TextStyle display;
  final TextStyle clock;

  static final light = AppText._(AppColors.light);
  static final dark = AppText._(AppColors.dark);

  static AppText of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color, {
    required double height,
    double spacing = 0,
    bool tabular = false,
  }) => TextStyle(
    fontFamily: 'Outfit',
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

/// Accès aux couleurs et aux styles de texte du thème courant.
extension AppThemeContext on BuildContext {
  AppColors get colors => AppColors.of(Theme.of(this).brightness);

  AppText get text => AppText.of(Theme.of(this).brightness);
}

/// Dimensions communes.
abstract final class Dim {
  static const tileRadius = 16.0;
  static const panelRadius = 20.0;
  static const buttonRadius = 14.0;

  /// Espace entre deux tuiles.
  static const gap = 12.0;

  /// Espace entre deux sections.
  static const sectionGap = 20.0;
}

ThemeData buildTheme(Brightness brightness) {
  final c = AppColors.of(brightness);
  final t = AppText.of(brightness);
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Dim.buttonRadius),
    borderSide: BorderSide(color: c.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Outfit',
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.text,
    ),
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    dividerColor: c.border,
    splashColor: c.text.withValues(alpha: 0.07),
    highlightColor: c.text.withValues(alpha: 0.04),
    textTheme: TextTheme(
      titleLarge: t.sectionTitle,
      titleMedium: t.itemTitle,
      bodyLarge: t.body,
      bodyMedium: t.body,
      bodySmall: t.caption,
      labelLarge: t.button,
    ),
    iconTheme: IconThemeData(color: c.textMuted, size: 24),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
      selectionHandleColor: c.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceMuted.withValues(alpha: 0.5),
      labelStyle: t.secondary,
      floatingLabelStyle: t.secondary.copyWith(color: c.accent),
      hintStyle: t.body.copyWith(color: c.textFaint),
      helperStyle: t.caption,
      helperMaxLines: 2,
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 2)),
      errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 2)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface,
      contentTextStyle: t.body,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dim.buttonRadius),
        side: BorderSide(color: c.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: t.sectionTitle,
      contentTextStyle: t.body,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent, textStyle: t.button, minimumSize: const Size(64, 48)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(8)),
      textStyle: t.caption.copyWith(color: c.background),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.textFaint.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
    ),
  );
}
