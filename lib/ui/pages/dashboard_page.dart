import 'package:flutter/material.dart';

import '../../data/home_backend.dart';
import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../format.dart';
import '../icons.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/device_tiles.dart';
import '../widgets/tiles.dart';
import '../widgets/week_bars.dart';
import 'page_scaffold.dart';

/// Accueil : tout ce qui sert au quotidien, accessible en un geste.
/// Sur une tablette en paysage, l'ensemble tient à l'écran ; sinon la page défile.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final now = DateTime.now();
    final name = home.settings.userName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: name.isEmpty ? greetingFor(now) : '${greetingFor(now)}, $name',
          subtitle: capitalize(formatLongDate(now)),
        ),
        const SizedBox(height: 18),
        Expanded(child: home.state.isEmpty ? const _EmptyHome() : const _HomeContent()),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final state = HomeScope.of(context).state;
    // Sections dans l'ordre d'importance, avec leur hauteur approximative ;
    // une section sans appareil n'est pas affichée.
    const header = 50.0;
    const row = 84.0;
    final sections = <(Widget, double)>[
      if (state.lights.isNotEmpty) (const _LightsSection(), header + 116.0 * ((lightsByRoom(state).length + 1) ~/ 2)),
      if (state.climates.isNotEmpty) (const _ClimateSection(), header + row * state.climates.length),
      if (state.covers.isNotEmpty) (const _CoversSection(), header + 64 + row * state.covers.length),
      if (state.computers.isNotEmpty) (const _ComputersSection(), header + row * state.computers.length),
      if (state.vacuums.isNotEmpty) (const _VacuumsSection(), header + row * state.vacuums.length),
      if ((state.energyWeek ?? const []).isNotEmpty) (const _EnergySection(), header + 170.0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = (width >= 1000 ? 3 : (width >= 620 ? 2 : 1)).clamp(1, sections.isEmpty ? 1 : sections.length);
        // Chaque section rejoint la colonne la moins haute : les colonnes restent équilibrées
        // quels que soient les appareils de la maison.
        final columns = List.generate(count, (_) => <Widget>[]);
        final heights = List.filled(count, 0.0);
        for (final (section, height) in sections) {
          var target = 0;
          for (var i = 1; i < count; i++) {
            if (heights[i] < heights[target]) target = i;
          }
          columns[target].add(section);
          heights[target] += height + 14;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.scenes.isNotEmpty) ...[
                SceneButtons(scenes: state.scenes, scroll: true),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: Dim.sectionGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = 0; j < columns[i].length; j++) ...[
                            if (j > 0) const SizedBox(height: 14),
                            columns[i][j],
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Affiché tant qu'aucun appareil n'est connu (connexion en cours, panne, maison vide).
class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final (icon, text) = switch (home.link.state) {
      LinkState.connecting => (Icons.sync_rounded, 'Connexion à votre maison…'),
      LinkState.offline => (Icons.wifi_off_rounded, home.link.message ?? 'Impossible de joindre votre maison.'),
      LinkState.online => (Icons.home_rounded, 'Aucun appareil à afficher pour l’instant.'),
    };
    return Align(
      alignment: const Alignment(0, -0.3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: EmptyHint(
          icon: icon,
          text: text,
          action: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (home.link.state == LinkState.offline)
                AppButton(
                  label: 'Reconnecter',
                  icon: Icons.refresh_rounded,
                  kind: ButtonKind.primary,
                  onPressed: home.reconnect,
                ),
              AppButton(
                label: 'Ouvrir les réglages',
                icon: Icons.tune_rounded,
                onPressed: () => ShellNav.go(context, AppSection.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Lumières ─────────────────────────────

class _LightsSection extends StatelessWidget {
  const _LightsSection();

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final on = state.lightsOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'Lumières',
          detail: on == 0 ? 'tout est éteint' : plural(on, 'allumée'),
          onOpen: () => ShellNav.go(context, AppSection.lights),
          trailing: on == 0
              ? null
              : AppButton(label: 'Tout éteindre', compact: true, onPressed: () => home.setLights(on: false)),
        ),
        TileGrid(
          minTileWidth: 150,
          tileHeight: 104,
          children: [
            for (final (room, lights) in lightsByRoom(state))
              () {
                final onCount = lights.where((l) => l.isOn).length;
                return ToggleTile(
                  vertical: true,
                  icon: roomIcon(room.kind),
                  title: room.name,
                  status: onCount == 0
                      ? 'Éteint'
                      : lights.length == 1
                      ? 'Allumé'
                      : '$onCount sur ${lights.length} allumée${onCount > 1 ? 's' : ''}',
                  on: onCount > 0,
                  onTap: () => setRoomLights(home, room, lights, onCount == 0),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────── Chauffage ─────────────────────────────

class _ClimateSection extends StatelessWidget {
  const _ClimateSection();

  @override
  Widget build(BuildContext context) {
    final climates = HomeScope.of(context).state.climates;
    final heating = climates.where((c) => c.isHeating && c.mode != ClimateMode.off).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'Chauffage',
          detail: heating == 0 ? null : '$heating en chauffe',
          onOpen: () => ShellNav.go(context, AppSection.climate),
        ),
        for (var i = 0; i < climates.length; i++) ...[
          if (i > 0) const SizedBox(height: Dim.gap),
          _ClimateRow(device: climates[i]),
        ],
      ],
    );
  }
}

class _ClimateRow extends StatelessWidget {
  const _ClimateRow({required this.device});

  final ClimateDevice device;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final c = context.colors;
    final t = context.text;
    final name = home.state.room(device.roomId)?.name ?? device.name;
    final off = device.mode == ClimateMode.off;
    final heating = device.isHeating && !off;
    final adjustable = device.available && !off;
    final status = !device.available
        ? 'Indisponible'
        : [if (device.currentTemp != null) formatTemp(device.currentTemp), if (!off) device.mode.label].join(' · ');
    return SizedBox(
      height: 72,
      child: Opacity(
        opacity: device.available ? 1 : 0.5,
        child: Tile(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          onTap: () => ShellNav.go(context, AppSection.climate),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                    Row(
                      children: [
                        if (heating) ...[
                          Icon(Icons.local_fire_department_rounded, size: 17, color: c.heat, semanticLabel: 'Chauffe'),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StepperControl(
                value: off ? 'Arrêt' : formatTemp(device.targetTemp),
                valueStyle: off ? t.itemTitle.copyWith(color: c.textMuted) : null,
                valueWidth: 70,
                minusTooltip: 'Baisser $name',
                plusTooltip: 'Augmenter $name',
                onMinus: adjustable ? () => home.nudgeClimate(device.id, -1) : null,
                onPlus: adjustable ? () => home.nudgeClimate(device.id, 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Volets ─────────────────────────────

class _CoversSection extends StatelessWidget {
  const _CoversSection();

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final covers = state.covers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'Volets',
          detail: '${state.coversOpen} ouvert${state.coversOpen > 1 ? 's' : ''} sur ${covers.length}',
          onOpen: () => ShellNav.go(context, AppSection.covers),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Tout ouvrir',
                icon: Icons.keyboard_arrow_up_rounded,
                expand: true,
                onPressed: () => home.allCovers(CoverCommand.open),
              ),
            ),
            const SizedBox(width: Dim.gap),
            Expanded(
              child: AppButton(
                label: 'Tout fermer',
                icon: Icons.keyboard_arrow_down_rounded,
                expand: true,
                onPressed: () => home.allCovers(CoverCommand.close),
              ),
            ),
          ],
        ),
        for (final cover in covers) ...[const SizedBox(height: Dim.gap), _CoverRow(cover: cover)],
      ],
    );
  }
}

class _CoverRow extends StatelessWidget {
  const _CoverRow({required this.cover});

  final CoverDevice cover;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final t = context.text;
    final room = home.state.room(cover.roomId);
    final name = room?.name ?? cover.name;
    final position = switch (cover.motion) {
      CoverMotion.opening => 'ouverture…',
      CoverMotion.closing => 'fermeture…',
      CoverMotion.idle => switch (cover.position) {
        0 => 'fermé',
        100 => 'ouvert',
        final p => '$p %',
      },
    };
    final detail = !cover.available
        ? 'Indisponible'
        : room != null
        ? '${cover.name} · $position'
        : capitalize(position);
    VoidCallback? command(CoverCommand c) => cover.available ? () => home.coverCommand(cover.id, c) : null;

    return SizedBox(
      height: 72,
      child: Opacity(
        opacity: cover.available ? 1 : 0.5,
        child: Tile(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          onTap: () => ShellNav.go(context, AppSection.covers),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SquareButton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: 'Ouvrir $name',
                size: 44,
                active: cover.motion == CoverMotion.opening,
                onPressed: command(CoverCommand.open),
              ),
              const SizedBox(width: 6),
              SquareButton(
                icon: Icons.stop_rounded,
                tooltip: 'Arrêter $name',
                size: 44,
                onPressed: command(CoverCommand.stop),
              ),
              const SizedBox(width: 6),
              SquareButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Fermer $name',
                size: 44,
                active: cover.motion == CoverMotion.closing,
                onPressed: command(CoverCommand.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Ordinateurs ─────────────────────────────

class _ComputersSection extends StatelessWidget {
  const _ComputersSection();

  @override
  Widget build(BuildContext context) {
    final computers = HomeScope.of(context).state.computers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'Ordinateurs', onOpen: () => ShellNav.go(context, AppSection.devices)),
        for (var i = 0; i < computers.length; i++) ...[
          if (i > 0) const SizedBox(height: Dim.gap),
          SizedBox(height: 72, child: ComputerTile(pc: computers[i])),
        ],
      ],
    );
  }
}

// ───────────────────────────── Aspirateurs ─────────────────────────────

class _VacuumsSection extends StatelessWidget {
  const _VacuumsSection();

  @override
  Widget build(BuildContext context) {
    final vacuums = HomeScope.of(context).state.vacuums;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: vacuums.length > 1 ? 'Aspirateurs' : 'Aspirateur',
          onOpen: () => ShellNav.go(context, AppSection.devices),
        ),
        for (var i = 0; i < vacuums.length; i++) ...[
          if (i > 0) const SizedBox(height: Dim.gap),
          SizedBox(height: 72, child: VacuumTile(vacuum: vacuums[i])),
        ],
      ],
    );
  }
}

// ───────────────────────────── Consommation ─────────────────────────────

class _EnergySection extends StatefulWidget {
  const _EnergySection();

  @override
  State<_EnergySection> createState() => _EnergySectionState();
}

class _EnergySectionState extends State<_EnergySection> {
  /// Jour sélectionné ; nul = aujourd'hui.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final state = HomeScope.of(context).state;
    final week = state.energyWeek ?? const <double>[];
    if (week.isEmpty) return const SizedBox.shrink();
    final t = context.text;
    final last = week.length - 1;
    final selected = (_selected ?? last).clamp(0, last);
    final total = week.fold<double>(0, (a, b) => a + b);
    final day = selected == last
        ? 'aujourd’hui'
        : weekdayName(WeekBars.weekdayAt(selected, week.length, DateTime.now()));

    Widget stat(String value, String label, {required bool end}) => Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, maxLines: 1, style: t.number),
        Text(label, maxLines: 1, style: t.caption),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader(title: 'Consommation'),
        Tile(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: stat('${formatNumber(week[selected])} ${state.energyUnit}', day, end: false)),
                  stat('${formatNumber(total)} ${state.energyUnit}', 'sur 7 jours', end: true),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: WeekBars(values: week, selected: selected, onSelect: (i) => setState(() => _selected = i)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
