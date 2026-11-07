import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/home.dart';
import '../theme.dart';

/// Fenêtre stylisée dont le volet descend selon la position.
/// Un glissement vertical permet de choisir la position au doigt.
class ShutterView extends StatefulWidget {
  const ShutterView({
    super.key,
    required this.position,
    this.motion = CoverMotion.idle,
    this.onChangeEnd,
    this.compact = false,
  });

  /// 0 = fermé, 100 = ouvert.
  final int position;
  final CoverMotion motion;
  final ValueChanged<int>? onChangeEnd;
  final bool compact;

  @override
  State<ShutterView> createState() => _ShutterViewState();
}

class _ShutterViewState extends State<ShutterView> {
  int? _drag;

  int _positionAt(Offset local, double height) {
    final closed = (local.dy / height).clamp(0.0, 1.0);
    return (100 - closed * 100).round();
  }

  void _update(Offset local, double height) {
    final p = _positionAt(local, height);
    if (_drag != null && (p ~/ 10) != (_drag! ~/ 10)) HapticFeedback.selectionClick();
    setState(() => _drag = p);
  }

  void _end() {
    final p = _drag;
    setState(() => _drag = null);
    if (p != null) widget.onChangeEnd?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      final interactive = widget.onChangeEnd != null;
      return GestureDetector(
        onVerticalDragStart: interactive ? (d) => _update(d.localPosition, height) : null,
        onVerticalDragUpdate: interactive ? (d) => _update(d.localPosition, height) : null,
        onVerticalDragEnd: interactive ? (_) => _end() : null,
        onVerticalDragCancel: interactive ? () => setState(() => _drag = null) : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (_drag ?? widget.position).toDouble()),
          duration: _drag != null ? const Duration(milliseconds: 60) : const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            size: Size.infinite,
            painter: _ShutterPainter(
              position: value,
              compact: widget.compact,
              motion: _drag != null ? CoverMotion.idle : widget.motion,
            ),
          ),
        ),
      );
    });
  }
}

class _ShutterPainter extends CustomPainter {
  const _ShutterPainter({required this.position, required this.compact, required this.motion});

  final double position;
  final bool compact;
  final CoverMotion motion;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = compact ? 14.0 : 20.0;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final inset = compact ? 6.0 : 9.0;
    final window = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final windowRRect = RRect.fromRectAndRadius(window, Radius.circular(radius - inset / 2));

    // Cadre.
    canvas.drawRRect(outer, Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawRRect(
      outer.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.25), Palette.amber.withValues(alpha: 0.12)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(windowRRect);

    // Ciel de fin de journée derrière la vitre.
    canvas.drawRect(
      window,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3B872), Color(0xFFD97A45), Color(0xFF6E3220)],
          stops: [0, 0.55, 1],
        ).createShader(window),
    );
    final sun = Offset(window.left + window.width * 0.72, window.top + window.height * 0.58);
    canvas.drawCircle(
      sun,
      window.shortestSide * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFE2B0).withValues(alpha: 0.9), const Color(0xFFFFE2B0).withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: sun, radius: window.shortestSide * 0.5)),
    );

    // Montants de la fenêtre.
    final mullion = Paint()
      ..color = const Color(0xFF2A170C).withValues(alpha: 0.55)
      ..strokeWidth = compact ? 2 : 3;
    canvas.drawLine(Offset(window.center.dx, window.top), Offset(window.center.dx, window.bottom), mullion);
    canvas.drawLine(
      Offset(window.left, window.top + window.height * 0.45),
      Offset(window.right, window.top + window.height * 0.45),
      mullion,
    );

    // Tablier du volet.
    final closed = (1 - position / 100).clamp(0.0, 1.0);
    final apronBottom = window.top + window.height * closed;
    final slat = compact ? 6.0 : 9.0;
    if (closed > 0.001) {
      var y = apronBottom;
      while (y > window.top - slat) {
        final r = Rect.fromLTWH(window.left, y - slat, window.width, slat);
        canvas.drawRect(
          r,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8C5634), Color(0xFF5E3720), Color(0xFF3F2414)],
              stops: [0, 0.6, 1],
            ).createShader(r),
        );
        canvas.drawLine(
          Offset(r.left, r.top + 0.5),
          Offset(r.right, r.top + 0.5),
          Paint()
            ..color = const Color(0xFFE2A672).withValues(alpha: 0.28)
            ..strokeWidth = 1,
        );
        y -= slat;
      }
      // Lame finale.
      final bar = Rect.fromLTWH(window.left, apronBottom - slat * 0.9, window.width, slat * 0.9);
      canvas.drawRect(
        bar,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC88552), Color(0xFF6B3A1E)],
          ).createShader(bar),
      );
      canvas.drawRect(
        Rect.fromLTWH(window.left, apronBottom, window.width, math.min(10, window.bottom - apronBottom)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
          ).createShader(Rect.fromLTWH(window.left, apronBottom, window.width, 10)),
      );
    }
    canvas.restore();

    // Coffre du volet.
    final box = RRect.fromRectAndCorners(
      Rect.fromLTWH(inset, inset, window.width, compact ? 5 : 7),
      topLeft: Radius.circular(radius - inset / 2),
      topRight: Radius.circular(radius - inset / 2),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xFF2A170C));

    if (motion != CoverMotion.idle) {
      final icon = motion == CoverMotion.opening ? Icons.keyboard_double_arrow_up_rounded : Icons.keyboard_double_arrow_down_rounded;
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: compact ? 18 : 26,
            color: Palette.cream.withValues(alpha: 0.9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, size.center(Offset.zero) - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ShutterPainter old) => old.position != position || old.compact != compact || old.motion != motion;
}
