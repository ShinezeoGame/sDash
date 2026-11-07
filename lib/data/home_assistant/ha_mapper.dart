// Conversion des données brutes de Home Assistant vers les modèles de sDash.
// Fonctions pures : testables sans connexion réseau.

import '../../models/home.dart';
import '../settings.dart';

typedef Json = Map<String, dynamic>;

/// Domaines Home Assistant exploités par l'application.
const haRelevantDomains = {
  'light',
  'climate',
  'cover',
  'switch',
  'scene',
  'script',
  'weather',
  'button',
  'input_boolean',
};

const _awayPresets = ['away', 'frost_protection', 'frost', 'hors_gel', 'hors-gel', 'antifreeze'];

String haDomain(String entityId) {
  final dot = entityId.indexOf('.');
  return dot < 0 ? entityId : entityId.substring(0, dot);
}

/// Pièces et visibilité des entités, issues des registres Home Assistant.
class HaRegistry {
  const HaRegistry({this.areas = const [], this.entityArea = const {}, this.hidden = const {}});

  static const empty = HaRegistry();

  /// Pièces dans l'ordre défini dans Home Assistant.
  final List<Room> areas;
  final Map<String, String> entityArea;

  /// Entités masquées, désactivées ou techniques (configuration / diagnostic).
  final Set<String> hidden;

  factory HaRegistry.fromLists({
    List<dynamic> areas = const [],
    List<dynamic> entities = const [],
    List<dynamic> devices = const [],
  }) {
    final rooms = <Room>[
      for (final a in areas.whereType<Json>())
        if (a['area_id'] is String)
          Room(
            id: a['area_id'] as String,
            name: (a['name'] as String?) ?? a['area_id'] as String,
            kind: guessRoomKind((a['name'] as String?) ?? ''),
          ),
    ];
    final deviceArea = <String, String>{
      for (final d in devices.whereType<Json>())
        if (d['id'] is String && d['area_id'] is String) d['id'] as String: d['area_id'] as String,
    };
    final entityArea = <String, String>{};
    final hidden = <String>{};
    for (final e in entities.whereType<Json>()) {
      final id = e['entity_id'];
      if (id is! String) continue;
      final area = e['area_id'] as String? ?? deviceArea[e['device_id']];
      if (area != null) entityArea[id] = area;
      if (e['hidden_by'] != null || e['disabled_by'] != null || e['entity_category'] != null) {
        hidden.add(id);
      }
    }
    return HaRegistry(areas: rooms, entityArea: entityArea, hidden: hidden);
  }
}

String _friendlyName(String entityId, Json state) {
  final attrs = state['attributes'];
  final name = attrs is Json ? attrs['friendly_name'] : null;
  if (name is String && name.trim().isNotEmpty) return name.trim();
  final objectId = entityId.contains('.') ? entityId.split('.').last : entityId;
  final words = objectId.replaceAll('_', ' ');
  return words.isEmpty ? entityId : words[0].toUpperCase() + words.substring(1);
}

/// Retire le nom de la pièce en tête du nom (« Salon Plafonnier » → « Plafonnier »).
String _stripRoom(String name, String? roomName) {
  if (roomName == null) return name;
  final lower = name.toLowerCase();
  final prefix = roomName.toLowerCase();
  if (lower.startsWith('$prefix ') && name.length > roomName.length + 1) {
    final rest = name.substring(roomName.length + 1).trim();
    return rest[0].toUpperCase() + rest.substring(1);
  }
  return name;
}

