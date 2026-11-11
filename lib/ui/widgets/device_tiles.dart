import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/home.dart';
import '../../state/home_controller.dart';
import '../../state/home_scope.dart';
import '../icons.dart';
import '../theme.dart';
import 'controls.dart';
import 'tiles.dart';

/// Identifiant du groupe des lumières sans pièce.
const otherRoomId = '_autres';

/// Regroupe les lumières par pièce (les lumières sans pièce vont dans « Autres »).
List<(Room, List<LightDevice>)> lightsByRoom(HomeState state) {
  final groups = <(Room, List<LightDevice>)>[];
  for (final room in state.rooms) {
    final lights = state.lights.where((l) => l.roomId == room.id).toList();
    if (lights.isNotEmpty) groups.add((room, lights));
  }
  final known = state.rooms.map((r) => r.id).toSet();
  final orphans = state.lights.where((l) => l.roomId == null || !known.contains(l.roomId)).toList();
  if (orphans.isNotEmpty) groups.add((const Room(id: otherRoomId, name: 'Autres'), orphans));
  return groups;
}

/// Allume ou éteint toutes les lumières d'une pièce.
Future<void> setRoomLights(HomeController home, Room room, List<LightDevice> lights, bool on) async {
  if (room.id != otherRoomId) return home.setLights(roomId: room.id, on: on);
  await Future.wait([
    for (final l in lights)
      if (l.isOn != on) home.setLight(l.id, on: on),
  ]);
}

Color powerColor(AppColors c, PowerState state) => switch (state) {
  PowerState.on => c.success,
  PowerState.starting || PowerState.stopping => c.accent,
  PowerState.off || PowerState.unknown => c.textFaint,
};

/// Allume ou éteint un ordinateur, avec confirmation avant l'extinction.
Future<void> toggleComputer(BuildContext context, HomeController home, ComputerDevice pc) async {
  if (pc.state.isBusy) return;
  if (pc.state != PowerState.on) {
    await home.setComputerPower(pc.id, true);
    return;
  }
  if (!pc.canShutdown) {
    home.post('Aucune commande d’extinction n’est configurée pour « ${pc.name} ».', isError: true);
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Éteindre « ${pc.name} » ?'),
      content: const Text('Les travaux non enregistrés sur cette machine pourraient être perdus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Éteindre')),
      ],
    ),
  );
  if (confirmed == true) await home.setComputerPower(pc.id, false);
}

/// Ligne d'un ordinateur : nom, état et bouton marche/arrêt.
class ComputerTile extends StatelessWidget {
  const ComputerTile({super.key, required this.pc});

  final ComputerDevice pc;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final c = context.colors;
    final t = context.text;
    final on = pc.state == PowerState.on;
    return Tile(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          IconBadge(
            icon: pc.isServer ? Icons.dns_rounded : Icons.desktop_windows_rounded,
            tone: on ? BadgeTone.highlight : BadgeTone.neutral,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                Row(
                  children: [
                    StatusDot(color: powerColor(c, pc.state)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        [pc.state.label, if (pc.detail != null) pc.detail!].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SquareButton(
            icon: Icons.power_settings_new_rounded,
            tooltip: on ? 'Éteindre ${pc.name}' : 'Allumer ${pc.name}',
            active: on,
            busy: pc.state.isBusy,
            onPressed: () => toggleComputer(context, home, pc),
          ),
        ],
      ),
    );
  }
}

/// Robot aspirateur : état, batterie, lancer / mettre en pause, renvoyer à la base.
class VacuumTile extends StatelessWidget {
  const VacuumTile({super.key, required this.vacuum});

