import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Réglages visuels partagés (effet verre allégé pour les tablettes modestes).
class GlassSettings extends InheritedWidget {
  const GlassSettings({super.key, required this.reduced, required super.child});

  final bool reduced;

  static bool reducedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassSettings>()?.reduced ?? false;

  @override
  bool updateShouldNotify(GlassSettings oldWidget) => oldWidget.reduced != reduced;
}

/// Texture de grain de cuir générée une fois au démarrage (bruit cellulaire tuilable).
abstract final class LeatherGrain {
  static ui.Image? image;

  static Future<void> ensureLoaded() async {
    if (image != null) return;
    const size = 128;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(generatePixels(size), size, size, ui.PixelFormat.rgba8888, completer.complete);
    image = await completer.future;
  }

  /// Bruit cellulaire tuilable sur une grille légèrement déformée : les « plis »
  /// entre cellules sont assombris, comme le grain pleine fleur d'un cuir.
  static Uint8List generatePixels(int size) {
    final random = math.Random(11);
    const grid = 18;
    final step = size / grid;
    final points = List.generate(
      grid * grid,
      (i) => Offset(
        (i % grid + 0.5 + (random.nextDouble() - 0.5) * 0.85) * step,
        (i ~/ grid + 0.5 + (random.nextDouble() - 0.5) * 0.85) * step,
      ),
    );
    final pixels = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final gx = (x / step).floor();
        final gy = (y / step).floor();
        var f1 = double.infinity;
        var f2 = double.infinity;
        for (var j = -2; j <= 2; j++) {
          for (var i = -2; i <= 2; i++) {
            final cx = gx + i;
            final cy = gy + j;
            final wx = (cx % grid + grid) % grid;
            final wy = (cy % grid + grid) % grid;
            final p = points[wy * grid + wx];
            final px = p.dx + (cx - wx) * step;
            final py = p.dy + (cy - wy) * step;
            final d = (px - x) * (px - x) + (py - y) * (py - y);
            if (d < f1) {
              f2 = f1;
              f1 = d;
            } else if (d < f2) {
              f2 = d;
            }
          }
        }
        final edge = math.sqrt(f2) - math.sqrt(f1); // 0 sur les plis
        final crease = 1 - (edge / 1.6).clamp(0.0, 1.0);
        // Légère variation à grande échelle (périodique pour rester tuilable).
        final wave = 0.8 + 0.2 * math.sin(2 * math.pi * x / size * 2) * math.cos(2 * math.pi * y / size * 3);
        final alpha = ((crease * crease * 30 + random.nextDouble() * 5) * wave).round().clamp(0, 255);
        // Noir pur : valeurs identiques en alpha prémultiplié ou non.
        pixels[(y * size + x) * 4 + 3] = alpha;
      }
    }
    return pixels;
  }

  /// Peint le grain sur [rect] (ou dans [clip]) ; [opacity] module l'intensité.
  static void paint(Canvas canvas, Rect rect, {double opacity = 1, RRect? clip}) {
    final img = image;
    if (img == null || opacity <= 0) return;
    final paint = Paint()
      // Échelle 0,6 : grain plus serré, qui reste fin sur les écrans haute densité.
      ..shader = ImageShader(
        img,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.diagonal3Values(0.6, 0.6, 1).storage,
        filterQuality: FilterQuality.medium,
      )
      ..color = Colors.black.withValues(alpha: opacity.clamp(0.0, 1.0));
    if (clip != null) {
      canvas.drawRRect(clip, paint);
    } else {
      canvas.drawRect(rect, paint);
    }
  }
}

/// Carte en verre dépoli aux reflets chauds.
class GlassCard extends StatelessWidget {
  const GlassCard({
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

  /// Lueur colorée optionnelle (ex. ambre pour un appareil allumé).
  final Color? tint;

  /// Surpiqûre façon cuir le long du bord.
  final bool stitched;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    final reduced = GlassSettings.reducedOf(context);
    final borderRadius = BorderRadius.circular(radius);
    Widget content = CustomPaint(
      painter: GlassPainter(radius: radius, tint: tint, stitched: stitched, reduced: reduced, grain: grain),
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
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        enabled: !reduced,
        child: content,
      ),
    );
  }
}

/// Peintre partagé du matériau verre : remplissage, reflet, liseré et surpiqûre.
class GlassPainter extends CustomPainter {
  const GlassPainter({
    this.radius = 30,
    this.tint,
    this.stitched = false,
    this.reduced = false,
    this.grain = true,
    this.strength = 1,
  });

  final double radius;
  final Color? tint;
  final bool stitched;
  final bool reduced;
  final bool grain;

  /// Intensité du remplissage (les pastilles sont plus légères que les cartes).
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    if (reduced) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF26180F).withValues(alpha: 0.94));
    }

    // Verre teinté : blanc chaud, plus dense en haut à gauche.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFE6CC).withValues(alpha: 0.12 * strength),
            const Color(0xFFFFD9B5).withValues(alpha: 0.05 * strength),
            const Color(0xFFFFC890).withValues(alpha: 0.035 * strength),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    final glow = tint;
    if (glow != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.8, -0.9),
            radius: 1.3,
            colors: [glow.withValues(alpha: 0.26), glow.withValues(alpha: 0.0)],
          ).createShader(rect),
      );
    }

    if (grain) LeatherGrain.paint(canvas, rect, opacity: 0.6, clip: rrect);

    // Reflet supérieur.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.07 * strength),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // Liseré lumineux.
    final border = rrect.deflate(0.6);
    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.06),
            Palette.amber.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );

    if (stitched) _paintStitch(canvas, rrect.deflate(7));
  }

  void _paintStitch(Canvas canvas, RRect rrect) {
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = Palette.honey.withValues(alpha: 0.30);
    const dash = 5.5;
    const gap = 4.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(GlassPainter old) =>
      old.radius != radius ||
      old.tint != tint ||
      old.stitched != stitched ||
      old.reduced != reduced ||
      old.grain != grain ||
      old.strength != strength;
}

/// Pastille de verre (étiquettes, filtres, indicateurs).
class GlassPill extends StatelessWidget {
  const GlassPill({
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
    final reduced = GlassSettings.reducedOf(context);
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: selected
          ? BoxDecoration(
              gradient: Palette.warm,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: Palette.ember.withValues(alpha: 0.35), blurRadius: 16)],
            )
          : const BoxDecoration(),
      child: CustomPaint(
        painter: selected ? null : GlassPainter(radius: 100, reduced: reduced, grain: false, strength: 0.9),
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
