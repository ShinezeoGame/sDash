import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/shutter_view.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

class CoversPage extends StatelessWidget {
  const CoversPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final covers = state.covers;
    return AppPage(
      title: 'Volets',
      subtitle: covers.isEmpty
          ? null
          : '${state.coversOpen} ouvert${state.coversOpen > 1 ? 's' : ''} sur ${covers.length}',
      actions: [
        AppButton(
          label: 'Tout ouvrir',
          icon: Icons.keyboard_arrow_up_rounded,
          onPressed: covers.isEmpty ? null : () => home.allCovers(CoverCommand.open),
        ),
        AppButton(
          label: 'Tout fermer',
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: covers.isEmpty ? null : () => home.allCovers(CoverCommand.close),
        ),
      ],
      children: [
        if (covers.isEmpty)
          const EmptyHint(icon: Icons.blinds_rounded, text: 'Aucun volet détecté.')
        else
          TileGrid(minTileWidth: 250, tileHeight: 244, children: [for (final c in covers) CoverCard(cover: c)]),
      ],
    );
  }
}

/// Volet : la fenêtre montre la position (on peut la faire glisser), les trois
/// boutons reprennent ceux d'un interrupteur mural — monter, stop, descendre.
class CoverCard extends StatelessWidget {
  const CoverCard({super.key, required this.cover});

  final CoverDevice cover;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final t = context.text;
    final room = home.state.room(cover.roomId);
    final name = room?.name ?? cover.name;
    final state = switch (cover.motion) {
      CoverMotion.opening => 'Ouverture…',
      CoverMotion.closing => 'Fermeture…',
      CoverMotion.idle => switch (cover.position) {
        0 => 'Fermé',
        100 => 'Ouvert',
        _ => 'Entrouvert',
      },
    };
    final details = !cover.available ? 'Indisponible' : [if (room != null) cover.name, state].join(' · ');
    VoidCallback? command(CoverCommand c) => cover.available ? () => home.coverCommand(cover.id, c) : null;

    return Opacity(
      opacity: cover.available ? 1 : 0.5,
      child: Tile(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
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
                const SizedBox(width: 8),
                Text('${cover.position} %', style: t.number),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ShutterView(
                      position: cover.position,
                      motion: cover.motion,
                      onChangeEnd: cover.available ? (p) => home.setCoverPosition(cover.id, p) : null,
                    ),
                  ),
                  const SizedBox(width: Dim.gap),
                  SizedBox(
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SquareButton(
                            icon: Icons.keyboard_arrow_up_rounded,
                            tooltip: 'Ouvrir $name',
                            active: cover.motion == CoverMotion.opening,
                            onPressed: command(CoverCommand.open),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SquareButton(
                            icon: Icons.stop_rounded,
                            tooltip: 'Arrêter $name',
                            onPressed: command(CoverCommand.stop),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SquareButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            tooltip: 'Fermer $name',
                            active: cover.motion == CoverMotion.closing,
                            onPressed: command(CoverCommand.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
