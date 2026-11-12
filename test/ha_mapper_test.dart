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

  test('télé, enceinte et passerelle : état, volume et fonctions annoncées', () {
    final home = mapHomeAssistant(
      states: {
        'media_player.hisense_55e8q': entity('media_player.hisense_55e8q', 'on', {
          'friendly_name': '55E8Q',
          'device_class': 'tv',
          'volume_level': 0.18,
          'is_volume_muted': false,
          'source': 'HDMI 1',
          'supported_features': 1 | 4 | 8 | 512 | 16384, // pause, volume, muet, média, lecture
        }),
        'media_player.echo_salon': entity('media_player.echo_salon', 'playing', {
          'friendly_name': 'Echo Salon',
          'media_title': 'Clair de lune',
          'media_artist': 'Debussy',
          'supported_features': 1 | 128 | 256 | 1024 | 16384,
        }),
        'media_player.fire_tv': entity('media_player.fire_tv', 'off', {
          'friendly_name': 'Fire TV',
          'supported_features': 128 | 256,
        }),
      },
      registry: HaRegistry.fromLists(
        areas: [
          {'area_id': 'salon', 'name': 'Salon'},
        ],
        devices: const [],
        entities: [
          {'entity_id': 'media_player.echo_salon', 'area_id': 'salon'},
        ],
      ),
    );
    MediaDevice byId(String id) => home.media.firstWhere((m) => m.id == id);

    final tv = byId('media_player.hisense_55e8q');
    expect(tv.kind, MediaKind.tv);
    expect(tv.isOn, isTrue);
    expect(tv.isPlaying, isFalse);
    expect(tv.volume, 0.18);
    expect(tv.title, 'HDMI 1');
    expect([tv.canVolume, tv.canMute, tv.canPlayPause], [true, true, true]);
    expect([tv.canTurnOn, tv.canTurnOff], [false, false], reason: 'DLNA ne sait ni allumer ni éteindre');

    final echo = byId('media_player.echo_salon');
    expect(echo.kind, MediaKind.speaker);
    expect(echo.name, 'Echo', reason: 'le nom de la pièce est retiré');
    expect(echo.roomId, 'salon');
    expect(echo.isPlaying, isTrue);
    expect(echo.title, 'Clair de lune — Debussy');
    expect([echo.canTurnOn, echo.canVolume, echo.canMute], [true, true, false]);

    final fire = byId('media_player.fire_tv');
    expect(fire.kind, MediaKind.streamer);
    expect(fire.isOn, isFalse);

    // Les records comparent leurs Map par identité : on compare les éléments.
    final (service, data) = mediaService(MediaCommand.toggleMute, {
      'attributes': {'is_volume_muted': false},
    });
    expect(service, 'volume_mute');
    expect(data, {'is_volume_muted': true});
    expect(mediaService(MediaCommand.volumeUp, null).$1, 'volume_up');
  });

  test('télé DLNA : réveil par son adresse MAC et volume par pas de 2 %', () {
    final registry = HaRegistry.fromLists(
      areas: [
        {'area_id': 'salon', 'name': 'Salon'},
      ],
      devices: [
        {
          'id': 'tv',
          'area_id': 'salon',
          'connections': [
            ['upnp', 'uuid:0000'],
            ['mac', 'b8:d8:2d:00:00:01'],
          ],
        },
      ],
      entities: [
        {'entity_id': 'media_player.tv_salon', 'device_id': 'tv'},
      ],
    );
    final idle = entity('media_player.tv_salon', 'idle', {
      'friendly_name': 'TV Salon',
      'volume_level': 0.2,
      'is_volume_muted': false,
      'supported_features': 1 | 4 | 8 | 512 | 16384,
    });
    final tv = mapHomeAssistant(states: {'media_player.tv_salon': idle}, registry: registry).media.single;
    expect(tv.name, 'TV');
    expect(tv.kind, MediaKind.tv);
    expect(tv.isOn, isTrue, reason: '« Inactif » : allumée, sans lecture');
    expect(tv.wakeMac, 'b8:d8:2d:00:00:01');
    expect(tv.canWake, isTrue);

    final asleep = mapHomeAssistant(
      states: {
        'media_player.tv_salon': entity('media_player.tv_salon', 'unavailable', {'friendly_name': 'TV Salon'}),
      },
      registry: registry,
    ).media.single;
    expect(asleep.looksOff, isTrue, reason: 'injoignable : éteinte, mais réveillable');

    expect(tv.offVia, isNull, reason: 'aucun boîtier dans la pièce');

    // Avec le Freebox Player (Android TV Remote) dans la même pièce, il éteint la télé par HDMI-CEC.
    final withBox = mapHomeAssistant(
      states: {
        'media_player.tv_salon': idle,
        'media_player.freebox_player_pop': entity('media_player.freebox_player_pop', 'off', {
          'friendly_name': 'Freebox Player POP',
          'supported_features': 128 | 256 | 1024 | 8 | 1 | 16384,
        }),
      },
      registry: HaRegistry.fromLists(
        areas: [
          {'area_id': 'salon', 'name': 'Salon'},
        ],
        devices: [
          {'id': 'tv', 'area_id': 'salon'},
          {'id': 'box', 'area_id': 'salon'},
        ],
        entities: [
          {'entity_id': 'media_player.tv_salon', 'device_id': 'tv'},
          {'entity_id': 'media_player.freebox_player_pop', 'device_id': 'box'},
        ],
      ),
    );
    final linked = withBox.media.firstWhere((m) => m.id == 'media_player.tv_salon');
    expect(linked.offVia, 'media_player.freebox_player_pop');
    expect(linked.canPowerOff, isTrue);
    expect(withBox.media.firstWhere((m) => m.id != linked.id).kind, MediaKind.streamer);

    final (service, data) = mediaService(MediaCommand.volumeUp, idle);
    expect(service, 'volume_set');
    expect(data['volume_level'] as double, closeTo(0.22, 1e-9));
    expect(mediaService(MediaCommand.volumeDown, idle).$2['volume_level'] as double, closeTo(0.18, 1e-9));
  });

  group('appareils de l’inventaire réel', () {
    final registry = HaRegistry.fromLists(
      areas: [
        {'area_id': 'salon', 'name': 'Salon'},
        {'area_id': 'bureau', 'name': 'Bureau'},
      ],
      devices: [
        {'id': 'robot', 'area_id': 'salon'},
        {'id': 'nas', 'area_id': 'bureau'},
      ],
      entities: [
        {'entity_id': 'vacuum.bob', 'device_id': 'robot'},
        {'entity_id': 'sensor.bob_batterie', 'device_id': 'robot'},
        {'entity_id': 'light.yeelight_color4_0x17798875', 'area_id': 'bureau'},
        {'entity_id': 'sensor.nas_temperature', 'device_id': 'nas'},
      ],
    );
    final states = <String, Json>{
      'vacuum.bob': entity('vacuum.bob', 'docked', {'friendly_name': 'bob', 'fan_speed': 'balanced'}),
      'sensor.bob_batterie': entity('sensor.bob_batterie', '87', {
        'device_class': 'battery',
        'unit_of_measurement': '%',
      }),
      'light.yeelight_color4_0x17798875': entity('light.yeelight_color4_0x17798875', 'off', {
        'friendly_name': 'Lampadaire Bureau',
        'supported_color_modes': ['color_temp', 'hs', 'rgb'],
      }),
      'sensor.nas_temperature': entity('sensor.nas_temperature', '36', {'device_class': 'temperature'}),
    };

    test('aspirateur : état, pièce et batterie lue sur le capteur du même appareil', () {
      final home = mapHomeAssistant(states: states, registry: registry);
      final bob = home.vacuums.single;
      expect(bob.name, 'bob', reason: 'le nom choisi dans Home Assistant est respecté');
      expect(bob.state, VacuumState.docked);
      expect(bob.battery, 87);
      expect(bob.roomId, 'salon');
      expect(home.rooms.map((r) => r.id), containsAll(['salon', 'bureau']));
    });

    test('le nom de la pièce est retiré aussi en fin de nom', () {
      final home = mapHomeAssistant(states: states, registry: registry);
      expect(home.lights.single.name, 'Lampadaire');
    });

    test('seuls les capteurs de batterie sont suivis', () {
      expect(haKeepEntity('sensor.bob_batterie', states['sensor.bob_batterie']), isTrue);
      expect(haKeepEntity('sensor.nas_temperature', states['sensor.nas_temperature']), isFalse);
      expect(haKeepEntity('vacuum.bob', states['vacuum.bob']), isTrue);
      expect(haKeepEntity('binary_sensor.bob_en_charge', null), isFalse);
    });

    test('extinction par une entité : bouton pressé, script lancé, interrupteur coupé', () {
      expect(triggerService('button.nas_shut_down'), ('button', 'press'));
      expect(triggerService('script.eteindre_pc'), ('script', 'turn_on'));
      expect(triggerService('switch.pc_bureau'), ('switch', 'turn_off'));
    });

    test('une entité d’extinction n’est jamais utilisée pour allumer', () {
      expect(isShutdownEntity('button.nas_shut_down'), isTrue);
      expect(isShutdownEntity('button.nas_redemarrer'), isTrue);
      expect(isShutdownEntity('script.eteindre_pc'), isTrue);
      expect(isShutdownEntity('button.wake_pc_bureau'), isFalse);
      expect(isShutdownEntity('switch.pc_bureau'), isFalse, reason: 'un interrupteur allume et éteint');

      // Réglage enregistré avec l'entité dans le mauvais champ : remis à sa place au chargement.
      final nas = ComputerConfig.fromJson({
        'id': 'n',
        'name': 'NAS',
        'mac': '00:11:32:00:00:01',
        'host': '192.168.1.39',
        'haEntity': 'button.nas_shut_down',
      });
      expect(nas.haEntity, isEmpty);
      expect(nas.haShutdownEntity, 'button.nas_shut_down');
      expect(nas.usesHomeAssistant, isFalse, reason: 'état lu par l’adresse IP, allumage par Wake-on-LAN');
      expect(nas.isServer, isTrue);
      expect(const ComputerConfig(id: 'p', name: 'PC du salon').isServer, isFalse);
    });

    test('un ordinateur Home Assistant avec entité d’extinction peut être éteint', () {
      final home = mapHomeAssistant(
        states: {...states, 'button.nas_wake': entity('button.nas_wake', 'unknown')},
        registry: registry,
        computers: const [
          ComputerConfig(id: 'n', name: 'NAS', haEntity: 'button.nas_wake', haShutdownEntity: 'button.nas_shut_down'),
        ],
      );
      expect(home.computers.single.canShutdown, isTrue);
    });
  });
}
