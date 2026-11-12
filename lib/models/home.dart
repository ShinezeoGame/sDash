// Modèles de données de la maison, indépendants de l'interface et du backend.

enum RoomKind { living, kitchen, bedroom, office, bathroom, entrance, outdoor, generic }

/// Devine le type de pièce à partir de son nom (« Salon », « Chambre d'amis »…).
RoomKind guessRoomKind(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['salon', 'séjour', 'sejour', 'living', 'lounge'])) return RoomKind.living;
  if (has(['cuisine', 'kitchen'])) return RoomKind.kitchen;
  if (has(['chambre', 'bedroom', 'dortoir'])) return RoomKind.bedroom;
  if (has(['bureau', 'office', 'study'])) return RoomKind.office;
  if (has(['bain', 'sdb', 'douche', 'bath', 'wc', 'toilette'])) return RoomKind.bathroom;
  if (has(['entrée', 'entree', 'hall', 'couloir', 'garage', 'entrance'])) {
    return RoomKind.entrance;
  }
  if (has(['jardin', 'terrasse', 'balcon', 'extérieur', 'exterieur', 'garden'])) {
    return RoomKind.outdoor;
  }
  return RoomKind.generic;
}

class Room {
  const Room({required this.id, required this.name, RoomKind? kind}) : kind = kind ?? RoomKind.generic;

  final String id;
  final String name;
  final RoomKind kind;
}

/// Interface commune minimale pour fusionner les listes d'appareils par identifiant.
abstract class Identified {
  String get id;
}

class LightDevice implements Identified {
  const LightDevice({
    required this.id,
    required this.name,
    this.roomId,
    this.isOn = false,
    this.brightness = 1.0,
    this.dimmable = true,
    this.available = true,
  });

  @override
  final String id;
  final String name;
  final String? roomId;
  final bool isOn;

  /// Luminosité entre 0 et 1 (conservée même lampe éteinte).
  final double brightness;
  final bool dimmable;
  final bool available;

  LightDevice copyWith({bool? isOn, double? brightness, bool? available}) => LightDevice(
    id: id,
    name: name,
    roomId: roomId,
    isOn: isOn ?? this.isOn,
    brightness: brightness ?? this.brightness,
    dimmable: dimmable,
    available: available ?? this.available,
  );
}

enum ClimateMode { comfort, eco, away, off }

extension ClimateModeLabel on ClimateMode {
  String get label => switch (this) {
    ClimateMode.comfort => 'Confort',
    ClimateMode.eco => 'Éco',
    ClimateMode.away => 'Hors-gel',
    ClimateMode.off => 'Arrêt',
  };
}

class ClimateDevice implements Identified {
  const ClimateDevice({
    required this.id,
    required this.name,
    this.roomId,
    this.currentTemp,
    this.targetTemp = 20,
    this.minTemp = 7,
    this.maxTemp = 30,
    this.step = 0.5,
    this.mode = ClimateMode.comfort,
    this.isHeating = false,
    this.humidity,
    this.supportedModes = const {ClimateMode.comfort, ClimateMode.eco, ClimateMode.away, ClimateMode.off},
    this.available = true,
  });

  @override
  final String id;
  final String name;
  final String? roomId;
  final double? currentTemp;
  final double targetTemp;
  final double minTemp;
  final double maxTemp;
  final double step;
  final ClimateMode mode;

  /// Vrai quand le radiateur / la chaudière chauffe effectivement.
  final bool isHeating;
  final double? humidity;
  final Set<ClimateMode> supportedModes;
  final bool available;

  /// Arrondit et borne une consigne selon le pas et les limites de l'appareil.
  double clampTarget(double value) {
    final stepped = (value / step).round() * step;
    return stepped.clamp(minTemp, maxTemp).toDouble();
  }

  ClimateDevice copyWith({
    double? currentTemp,
    double? targetTemp,
    ClimateMode? mode,
    bool? isHeating,
    bool? available,
  }) => ClimateDevice(
    id: id,
    name: name,
    roomId: roomId,
    currentTemp: currentTemp ?? this.currentTemp,
    targetTemp: targetTemp ?? this.targetTemp,
    minTemp: minTemp,
    maxTemp: maxTemp,
    step: step,
    mode: mode ?? this.mode,
    isHeating: isHeating ?? this.isHeating,
    humidity: humidity,
    supportedModes: supportedModes,
    available: available ?? this.available,
  );
}

enum CoverMotion { idle, opening, closing }

enum CoverCommand { open, close, stop }

class CoverDevice implements Identified {
  const CoverDevice({
    required this.id,
    required this.name,
    this.roomId,
    this.position = 0,
    this.motion = CoverMotion.idle,
    this.supportsPosition = true,
    this.available = true,
  });

