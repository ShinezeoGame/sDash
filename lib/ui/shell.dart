import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/home_backend.dart';
import '../state/home_controller.dart';
import '../state/home_scope.dart';
import 'format.dart';
import 'icons.dart';
import 'navigation.dart';
import 'pages/climate_page.dart';
import 'pages/covers_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/devices_page.dart';
import 'pages/lights_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';
import 'widgets/ambient_background.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

/// Structure de l'application : rail de navigation, barre supérieure et page active.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  AppSection _section = AppSection.dashboard;
  StreamSubscription<AppMessage>? _messages;
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute) setState(() => _now = now);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messages ??= HomeScope.read(context).messages.listen(_showMessage);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _messages?.cancel();
    super.dispose();
  }

  void _showMessage(AppMessage message) {
    if (!mounted) return;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        width: wide ? 520 : null,
        duration: Duration(seconds: message.isError ? 5 : 3),
        content: Row(
          children: [
            Icon(
              message.isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: message.isError ? Palette.rose : Palette.sage,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message.text)),
          ],
        ),
      ));
  }

  void _go(AppSection section) {
    if (section == _section) return;
    HapticFeedback.selectionClick();
    setState(() => _section = section);
  }

  Widget _page(AppSection section) => switch (section) {
        AppSection.dashboard => const DashboardPage(),
        AppSection.lights => const LightsPage(),
        AppSection.climate => const ClimatePage(),
        AppSection.covers => const CoversPage(),
        AppSection.devices => const DevicesPage(),
        AppSection.settings => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 700;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(now: _now, compact: !wide),
        SizedBox(height: wide ? 18 : 12),
        Expanded(
          child: !home.ready
              ? const Center(child: CircularProgressIndicator(color: Palette.amber))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_section), child: _page(_section)),
                ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Palette.espresso,
      body: AmbientBackground(
        child: SafeArea(
          child: BackdropGroup(
            child: ShellNav(
              current: _section,
              goTo: _go,
              child: Padding(
                padding: EdgeInsets.all(wide ? 20 : 12),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _NavRail(selected: _section, onSelect: _go),
                          const SizedBox(width: 20),
                          Expanded(child: content),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: content),
                          const SizedBox(height: 12),
                          _BottomNav(selected: _section, onSelect: _go),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Palette.warm,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Palette.ember.withValues(alpha: 0.5), blurRadius: 22)],
      ),
      alignment: Alignment.center,
      child: Text(
        's',
        style: AppText.greeting.copyWith(color: Palette.onWarm, fontSize: 30, fontWeight: FontWeight.w600, height: 1),
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final main = AppSection.values.where((s) => s != AppSection.settings);
    return GlassCard(
      stitched: true,
      radius: 34,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      child: SizedBox(
        width: 70,
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const _Logo(),
                    const SizedBox(height: 26),
                    for (final s in main) ...[
                      _NavItem(key: ValueKey('nav-${s.name}'), section: s, selected: s == selected, onTap: () => onSelect(s)),
                      const SizedBox(height: 8),
                    ],
                    const Spacer(),
                    _NavItem(
                      key: const ValueKey('nav-settings'),
                      section: AppSection.settings,
                      selected: selected == AppSection.settings,
                      onTap: () => onSelect(AppSection.settings),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({super.key, required this.section, required this.selected, required this.onTap});

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: selected ? Palette.warm : null,
                  boxShadow: selected ? [BoxShadow(color: Palette.ember.withValues(alpha: 0.45), blurRadius: 18)] : null,
                ),
                child: Icon(section.icon, size: 22, color: selected ? Palette.onWarm : Palette.taupe),
              ),
              const SizedBox(height: 6),
              Text(
                section.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: AppText.caption.copyWith(
                  fontSize: 11.5,
                  color: selected ? Palette.cream : Palette.taupe,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final s in AppSection.values)
            Expanded(child: _NavItem(key: ValueKey('nav-${s.name}'), section: s, selected: s == selected, onTap: () => onSelect(s))),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.now, required this.compact});

  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final state = home.state;
    final name = home.settings.userName.trim();
    final date = formatLongDate(now);
    final summary = [
      if (state.lights.isNotEmpty) state.lightsOn == 0 ? 'lumières éteintes' : '${plural(state.lightsOn, 'lumière')} allumée${state.lightsOn > 1 ? 's' : ''}',
      if (state.covers.isNotEmpty) '${plural(state.coversOpen, 'volet')} ouvert${state.coversOpen > 1 ? 's' : ''}',
    ].join(' · ');
    final link = home.link;
    final linkColor = switch (link.state) {
      LinkState.online => Palette.sage,
      LinkState.connecting => Palette.amber,
      LinkState.offline => Palette.rose,
    };
    final linkText = switch (link.state) {
      LinkState.online => home.backendLabel,
      LinkState.connecting => 'Connexion…',
      LinkState.offline => 'Hors ligne',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? greetingFor(now) : '${greetingFor(now)}, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact ? AppText.greeting.copyWith(fontSize: 24) : AppText.greeting,
              ),
              const SizedBox(height: 4),
              Text(
                [date[0].toUpperCase() + date.substring(1), if (summary.isNotEmpty && !compact) summary].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
        if (!compact && state.outdoorTemp != null) ...[
          GlassPill(
            child: Row(
              children: [
                Icon(weatherIcon(state.weather), color: Palette.honey),
                const SizedBox(width: 8),
                Text(formatTemp(state.outdoorTemp), style: AppText.subtitle.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (!compact && state.indoorTemp != null) ...[
          GlassPill(
            child: Row(
              children: [
                const Icon(Icons.home_rounded, color: Palette.honey),
                const SizedBox(width: 8),
                Text(formatTemp(state.indoorTemp), style: AppText.subtitle.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        Tooltip(
          message: link.message ?? linkText,
          child: GlassPill(
            onTap: link.state == LinkState.offline ? home.reconnect : null,
            child: Row(
              children: [
                StatusDot(color: linkColor),
                const SizedBox(width: 9),
                Text(linkText),
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 12 : 22),
        Text(formatClock(now), style: compact ? AppText.clock.copyWith(fontSize: 30) : AppText.clock),
      ],
    );
  }
}
