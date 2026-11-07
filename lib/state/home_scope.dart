import 'package:flutter/widgets.dart';

import 'home_controller.dart';

/// Rend le [HomeController] accessible dans tout l'arbre de widgets.
class HomeScope extends InheritedNotifier<HomeController> {
  const HomeScope({super.key, required HomeController controller, required super.child})
      : super(notifier: controller);

  /// Récupère le contrôleur et reconstruit le widget à chaque changement d'état.
  static HomeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeScope>()!.notifier!;

  /// Récupère le contrôleur sans s'abonner aux changements (pour les actions).
  static HomeController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HomeScope>()!.notifier!;
}
