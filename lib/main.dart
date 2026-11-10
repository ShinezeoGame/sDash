import 'package:flutter/material.dart';

import 'app.dart';
import 'state/home_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = HomeController();
  // Les réglages sont lus avant le premier affichage : le thème choisi s'applique d'emblée.
  await controller.init();
  runApp(SDashApp(controller: controller));
}
