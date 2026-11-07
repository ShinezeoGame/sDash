import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/surface.dart';

/// Regroupe les lumières par pièce (les lumières sans pièce vont dans « Autres »).
List<(Room, List<LightDevice>)> lightsByRoom(HomeState state) {
  final groups = <(Room, List<LightDevice>)>[];
  for (final room in state.rooms) {
    final lights = state.lights.where((l) => l.roomId == room.id).toList();
    if (lights.isNotEmpty) groups.add((room, lights));
  }
  final known = state.rooms.map((r) => r.id).toSet();
  final orphans = state.lights.where((l) => l.roomId == null || !known.contains(l.roomId)).toList();
  if (orphans.isNotEmpty) groups.add((const Room(id: '_autres', name: 'Autres'), orphans));
  return groups;
}

/// Résumé des lumières pièce par pièce, avec interrupteur général par pièce.
class LightsCard extends StatelessWidget {
  const LightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final groups = lightsByRoom(state);
    final on = state.lightsOn;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Lumières',
            subtitle: state.lights.isEmpty
                ? 'Aucune lumière'
                : on == 0
                ? 'Tout est éteint'
                : '${plural(on, 'allumée')} sur ${state.lights.length}',
            trailing: PillButton(
              label: 'Tout éteindre',
              icon: Icons.power_settings_new_rounded,
              compact: true,
              onPressed: on > 0 ? () => home.setLights(on: false) : null,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: groups.isEmpty
                ? const EmptyHint(icon: Icons.lightbulb_outline_rounded, text: 'Aucune lumière détectée')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (context, i) {
                      final (room, lights) = groups[i];
                      final onCount = lights.where((l) => l.isOn).length;
                      final roomId = room.id == '_autres' ? null : room.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => ShellNav.go(context, AppSection.lights),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: Row(
                            children: [
                              IconOrb(icon: roomIcon(room.kind), active: onCount > 0, size: 40),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(room.name, style: AppText.subtitle.copyWith(fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(
                                      onCount == 0
                                          ? 'Éteint'
                                          : '$onCount sur ${lights.length} allumée${onCount > 1 ? 's' : ''}',
                                      style: AppText.label,
                                    ),
                                  ],
                                ),
                              ),
                              GlowToggle(
                                value: onCount > 0,
                                onChanged: (v) => roomId == null
                                    ? Future.wait([for (final l in lights) home.setLight(l.id, on: v)])
                                    : home.setLights(roomId: roomId, on: v),
                              ),
                            ],
                          ),
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