  final VacuumDevice vacuum;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final c = context.colors;
    final t = context.text;
    final cleaning = vacuum.isCleaning;
    final atBase = vacuum.state == VacuumState.docked || vacuum.state == VacuumState.returning;
    final status = vacuum.available ? vacuum.state.label : 'Indisponible';
    final battery = vacuum.available ? vacuum.battery : null;
    final dot = switch (vacuum.state) {
      VacuumState.error => c.danger,
      VacuumState.cleaning || VacuumState.returning => c.accent,
      VacuumState.docked => c.success,
      _ => c.textFaint,
    };
    return Opacity(
      opacity: vacuum.available ? 1 : 0.5,
      child: Tile(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            IconBadge(icon: Icons.cleaning_services_rounded, tone: cleaning ? BadgeTone.highlight : BadgeTone.neutral),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(vacuum.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                  Row(
                    children: [
                      StatusDot(color: dot),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                      ),
                      // La batterie reste toujours lisible : c'est l'état qui se raccourcit.
                      if (battery != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.battery_full_rounded, size: 16, color: c.textMuted, semanticLabel: 'Batterie'),
                        Text('$battery %', maxLines: 1, style: t.secondary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SquareButton(
              icon: cleaning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: cleaning ? 'Mettre ${vacuum.name} en pause' : 'Lancer ${vacuum.name}',
              active: cleaning,
              onPressed: vacuum.available
                  ? () => home.vacuumCommand(vacuum.id, cleaning ? VacuumCommand.pause : VacuumCommand.start)
                  : null,
            ),
            const SizedBox(width: 8),
            SquareButton(
              icon: Icons.home_rounded,
              tooltip: 'Renvoyer ${vacuum.name} à sa base',
              onPressed: vacuum.available && !atBase
                  ? () => home.vacuumCommand(vacuum.id, VacuumCommand.returnHome)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hauteur d'une tuile multimédia : une rangée de plus pour le volume et la lecture.
double mediaTileHeight(MediaDevice media) => media.hasControls ? 132 : 72;

/// Télé ou enceinte : marche / arrêt, puis volume, coupure du son et lecture.
class MediaTile extends StatelessWidget {
  const MediaTile({super.key, required this.media});

  final MediaDevice media;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.read(context);
    final c = context.colors;
    final t = context.text;
    final m = media;
    final on = m.available && m.isOn;
    final status = !m.available
        ? 'Indisponible'
        : !m.isOn
        ? 'À l’arrêt'
        : [m.isPlaying ? 'En lecture' : 'En marche', if (m.title != null) m.title!].join(' · ');
    final canPower = m.available && (on ? m.canTurnOff : m.canTurnOn);
    VoidCallback? send(MediaCommand command, bool enabled) => enabled ? () => home.mediaCommand(m.id, command) : null;

    return Opacity(
      opacity: m.available ? 1 : 0.5,
      child: Tile(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                IconBadge(icon: mediaIcon(m.kind), tone: on ? BadgeTone.highlight : BadgeTone.neutral),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                      Row(
                        children: [
                          StatusDot(color: on ? c.success : c.textFaint),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (m.canTurnOn || m.canTurnOff) ...[
                  const SizedBox(width: 10),
                  SquareButton(
                    icon: Icons.power_settings_new_rounded,
                    tooltip: on ? 'Éteindre ${m.name}' : 'Allumer ${m.name}',
                    active: on,
                    onPressed: send(on ? MediaCommand.turnOff : MediaCommand.turnOn, canPower),
                  ),
                ],
              ],
            ),
            if (m.hasControls) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (m.canVolume) ...[
                    SquareButton(
                      icon: Icons.volume_down_rounded,
                      tooltip: 'Baisser le volume de ${m.name}',
                      onPressed: send(MediaCommand.volumeDown, on),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        m.volume == null ? '—' : '${(m.volume! * 100).round()} %',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: t.secondary.copyWith(color: on ? c.text : c.textFaint),
                      ),
                    ),
                    SquareButton(
                      icon: Icons.volume_up_rounded,
                      tooltip: 'Monter le volume de ${m.name}',
                      onPressed: send(MediaCommand.volumeUp, on),
                    ),
                  ],
                  const Spacer(),
                  if (m.canMute)
                    SquareButton(
                      icon: Icons.volume_off_rounded,
                      tooltip: m.muted ? 'Remettre le son de ${m.name}' : 'Couper le son de ${m.name}',
                      active: on && m.muted,
                      onPressed: send(MediaCommand.toggleMute, on),
                    ),
                  if (m.canMute && m.canPlayPause) const SizedBox(width: 8),
                  if (m.canPlayPause)
                    SquareButton(
                      icon: m.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      tooltip: m.isPlaying ? 'Mettre ${m.name} en pause' : 'Reprendre la lecture sur ${m.name}',
                      onPressed: send(MediaCommand.playPause, on),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Boutons de scènes. Un appui active la scène ; le bouton confirme brièvement.
class SceneButtons extends StatefulWidget {
  const SceneButtons({super.key, required this.scenes, this.scroll = false});

  final List<SceneItem> scenes;

  /// Vrai : une seule rangée défilante (accueil). Faux : retour à la ligne.
  final bool scroll;

  @override
  State<SceneButtons> createState() => _SceneButtonsState();
}

class _SceneButtonsState extends State<SceneButtons> {
  String? _done;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _activate(SceneItem scene) {
    HapticFeedback.mediumImpact();
    HomeScope.read(context).activateScene(scene.id);
    setState(() => _done = scene.id);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _done = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget button(SceneItem scene) =>
        _SceneButton(scene: scene, done: _done == scene.id, onTap: () => _activate(scene));
    if (!widget.scroll) {
      return Wrap(spacing: Dim.gap, runSpacing: Dim.gap, children: [for (final s in widget.scenes) button(s)]);
    }
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.scenes.length,
        separatorBuilder: (_, _) => const SizedBox(width: Dim.gap),
        itemBuilder: (context, i) => button(widget.scenes[i]),
      ),
    );
  }
}

class _SceneButton extends StatelessWidget {
  const _SceneButton({required this.scene, required this.done, required this.onTap});

  final SceneItem scene;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Activer la scène ${scene.name}',
      child: Material(
        color: done ? c.active : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dim.buttonRadius),
          side: BorderSide(color: done ? c.active : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(done ? Icons.check_rounded : sceneIcon(scene.kind), size: 22, color: done ? c.onActive : c.accent),
                const SizedBox(width: 10),
                Text(scene.name, maxLines: 1, style: context.text.button.copyWith(color: done ? c.onActive : c.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
