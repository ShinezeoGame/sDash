import 'package:flutter/material.dart';

import '../data/settings.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/leather.dart';

export '../data/settings.dart' show AppStyle;
export 'widgets/leather.dart' show Relief;

/// Matière de l'interface (cuir ou verre), partagée par tous les widgets.
///
/// Les composants demandent leur surface et leur décoration « active » ici,
/// ce qui permet de changer de style sans toucher aux écrans.
class AppLook extends InheritedWidget {
  const AppLook({super.key, this.style = AppStyle.leather, this.reducedGlass = false, required super.child});

  final AppStyle style;

  /// Verre sans flou (tablettes peu puissantes) ; sans effet en style cuir.
  final bool reducedGlass;

  static const _fallback = AppLook(child: SizedBox.shrink());

  static AppLook of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppLook>() ?? _fallback;

  bool get leather => style == AppStyle.leather;

  /// Faux en style cuir : aucun flou d'arrière-plan n'est calculé.
  bool get blurEnabled => !leather && !reducedGlass;

  /// Surface d'un élément : cuir rembourré ou creusé, ou verre dépoli.
  CustomPainter surface({
    required double radius,
    Relief relief = Relief.raised,
    double strength = 1,
    bool stitched = false,
    Color? tint,
    bool grain = true,
  }) {
    if (leather) {
      return LeatherPainter(
        radius: radius,
        relief: relief,
        stitched: stitched,
        tint: tint,
        grain: grain,
        tone: strength < 1 ? 1.18 : 1,
      );
    }
    return GlassPainter(
      radius: radius,
      tint: tint,
      stitched: stitched,
      reduced: reducedGlass,
      grain: grain,
      strength: relief == Relief.sunken ? strength * 0.6 : strength,
    );
  }

  /// Décoration d'un élément sélectionné ou allumé : cuir fauve, ou dégradé lumineux.
  BoxDecoration active({BoxShape shape = BoxShape.rectangle, double radius = 100, double glow = 1}) {
    final borderRadius = shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null;
    if (leather) {
      return BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        gradient: Palette.tan,
        border: Border.all(color: const Color(0xFFFFE4BE).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8 * glow, offset: const Offset(0, 3)),
        ],
      );
    }
    return BoxDecoration(
      shape: shape,
      borderRadius: borderRadius,
      gradient: Palette.warm,
      boxShadow: [BoxShadow(color: Palette.ember.withValues(alpha: 0.42), blurRadius: 18 * glow)],
    );
  }

  @override
  bool updateShouldNotify(AppLook oldWidget) => oldWidget.style != style || oldWidget.reducedGlass != reducedGlass;
}
