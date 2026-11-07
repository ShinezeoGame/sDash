import 'package:flutter_test/flutter_test.dart';
import 'package:sdash/data/home_assistant/ha_backend.dart';
import 'package:sdash/data/home_assistant/ha_mapper.dart';
import 'package:sdash/data/settings.dart';
import 'package:sdash/models/home.dart';

Json entity(String id, String state, [Json attributes = const {}]) => {
  'entity_id': id,
  'state': state,
  'attributes': attributes,
};

void main() {
  final registry = HaRegistry.fromLists(
    areas: [
      {'area_id': 'salon', 'name': 'Salon'},
      {'area_id': 'chambre', 'name': 'Chambre'},
      {'area_id': 'garage', 'name': 'Garage'},
    ],
    devices: [
      {'id': 'dev1', 'area_id': 'chambre'},
    ],
    entities: [
      {'entity_id': 'light.salon_plafonnier', 'area_id': 'salon'},
      {'entity_id': 'climate.chambre', 'device_id': 'dev1'},
      {'entity_id': 'cover.salon', 'area_id': 'salon'},
      {'entity_id': 'switch.cache', 'area_id': 'salon', 'hidden_by': 'user'},
      {'entity_id': 'switch.config', 'area_id': 'salon', 'entity_category': 'config'},
    ],
  );

  final states = <String, Json>{
    'light.salon_plafonnier': entity('light.salon_plafonnier', 'on', {
      'friendly_name': 'Salon Plafonnier',
      'brightness': 128,
      'supported_color_modes': ['brightness'],
    }),
    'light.entree': entity('light.entree', 'off', {
      'friendly_name': 'Entrée',
      'supported_color_modes': ['onoff'],
    }),
    'climate.chambre': entity('climate.chambre', 'heat', {
      'friendly_name': 'Radiateur chambre',
      'current_temperature': 18.6,
      'temperature': 19.5,
      'hvac_action': 'heating',
      'hvac_modes': ['off', 'heat'],
      'preset_modes': ['comfort', 'eco', 'away'],
      'preset_mode': 'eco',
      'target_temp_step': 0.5,
    }),
    'cover.salon': entity('cover.salon', 'opening', {'friendly_name': 'Volet salon', 'current_position': 40}),
    'cover.simple': entity('cover.simple', 'closed', {'friendly_name': 'Garage'}),
    'switch.tv': entity('switch.tv', 'on', {'friendly_name': 'Télé'}),
    'switch.pc': entity('switch.pc', 'on', {'friendly_name': 'PC'}),
    'switch.cache': entity('switch.cache', 'on'),
    'switch.config': entity('switch.config', 'on'),
    'scene.cinema': entity('scene.cinema', 'scening', {'friendly_name': 'Cinéma'}),
    'weather.maison': entity('weather.maison', 'rainy', {'temperature': 9.2}),
  };

  test('convertit les entités Home Assistant en modèles sDash', () {
    final home = mapHomeAssistant(
      states: states,
      registry: registry,
      computers: const [ComputerConfig(id: '1', name: 'PC du bureau', haEntity: 'switch.pc')],
    );

    final ceiling = home.lights.firstWhere((l) => l.id == 'light.salon_plafonnier');
    expect(ceiling.name, 'Plafonnier', reason: 'le nom de la pièce est retiré');
    expect(ceiling.roomId, 'salon');
    expect(ceiling.isOn, isTrue);
    expect(ceiling.brightness, closeTo(0.5, 0.01));
    expect(home.lights.firstWhere((l) => l.id == 'light.entree').dimmable, isFalse);

    final climate = home.climates.single;
    expect(climate.roomId, 'chambre', reason: 'pièce héritée de l’appareil');
    expect(climate.mode, ClimateMode.eco);
    expect(climate.isHeating, isTrue);
    expect(climate.targetTemp, 19.5);
    expect(climate.supportedModes, containsAll(ClimateMode.values));

    final cover = home.covers.firstWhere((c) => c.id == 'cover.salon');
    expect(cover.position, 40);
    expect(cover.motion, CoverMotion.opening);
    final simple = home.covers.firstWhere((c) => c.id == 'cover.simple');
    expect(simple.supportsPosition, isFalse);
    expect(simple.position, 0);

    expect(home.switches.map((s) => s.id), ['switch.tv'], reason: 'entités masquées, techniques et PC exclues');
    expect(home.switches.single.kind, SwitchKind.tv);
    expect(home.scenes.single.kind, SceneKind.movie);
    expect(home.outdoorTemp, 9.2);
    expect(home.weather, WeatherKind.rainy);
    expect(home.computers.single.state, PowerState.on);
    expect(home.rooms.map((r) => r.id), ['salon', 'chambre'], reason: 'pièces vides ignorées');
  });

  test('changement de mode : rallume le chauffage puis applique le préréglage', () {
    final off = entity('climate.x', 'off', {
      'hvac_modes': ['off', 'heat'],
      'preset_modes': ['comfort', 'eco', 'frost_protection'],
    });
    // Les records comparent leurs Map par identité : on les convertit en listes.
    List<List<Object>> calls(ClimateMode mode) => [
      for (final (s, d) in climateModeCalls(off, mode)) [s, d],
    ];
    expect(calls(ClimateMode.away), [
      [
        'set_hvac_mode',
        {'hvac_mode': 'heat'},
      ],
      [
        'set_preset_mode',
        {'preset_mode': 'frost_protection'},
      ],
    ]);
    expect(calls(ClimateMode.off), [
      [
        'set_hvac_mode',
        {'hvac_mode': 'off'},
      ],
    ]);
  });

  test('statistiques d’énergie agrégées sur 7 jours', () {
    final now = DateTime(2026, 11, 7, 15);
    final result = {
      'sensor.energie': [
        {'start': DateTime(2026, 11, 1).millisecondsSinceEpoch, 'change': 5.5},
        {'start': DateTime(2026, 11, 6).toUtc().toIso8601String(), 'change': 7.25},
        {'start': DateTime(2026, 11, 7).millisecondsSinceEpoch, 'change': 2},
        {'start': DateTime(2026, 10, 20).millisecondsSinceEpoch, 'change': 99},
      ],
    };
    expect(parseEnergyWeek(result, 'sensor.energie', now), [5.5, 0, 0, 0, 0, 7.25, 2]);
    expect(parseEnergyWeek({}, 'sensor.energie', now), isNull);
  });

  test('adresse WebSocket déduite de l’URL saisie', () {
    expect(
      HomeAssistantBackend.websocketUri('http://192.168.1.5:8123/').toString(),
      'ws://192.168.1.5:8123/api/websocket',
    );
    expect(
      HomeAssistantBackend.websocketUri('https://maison.example.org').toString(),
      'wss://maison.example.org/api/websocket',
    );
    expect(
      HomeAssistantBackend.websocketUri('homeassistant.local:8123').toString(),
      'ws://homeassistant.local:8123/api/websocket',
    );
  });
}
