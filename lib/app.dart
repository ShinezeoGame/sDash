import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/home_controller.dart';
import 'state/home_scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/look.dart';

class SDashApp extends StatelessWidget {
  const SDashApp({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return HomeScope(
      controller: controller,
      child: MaterialApp(
        title: 'sDash',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppLook(
            style: controller.settings.style,
            reducedGlass: controller.settings.reducedGlass,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const Shell(),
      ),
    );
  }
}