double? _num(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

List<String> _strings(dynamic v) => v is List ? v.whereType<String>().toList() : const [];

/// Construit l'état complet de la maison à partir des entités Home Assistant.
HomeState mapHomeAssistant({
  required Map<String, Json> states,
  HaRegistry registry = HaRegistry.empty,
  List<ComputerConfig> computers = const [],
  List<double>? energyWeek,
  String energyUnit = 'kWh',
  Map<String, double>? brightnessMemory,
}) {
  final memory = brightnessMemory ?? <String, double>{};
  final roomNames = {for (final r in registry.areas) r.id: r.name};
  final computerEntities = {for (final c in computers) c.haEntity.trim()};

  final lights = <LightDevice>[];
  final climates = <ClimateDevice>[];
  final covers = <CoverDevice>[];
  final switches = <SwitchDevice>[];
  final scenes = <SceneItem>[];
  double? outdoorTemp;
  var weather = WeatherKind.unknown;

  final ids = states.keys.toList()..sort();
  for (final id in ids) {
    if (registry.hidden.contains(id) || computerEntities.contains(id)) continue;
    final s = states[id]!;
    final state = s['state'] as String? ?? 'unknown';
    final attrs = s['attributes'] is Json ? s['attributes'] as Json : const <String, dynamic>{};
    final roomId = registry.entityArea[id];
    final name = _stripRoom(_friendlyName(id, s), roomNames[roomId]);
    final available = state != 'unavailable';

    switch (haDomain(id)) {
      case 'light':
        final modes = _strings(attrs['supported_color_modes']);
        final dimmable = modes.isEmpty
            ? attrs.containsKey('brightness')
            : !(modes.length == 1 && modes.first == 'onoff');
        final raw = _num(attrs['brightness']);
        if (raw != null) memory[id] = (raw / 255).clamp(0.01, 1.0);
        lights.add(
          LightDevice(
            id: id,
            name: name,
            roomId: roomId,
            isOn: state == 'on',
            brightness: memory[id] ?? 1.0,
            dimmable: dimmable,
            available: available,
          ),
        );
      case 'climate':
        final presets = _strings(attrs['preset_modes']);
        final hvacModes = _strings(attrs['hvac_modes']);
        final preset = attrs['preset_mode'] as String?;
        final mode = state == 'off'
            ? ClimateMode.off
            : preset == 'eco'
            ? ClimateMode.eco
            : (_awayPresets.contains(preset) ? ClimateMode.away : ClimateMode.comfort);
        climates.add(
          ClimateDevice(
            id: id,
            name: name,
            roomId: roomId,
            currentTemp: _num(attrs['current_temperature']),
            targetTemp: _num(attrs['temperature']) ?? _num(attrs['target_temp_low']) ?? 19,
            minTemp: _num(attrs['min_temp']) ?? 7,
            maxTemp: _num(attrs['max_temp']) ?? 30,
            step: _num(attrs['target_temp_step']) ?? 0.5,
            mode: mode,
            isHeating: attrs['hvac_action'] == 'heating',
            humidity: _num(attrs['current_humidity']),
            supportedModes: {
              ClimateMode.comfort,
              if (presets.contains('eco')) ClimateMode.eco,
              if (presets.any(_awayPresets.contains)) ClimateMode.away,
              if (hvacModes.contains('off')) ClimateMode.off,
            },
            available: available,
          ),
        );
      case 'cover':
        final pos = _num(attrs['current_position']);
        covers.add(
          CoverDevice(
            id: id,
            name: name,
            roomId: roomId,
            position: pos?.round() ?? (state == 'open' || state == 'opening' ? 100 : 0),
            motion: switch (state) {
              'opening' => CoverMotion.opening,
              'closing' => CoverMotion.closing,
              _ => CoverMotion.idle,
            },
            supportsPosition: pos != null,
            available: available,
          ),
        );
      case 'switch':
        switches.add(
          SwitchDevice(
            id: id,
            name: name,
            roomId: roomId,
            isOn: state == 'on',
            kind: guessSwitchKind(name),
            available: available,
          ),
        );
      case 'scene' || 'script':
        scenes.add(SceneItem(id: id, name: name, kind: guessSceneKind(name)));
      case 'weather':
        if (outdoorTemp == null) {
          outdoorTemp = _num(attrs['temperature']);
          weather = weatherFromHomeAssistant(state);
        }
    }
  }

  final computerDevices = <ComputerDevice>[
    for (final c in computers)
      if (c.usesHomeAssistant)
        ComputerDevice(
          id: 'pc:${c.id}',
          name: c.name,
          state: switch (states[c.haEntity.trim()]?['state']) {
            'on' => PowerState.on,
            'off' => PowerState.off,
            _ => PowerState.unknown,
          },
          detail: c.host.isNotEmpty ? c.host : c.haEntity.trim(),
          canShutdown: haDomain(c.haEntity.trim()) != 'button',
        ),
  ];

  // Ne garde que les pièces réellement utilisées.
  final usedRooms = {
    ...lights.map((d) => d.roomId),
    ...climates.map((d) => d.roomId),
    ...covers.map((d) => d.roomId),
    ...switches.map((d) => d.roomId),
  };

  return HomeState(
    rooms: registry.areas.where((r) => usedRooms.contains(r.id)).toList(),
    lights: lights,
    climates: climates,
    covers: covers,
    switches: switches,
    computers: computerDevices,
    scenes: scenes,
    outdoorTemp: outdoorTemp,
    weather: weather,
    energyWeek: energyWeek,
    energyUnit: energyUnit,
  );
}

/// Commande Home Assistant correspondant à un changement de mode de chauffage.
/// Renvoie une liste de couples (service, données) à exécuter dans l'ordre.
List<(String, Json)> climateModeCalls(Json? entityState, ClimateMode mode) {
  final attrs = entityState?['attributes'] is Json ? entityState!['attributes'] as Json : const <String, dynamic>{};
  final presets = _strings(attrs['preset_modes']);
  final hvacModes = _strings(attrs['hvac_modes']);
  if (mode == ClimateMode.off) {
    return [
      ('set_hvac_mode', {'hvac_mode': 'off'}),
    ];
  }
  final calls = <(String, Json)>[];
  if (entityState?['state'] == 'off') {
    final heatMode = ['heat', 'auto', 'heat_cool'].firstWhere(hvacModes.contains, orElse: () => 'heat');
    calls.add(('set_hvac_mode', {'hvac_mode': heatMode}));
  }
  String? preset;
  switch (mode) {
    case ClimateMode.comfort:
      preset = presets.contains('comfort')
          ? 'comfort'
          : (presets.contains('home') ? 'home' : (presets.contains('none') ? 'none' : null));
    case ClimateMode.eco:
      preset = presets.contains('eco') ? 'eco' : null;
    case ClimateMode.away:
      preset = _awayPresets.firstWhere(presets.contains, orElse: () => '');
      if (preset.isEmpty) preset = null;
    case ClimateMode.off:
      break;
  }
  if (preset != null) calls.add(('set_preset_mode', {'preset_mode': preset}));
  return calls;
}

/// Agrège les statistiques journalières (`recorder/statistics_during_period`)
/// en 7 valeurs, de J-6 à aujourd'hui.
List<double>? parseEnergyWeek(dynamic result, String statisticId, DateTime now) {
  if (result is! Map) return null;
  final rows = result[statisticId];
  if (rows is! List) return null;
  final today = DateTime(now.year, now.month, now.day);
  final days = List<double>.filled(7, 0);
  for (final row in rows.whereType<Map>()) {
    final start = row['start'];
    DateTime? date;
    if (start is num) {
      date = DateTime.fromMillisecondsSinceEpoch(start.toInt());
    } else if (start is String) {
      date = DateTime.tryParse(start)?.toLocal();
    }
    final change = _num(row['change']);
    if (date == null || change == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    final ago = (today.difference(day).inHours / 24).round();
    final index = 6 - ago;
    if (index >= 0 && index < 7) days[index] += change;
  }
  return days;
}
