import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

/// Fond chaleureux : dégradé brun, halos de lumière cognac et grain de cuir.
/// Statique pour que les effets de verre restent légers à calculer.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _AmbientPainter())),
        child,
      ],
    );
  }
}

class _Glow {
  const _Glow(this.x, this.y, this.radius, this.color, this.alpha);

  final double x;
  final double y;

  /// Rayon relatif à la plus grande dimension de l'écran.
  final double radius;
  final Color color;
  final double alpha;
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();

  static const _glows = [
    _Glow(0.10, 0.00, 0.50, Palette.cognac, 0.72),
    _Glow(0.55, 0.36, 0.30, Palette.terracotta, 0.42),
    _Glow(0.97, 0.04, 0.32, Palette.amber, 0.32),
    _Glow(0.26, 1.02, 0.44, Palette.saddle, 0.70),
    _Glow(0.90, 0.98, 0.38, Palette.honey, 0.20),
    _Glow(0.42, 0.72, 0.24, Palette.ember, 0.14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF21150D), Color(0xFF150D08), Color(0xFF0D0805)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    final extent = size.longestSide;
    for (final g in _glows) {
      final center = Offset(g.x * size.width, g.y * size.height);
      final radius = g.radius * extent;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              g.color.withValues(alpha: g.alpha),
              g.color.withValues(alpha: g.alpha * 0.35),
              g.color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    LeatherGrain.paint(canvas, rect, opacity: 0.8);

    // Vignettage pour concentrer la lumière au centre.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => false;
}
