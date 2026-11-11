import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum BackendKind { demo, homeAssistant }

/// Thème de l'interface : automatique (suit le réglage de la tablette), clair ou sombre.
enum AppThemeMode { auto, light, dark }

/// Un ordinateur pilotable : soit en direct (Wake-on-LAN + ping depuis la tablette),
/// soit via une entité Home Assistant (ex. `switch.pc_bureau`).
class ComputerConfig {
  const ComputerConfig({
    required this.id,
    required this.name,
    this.mac = '',
    this.host = '',
    this.broadcast = '255.255.255.255',
    this.shutdownUrl = '',
    this.haEntity = '',
    this.haShutdownEntity = '',
  });

  final String id;
  final String name;

  /// Adresse MAC, ex. `AA:BB:CC:DD:EE:FF`, pour le réveil réseau.
  final String mac;

  /// IP ou nom d'hôte, utilisé pour savoir si la machine est allumée.
  final String host;

  /// Adresse de diffusion pour le paquet magique.
  final String broadcast;

  /// URL optionnelle appelée (POST) pour éteindre la machine.
  final String shutdownUrl;

  /// Entité Home Assistant optionnelle (prioritaire en mode Home Assistant).
  final String haEntity;

  /// Entité Home Assistant déclenchée pour éteindre la machine (ex. `button.nas_shut_down`).
  final String haShutdownEntity;

  bool get usesHomeAssistant => haEntity.trim().isNotEmpty;

  /// NAS ou serveur, d'après son nom (icône dédiée).
  bool get isServer => RegExp(r'\b(nas|serveur|server|srv)\b', caseSensitive: false).hasMatch(name);

  ComputerConfig copyWith({
    String? name,
    String? mac,
    String? host,
    String? broadcast,
    String? shutdownUrl,
    String? haEntity,
    String? haShutdownEntity,
  }) => ComputerConfig(
    id: id,
    name: name ?? this.name,
    mac: mac ?? this.mac,
    host: host ?? this.host,
    broadcast: broadcast ?? this.broadcast,
    shutdownUrl: shutdownUrl ?? this.shutdownUrl,
    haEntity: haEntity ?? this.haEntity,
    haShutdownEntity: haShutdownEntity ?? this.haShutdownEntity,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mac': mac,
    'host': host,
    'broadcast': broadcast,
    'shutdownUrl': shutdownUrl,
    'haEntity': haEntity,
    'haShutdownEntity': haShutdownEntity,
  };

  factory ComputerConfig.fromJson(Map<String, dynamic> json) {
    var entity = json['haEntity'] as String? ?? '';
    var shutdownEntity = json['haShutdownEntity'] as String? ?? '';
    // Une entité d'extinction saisie dans le champ « pour allumer » éteindrait la machine
    // au lieu de l'allumer : elle est remise à sa place.
    if (isShutdownEntity(entity) && shutdownEntity.trim().isEmpty) {
      shutdownEntity = entity;
      entity = '';
    }
    return ComputerConfig(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Ordinateur',
      mac: json['mac'] as String? ?? '',
      host: json['host'] as String? ?? '',
      broadcast: json['broadcast'] as String? ?? '255.255.255.255',
      shutdownUrl: json['shutdownUrl'] as String? ?? '',
      haEntity: entity,
      haShutdownEntity: shutdownEntity,
    );
  }
}

/// Vrai si l'entité Home Assistant est une commande d'extinction, de redémarrage ou de mise
/// en veille (ex. `button.nas_shut_down`, `script.eteindre_pc`) : elle ne doit jamais servir
/// à allumer une machine.
bool isShutdownEntity(String entityId) {
  final id = entityId.trim().toLowerCase();
  if (!RegExp(r'^(button|input_button|script)\.').hasMatch(id)) return false;
  return RegExp(
    r'shut_?down|power_?off|turn_?off|eteindre|eteint|extinction|arret|reboot|restart|redemarr|veille|sleep|hibernat|suspend',
  ).hasMatch(id);
}

class AppSettings {
  const AppSettings({
    this.userName = '',
    this.backend = BackendKind.demo,
    this.haUrl = '',
    this.haToken = '',
    this.energySensor = '',
    this.computers = const [],
    this.theme = AppThemeMode.auto,
    this.keepScreenOn = true,
    this.immersive = true,
  });

  final String userName;
  final BackendKind backend;
  final String haUrl;
  final String haToken;

  /// Capteur d'énergie Home Assistant (statistiques journalières), optionnel.
  final String energySensor;
  final List<ComputerConfig> computers;

  final AppThemeMode theme;
  final bool keepScreenOn;
  final bool immersive;

  bool get homeAssistantConfigured => haUrl.trim().isNotEmpty && haToken.trim().isNotEmpty;

  /// Vrai si un changement de réglages impose de recréer la connexion au backend.
  bool needsReconnect(AppSettings other) =>
      backend != other.backend ||
      haUrl != other.haUrl ||
      haToken != other.haToken ||
      energySensor != other.energySensor ||
      jsonEncode(computers.map((c) => c.toJson()).toList()) !=
          jsonEncode(other.computers.map((c) => c.toJson()).toList());

  AppSettings copyWith({
    String? userName,
    BackendKind? backend,
    String? haUrl,
    String? haToken,
    String? energySensor,
    List<ComputerConfig>? computers,
    AppThemeMode? theme,
    bool? keepScreenOn,
    bool? immersive,
  }) => AppSettings(
    userName: userName ?? this.userName,
    backend: backend ?? this.backend,
    haUrl: haUrl ?? this.haUrl,
    haToken: haToken ?? this.haToken,
    energySensor: energySensor ?? this.energySensor,
    computers: computers ?? this.computers,
    theme: theme ?? this.theme,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    immersive: immersive ?? this.immersive,
  );

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'backend': backend.name,
    'haUrl': haUrl,
    'haToken': haToken,
    'energySensor': energySensor,
    'computers': computers.map((c) => c.toJson()).toList(),
    'theme': theme.name,
    'keepScreenOn': keepScreenOn,
    'immersive': immersive,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    userName: json['userName'] as String? ?? '',
    backend: BackendKind.values.firstWhere((b) => b.name == json['backend'], orElse: () => BackendKind.demo),
    haUrl: json['haUrl'] as String? ?? '',
    haToken: json['haToken'] as String? ?? '',
    energySensor: json['energySensor'] as String? ?? '',
    computers: (json['computers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ComputerConfig.fromJson)
        .toList(),
    theme: AppThemeMode.values.firstWhere((v) => v.name == json['theme'], orElse: () => AppThemeMode.auto),
    keepScreenOn: json['keepScreenOn'] as bool? ?? true,
    immersive: json['immersive'] as bool? ?? true,
  );
}

/// Persistance des réglages dans le stockage privé de l'application.
class SettingsStore {
  static const _key = 'sdash.settings';

  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const AppSettings();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } catch (_) {
      // Réglages illisibles : on repart des valeurs par défaut.
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