  @override
  final String id;
  final String name;
  final String? roomId;

  /// 0 = fermé, 100 = complètement ouvert.
  final int position;
  final CoverMotion motion;
  final bool supportsPosition;
  final bool available;

  bool get isOpen => position > 0;

  CoverDevice copyWith({int? position, CoverMotion? motion, bool? available}) => CoverDevice(
    id: id,
    name: name,
    roomId: roomId,
    position: position ?? this.position,
    motion: motion ?? this.motion,
    supportsPosition: supportsPosition,
    available: available ?? this.available,
  );
}

enum SwitchKind { plug, tv, coffee, speaker, fan, generic }

SwitchKind guessSwitchKind(String name) {
  final n = name.toLowerCase();
  if (n.contains('tv') || n.contains('télé') || n.contains('tele')) return SwitchKind.tv;
  if (n.contains('café') || n.contains('cafe') || n.contains('coffee') || n.contains('bouilloire')) {
    return SwitchKind.coffee;
  }
  if (n.contains('enceinte') || n.contains('speaker') || n.contains('ampli') || n.contains('sono')) {
    return SwitchKind.speaker;
  }
  if (n.contains('ventil') || n.contains('fan')) return SwitchKind.fan;
  if (n.contains('prise') || n.contains('plug')) return SwitchKind.plug;
  return SwitchKind.generic;
}

class SwitchDevice implements Identified {
  const SwitchDevice({
    required this.id,
    required this.name,
    this.roomId,
    this.isOn = false,
    SwitchKind? kind,
    this.available = true,
  }) : kind = kind ?? SwitchKind.generic;

  @override
  final String id;
  final String name;
  final String? roomId;
  final bool isOn;
  final SwitchKind kind;
  final bool available;

  SwitchDevice copyWith({bool? isOn, bool? available}) => SwitchDevice(
    id: id,
    name: name,
    roomId: roomId,
    isOn: isOn ?? this.isOn,
    kind: kind,
    available: available ?? this.available,
  );
}

enum PowerState { off, starting, on, stopping, unknown }

extension PowerStateLabel on PowerState {
  String get label => switch (this) {
    PowerState.off => 'Éteint',
    PowerState.starting => 'Démarrage…',
    PowerState.on => 'Allumé',
    PowerState.stopping => 'Extinction…',
    PowerState.unknown => 'Inconnu',
  };

  bool get isBusy => this == PowerState.starting || this == PowerState.stopping;
}

class ComputerDevice implements Identified {
  const ComputerDevice({
    required this.id,
    required this.name,
    this.state = PowerState.unknown,
    this.detail,
    this.canShutdown = false,
    this.isServer = false,
  });

  @override
  final String id;
  final String name;
  final PowerState state;

  /// Information secondaire affichée sous le nom (adresse IP, entité…).
  final String? detail;
  final bool canShutdown;
  final bool isServer;

  ComputerDevice copyWith({PowerState? state}) => ComputerDevice(
    id: id,
    name: name,
    state: state ?? this.state,
    detail: detail,
    canShutdown: canShutdown,
    isServer: isServer,
  );
}

enum VacuumState { docked, cleaning, paused, returning, idle, error, unknown }

extension VacuumStateLabel on VacuumState {
  String get label => switch (this) {
    VacuumState.docked => 'À la base',
    VacuumState.cleaning => 'Nettoyage en cours',
    VacuumState.paused => 'En pause',
    VacuumState.returning => 'Retour à la base',
    VacuumState.idle => 'À l’arrêt',
    VacuumState.error => 'Erreur',
    VacuumState.unknown => 'Inconnu',
  };
}

VacuumState vacuumStateFromHomeAssistant(String state) => switch (state) {
  'docked' => VacuumState.docked,
  'cleaning' => VacuumState.cleaning,
  'paused' => VacuumState.paused,
  'returning' => VacuumState.returning,
  'idle' => VacuumState.idle,
  'error' => VacuumState.error,
  _ => VacuumState.unknown,
};

enum VacuumCommand { start, pause, returnHome }

class VacuumDevice implements Identified {
  const VacuumDevice({
    required this.id,
    required this.name,
    this.roomId,
    this.state = VacuumState.unknown,
    this.battery,
    this.available = true,
  });

  @override
  final String id;
  final String name;
  final String? roomId;
  final VacuumState state;

  /// Charge de la batterie en %, si connue.
  final int? battery;
  final bool available;

  bool get isCleaning => state == VacuumState.cleaning;

