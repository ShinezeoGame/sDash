import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/home.dart';
import '../theme.dart';

/// Fenêtre schématique dont le volet descend selon la position.
/// Un glissement vertical règle la position au doigt.
class ShutterView extends StatefulWidget {
  const ShutterView({super.key, required this.position, this.motion = CoverMotion.idle, this.onChangeEnd});

  /// 0 = fermé, 100 = ouvert.
  final int position;
  final CoverMotion motion;

  /// Appelé avec la position choisie quand le doigt est relevé ; nul = lecture seule.
  final ValueChanged<int>? onChangeEnd;

  @override
  State<ShutterView> createState() => _ShutterViewState();
}

class _ShutterViewState extends State<ShutterView> {
  int? _drag;

  void _update(Offset local, double height) {
    final closed = (local.dy / height).clamp(0.0, 1.0);
    final p = (100 - closed * 100).round();
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
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final interactive = widget.onChangeEnd != null;
        return Semantics(
          label: 'Position du volet',
          value: '${_drag ?? widget.position} %',
          child: GestureDetector(
            onVerticalDragStart: interactive ? (d) => _update(d.localPosition, height) : null,
            onVerticalDragUpdate: interactive ? (d) => _update(d.localPosition, height) : null,
            onVerticalDragEnd: interactive ? (_) => _end() : null,
            onVerticalDragCancel: interactive ? () => setState(() => _drag = null) : null,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_drag ?? widget.position).toDouble()),
              duration: _drag != null ? const Duration(milliseconds: 60) : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CustomPaint(
                size: Size.infinite,
                painter: _ShutterPainter(
                  position: value,
                  motion: _drag != null ? CoverMotion.idle : widget.motion,
                  glazing: c.glazing,
                  shutter: c.shutter,
                  frame: c.surface,
                  line: c.text.withValues(alpha: 0.2),
                  border: c.border,
                  badge: c.surface,
                  onBadge: c.text,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShutterPainter extends CustomPainter {
  const _ShutterPainter({
    required this.position,
    required this.motion,
    required this.glazing,
    required this.shutter,
    required this.frame,
    required this.line,
    required this.border,
    required this.badge,
    required this.onBadge,
  });

  final double position;
  final CoverMotion motion;
  final Color glazing;
  final Color shutter;
  final Color frame;
  final Color line;
  final Color border;
  final Color badge;
  final Color onBadge;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.save();
    canvas.clipRRect(rrect);

    // Vitre et montants.
    canvas.drawRect(rect, Paint()..color = glazing);
    final mullion = Paint()
      ..color = frame
      ..strokeWidth = 3;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), mullion);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), mullion);

    // Tablier du volet, qui descend depuis le haut.
    final closed = (1 - position / 100).clamp(0.0, 1.0);
    final bottom = size.height * closed;
    if (closed > 0.001) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, bottom), Paint()..color = shutter);
      final slat = Paint()
        ..color = line
        ..strokeWidth = 1;
      for (var y = bottom - 10; y > 0; y -= 10) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), slat);
      }
      canvas.drawRect(Rect.fromLTWH(0, bottom - 4, size.width, 4), Paint()..color = line);
    }
    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );

    // Flèche pendant le mouvement.
    if (motion != CoverMotion.idle) {
      final icon = motion == CoverMotion.opening ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
      final center = size.center(Offset.zero);
      canvas.drawCircle(center, 18, Paint()..color = badge);
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 22, color: onBadge),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ShutterPainter old) =>
      old.position != position || old.motion != motion || old.glazing != glazing || old.shutter != shutter;
}
