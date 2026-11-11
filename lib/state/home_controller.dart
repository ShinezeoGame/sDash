import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_backend.dart';
import '../data/direct_computers.dart';
import '../data/home_assistant/ha_backend.dart';
import '../data/home_backend.dart';
import '../data/settings.dart';
import '../data/system_bridge.dart';
import '../models/home.dart';

/// Message éphémère affiché en bas de l'écran.
class AppMessage {
  const AppMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

typedef BackendFactory = HomeBackend Function(AppSettings settings);

/// Cerveau de l'application : relie l'interface, les réglages et la source domotique.
///
/// Les commandes sont appliquées immédiatement à l'écran (mise à jour optimiste),
/// puis confirmées par le backend.
class HomeController extends ChangeNotifier {
  HomeController({SettingsStore? store, BackendFactory? backendFactory, this.applySystemSettings = true})
    : _store = store ?? SettingsStore(),
      _backendFactory = backendFactory ?? defaultBackendFactory;

  final SettingsStore _store;
  final BackendFactory _backendFactory;
  final bool applySystemSettings;

  /// Durée pendant laquelle une modification locale prime sur les données reçues.
  static const _localPriority = Duration(seconds: 3);

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  HomeState _state = HomeState.empty;
  HomeState get state => _state;

  LinkStatus _link = LinkStatus.connecting;
  LinkStatus get link => _link;

  bool _ready = false;
  bool get ready => _ready;

  HomeBackend? _backend;
  String get backendLabel => _backend?.label ?? '';
  bool get isDemo => _backend is DemoBackend;

  DirectComputers? _direct;
  HomeState _backendState = HomeState.empty;
  List<ComputerDevice> _directComputers = const [];

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, DateTime> _localEdits = {};
  final Map<String, Timer> _climateDebounce = {};
  final _messages = StreamController<AppMessage>.broadcast();
  Stream<AppMessage> get messages => _messages.stream;
  bool _disposed = false;

  static HomeBackend defaultBackendFactory(AppSettings s) {
    if (s.backend == BackendKind.homeAssistant && s.homeAssistantConfigured) {
      return HomeAssistantBackend(
        baseUrl: s.haUrl,
        token: s.haToken,
        energySensor: s.energySensor,
        computers: s.computers.where((c) => c.usesHomeAssistant).toList(),
      );
    }
    return DemoBackend();
  }

  Future<void> init() async {
    _settings = await _store.load();
    await _applySystem();
    await _startBackend();
    _ready = true;
    _notify();
  }

  Future<void> _applySystem() async {
    if (!applySystemSettings) return;
    await SystemBridge.setKeepScreenOn(_settings.keepScreenOn);
    await SystemBridge.setImmersive(_settings.immersive);
  }

  Future<void> _startBackend() async {
    await _stopBackend();
    final backend = _backendFactory(_settings);
    _backend = backend;
    _subscriptions
      ..add(backend.states.listen(_onBackendState))
      ..add(
        backend.status.listen((s) {
          _link = s;
          _notify();
        }),
      );

    final usesHa = backend is HomeAssistantBackend;
    final direct = DirectComputers([
      for (final c in _settings.computers)
        if (!(usesHa && c.usesHomeAssistant)) c,
    ], trigger: usesHa ? backend.triggerEntity : null);
    _direct = direct;
    _directComputers = direct.current;
    _subscriptions.add(
      direct.updates.listen((list) {
        _directComputers = list;
        _rebuild();
      }),
    );
    direct.start();
    _rebuild();
    unawaited(backend.connect());
  }

  /// Arrête la source courante. Tout est coupé de façon synchrone (minuteurs,
  /// abonnements) avant d'attendre la fin du nettoyage.
  Future<void> _stopBackend() async {
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    for (final t in _climateDebounce.values) {
      t.cancel();
    }
    _climateDebounce.clear();
    _localEdits.clear();
    final backend = _backend;
    final direct = _direct;
    _backend = null;
    _direct = null;
    _backendState = HomeState.empty;
    _link = LinkStatus.connecting;
    await Future.wait([
      for (final s in subscriptions) s.cancel(),
      if (backend != null) backend.dispose(),
      if (direct != null) direct.dispose(),
    ]);
  }

