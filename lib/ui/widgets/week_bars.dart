import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

/// Histogramme des 7 derniers jours (le dernier élément est aujourd'hui).
/// Un appui sur une barre la sélectionne.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.values, required this.selected, required this.onSelect, this.today});

  final List<double> values;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Date du jour (injectable pour les tests).
  final DateTime? today;

  /// Jour de la semaine correspondant à la barre [index].
  static int weekdayAt(int index, int count, DateTime today) =>
      today.subtract(Duration(days: count - 1 - index)).weekday;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final now = today ?? DateTime.now();
    final maxValue = values.fold<double>(0, math.max);
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelHeight = 22.0;
        final barArea = math.max(12.0, constraints.maxHeight - labelHeight);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: '${weekdayShort(weekdayAt(i, values.length, now))} ${formatNumber(values[i])}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: maxValue <= 0 ? 0 : values[i] / maxValue),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, f, _) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            height: math.max(6, barArea * f),
                            decoration: BoxDecoration(
                              color: i == selected ? c.accent : c.textFaint.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: labelHeight,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(
                              weekdayShort(weekdayAt(i, values.length, now)),
                              maxLines: 1,
                              style: t.caption.copyWith(
                                color: i == selected ? c.text : c.textMuted,
                                fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
