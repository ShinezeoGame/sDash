import 'package:flutter/material.dart';

import '../look.dart';
import '../theme.dart';
import 'glass.dart';

/// Fond de l'application. Style verre : dégradé brun, halos de lumière cognac et grain.
/// Style cuir : grande pièce de cuir sombre surpiquée, comme un sous-main de bureau.
/// Statique pour que les effets de verre restent légers à calculer.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: AppLook.of(context).leather ? const _LeatherDeskPainter() : const _AmbientPainter(),
          ),
        ),
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

/// Sous-main en cuir : peau sombre aux nuances naturelles, grain marqué et surpiqûre de bord.
class _LeatherDeskPainter extends CustomPainter {
  const _LeatherDeskPainter();

  static const _patches = [
    _Glow(0.12, 0.05, 0.55, Color(0xFF8A4B22), 0.32), // lumière chaude d'une lampe
    _Glow(0.70, 0.45, 0.40, Color(0xFF000000), 0.22),
    _Glow(0.35, 0.80, 0.35, Color(0xFF5A2E15), 0.30),
    _Glow(0.92, 0.10, 0.30, Color(0xFF6B3A1C), 0.22),
    _Glow(0.85, 0.95, 0.40, Color(0xFF000000), 0.25),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1A0F), Color(0xFF1C100A), Color(0xFF120A06)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final extent = size.longestSide;
    for (final p in _patches) {
      final center = Offset(p.x * size.width, p.y * size.height);
      final radius = p.radius * extent;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              p.color.withValues(alpha: p.alpha),
              p.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    LeatherGrain.paint(canvas, rect);
    LeatherGrain.paint(canvas, rect, opacity: 0.5);

    // Surpiqûre le long du bord de l'écran.
    final seam = RRect.fromRectAndRadius(rect.deflate(8), const Radius.circular(26));
    final path = Path()..addRRect(seam);
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.6);
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Palette.thread.withValues(alpha: 0.32);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 11) {
        final segment = metric.extractPath(d, d + 6.5);
        canvas.drawPath(segment.shift(const Offset(0, 1.2)), shadow);
        canvas.drawPath(segment, thread);
      }
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LeatherDeskPainter oldDelegate) => false;
}