  VacuumDevice copyWith({VacuumState? state, int? battery}) => VacuumDevice(
    id: id,
    name: name,
    roomId: roomId,
    state: state ?? this.state,
    battery: battery ?? this.battery,
    available: available,
  );
}

/// Télé, enceinte connectée ou passerelle de streaming (entités `media_player`).
enum MediaKind { tv, speaker, streamer, generic }

MediaKind guessMediaKind(String name, [String? deviceClass]) {
  final n = name.toLowerCase().replaceAll('_', ' ');
  if (RegExp(r'fire ?(tv|stick)|chromecast|shield|apple ?tv|stick|box').hasMatch(n)) return MediaKind.streamer;
  if (deviceClass == 'tv' || RegExp(r'\btv\b|télé|tele|hisense|vidaa|bravia|oled').hasMatch(n)) return MediaKind.tv;
  if (deviceClass == 'speaker' ||
      deviceClass == 'receiver' ||
      RegExp(r'echo|alexa|enceinte|sonos|speaker|homepod|nest').hasMatch(n)) {
    return MediaKind.speaker;
  }
  return MediaKind.generic;
}

enum MediaCommand { turnOn, turnOff, playPause, volumeUp, volumeDown, toggleMute }

class MediaDevice implements Identified {
  const MediaDevice({
    required this.id,
    required this.name,
    this.roomId,
    this.kind = MediaKind.generic,
    this.isOn = false,
    this.isPlaying = false,
    this.volume,
    this.muted = false,
    this.title,
    this.available = true,
    this.canTurnOn = false,
    this.canTurnOff = false,
    this.canVolume = false,
    this.canMute = false,
    this.canPlayPause = false,
    this.wakeMac,
    this.offVia,
  });

  @override
  final String id;
  final String name;
  final String? roomId;
  final MediaKind kind;
  final bool isOn;
  final bool isPlaying;

  /// Volume entre 0 et 1, si l'appareil le communique.
  final double? volume;
  final bool muted;

  /// Ce qui est en cours : titre, application ou source.
  final String? title;
  final bool available;

  final bool canTurnOn;
  final bool canTurnOff;
  final bool canVolume;
  final bool canMute;
  final bool canPlayPause;

  /// Adresse MAC de l'appareil : sans commande d'allumage, la tablette le réveille
  /// par le réseau (Wake-on-LAN), comme une télé ajoutée par DLNA.
  final String? wakeMac;

  /// Passerelle de la même pièce (Freebox, Fire TV…) qui éteint cette télé par HDMI-CEC
  /// quand elle ne sait pas s'éteindre seule.
  final String? offVia;

  /// Extinction possible, directement ou par la passerelle.
  bool get canPowerOff => canTurnOff || offVia != null;

  /// Allumage possible uniquement par le réseau.
  bool get canWake => wakeMac != null && !canTurnOn;

  /// Une télé réveillable et injoignable est simplement éteinte.
  bool get looksOff => !available && canWake;

  /// Vrai si la tuile affiche la rangée volume / lecture.
  bool get hasControls => canVolume || canMute || canPlayPause;

  /// État attendu après une commande (pas de volume de 10 %, celui de Home Assistant).
  MediaDevice applied(MediaCommand command) => switch (command) {
    MediaCommand.turnOn => copyWith(isOn: true),
    MediaCommand.turnOff => copyWith(isOn: false, isPlaying: false),
    MediaCommand.playPause => copyWith(isPlaying: !isPlaying),
    MediaCommand.volumeUp => copyWith(volume: ((volume ?? 0.5) + 0.1).clamp(0.0, 1.0)),
    MediaCommand.volumeDown => copyWith(volume: ((volume ?? 0.5) - 0.1).clamp(0.0, 1.0)),
    MediaCommand.toggleMute => copyWith(muted: !muted),
  };

  MediaDevice copyWith({bool? isOn, bool? isPlaying, double? volume, bool? muted, String? offVia}) => MediaDevice(
    id: id,
    name: name,
    roomId: roomId,
    kind: kind,
    isOn: isOn ?? this.isOn,
    isPlaying: isPlaying ?? this.isPlaying,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    title: title,
    available: available,
    canTurnOn: canTurnOn,
    canTurnOff: canTurnOff,
    canVolume: canVolume,
    canMute: canMute,
    canPlayPause: canPlayPause,
    wakeMac: wakeMac,
    offVia: offVia ?? this.offVia,
  );
}

enum SceneKind { cosy, movie, night, morning, away, generic }

