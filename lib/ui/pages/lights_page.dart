import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../cards/lights_card.dart';
import '../format.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import 'page_scaffold.dart';

class LightsPage extends StatelessWidget {
  const LightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final groups = lightsByRoom(state);
    return DetailPage(
      title: 'Lumières',
      subtitle: state.lights.isEmpty
          ? 'Aucune lumière'
          : '${plural(state.lightsOn, 'allumée')} sur ${state.lights.length}',
      actions: [
        PillButton(
          label: 'Tout allumer',
          icon: Icons.lightbulb_rounded,
          onPressed: state.lightsOn < state.lights.length ? () => home.setLights(on: true) : null,
        ),
        PillButton(
          label: 'Tout éteindre',
          icon: Icons.power_settings_new_rounded,
          primary: state.lightsOn > 0,
          onPressed: state.lightsOn > 0 ? () => home.setLights(on: false) : null,
        ),
      ],
      children: [
        if (groups.isEmpty)
          const GlassCard(
            child: EmptyHint(icon: Icons.lightbulb_outline_rounded, text: 'Aucune lumière détectée'),
          ),
        for (final (room, lights) in groups) ...[
          SectionTitle(
            text: room.name,
            icon: roomIcon(room.kind),
            trailing: GlowToggle(
              value: lights.any((l) => l.isOn),
              onChanged: (v) => Future.wait([
                for (final l in lights)
                  if (l.isOn != v) home.setLight(l.id, on: v),
              ]),
            ),
          ),
          TileGrid(minTileWidth: 250, tileHeight: 176, children: [for (final l in lights) LightTile(light: l)]),
          const SizedBox(height: 26),
        ],
      ],
    );
  }
}

class LightTile extends StatelessWidget {
  const LightTile({super.key, required this.light});

  final LightDevice light;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final status = !light.available
        ? 'Indisponible'
        : light.isOn
        ? (light.dimmable ? 'Allumée · ${(light.brightness * 100).round()} %' : 'Allumée')
        : 'Éteinte';
    return GlassCard(
      tint: light.isOn ? Palette.amber : null,
      padding: const EdgeInsets.all(18),
      onTap: light.available ? () => home.toggleLight(light.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconOrb(icon: light.isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded, active: light.isOn),
              const Spacer(),
              GlowToggle(
                value: light.isOn,
                enabled: light.available,
                onChanged: (v) => home.setLight(light.id, on: v),
              ),
            ],
          ),
          const Spacer(),
          Text(light.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.subtitle),
          const SizedBox(height: 2),
          Text(status, style: AppText.label),
          const SizedBox(height: 12),
          if (light.dimmable)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: light.isOn ? 1 : 0.55,
              child: WarmSlider(
                value: light.brightness,
                height: 34,
                enabled: light.available,
                icon: Icons.wb_sunny_rounded,
                onChangeEnd: (v) => home.setLight(light.id, brightness: v),
              ),
            )
          else
            const SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Non variable', style: AppText.caption),
              ),
            ),
        ],
      ),
    );
  }
}
