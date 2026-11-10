import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/home_backend.dart';
import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/tiles.dart';

/// Heure courante, mise à jour à chaque minute.
class ClockText extends StatefulWidget {
  const ClockText({super.key});

  @override
  State<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<ClockText> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute) setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(formatClock(_now), style: context.text.clock);
}

/// Informations permanentes de l'en-tête : températures, état de la liaison, heure.
/// Le détail affiché dépend de la largeur disponible.
class StatusCluster extends StatelessWidget {
  const StatusCluster({super.key, required this.width});

  /// Largeur de l'en-tête.
  final double width;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final c = context.colors;
    final showTemps = width >= 860;

    // La liaison n'est signalée que si elle mérite l'attention : démo, connexion en cours, panne.
    Widget? linkChip;
    switch (home.link.state) {
      case LinkState.offline:
        linkChip = InfoChip(
          icon: Icons.wifi_off_rounded,
          label: width >= 600 ? 'Hors ligne · Reconnecter' : 'Hors ligne',
          color: c.danger,
          onTap: home.reconnect,
        );
      case LinkState.connecting:
        if (width >= 480) linkChip = const InfoChip(icon: Icons.sync_rounded, label: 'Connexion…');
      case LinkState.online:
        if (home.isDemo && width >= 480) {
          linkChip = const InfoChip(icon: Icons.science_rounded, label: 'Mode démo');
        }
    }
    final message = home.link.message;
    if (linkChip != null && message != null) linkChip = Tooltip(message: message, child: linkChip);

    final items = <Widget>[
      if (showTemps && state.outdoorTemp != null)
        InfoChip(icon: weatherIcon(state.weather), label: 'Extérieur', value: formatTemp(state.outdoorTemp)),
      if (showTemps && state.indoorTemp != null)
        InfoChip(icon: Icons.home_rounded, label: 'Intérieur', value: formatTemp(state.indoorTemp)),
      ?linkChip,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items) ...[item, const SizedBox(width: 10)],
        const SizedBox(width: 6),
        const ClockText(),
      ],
    );
  }
}

/// En-tête commun à toutes les pages : titre, précision, actions de la page et état général.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Sur grand écran les actions tiennent sur la ligne du titre ; sinon elles passent dessous.
        final inline = actions.isNotEmpty && width >= 1000;
        final actionsRow = Wrap(spacing: 10, runSpacing: 10, children: actions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: width < 480 ? t.pageTitle.copyWith(fontSize: 23) : t.pageTitle,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                if (inline) ...[actionsRow, const SizedBox(width: 14)],
                StatusCluster(width: inline ? width - 340 : width),
              ],
            ),
            if (!inline && actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: actionsRow),
          ],
        );
      },
    );
  }
}

/// Page standard : en-tête fixe, contenu défilant.
class AppPage extends StatelessWidget {
  const AppPage({
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

  /// Largeur maximale du contenu (formulaires).
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(padding: const EdgeInsets.only(bottom: 24), children: children);
    if (maxWidth != null) {
      list = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: list,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(title: title, subtitle: subtitle, actions: actions),
        const SizedBox(height: 18),
        Expanded(child: list),
      ],
    );
  }
}

/// Grille de tuiles de largeur égale ; le nombre de colonnes s'adapte à la place disponible.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minTileWidth = 220, this.tileHeight, this.gap = Dim.gap});

  final List<Widget> children;
  final double minTileWidth;
  final double? tileHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor());
        // Arrondi vers le bas : évite qu'un écart d'un pixel renvoie la dernière tuile à la ligne.
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: width, height: tileHeight, child: child)],
        );
      },
    );
  }
}