  void _onBackendState(HomeState incoming) {
    final now = DateTime.now();
    _localEdits.removeWhere((_, t) => now.difference(t) > _localPriority);
    _backendState = incoming;
    _rebuild(preferLocal: true);
  }

  List<T> _mergeLocal<T extends Identified>(List<T> incoming, List<T> local) {
    if (_localEdits.isEmpty) return incoming;
    final byId = {for (final d in local) d.id: d};
    return [for (final d in incoming) _localEdits.containsKey(d.id) ? (byId[d.id] ?? d) : d];
  }

  void _rebuild({bool preferLocal = false}) {
    var base = _backendState;
    if (preferLocal) {
      base = base.copyWith(
        lights: _mergeLocal(base.lights, _state.lights),
        switches: _mergeLocal(base.switches, _state.switches),
        climates: _mergeLocal(base.climates, _state.climates),
        media: _mergeLocal(base.media, _state.media),
      );
    }
    _state = base.copyWith(computers: [...base.computers, ..._directComputers]);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _patch(HomeState next, Iterable<String> ids) {
    final now = DateTime.now();
    for (final id in ids) {
      _localEdits[id] = now;
    }
    _state = next;
    _notify();
  }

  Future<void> _run(Future<void> Function(HomeBackend backend) action, {String? success}) async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await action(backend);
      if (success != null) post(success);
    } catch (e) {
      post(describeError(e), isError: true);
      // En cas d'échec, on rend la main aux données du backend.
      _localEdits.clear();
      _rebuild();
    }
  }

  void post(String text, {bool isError = false}) {
    if (!_messages.isClosed) _messages.add(AppMessage(text, isError: isError));
  }

