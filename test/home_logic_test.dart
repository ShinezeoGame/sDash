import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdash/data/demo_backend.dart';
import 'package:sdash/data/settings.dart';
import 'package:sdash/models/home.dart';
import 'package:sdash/state/home_controller.dart';
import 'package:sdash/ui/format.dart';

void main() {
  group('format français', () {
    test('températures et nombres', () {
      expect(formatTemp(21.5), '21,5°');
      expect(formatTemp(21), '21°');
      expect(formatTemp(null), '--°');
      expect(formatNumber(48.73), '48,7');
      expect(formatNumber(100), '100');
    });

    test('dates', () {
      final d = DateTime(2026, 11, 7, 18, 5);
      expect(formatLongDate(d), 'samedi 7 novembre');
      expect(formatClock(d), '18:05');
      expect(greetingFor(d), 'Bonsoir');
      expect(greetingFor(DateTime(2026, 11, 7, 9)), 'Bonjour');
    });
  });

  group('maison de démo', () {
    test('la scène « Bonne nuit » éteint tout et ferme les volets', () async {
      final demo = DemoBackend(latency: Duration.zero);
      await demo.activateScene('scene.nuit');
      expect(demo.current.lights.every((l) => !l.isOn), isTrue);
      expect(demo.current.climates.every((c) => c.mode == ClimateMode.eco), isTrue);
      for (var i = 0; i < 30; i++) {
        demo.simulateStep();
      }
      expect(demo.current.covers.every((c) => c.position == 0 && c.motion == CoverMotion.idle), isTrue);
      await demo.dispose();
    });

    test('chaque mode de chauffage retient sa propre consigne', () async {
      final demo = DemoBackend(latency: Duration.zero);
      await demo.setClimateTarget('climate.salon', 22.5);
      await demo.setClimateMode('climate.salon', ClimateMode.eco);
      expect(demo.current.climates.first.targetTemp, 18);
      await demo.setClimateMode('climate.salon', ClimateMode.comfort);
      expect(demo.current.climates.first.targetTemp, 22.5);
      await demo.dispose();
    });
  });

  group('contrôleur', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('applique les commandes immédiatement et borne les consignes', () async {
      final controller = HomeController(
        applySystemSettings: false,
        backendFactory: (_) => DemoBackend(latency: Duration.zero),
      );
      await controller.init();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final lamp = controller.state.lights.firstWhere((l) => l.id == 'light.salon_led');
      expect(lamp.isOn, isFalse);
      final pending = controller.toggleLight(lamp.id);
      expect(controller.state.lights.firstWhere((l) => l.id == lamp.id).isOn, isTrue, reason: 'mise à jour optimiste');
      await pending;

      controller.setClimateTarget('climate.salon', 99);
      expect(controller.state.climates.firstWhere((c) => c.id == 'climate.salon').targetTemp, 30);
      controller.nudgeClimate('climate.salon', -3);
      expect(controller.state.climates.firstWhere((c) => c.id == 'climate.salon').targetTemp, 28.5);

      controller.dispose();
    });

    test('les réglages sont enregistrés et relus', () async {
      final store = SettingsStore();
      await store.save(
        const AppSettings(
          userName: 'Alex',
          computers: [ComputerConfig(id: '1', name: 'PC', mac: 'AA:BB:CC:DD:EE:FF', host: '192.168.1.42')],
        ),
      );
      final loaded = await store.load();
      expect(loaded.userName, 'Alex');
      expect(loaded.computers.single.mac, 'AA:BB:CC:DD:EE:FF');
      expect(loaded.backend, BackendKind.demo);
      expect(loaded.theme, AppThemeMode.auto, reason: 'le thème suit la tablette par défaut');
      await store.save(loaded.copyWith(theme: AppThemeMode.dark));
      expect((await store.load()).theme, AppThemeMode.dark);
      expect(loaded.needsReconnect(loaded.copyWith(userName: 'Sam')), isFalse);
      expect(loaded.needsReconnect(loaded.copyWith(backend: BackendKind.homeAssistant)), isTrue);
    });
  });
}
