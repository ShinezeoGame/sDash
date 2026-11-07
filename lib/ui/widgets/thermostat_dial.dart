import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../theme.dart';

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

  double _fraction(double v) => widget.max <= widget.min ? 0 : ((v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

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
    return LayoutBuilder(builder: (context, constraints) {
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
            onPanStart: interactive ? (d) => _handle(d.localPosition, size) : null,
            onPanUpdate: interactive ? (d) => _handle(d.localPosition, size) : null,
            onPanEnd: interactive ? (_) => _finish() : null,
            onPanCancel: interactive ? _finish : null,
            child: CustomPaint(
              painter: _DialPainter(
                fraction: _fraction(_value),
                currentFraction: widget.current == null ? null : _fraction(widget.current!),
                enabled: widget.enabled,
                heating: widget.heating,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.compact ? 'Consigne' : 'Consigne', style: AppText.label.copyWith(fontSize: side * 0.05)),
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
                          style: AppText.label.copyWith(fontSize: side * 0.048, color: Palette.sand),
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
    });
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.fraction,
    required this.currentFraction,
    required this.enabled,
    required this.heating,
  });

  final double fraction;
  final double? currentFraction;
  final bool enabled;
  final bool heating;

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
          ..color = active ? Palette.honey.withValues(alpha: major ? 0.85 : 0.55) : Colors.white.withValues(alpha: major ? 0.18 : 0.10),
      );
    }

    // Disque intérieur en verre.
    final innerRadius = arcRadius - stroke * 1.25;
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.015)],
        ).createShader(Rect.fromCircle(center: center, radius: innerRadius)),
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
        ).createShader(Rect.fromCircle(center: center, radius: innerRadius)),
    );

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
        ..color = Colors.black.withValues(alpha: 0.25),
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
      colors: enabled ? const [Palette.terracotta, Palette.cognac, Palette.amber, Palette.honey] : [Palette.dusk, Palette.taupe],
      transform: const GradientRotation(_start),
    ).createShader(arcRect);

    if (enabled) {
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
    canvas.drawCircle(knob, knobRadius, Paint()..color = enabled ? Palette.cream : Palette.sand);
    canvas.drawCircle(
      knob,
      knobRadius * 0.42,
      Paint()..color = enabled ? Palette.cognac : Palette.dusk,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction || old.currentFraction != currentFraction || old.enabled != enabled || old.heating != heating;
}
