import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Gabarit des pages détaillées : titre, actions et contenu défilant.
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.maxWidth,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 22),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            runSpacing: 14,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppText.greeting.copyWith(fontSize: 28)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: AppText.label.copyWith(fontSize: 15)),
                  ],
                ],
              ),
              if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
        ),
        ...children,
      ],
    );
    if (maxWidth != null) {
      list = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: list),
      );
    }
    return list;
  }
}

/// Grille de tuiles de largeur égale, le nombre de colonnes s'adaptant à l'écran.
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 260,
    this.tileHeight,
    this.gap = 18,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double? tileHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = math.max(1, ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor());
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, height: tileHeight, child: child),
        ],
      );
    });
  }
}