SceneKind guessSceneKind(String name) {
  final n = name.toLowerCase();
  if (n.contains('cosy') || n.contains('soir') || n.contains('détente') || n.contains('relax')) {
    return SceneKind.cosy;
  }
  if (n.contains('ciné') || n.contains('cine') || n.contains('film') || n.contains('movie') || n.contains('tv')) {
    return SceneKind.movie;
  }
  if (n.contains('nuit') || n.contains('night') || n.contains('coucher') || n.contains('dodo')) {
    return SceneKind.night;
  }
  if (n.contains('réveil') || n.contains('reveil') || n.contains('matin') || n.contains('morning')) {
    return SceneKind.morning;
  }
  if (n.contains('départ') ||
      n.contains('depart') ||
      n.contains('absent') ||
      n.contains('away') ||
      n.contains('vacances')) {
    return SceneKind.away;
  }
  return SceneKind.generic;
}

class SceneItem implements Identified {
  const SceneItem({required this.id, required this.name, SceneKind? kind}) : kind = kind ?? SceneKind.generic;

  @override
  final String id;
  final String name;
  final SceneKind kind;
}

enum WeatherKind { sunny, partlyCloudy, cloudy, rainy, snowy, stormy, foggy, night, unknown }

WeatherKind weatherFromHomeAssistant(String state) => switch (state) {
  'sunny' => WeatherKind.sunny,
  'clear-night' => WeatherKind.night,
  'partlycloudy' => WeatherKind.partlyCloudy,
  'cloudy' => WeatherKind.cloudy,
  'rainy' || 'pouring' => WeatherKind.rainy,
  'snowy' || 'snowy-rainy' || 'hail' => WeatherKind.snowy,
  'lightning' || 'lightning-rainy' || 'windy' || 'windy-variant' || 'exceptional' => WeatherKind.stormy,
  'fog' => WeatherKind.foggy,
  _ => WeatherKind.unknown,
};

/// Photographie complète de l'état de la maison à un instant donné.
class HomeState {
  const HomeState({
    this.rooms = const [],
    this.lights = const [],
    this.climates = const [],
    this.covers = const [],
    this.switches = const [],
    this.computers = const [],
    this.vacuums = const [],
    this.media = const [],
    this.scenes = const [],
    this.outdoorTemp,
    this.weather = WeatherKind.unknown,
    this.energyWeek,
    this.energyUnit = 'kWh',
  });

  static const empty = HomeState();

  final List<Room> rooms;
  final List<LightDevice> lights;
  final List<ClimateDevice> climates;
  final List<CoverDevice> covers;
  final List<SwitchDevice> switches;
  final List<ComputerDevice> computers;
  final List<VacuumDevice> vacuums;
  final List<MediaDevice> media;
  final List<SceneItem> scenes;
  final double? outdoorTemp;
  final WeatherKind weather;

  /// Consommation des 7 derniers jours, le dernier élément étant aujourd'hui.
  final List<double>? energyWeek;
  final String energyUnit;

  bool get isEmpty =>
      lights.isEmpty &&
      climates.isEmpty &&
      covers.isEmpty &&
      switches.isEmpty &&
      computers.isEmpty &&
      vacuums.isEmpty &&
      media.isEmpty &&
      scenes.isEmpty;

  Room? room(String? id) {
    if (id == null) return null;
    for (final r in rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  String roomName(String? id) => room(id)?.name ?? 'Maison';

  int get lightsOn => lights.where((l) => l.isOn).length;

  int get coversOpen => covers.where((c) => c.isOpen).length;

  /// Température intérieure moyenne mesurée par les thermostats.
  double? get indoorTemp {
    final temps = climates.map((c) => c.currentTemp).whereType<double>().toList();
    if (temps.isEmpty) return null;
    return temps.reduce((a, b) => a + b) / temps.length;
  }

  HomeState copyWith({
    List<Room>? rooms,
    List<LightDevice>? lights,
    List<ClimateDevice>? climates,
    List<CoverDevice>? covers,
    List<SwitchDevice>? switches,
    List<ComputerDevice>? computers,
    List<VacuumDevice>? vacuums,
    List<MediaDevice>? media,
    List<SceneItem>? scenes,
    double? outdoorTemp,
    WeatherKind? weather,
    List<double>? energyWeek,
    String? energyUnit,
  }) => HomeState(
    rooms: rooms ?? this.rooms,
    lights: lights ?? this.lights,
    climates: climates ?? this.climates,
    covers: covers ?? this.covers,
    switches: switches ?? this.switches,
    computers: computers ?? this.computers,
    vacuums: vacuums ?? this.vacuums,
    media: media ?? this.media,
    scenes: scenes ?? this.scenes,
    outdoorTemp: outdoorTemp ?? this.outdoorTemp,
    weather: weather ?? this.weather,
    energyWeek: energyWeek ?? this.energyWeek,
    energyUnit: energyUnit ?? this.energyUnit,
  );
}
