import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../look.dart';
import '../theme.dart';

/// Histogramme des 7 derniers jours (le dernier élément est aujourd'hui).
class WeekBars extends StatefulWidget {
  const WeekBars({super.key, required this.values, required this.unit, this.today});

  final List<double> values;
  final String unit;

  /// Date du jour (injectable pour les tests).
  final DateTime? today;

  @override
  State<WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<WeekBars> {
  late int _selected = widget.values.length - 1;

  @override
  void didUpdateWidget(WeekBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.values.length) _selected = widget.values.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final today = widget.today ?? DateTime.now();
    final maxValue = values.fold<double>(0, math.max);
    final look = AppLook.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelHeight = 26.0;
        const bubbleHeight = 32.0;
        final barArea = math.max(20.0, constraints.maxHeight - labelHeight - bubbleHeight);
        final columnWidth = constraints.maxWidth / values.length;
        final barWidth = math.min(38.0, columnWidth * 0.66);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: bubbleHeight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: i == _selected ? 1 : 0,
                          child: OverflowBox(
                            maxWidth: 160,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Palette.honey,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(color: Palette.honey.withValues(alpha: 0.4), blurRadius: 12)],
                              ),
                              child: Text(
                                '${formatNumber(values[i])} ${widget.unit}',
                                style: AppText.label.copyWith(color: Palette.onWarm, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: maxValue <= 0 ? 0 : values[i] / maxValue),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) {
                          final height = math.max(barWidth * 0.9, barArea * t);
                          if (look.leather) {
                            // Cuir : gorges creusées, la barre choisie est une sangle fauve.
                            return SizedBox(
                              width: barWidth,
                              height: height,
                              child: i == _selected
                                  ? DecoratedBox(decoration: look.active(radius: barWidth / 2, glow: 0.8))
                                  : CustomPaint(
                                      painter: look.surface(radius: barWidth / 2, relief: Relief.sunken, grain: false),
                                    ),
                            );
                          }
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: barWidth,
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(barWidth / 2),
                              gradient: i == _selected
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Palette.cream, Palette.honey],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.14),
                                        Colors.white.withValues(alpha: 0.04),
                                      ],
                                    ),
                              border: Border.all(color: Colors.white.withValues(alpha: i == _selected ? 0.5 : 0.10)),
                              boxShadow: i == _selected
                                  ? [BoxShadow(color: Palette.honey.withValues(alpha: 0.35), blurRadius: 18)]
                                  : null,
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        height: labelHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            weekdayShort(today.subtract(Duration(days: values.length - 1 - i)).weekday),
                            style: AppText.label.copyWith(color: i == _selected ? Palette.cream : Palette.taupe),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
