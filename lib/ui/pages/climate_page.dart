import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../cards/climate_card.dart';
import '../format.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/surface.dart';
import '../widgets/thermostat_dial.dart';
import 'page_scaffold.dart';

class ClimatePage extends StatelessWidget {
  const ClimatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomeScope.of(context).state;
    final heating = state.climates.where((c) => c.isHeating && c.mode != ClimateMode.off).length;
    return DetailPage(
      title: 'Chauffage',
      subtitle: [
        if (state.indoorTemp != null) 'Intérieur ${formatTemp(state.indoorTemp)}',
        if (state.outdoorTemp != null) 'Extérieur ${formatTemp(state.outdoorTemp)}',
        heating == 0 ? 'Aucune pièce ne chauffe' : '${plural(heating, 'pièce')} en chauffe',
      ].join(' · '),
      children: [
        if (state.climates.isEmpty)
          const SurfaceCard(
            child: EmptyHint(icon: Icons.thermostat_rounded, text: 'Aucun thermostat détecté'),
          ),
        TileGrid(
          minTileWidth: 330,
          tileHeight: 450,
          children: [for (final c in state.climates) ClimateTile(device: c)],
        ),
      ],
    );
  }
}

class ClimateTile extends StatelessWidget {
  const ClimateTile({super.key, required this.device});

  final ClimateDevice device;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final room = home.state.room(device.roomId);
    final off = device.mode == ClimateMode.off;
    return SurfaceCard(
      stitched: true,
      tint: device.isHeating && !off ? Palette.ember : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconOrb(
                icon: room != null ? roomIcon(room.kind) : Icons.thermostat_rounded,
                active: device.isHeating && !off,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CardHeader(
                  title: room?.name ?? device.name,
                  subtitle: [
                    if (device.humidity != null) 'Humidité ${formatNumber(device.humidity!, decimals: 0)} %',
                    if (!device.available) 'Indisponible',
                    if (device.humidity == null && device.available) device.mode.label,
                  ].join(' · '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ThermostatDial(
              target: device.targetTemp,
              min: device.minTemp,
              max: device.maxTemp,
              step: device.step,
              current: device.currentTemp,
              heating: device.isHeating,
              enabled: !off && device.available,
              compact: true,
              onChanged: (_) {},
              onChangeEnd: (v) => home.setClimateTarget(device.id, v),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SurfaceIconButton(
                icon: Icons.remove_rounded,
                tooltip: 'Baisser',
                onPressed: off ? null : () => home.nudgeClimate(device.id, -1),
              ),
              const SizedBox(width: 18),
              SurfaceIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Augmenter',
                onPressed: off ? null : () => home.nudgeClimate(device.id, 1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedPills<ClimateMode>(
            values: climateModeOrder.where(device.supportedModes.contains).toList(),
            selected: device.mode,
            labelOf: (m) => m.label,
            iconOf: climateModeIcon,
            onSelected: (m) => home.setClimateMode(device.id, m),
          ),
        ],
      ),
    );
  }
}
