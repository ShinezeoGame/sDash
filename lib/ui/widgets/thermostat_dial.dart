import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../look.dart';
import '../theme.dart';
import 'glass.dart' show LeatherGrain;

/// Cadran circulaire de thermostat : arc de 270°, poignée déplaçable au doigt.
class ThermostatDial extends StatefulWidget {
  const ThermostatDial({
    super.key,
    required this.target,
    required this.min,
    required this.max,
    this.step = 0.5,
    this.current,
    this.heating = false,
    this.enabled = true,
    this.onChanged,
    this.onChangeEnd,
    this.compact = false,
  });

  final double target;
  final double min;
  final double max;
  final double step;
  final double? current;
  final bool heating;

  /// Faux quand le chauffage est à l'arrêt : le cadran est grisé.
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool compact;

  @override
  State<ThermostatDial> createState() => _ThermostatDialState();
}

class _ThermostatDialState extends State<ThermostatDial> {
  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  double? _drag;

  double get _value => _drag ?? widget.target;

  double _fraction(double v) =>
      widget.max <= widget.min ? 0 : ((v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double? _valueAt(Offset local, Size size) {
    final center = size.center(Offset.zero);
    final d = local - center;
    if (d.distance < size.shortestSide * 0.18) return null; // zone centrale ignorée
    final angle = (math.atan2(d.dy, d.dx) + 2 * math.pi) % (2 * math.pi);
    var relative = (angle - _start + 2 * math.pi) % (2 * math.pi);
    if (relative > _sweep) {
      relative = (relative - _sweep) < (2 * math.pi - _sweep) / 2 ? _sweep : 0;
    }
    final raw = widget.min + (relative / _sweep) * (widget.max - widget.min);
    final stepped = (raw / widget.step).round() * widget.step;
    return stepped.clamp(widget.min, widget.max).toDouble();
  }

  void _handle(Offset local, Size size) {
    final v = _valueAt(local, size);
    if (v == null || v == _drag) return;
    if (_drag != null && (v - _drag!).abs() >= widget.step) HapticFeedback.selectionClick();
    setState(() => _drag = v);
    widget.onChanged?.call(v);
  }

  void _finish() {
    final v = _drag;
    setState(() => _drag = null);
    if (v != null) widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final size = Size.square(side);
        final interactive = widget.enabled && widget.onChanged != null;
        final valueStyle = AppText.display.copyWith(fontSize: side * (widget.compact ? 0.22 : 0.21));
        final status = !widget.enabled
            ? 'Arrêt'
            : widget.heating
            ? 'Chauffe'
            : 'Stable';
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: GestureDetector(
              // Glissements verticaux et horizontaux plutôt qu'un « pan » : le cadran l'emporte
              // ainsi sur le défilement de la page qui le contient.
              onVerticalDragStart: interactive ? (d) => _handle(d.localPosition, size) : null,
              onVerticalDragUpdate: interactive ? (d) => _handle(d.localPosition, size) : null,
              onVerticalDragEnd: interactive ? (_) => _finish() : null,
              onVerticalDragCancel: interactive ? _finish : null,
              onHorizontalDragStart: interactive ? (d) => _handle(d.localPosition, size) : null,
              onHorizontalDragUpdate: interactive ? (d) => _handle(d.localPosition, size) : null,
              onHorizontalDragEnd: interactive ? (_) => _finish() : null,
              onHorizontalDragCancel: interactive ? _finish : null,
              child: CustomPaint(
                painter: _DialPainter(
                  fraction: _fraction(_value),
                  currentFraction: widget.current == null ? null : _fraction(widget.current!),
                  enabled: widget.enabled,
                  heating: widget.heating,
                  leather: AppLook.of(context).leather,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Consigne', style: AppText.label.copyWith(fontSize: (side * 0.06).clamp(11.0, 14.0))),
                      SizedBox(height: side * 0.015),
                      Text(
                        widget.enabled ? formatTemp(_value) : '--',
                        style: valueStyle.copyWith(color: widget.enabled ? Palette.cream : Palette.taupe),
                      ),
                      SizedBox(height: side * 0.025),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.heating && widget.enabled ? Palette.ember : Palette.taupe,
                              boxShadow: widget.heating && widget.enabled
                                  ? [BoxShadow(color: Palette.ember.withValues(alpha: 0.8), blurRadius: 8)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.current != null ? '$status · ${formatTemp(widget.current)}' : status,
                            style: AppText.label.copyWith(
                              fontSize: (side * 0.058).clamp(11.0, 14.0),
                              color: Palette.sand,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.fraction,
    required this.currentFraction,
    required this.enabled,
    required this.heating,
    this.leather = false,
  });

  final double fraction;
  final double? currentFraction;
  final bool enabled;
  final bool heating;

  /// Style cuir : disque rembourré, arc en sangle cousue, poignée en laiton.
  final bool leather;

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = size.shortestSide;
    final stroke = side * 0.07;
    final tickRadius = side / 2 - 2;
    final arcRadius = tickRadius - side * 0.07 - stroke / 2;
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

    // Graduations.
    const ticks = 54;
    for (var i = 0; i <= ticks; i++) {
      final t = i / ticks;
      final angle = _start + _sweep * t;
      final major = i % 9 == 0;
      final len = major ? side * 0.04 : side * 0.022;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final active = enabled && t <= fraction;
      canvas.drawLine(
        center + dir * (tickRadius - len),
        center + dir * tickRadius,
        Paint()
          ..strokeWidth = major ? 2 : 1.3
          ..strokeCap = StrokeCap.round
          ..color = active
              ? Palette.honey.withValues(alpha: major ? 0.85 : 0.55)
              : Colors.white.withValues(alpha: major ? 0.18 : 0.10),
      );
    }

    final innerRadius = arcRadius - stroke * 1.25;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    if (leather) {
      // Disque central : bouton de cuir rembourré, couronne surpiquée.
      canvas.drawCircle(
        center + const Offset(0, 4),
        innerRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.45),
            colors: [Color(0xFF6A3E22), Color(0xFF3A2112), Color(0xFF26150B)],
            stops: [0, 0.7, 1],
          ).createShader(innerRect),
      );
      LeatherGrain.paint(canvas, innerRect, clip: RRect.fromRectAndRadius(innerRect, Radius.circular(innerRadius)));
      canvas.drawCircle(
        center,
        innerRadius - 0.7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFE2BC).withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.5)],
          ).createShader(innerRect),
      );
      _dashedCircle(canvas, center, innerRadius - side * 0.035, Palette.thread.withValues(alpha: 0.5), 1.3);
    } else {
      // Disque intérieur en verre.
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.5),
            colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.015)],
          ).createShader(innerRect),
      );
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.03)],
          ).createShader(innerRect),
      );
    }

    // Rail.
    canvas.drawArc(
      arcRect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: leather ? 0.5 : 0.25),
    );
    canvas.drawArc(
      arcRect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    final sweep = math.max(0.0001, _sweep * fraction);
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: _sweep,
      colors: !enabled
          ? [Palette.dusk, Palette.taupe]
          : leather
          ? const [Color(0xFF8E4F22), Color(0xFFB57340), Color(0xFFD69A5C), Color(0xFFE9B67E)]
          : const [Palette.terracotta, Palette.cognac, Palette.amber, Palette.honey],
      transform: const GradientRotation(_start),
    ).createShader(arcRect);

    if (enabled && leather) {
      // Ombre portée de la sangle.
      canvas.drawArc(
        arcRect.shift(const Offset(0, 3)),
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    } else if (enabled) {
      // Halo lumineux sous l'arc.
      canvas.drawArc(
        arcRect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = Palette.ember.withValues(alpha: heating ? 0.55 : 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.7),
      );
    }
    canvas.drawArc(
      arcRect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient,
    );
    if (leather && fraction > 0.02) {
      // Surpiqûre au centre de la sangle.
      final strap = Path()..addArc(arcRect, _start, sweep);
      final thread = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF0D8).withValues(alpha: 0.6);
      for (final metric in strap.computeMetrics()) {
        for (var d = stroke * 0.6; d < metric.length - stroke * 0.6; d += 9) {
          canvas.drawPath(metric.extractPath(d, d + 5), thread);
        }
      }
    }

    // Température mesurée.
    final current = currentFraction;
    if (current != null) {
      final a = _start + _sweep * current;
      final p = center + Offset(math.cos(a), math.sin(a)) * arcRadius;
      canvas.drawCircle(p, stroke * 0.2, Paint()..color = Palette.cream.withValues(alpha: 0.9));
    }

    // Poignée.
    final knobAngle = _start + _sweep * fraction;
    final knob = center + Offset(math.cos(knobAngle), math.sin(knobAngle)) * arcRadius;
    final knobRadius = stroke * 0.78;
    canvas.drawCircle(
      knob + const Offset(0, 2),
      knobRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    if (leather) {
      final knobRect = Rect.fromCircle(center: knob, radius: knobRadius);
      canvas.drawCircle(knob, knobRadius, Paint()..shader = Palette.brass.createShader(knobRect));
      canvas.drawCircle(
        knob,
        knobRadius * 0.55,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF6E4C17).withValues(alpha: 0.6),
      );
    } else {
      canvas.drawCircle(knob, knobRadius, Paint()..color = enabled ? Palette.cream : Palette.sand);
      canvas.drawCircle(knob, knobRadius * 0.42, Paint()..color = enabled ? Palette.cognac : Palette.dusk);
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Color color, double width) {
    final path = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.currentFraction != currentFraction ||
      old.enabled != enabled ||
      old.heating != heating ||
      old.leather != leather;
}
