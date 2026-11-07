import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../look.dart';
import '../theme.dart';

/// Carte de l'interface. En style cuir : pièce de cuir rembourrée et surpiquée,
/// avec ombre portée. En style verre : verre dépoli sur flou d'arrière-plan.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 30,
    this.blur = 28,
    this.tint,
    this.stitched = false,
    this.onTap,
    this.onLongPress,
    this.grain = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  /// Reflet coloré optionnel (ex. ambre pour un appareil allumé).
  final Color? tint;

  /// Surpiqûre le long du bord (toujours présente en style cuir).
  final bool stitched;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final borderRadius = BorderRadius.circular(radius);
    Widget content = CustomPaint(
      painter: look.surface(radius: radius, tint: tint, stitched: look.leather || stitched, grain: grain),
      child: Padding(padding: padding, child: child),
    );
    if (onTap != null || onLongPress != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: Palette.amber.withValues(alpha: 0.10),
          highlightColor: Palette.amber.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }
    if (look.leather) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: ClipRRect(borderRadius: borderRadius, child: content),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        enabled: look.blurEnabled,
        child: content,
      ),
    );
  }
}

/// Pastille (étiquettes, filtres, boutons texte) : cuir embossé ou verre.
class SurfacePill extends StatelessWidget {
  const SurfacePill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: selected
          ? look.active(radius: 100, glow: 0.9)
          : BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: look.leather
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
      child: CustomPaint(
        painter: selected ? null : look.surface(radius: 100, strength: 0.9, grain: look.leather),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: AppText.label.copyWith(
              color: selected ? Palette.onWarm : Palette.sand,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: selected ? Palette.onWarm : Palette.sand, size: 18),
              child: child,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: pill);
  }
}
