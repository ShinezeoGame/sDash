import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart' show LeatherGrain;

/// Relief d'une pièce de cuir : rembourrée (cartes, boutons) ou creusée (rails, gorges).
enum Relief { raised, sunken }

/// Matériau cuir opaque : dégradé chocolat, grain, rembourrage, liseré et surpiqûre.
class LeatherPainter extends CustomPainter {
  const LeatherPainter({
    this.radius = 30,
    this.relief = Relief.raised,
    this.stitched = false,
    this.tint,
    this.grain = true,
    this.tone = 1,
  });

  final double radius;
  final Relief relief;
  final bool stitched;

  /// Reflet coloré optionnel (appareil allumé…).
  final Color? tint;
  final bool grain;

  /// Éclaircissement du cuir : 1 pour les cartes, un peu plus pour les petits boutons.
  final double tone;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(math.min(radius, size.shortestSide / 2)));
    if (relief == Relief.raised) {
      _raised(canvas, rect, rrect);
    } else {
      _sunken(canvas, rect, rrect);
    }
  }

  void _raised(Canvas canvas, Rect rect, RRect rrect) {
    const light = Color(0xFF8A5530);
    final lift = (tone - 1).clamp(0.0, 1.0);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(Palette.leatherTop, light, lift)!, Color.lerp(Palette.leatherBottom, light, lift * 0.6)!],
        ).createShader(rect),
    );

    // Rembourrage : la lumière accroche le haut de la pièce.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.6),
          radius: 1.15,
          colors: [const Color(0xFFFFD9A8).withValues(alpha: 0.11), const Color(0xFFFFD9A8).withValues(alpha: 0)],
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
            colors: [glow.withValues(alpha: 0.22), glow.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    if (grain) LeatherGrain.paint(canvas, rect, clip: rrect);

    // Bords arrondis du rembourrage : légère ombre intérieure tout autour.
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();

    // Liseré : clair en haut, sombre en bas.
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFE2BC).withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.03),
            Colors.black.withValues(alpha: 0.5),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );

    if (stitched) _stitch(canvas, rrect.deflate(rrect.tlRadiusX > 20 ? 9 : 6));
  }

  void _sunken(Canvas canvas, Rect rect, RRect rrect) {
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF140A05).withValues(alpha: 0.55));
    if (grain) LeatherGrain.paint(canvas, rect, opacity: 0.8, clip: rrect);
    // Ombre portée par le bord supérieur, à l'intérieur de la gorge.
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)).inflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
    // Lèvre claire en bas : le cuir remonte vers la lumière.
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.35), const Color(0xFFFFDDB3).withValues(alpha: 0.16)],
        ).createShader(rect),
    );
  }

  void _stitch(Canvas canvas, RRect rrect) {
    final path = Path()..addRRect(rrect);
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.55);
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Palette.thread.withValues(alpha: 0.6);
    const dash = 6.0;
    const gap = 4.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment.shift(const Offset(0, 1.3)), shadow);
        canvas.drawPath(segment, thread);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(LeatherPainter old) =>
      old.radius != radius ||
      old.relief != relief ||
      old.stitched != stitched ||
      old.tint != tint ||
      old.grain != grain ||
      old.tone != tone;
}
