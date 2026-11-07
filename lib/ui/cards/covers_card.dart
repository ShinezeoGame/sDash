import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/shutter_view.dart';

/// Aperçu des volets : mini-fenêtres réglables au doigt et commandes générales.
class CoversCard extends StatelessWidget {
  const CoversCard({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final covers = state.covers;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Volets',
            subtitle: covers.isEmpty
                ? 'Aucun volet'
                : '${state.coversOpen} ouvert${state.coversOpen > 1 ? 's' : ''} sur ${covers.length}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  size: 40,
                  tooltip: 'Tout ouvrir',
                  onPressed: covers.isEmpty ? null : () => home.allCovers(CoverCommand.open),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  size: 40,
                  tooltip: 'Tout fermer',
                  onPressed: covers.isEmpty ? null : () => home.allCovers(CoverCommand.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: covers.isEmpty
                ? const EmptyHint(icon: Icons.blinds_rounded, text: 'Aucun volet détecté')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 14.0;
                      Widget tile(CoverDevice c) => Column(
                        children: [
                          Expanded(
                            child: ShutterView(
                              compact: true,
                              position: c.position,
                              motion: c.motion,
                              onChangeEnd: c.available ? (p) => home.setCoverPosition(c.id, p) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => ShellNav.go(context, AppSection.covers),
                            child: Column(
                              children: [
                                Text(
                                  state.room(c.roomId)?.name ?? c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.label.copyWith(color: Palette.cream),
                                ),
                                Text('${c.position} %', style: AppText.caption.copyWith(color: Palette.taupe)),
                              ],
                            ),
                          ),
                        ],
                      );
                      final fitted = (constraints.maxWidth - gap * (covers.length - 1)) / covers.length;
                      if (fitted >= 58) {
                        return Row(
                          children: [
                            for (var i = 0; i < covers.length; i++) ...[
                              if (i > 0) const SizedBox(width: gap),
                              Expanded(child: tile(covers[i])),
                            ],
                          ],
                        );
                      }
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: covers.length,
                        separatorBuilder: (_, _) => const SizedBox(width: gap),
                        itemBuilder: (context, i) => SizedBox(width: 82, child: tile(covers[i])),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