  static String describeError(Object e) {
    if (e is BackendException) return e.message;
    if (e is UnsupportedError) return e.message ?? 'Action non prise en charge';
    if (e is FormatException) return e.message;
    if (e is TimeoutException) return 'Délai dépassé, l’appareil ne répond pas';
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('Network is unreachable')) {
      return 'Réseau injoignable';
    }
    return 'Commande impossible : $text';
  }

  // ───────────────────────────── Lumières ─────────────────────────────

  Future<void> toggleLight(String id) async {
    final light = _state.lights.where((l) => l.id == id).firstOrNull;
    if (light != null) await setLight(id, on: !light.isOn);
  }

  Future<void> setLight(String id, {bool? on, double? brightness}) {
    _patch(
      _state.copyWith(
        lights: [
          for (final l in _state.lights)
            if (l.id == id)
              l.copyWith(
                isOn: on ?? (brightness != null ? brightness > 0.01 : l.isOn),
                brightness: brightness != null && brightness > 0.01 ? brightness : null,
              )
            else
              l,
        ],
      ),
      [id],
    );
    return _run((b) => b.setLight(id, on: on, brightness: brightness));
  }

  /// Allume ou éteint toutes les lumières d'une pièce (ou de la maison si [roomId] est nul).
  Future<void> setLights({String? roomId, required bool on}) async {
    final targets = _state.lights.where((l) => (roomId == null || l.roomId == roomId) && l.isOn != on).toList();
    if (targets.isEmpty) return;
    final ids = targets.map((l) => l.id).toSet();
    _patch(
      _state.copyWith(lights: [for (final l in _state.lights) ids.contains(l.id) ? l.copyWith(isOn: on) : l]),
      ids,
    );
    await _run((b) => Future.wait([for (final id in ids) b.setLight(id, on: on)]));
  }

  // ───────────────────────────── Appareils ─────────────────────────────

  Future<void> toggleSwitch(String id) async {
    final device = _state.switches.where((s) => s.id == id).firstOrNull;
    if (device == null) return;
    final on = !device.isOn;
    _patch(_state.copyWith(switches: [for (final s in _state.switches) s.id == id ? s.copyWith(isOn: on) : s]), [id]);
    await _run((b) => b.setSwitch(id, on));
  }

  // ───────────────────────────── Chauffage ─────────────────────────────

  /// Change la consigne ; l'envoi est différé pour regrouper les appuis successifs.
  void setClimateTarget(String id, double target) {
    final device = _state.climates.where((c) => c.id == id).firstOrNull;
    if (device == null) return;
    final value = device.clampTarget(target);
    _patch(
      _state.copyWith(climates: [for (final c in _state.climates) c.id == id ? c.copyWith(targetTemp: value) : c]),
      [id],
    );
    _climateDebounce[id]?.cancel();
    _climateDebounce[id] = Timer(const Duration(milliseconds: 600), () {
      _climateDebounce.remove(id);
      _localEdits[id] = DateTime.now();
      unawaited(_run((b) => b.setClimateTarget(id, value)));
    });
  }

  void nudgeClimate(String id, int steps) {
    final device = _state.climates.where((c) => c.id == id).firstOrNull;
    if (device != null) setClimateTarget(id, device.targetTemp + steps * device.step);
  }

  Future<void> setClimateMode(String id, ClimateMode mode) {
    _patch(_state.copyWith(climates: [for (final c in _state.climates) c.id == id ? c.copyWith(mode: mode) : c]), [id]);
    return _run((b) => b.setClimateMode(id, mode));
  }

  // ───────────────────────────── Volets ─────────────────────────────

  Future<void> setCoverPosition(String id, int position) => _run((b) => b.setCoverPosition(id, position));

  Future<void> coverCommand(String id, CoverCommand command) => _run((b) => b.coverCommand(id, command));

  Future<void> allCovers(CoverCommand command, {String? roomId}) => _run(
    (b) => Future.wait([
      for (final c in _state.covers)
        if (roomId == null || c.roomId == roomId) b.coverCommand(c.id, command),
    ]),
  );

  // ───────────────────────────── Ordinateurs ─────────────────────────────

  Future<void> setComputerPower(String id, bool on) async {
    final direct = _direct;
    final name = _state.computers.where((c) => c.id == id).firstOrNull?.name ?? 'Ordinateur';
    final success = on ? 'Réveil de « $name » envoyé' : 'Extinction de « $name » demandée';
    if (direct != null && direct.owns(id)) {
      try {
        await direct.setPower(id, on);
        post(success);
      } catch (e) {
        post(describeError(e), isError: true);
      }
      return;
    }
    await _run((b) => b.setComputerPower(id, on), success: success);
  }

  // ───────────────────────────── Aspirateurs ─────────────────────────────

  Future<void> vacuumCommand(String id, VacuumCommand command) {
    final name = _state.vacuums.where((v) => v.id == id).firstOrNull?.name ?? 'Le robot';
    final success = switch (command) {
      VacuumCommand.start => 'Nettoyage lancé',
      VacuumCommand.pause => 'Nettoyage mis en pause',
      VacuumCommand.returnHome => '« $name » retourne à sa base',
    };
    return _run((b) => b.vacuumCommand(id, command), success: success);
  }

  // ───────────────────────────── Multimédia ─────────────────────────────

  /// Le volume n'est pas anticipé : son pas dépend de l'appareil. L'état réel reprend
  /// aussitôt la main, même juste après un allumage anticipé.
  Future<void> mediaCommand(String id, MediaCommand command) {
    if (command == MediaCommand.volumeUp || command == MediaCommand.volumeDown) {
      _localEdits.remove(id);
    } else {
      _patch(_state.copyWith(media: [for (final m in _state.media) m.id == id ? m.applied(command) : m]), [id]);
    }
    return _run((b) => b.mediaCommand(id, command));
  }

  // ───────────────────────────── Scènes ─────────────────────────────

  Future<void> activateScene(String id) {
    final name = _state.scenes.where((s) => s.id == id).firstOrNull?.name ?? 'Scène';
    return _run((b) => b.activateScene(id), success: 'Scène « $name » activée');
  }

  // ───────────────────────────── Réglages ─────────────────────────────

  Future<void> updateSettings(AppSettings next) async {
    final previous = _settings;
    _settings = next;
    _notify();
    await _store.save(next);
    if (previous.keepScreenOn != next.keepScreenOn || previous.immersive != next.immersive) {
      await _applySystem();
    }
    if (previous.needsReconnect(next)) await _startBackend();
  }

  Future<void> reconnect() => _startBackend();

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stopBackend());
    unawaited(_messages.close());
    super.dispose();
  }
}
