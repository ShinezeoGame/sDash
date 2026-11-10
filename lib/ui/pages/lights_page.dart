import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/device_tiles.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

class LightsPage extends StatelessWidget {
  const LightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final groups = lightsByRoom(state);
    final on = state.lightsOn;
    return AppPage(
      title: 'Lumières',
      subtitle: state.lights.isEmpty
          ? null
          : on == 0
          ? 'Tout est éteint'
          : '${plural(on, 'allumée')} sur ${state.lights.length}',
      actions: [
        AppButton(
          label: 'Tout allumer',
          icon: Icons.lightbulb_rounded,
          onPressed: on < state.lights.length ? () => home.setLights(on: true) : null,
        ),
        AppButton(
          label: 'Tout éteindre',
          icon: Icons.power_settings_new_rounded,
          kind: ButtonKind.primary,
          onPressed: on > 0 ? () => home.setLights(on: false) : null,
        ),
      ],
      children: [
        if (groups.isEmpty) const EmptyHint(icon: Icons.lightbulb_outline_rounded, text: 'Aucune lumière détectée.'),
        for (final (room, lights) in groups) ...[
          SectionHeader(
            icon: roomIcon(room.kind),
            title: room.name,
            detail: '${lights.where((l) => l.isOn).length} sur ${lights.length}',
            trailing: AppSwitch(
              label: 'Lumières : ${room.name}',
              value: lights.any((l) => l.isOn),
              onChanged: (v) => setRoomLights(home, room, lights, v),
            ),
          ),
          TileGrid(minTileWidth: 220, tileHeight: 132, children: [for (final l in lights) LightTile(light: l)]),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// Tuile d'une lampe : un appui allume ou éteint, le curseur règle la luminosité.
class LightTile extends StatefulWidget {
  const LightTile({super.key, required this.light});

  final LightDevice light;

  @override
  State<LightTile> createState() => _LightTileState();
}

class _LightTileState extends State<LightTile> {
  /// Luminosité en cours de réglage, pour afficher le pourcentage pendant le geste.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final c = context.colors;
    final light = widget.light;
    final on = light.isOn;
    final percent = ((_drag ?? light.brightness) * 100).round();
    final status = !light.available
        ? 'Indisponible'
        : _drag != null
        ? 'Luminosité $percent %'
        : !on
        ? 'Éteinte'
        : light.dimmable
        ? 'Allumée · $percent %'
        : 'Allumée';

    return ToggleTile(
      icon: on ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
      title: light.name,
      status: status,
      on: on,
      available: light.available,
      onTap: () => home.toggleLight(light.id),
      footer: !light.dimmable
          ? const SizedBox(height: 44)
          : AppSlider(
              value: light.brightness,
              enabled: light.available,
              icon: Icons.wb_sunny_rounded,
              semanticLabel: 'Luminosité de ${light.name}',
              // Sur la tuile ambrée, le curseur passe en clair pour rester lisible.
              trackColor: on ? Colors.black.withValues(alpha: 0.12) : null,
              fillColor: on ? Colors.white.withValues(alpha: 0.9) : c.textFaint.withValues(alpha: 0.25),
              foregroundColor: on ? c.onActive : c.textMuted,
              onChanged: (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                setState(() => _drag = null);
                home.setLight(light.id, brightness: v);
              },
            ),
    );
  }
}
