import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/thermostat_dial.dart';

const climateModeOrder = [ClimateMode.comfort, ClimateMode.eco, ClimateMode.away, ClimateMode.off];

/// Carte principale du chauffage : cadran, réglage fin et modes.
class ClimateCard extends StatefulWidget {
  const ClimateCard({super.key});

  @override
  State<ClimateCard> createState() => _ClimateCardState();
}

class _ClimateCardState extends State<ClimateCard> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final climates = home.state.climates;
    if (climates.isEmpty) {
      return const GlassCard(
        stitched: true,
        child: Column(
          children: [
            CardHeader(title: 'Chauffage'),
            Expanded(child: EmptyHint(icon: Icons.thermostat_rounded, text: 'Aucun thermostat détecté')),
          ],
        ),
      );
    }
    final device = climates.firstWhere((c) => c.id == _selectedId, orElse: () => climates.first);
    final room = home.state.roomName(device.roomId);
    final details = [
      if (device.humidity != null) 'Humidité ${formatNumber(device.humidity!, decimals: 0)} %',
      if (home.state.outdoorTemp != null) 'Dehors ${formatTemp(home.state.outdoorTemp)}',
    ].join(' · ');

    return GlassCard(
      stitched: true,
      tint: device.isHeating && device.mode != ClimateMode.off ? Palette.ember : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Chauffage',
            subtitle: details.isEmpty ? room : details,
            trailing: GlassIconButton(
              icon: Icons.open_in_full_rounded,
              size: 40,
              tooltip: 'Tous les thermostats',
              onPressed: () => ShellNav.go(context, AppSection.climate),
            ),
          ),
          if (climates.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: climates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = climates[i];
                  return GlassPill(
                    selected: c.id == device.id,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onTap: () => setState(() => _selectedId = c.id),
                    child: Text(home.state.room(c.roomId)?.name ?? c.name),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GlassIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Baisser',
                  onPressed: device.mode == ClimateMode.off ? null : () => home.nudgeClimate(device.id, -1),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ThermostatDial(
                      key: ValueKey(device.id),
                      target: device.targetTemp,
                      min: device.minTemp,
                      max: device.maxTemp,
                      step: device.step,
                      current: device.currentTemp,
                      heating: device.isHeating,
                      enabled: device.mode != ClimateMode.off,
                      onChanged: (_) {},
                      onChangeEnd: (v) => home.setClimateTarget(device.id, v),
                    ),
                  ),
                ),
                GlassIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Augmenter',
                  onPressed: device.mode == ClimateMode.off ? null : () => home.nudgeClimate(device.id, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: PillSelector<ClimateMode>(
              compact: true,
              values: climateModeOrder.where(device.supportedModes.contains).toList(),
              selected: device.mode,
              labelOf: (m) => m.label,
              iconOf: climateModeIcon,
              onSelected: (m) => home.setClimateMode(device.id, m),
            ),
          ),
        ],
      ),
    );
  }
}
