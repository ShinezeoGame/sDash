import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../cards/computers_card.dart';
import '../cards/scenes_card.dart';
import '../icons.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import 'page_scaffold.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    return DetailPage(
      title: 'Appareils',
      subtitle: 'Ordinateurs, prises et scènes',
      children: [
        SectionTitle(
          text: 'Ordinateurs',
          icon: Icons.desktop_windows_rounded,
          trailing: PillButton(
            label: 'Configurer',
            icon: Icons.tune_rounded,
            compact: true,
            onPressed: () => ShellNav.go(context, AppSection.settings),
          ),
        ),
        if (state.computers.isEmpty)
          const GlassCard(
            child: EmptyHint(
              icon: Icons.desktop_windows_rounded,
              text: 'Ajoutez un ordinateur dans les réglages pour l’allumer à distance (Wake-on-LAN).',
            ),
          )
        else
          TileGrid(
            minTileWidth: 280,
            tileHeight: 210,
            children: [for (final pc in state.computers) _ComputerTile(pc: pc)],
          ),
        const SizedBox(height: 28),
        if (state.switches.isNotEmpty) ...[
          const SectionTitle(text: 'Prises & appareils', icon: Icons.power_rounded),
          TileGrid(
            minTileWidth: 240,
            tileHeight: 150,
            children: [for (final s in state.switches) _SwitchTile(device: s)],
          ),
          const SizedBox(height: 28),
        ],
        if (state.scenes.isNotEmpty) ...[
          const SectionTitle(text: 'Scènes', icon: Icons.auto_awesome_rounded),
          ScenesGrid(scenes: state.scenes, minTileWidth: 200),
        ],
      ],
    );
  }
}

class _ComputerTile extends StatelessWidget {
  const _ComputerTile({required this.pc});

  final ComputerDevice pc;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final on = pc.state == PowerState.on;
    return GlassCard(
      tint: on ? Palette.sage : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconOrb(icon: pc.isServer ? Icons.dns_rounded : Icons.desktop_windows_rounded, active: on, size: 48),
              const Spacer(),
              PowerButton(state: pc.state, size: 64, onPressed: () => toggleComputer(context, home, pc)),
            ],
          ),
          const Spacer(),
          Text(pc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
          const SizedBox(height: 6),
          Row(
            children: [
              StatusDot(color: powerColor(pc.state)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [pc.state.label, if (pc.detail != null) pc.detail!].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.device});

  final SwitchDevice device;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final room = HomeScope.of(context).state.room(device.roomId);
    return GlassCard(
      tint: device.isOn ? Palette.amber : null,
      padding: const EdgeInsets.all(18),
      onTap: device.available ? () => home.toggleSwitch(device.id) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconOrb(icon: switchIcon(device.kind), active: device.isOn),
              const Spacer(),
              GlowToggle(value: device.isOn, enabled: device.available, onChanged: (_) => home.toggleSwitch(device.id)),
            ],
          ),
          const Spacer(),
          Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.subtitle),
          const SizedBox(height: 2),
          Text(
            [room?.name ?? 'Maison', !device.available ? 'Indisponible' : (device.isOn ? 'Allumé' : 'Éteint')].join(' · '),
            style: AppText.label,
          ),
        ],
      ),
    );
  }
}
