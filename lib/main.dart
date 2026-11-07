import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'state/home_controller.dart';
import 'ui/widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LeatherGrain.ensureLoaded();
  final controller = HomeController();
  runApp(SDashApp(controller: controller));
  unawaited(controller.init());
}
