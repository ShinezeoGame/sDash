import 'package:flutter/material.dart';

enum AppSection {
  dashboard('Accueil', Icons.space_dashboard_rounded),
  lights('Lumières', Icons.lightbulb_rounded),
  climate('Chauffage', Icons.thermostat_rounded),
  covers('Volets', Icons.blinds_rounded),
  devices('Appareils', Icons.devices_other_rounded),
  settings('Réglages', Icons.tune_rounded);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Permet aux cartes de naviguer vers une section détaillée.
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.current, required this.goTo, required super.child});

  final AppSection current;
  final ValueChanged<AppSection> goTo;

  static ShellNav? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellNav>();

  static void go(BuildContext context, AppSection section) => maybeOf(context)?.goTo(section);

  @override
  bool updateShouldNotify(ShellNav oldWidget) => oldWidget.current != current;
}
