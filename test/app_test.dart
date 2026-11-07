import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdash/app.dart';
import 'package:sdash/data/demo_backend.dart';
import 'package:sdash/state/home_controller.dart';
import 'package:sdash/ui/navigation.dart';

/// Charge la vraie police pour que les mesures de texte correspondent à l'appareil.
Future<void> loadOutfit() async {
  final loader = FontLoader('Outfit');
  for (final weight in ['300Light', '400Regular', '500Medium', '600SemiBold']) {
    final bytes = File('assets/fonts/Outfit_$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<HomeController> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = HomeController(
    applySystemSettings: false,
    backendFactory: (_) => DemoBackend(latency: Duration.zero),
  );
  await tester.pumpWidget(SDashApp(controller: controller));
  await controller.init();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
  return controller;
}

Future<void> tearDownApp(WidgetTester tester, HomeController controller) async {
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadOutfit);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sizes = {
    'tablette paysage 1280×800': Size(1280, 800),
    'tablette 7" paysage 1024×600': Size(1024, 600),
    'tablette portrait 800×1280': Size(800, 1280),
    'téléphone 412×915': Size(412, 915),
  };

  for (final entry in sizes.entries) {
    testWidgets('toutes les pages s’affichent sans débordement — ${entry.key}', (tester) async {
      final controller = await pumpApp(tester, entry.value);

      expect(find.text('Chauffage'), findsWidgets);
      expect(find.text('Lumières'), findsWidgets);
      expect(tester.takeException(), isNull);

      for (final section in AppSection.values) {
        await tester.tap(find.byKey(ValueKey('nav-${section.name}')));
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.takeException(), isNull, reason: 'page ${section.label}');
      }

      await tearDownApp(tester, controller);
    });
  }

  testWidgets('un appui sur une tuile de la page Lumières allume la lampe', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const ValueKey('nav-lights')));
    await tester.pump(const Duration(milliseconds: 900));

    expect(controller.state.lights.firstWhere((l) => l.id == 'light.chambre_chevet').isOn, isFalse);
    await tester.ensureVisible(find.text('Chevet'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Chevet'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.state.lights.firstWhere((l) => l.id == 'light.chambre_chevet').isOn, isTrue);

    await tearDownApp(tester, controller);
  });
}
