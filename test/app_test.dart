import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdash/app.dart';
import 'package:sdash/data/demo_backend.dart';
import 'package:sdash/data/settings.dart';
import 'package:sdash/models/home.dart';
import 'package:sdash/state/home_controller.dart';
import 'package:sdash/ui/navigation.dart';
import 'package:sdash/ui/pages/climate_page.dart';
import 'package:sdash/ui/shell.dart';
import 'package:sdash/ui/widgets/tiles.dart';

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

  for (final size in const [Size(412, 915), Size(360, 780)]) {
    testWidgets('téléphone ${size.width.toInt()} px : les libellés du menu sont entiers', (tester) async {
      final controller = await pumpApp(tester, size);
      for (final section in AppSection.values) {
        final nav = find.byKey(ValueKey('nav-${section.name}'));
        await tester.tap(nav);
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 450));
        final label = tester.renderObject<RenderParagraph>(
          find.descendant(of: nav, matching: find.text(section.label)),
        );
        expect(
          label.size.width,
          greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity) - 0.5),
          reason: '« ${section.label} » est coupé',
        );
      }
      await tearDownApp(tester, controller);
    });
  }

  testWidgets('thème sombre : toutes les pages s’affichent sans débordement', (tester) async {
    SharedPreferences.setMockInitialValues({'sdash.settings': '{"theme":"dark"}'});
    final controller = await pumpApp(tester, const Size(1280, 800));
    expect(controller.settings.theme, AppThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(Shell))).brightness, Brightness.dark);
    for (final section in AppSection.values) {
      await tester.tap(find.byKey(ValueKey('nav-${section.name}')));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull, reason: 'page ${section.label}');
    }
    await tearDownApp(tester, controller);
  });

  testWidgets('thème automatique : clair par défaut', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    expect(controller.settings.theme, AppThemeMode.auto);
    expect(Theme.of(tester.element(find.byType(Shell))).brightness, Brightness.light);
    await tearDownApp(tester, controller);
  });

  testWidgets('accueil : un appui sur la tuile d’une pièce éteint ses lumières', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    bool kitchenOn() => controller.state.lights.any((l) => l.roomId == 'cuisine' && l.isOn);

    expect(kitchenOn(), isTrue);
    await tester.tap(find.widgetWithText(ToggleTile, 'Cuisine'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(kitchenOn(), isFalse);

    await tester.tap(find.widgetWithText(ToggleTile, 'Cuisine'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(kitchenOn(), isTrue);

    await tearDownApp(tester, controller);
  });

  testWidgets('accueil : les boutons − et + règlent la consigne du chauffage', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    double target() => controller.state.climates.firstWhere((c) => c.id == 'climate.salon').targetTemp;

    expect(target(), 21.5);
    await tester.tap(find.byTooltip('Augmenter Salon'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(target(), 22.0);
    await tester.tap(find.byTooltip('Baisser Salon'));
    await tester.tap(find.byTooltip('Baisser Salon'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(target(), 21.0);

    await tester.pump(const Duration(seconds: 1));
    await tearDownApp(tester, controller);
  });

  testWidgets('accueil : les boutons d’un volet envoient la commande', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    CoverDevice cover() => controller.state.covers.firstWhere((c) => c.id == 'cover.chambre');

    expect(cover().position, 0);
    await tester.tap(find.byTooltip('Ouvrir Chambre'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(cover().motion, CoverMotion.opening);

    await tearDownApp(tester, controller);
  });

  testWidgets('accueil : le bouton de l’aspirateur lance le nettoyage', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    VacuumDevice robot() => controller.state.vacuums.single;

    expect(robot().state, VacuumState.docked);
    await tester.ensureVisible(find.byTooltip('Lancer Robot aspirateur'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Lancer Robot aspirateur'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(robot().state, VacuumState.cleaning);

    await tearDownApp(tester, controller);
  });

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

  testWidgets('page Chauffage : réglage par paliers et changement de mode', (tester) async {
    final controller = await pumpApp(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const ValueKey('nav-climate')));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
    ClimateDevice salon() => controller.state.climates.firstWhere((c) => c.id == 'climate.salon');

    await tester.tap(find.byTooltip('Augmenter Salon'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(salon().targetTemp, 22.0);

    final card = find.widgetWithText(ClimateCard, 'Salon');
    await tester.tap(find.descendant(of: card, matching: find.text('Arrêt')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(salon().mode, ClimateMode.off);

    await tester.pump(const Duration(seconds: 1));
    await tearDownApp(tester, controller);
  });
}
