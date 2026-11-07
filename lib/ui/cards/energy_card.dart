import 'package:flutter/material.dart';

import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/surface.dart';
import '../widgets/week_bars.dart';

/// Consommation de la semaine ; à défaut, relevé des températures par pièce.
class EnergyCard extends StatelessWidget {
  const EnergyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomeScope.of(context).state;
    final week = state.energyWeek;

    if (week != null && week.isNotEmpty) {
      final total = week.fold<double>(0, (a, b) => a + b);
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CardHeader(title: 'Consommation', subtitle: '7 derniers jours'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatNumber(total), style: AppText.display.copyWith(fontSize: 44)),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${state.energyUnit}\ncette semaine', style: AppText.label.copyWith(height: 1.15)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: WeekBars(values: week, unit: state.energyUnit),
            ),
          ],
        ),
      );
    }

    final rows = [
      for (final c in state.climates)
        if (c.currentTemp != null) (state.room(c.roomId), c.name, c.currentTemp!, c.humidity),
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Températures',
            subtitle: state.outdoorTemp != null ? 'Extérieur ${formatTemp(state.outdoorTemp)}' : 'Par pièce',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: rows.isEmpty
                ? const EmptyHint(icon: Icons.device_thermostat_rounded, text: 'Aucune mesure disponible')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (context, i) {
                      final (room, name, temp, humidity) = rows[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              room != null ? roomIcon(room.kind) : Icons.home_rounded,
                              color: Palette.honey,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(room?.name ?? name, style: AppText.subtitle.copyWith(fontSize: 16))),
                            if (humidity != null) ...[
                              const Icon(Icons.water_drop_rounded, size: 15, color: Palette.taupe),
                              const SizedBox(width: 4),
                              Text('${formatNumber(humidity, decimals: 0)} %', style: AppText.label),
                              const SizedBox(width: 14),
                            ],
                            Text(formatTemp(temp), style: AppText.title.copyWith(fontWeight: FontWeight.w400)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
