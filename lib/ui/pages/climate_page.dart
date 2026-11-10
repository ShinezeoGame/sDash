import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

const climateModeOrder = [ClimateMode.comfort, ClimateMode.eco, ClimateMode.away, ClimateMode.off];

class ClimatePage extends StatelessWidget {
  const ClimatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomeScope.of(context).state;
    final heating = state.climates.where((c) => c.isHeating && c.mode != ClimateMode.off).length;
    return AppPage(
      title: 'Chauffage',
      subtitle: state.climates.isEmpty
          ? null
          : heating == 0
          ? 'Aucune pièce ne chauffe'
          : '${plural(heating, 'pièce')} en chauffe',
      children: [
        if (state.climates.isEmpty)
          const EmptyHint(icon: Icons.thermostat_rounded, text: 'Aucun thermostat détecté.')
        else
          TileGrid(
            minTileWidth: 320,
            tileHeight: 252,
            children: [for (final c in state.climates) ClimateCard(device: c)],
          ),
      ],
    );
  }
}

/// Thermostat d'une pièce : consigne à régler par paliers, et choix du mode.
class ClimateCard extends StatelessWidget {
  const ClimateCard({super.key, required this.device});

  final ClimateDevice device;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final c = context.colors;
    final t = context.text;
    final room = home.state.room(device.roomId);
    final name = room?.name ?? device.name;
    final off = device.mode == ClimateMode.off;
    final heating = device.isHeating && !off;
    final adjustable = device.available && !off;
    final details = !device.available
        ? 'Indisponible'
        : [
            if (device.currentTemp != null) 'Actuellement ${formatTemp(device.currentTemp)}',
            if (device.humidity != null) 'humidité ${formatNumber(device.humidity!, decimals: 0)} %',
          ].join(' · ');

    return Opacity(
      opacity: device.available ? 1 : 0.5,
      child: Tile(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: room != null ? roomIcon(room.kind) : Icons.thermostat_rounded,
                  tone: heating ? BadgeTone.highlight : BadgeTone.neutral,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                      Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                SquareButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Baisser $name',
                  size: 64,
                  onPressed: adjustable ? () => home.nudgeClimate(device.id, -1) : null,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          off ? 'Arrêt' : formatTemp(device.targetTemp),
                          maxLines: 1,
                          style: off ? t.display.copyWith(color: c.textFaint, fontSize: 40) : t.display,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (heating)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded, size: 16, color: c.heat),
                              const SizedBox(width: 4),
                              Text('Consigne · chauffe', maxLines: 1, style: t.caption.copyWith(color: c.heat)),
                            ],
                          ),
                        )
                      else
                        Text(off ? 'Chauffage coupé' : 'Consigne', style: t.caption),
                    ],
                  ),
                ),
                SquareButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Augmenter $name',
                  size: 64,
                  onPressed: adjustable ? () => home.nudgeClimate(device.id, 1) : null,
                ),
              ],
            ),
            const Spacer(),
            Segmented<ClimateMode>(
              values: climateModeOrder.where(device.supportedModes.contains).toList(),
              selected: device.mode,
              labelOf: (m) => m.label,
              iconOf: climateModeIcon,
              onSelected: (m) => home.setClimateMode(device.id, m),
            ),
          ],
        ),
      ),
    );
  }
}
