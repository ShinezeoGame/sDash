import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/home_controller.dart';
import '../state/home_scope.dart';
import 'navigation.dart';
import 'pages/climate_page.dart';
import 'pages/covers_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/devices_page.dart';
import 'pages/lights_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';

/// Structure de l'application : navigation (à gauche sur tablette, en bas sur
/// téléphone) et page active.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  AppSection _section = AppSection.dashboard;
  StreamSubscription<AppMessage>? _messages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messages ??= HomeScope.read(context).messages.listen(_showMessage);
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  void _showMessage(AppMessage message) {
    if (!mounted) return;
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          width: wide ? 520 : null,
          duration: Duration(seconds: message.isError ? 5 : 3),
          content: Row(
            children: [
              Icon(
                message.isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: message.isError ? c.danger : c.success,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message.text)),
            ],
          ),
        ),
      );
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
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final page = Padding(
      padding: wide ? const EdgeInsets.fromLTRB(24, 20, 24, 0) : const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: !home.ready
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
              child: KeyedSubtree(key: ValueKey(_section), child: _page(_section)),
            ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Barres système assorties au thème quand le plein écran est désactivé.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: context.colors.background,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ShellNav(
            current: _section,
            goTo: _go,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NavRail(selected: _section, onSelect: _go),
                      Expanded(child: page),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: page),
                      _BottomNav(selected: _section, onSelect: _go),
                    ],
                  ),
          ),
        ),
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
    final c = context.colors;
    Widget item(AppSection s) =>
        _NavItem(key: ValueKey('nav-${s.name}'), section: s, selected: s == selected, onTap: () => onSelect(s));
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                // Toutes les entrées ont la même largeur, quelle que soit la longueur du libellé.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in AppSection.values.where((s) => s != AppSection.settings)) ...[
                    item(s),
                    const SizedBox(height: 6),
                  ],
                  const Spacer(),
                  item(AppSection.settings),
                ],
              ),
            ),
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
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          for (final s in AppSection.values)
            Expanded(
              child: _NavItem(
                key: ValueKey('nav-${s.name}'),
                section: s,
                selected: s == selected,
                onTap: () => onSelect(s),
              ),
            ),
        ],
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
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.accentSoft : c.accentSoft.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(section.icon, size: 26, color: selected ? c.accent : c.textMuted),
                const SizedBox(height: 4),
                Text(
                  section.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: context.text.caption.copyWith(
                    fontSize: 12.5,
                    color: selected ? c.text : c.textMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
