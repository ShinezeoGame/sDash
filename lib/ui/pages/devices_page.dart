import 'package:flutter/material.dart';

import '../../state/home_scope.dart';
import '../icons.dart';
import '../navigation.dart';
import '../widgets/controls.dart';
import '../widgets/device_tiles.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    return AppPage(
      title: 'Appareils',
      subtitle: 'Télé, ordinateurs et autres appareils',
      children: [
        if (state.media.isNotEmpty) ...[
          const SectionHeader(icon: Icons.tv_rounded, title: 'Multimédia'),
          TileGrid(
            minTileWidth: 320,
            tileHeight: state.media.map(mediaTileHeight).reduce((a, b) => a > b ? a : b),
            children: [for (final m in state.media) MediaTile(media: m)],
          ),
          const SizedBox(height: 14),
        ],
        SectionHeader(
          icon: Icons.desktop_windows_rounded,
          title: 'Ordinateurs',
          trailing: AppButton(
            label: 'Configurer',
            icon: Icons.tune_rounded,
            compact: true,
            onPressed: () => ShellNav.go(context, AppSection.settings),
          ),
        ),
        if (state.computers.isEmpty)
          const EmptyHint(
            icon: Icons.desktop_windows_rounded,
            text: 'Ajoutez un ordinateur dans les réglages pour l’allumer à distance.',
          )
        else
          TileGrid(
            minTileWidth: 280,
            tileHeight: 72,
            children: [for (final pc in state.computers) ComputerTile(pc: pc)],
          ),
        if (state.vacuums.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader(icon: Icons.cleaning_services_rounded, title: 'Robot aspirateur'),
          TileGrid(minTileWidth: 320, tileHeight: 72, children: [for (final v in state.vacuums) VacuumTile(vacuum: v)]),
        ],
        if (state.switches.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader(icon: Icons.power_rounded, title: 'Prises et appareils'),
          TileGrid(
            minTileWidth: 220,
            tileHeight: 72,
            children: [
              for (final s in state.switches)
                ToggleTile(
                  icon: switchIcon(s.kind),
                  title: s.name,
                  status: !s.available
                      ? 'Indisponible'
                      : [?state.room(s.roomId)?.name, s.isOn ? 'allumé' : 'éteint'].join(' · '),
                  on: s.isOn,
                  available: s.available,
                  onTap: () => home.toggleSwitch(s.id),
                ),
            ],
          ),
        ],
        if (state.scenes.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader(icon: Icons.auto_awesome_rounded, title: 'Scènes'),
          SceneButtons(scenes: state.scenes),
        ],
      ],
    );
  }
}
