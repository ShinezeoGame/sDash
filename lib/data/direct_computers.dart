import 'dart:async';

import '../models/home.dart';
import 'home_backend.dart';
import 'network/net_tools.dart' as net;
import 'network/wake_on_lan.dart';
import 'settings.dart';

/// Ordinateurs pilotés directement depuis la tablette : réveil par paquet magique,
/// état déduit d'une sonde réseau, extinction via une URL optionnelle.
class DirectComputers {
  DirectComputers(this.configs, {this.trigger});

  final List<ComputerConfig> configs;

  /// Déclenche une entité Home Assistant (extinction par `haShutdownEntity`) ;
  /// nul hors mode Home Assistant.
  final Future<void> Function(String entityId)? trigger;

  bool _canShutdown(ComputerConfig c) =>
      c.shutdownUrl.trim().isNotEmpty || (c.haShutdownEntity.trim().isNotEmpty && trigger != null);

  static const _idPrefix = 'pc:';
  static const _bootTimeout = Duration(minutes: 3);
  static const _idleProbeInterval = Duration(seconds: 15);

  final _updates = StreamController<List<ComputerDevice>>.broadcast();
  final Map<String, PowerState> _states = {};
  final Map<String, DateTime> _busySince = {};
  final Map<String, DateTime> _lastProbe = {};
  final Set<String> _probing = {};
  Timer? _timer;

  Stream<List<ComputerDevice>> get updates => _updates.stream;

  static String deviceId(ComputerConfig c) => '$_idPrefix${c.id}';

  bool owns(String deviceId) => configs.any((c) => DirectComputers.deviceId(c) == deviceId);

  List<ComputerDevice> get current => [
    for (final c in configs)
      ComputerDevice(
        id: deviceId(c),
        name: c.name,
        state: _states[c.id] ?? PowerState.unknown,
        detail: c.host.isNotEmpty ? c.host : (c.mac.isNotEmpty ? c.mac.toUpperCase() : null),
        canShutdown: _canShutdown(c),
      ),
  ];

  void start() {
    if (configs.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _probeDue());
    _probeDue();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _updates.close();
  }

  void _publish() {
    if (!_updates.isClosed) _updates.add(current);
  }

  void _probeDue() {
    final now = DateTime.now();
    for (final c in configs) {
      final busy = _busySince.containsKey(c.id);
      final last = _lastProbe[c.id];
      if (busy || last == null || now.difference(last) >= _idleProbeInterval) {
        unawaited(_probe(c));
      }
    }
  }

  Future<void> _probe(ComputerConfig c) async {
    if (!net.netToolsSupported || _probing.contains(c.id)) return;
    if (c.host.trim().isEmpty) {
      // Sans adresse à sonder, l'état réel est inconnu : on lève l'indicateur « démarrage ».
      final since = _busySince[c.id];
      if (since != null && DateTime.now().difference(since) > const Duration(seconds: 45)) {
        _busySince.remove(c.id);
        _states[c.id] = PowerState.unknown;
        _publish();
      }
      return;
    }
    _probing.add(c.id);
    _lastProbe[c.id] = DateTime.now();
    try {
      final reachable = await net.isHostReachable(c.host);
      final previous = _states[c.id];
      final since = _busySince[c.id];
      PowerState next;
      if (previous == PowerState.starting && since != null) {
        next = reachable
            ? PowerState.on
            : (DateTime.now().difference(since) > _bootTimeout ? PowerState.off : PowerState.starting);
      } else if (previous == PowerState.stopping && since != null) {
        next = !reachable
            ? PowerState.off
            : (DateTime.now().difference(since) > _bootTimeout ? PowerState.on : PowerState.stopping);
      } else {
        next = reachable ? PowerState.on : PowerState.off;
      }
      if (!next.isBusy) _busySince.remove(c.id);
      if (next != previous) {
        _states[c.id] = next;
        _publish();
      }
    } finally {
      _probing.remove(c.id);
    }
  }

  Future<void> setPower(String deviceId, bool on) async {
    final config = configs.where((c) => DirectComputers.deviceId(c) == deviceId).firstOrNull;
    if (config == null) throw const BackendException('Ordinateur introuvable');
    final viaHomeAssistant = !on && config.shutdownUrl.trim().isEmpty && _canShutdown(config);
    if (!net.netToolsSupported && !viaHomeAssistant) {
      throw const BackendException('Le pilotage réseau n’est disponible que sur la tablette.');
    }
    if (on) {
      if (!isValidMac(config.mac)) {
        throw BackendException('Adresse MAC manquante ou invalide pour « ${config.name} ».');
      }
      await net.sendMagicPacket(config.mac, broadcast: config.broadcast);
      _states[config.id] = PowerState.starting;
    } else {
      if (viaHomeAssistant) {
        await trigger!(config.haShutdownEntity.trim());
      } else if (config.shutdownUrl.trim().isNotEmpty) {
        await net.sendHttpCommand(config.shutdownUrl);
      } else {
        throw BackendException('Aucune commande d’extinction configurée pour « ${config.name} ».');
      }
      _states[config.id] = PowerState.stopping;
    }
    _busySince[config.id] = DateTime.now();
    _publish();
  }
}
