import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/shutter_view.dart';
import 'page_scaffold.dart';

class CoversPage extends StatelessWidget {
  const CoversPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    return DetailPage(
      title: 'Volets',
      subtitle: state.covers.isEmpty
          ? 'Aucun volet'
          : '${state.coversOpen} ouvert${state.coversOpen > 1 ? 's' : ''} sur ${state.covers.length} · glissez sur une fenêtre pour régler',
      actions: [
        PillButton(
          label: 'Tout ouvrir',
          icon: Icons.keyboard_arrow_up_rounded,
          onPressed: state.covers.isEmpty ? null : () => home.allCovers(CoverCommand.open),
        ),
        PillButton(
          label: 'Tout fermer',
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: state.covers.isEmpty ? null : () => home.allCovers(CoverCommand.close),
        ),
      ],
      children: [
        if (state.covers.isEmpty)
          const GlassCard(
            child: EmptyHint(icon: Icons.blinds_rounded, text: 'Aucun volet détecté'),
          ),
        TileGrid(minTileWidth: 240, tileHeight: 380, children: [for (final c in state.covers) CoverTile(cover: c)]),
      ],
    );
  }
}

class CoverTile extends StatelessWidget {
  const CoverTile({super.key, required this.cover});

  final CoverDevice cover;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final room = home.state.room(cover.roomId);
    final motion = switch (cover.motion) {
      CoverMotion.opening => 'Ouverture…',
      CoverMotion.closing => 'Fermeture…',
      CoverMotion.idle =>
        cover.position == 0
            ? 'Fermé'
            : cover.position == 100
            ? 'Ouvert'
            : 'Ouvert à ${cover.position} %',
    };
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CardHeader(title: room?.name ?? cover.name, subtitle: room != null ? cover.name : null),
              ),
              Text('${cover.position} %', style: AppText.title.copyWith(fontWeight: FontWeight.w300)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ShutterView(
              position: cover.position,
              motion: cover.motion,
              onChangeEnd: cover.available ? (p) => home.setCoverPosition(cover.id, p) : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(cover.available ? motion : 'Indisponible', textAlign: TextAlign.center, style: AppText.label),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GlassIconButton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: 'Ouvrir',
                active: cover.motion == CoverMotion.opening,
                onPressed: cover.available ? () => home.coverCommand(cover.id, CoverCommand.open) : null,
              ),
              GlassIconButton(
                icon: Icons.stop_rounded,
                tooltip: 'Stop',
                onPressed: cover.available ? () => home.coverCommand(cover.id, CoverCommand.stop) : null,
              ),
              GlassIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Fermer',
                active: cover.motion == CoverMotion.closing,
                onPressed: cover.available ? () => home.coverCommand(cover.id, CoverCommand.close) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
