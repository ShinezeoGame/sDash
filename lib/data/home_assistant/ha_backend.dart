import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/home.dart';
import '../home_backend.dart';
import '../settings.dart';
import 'ha_mapper.dart';

/// Connexion temps réel à Home Assistant via son API WebSocket
/// (https://developers.home-assistant.io/docs/api/websocket).
class HomeAssistantBackend implements HomeBackend {
  HomeAssistantBackend({required this.baseUrl, required this.token, this.energySensor = '', this.computers = const []});

  final String baseUrl;
  final String token;
  final String energySensor;
  final List<ComputerConfig> computers;

  final _states = StreamController<HomeState>.broadcast();
  final _status = StreamController<LinkStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _nextId = 1;
  final Map<int, Completer<dynamic>> _pending = {};

  final Map<String, Json> _entities = {};
  final Map<String, double> _brightnessMemory = {};
  HaRegistry _registry = HaRegistry.empty;
  List<double>? _energyWeek;
  String _energyUnit = 'kWh';

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _energyTimer;
  Timer? _emitTimer;
  int _retry = 0;
  bool _ready = false;
  bool _authFailed = false;
  bool _disposed = false;

  @override
  String get label => 'Home Assistant';

  @override
  Stream<HomeState> get states => _states.stream;

  @override
  Stream<LinkStatus> get status => _status.stream;

  /// Convertit l'adresse saisie (`http://192.168.1.5:8123`) en URL WebSocket.
  static Uri websocketUri(String base) {
    var value = base.trim();
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.parse(value);
    final secure = uri.scheme == 'https' || uri.scheme == 'wss';
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '$path/api/websocket',
    );
  }

  void _setStatus(LinkState state, [String? message]) {
    if (!_status.isClosed) _status.add(LinkStatus(state, message));
  }

  @override
  Future<void> connect() => _open();

  Future<void> _open() async {
    if (_disposed) return;
    _setStatus(LinkState.connecting, 'Connexion à Home Assistant…');
    try {
      final channel = WebSocketChannel.connect(websocketUri(baseUrl));
      await channel.ready.timeout(const Duration(seconds: 10));
      if (_disposed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object _) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
    } catch (e) {
      _setStatus(LinkState.offline, 'Home Assistant injoignable (${_shortError(e)})');
      _scheduleReconnect();
    }
  }

  String _shortError(Object e) {
    final text = e.toString();
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }

  void _send(Json message) => _channel?.sink.add(jsonEncode(message));

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Json message;
    try {
      message = jsonDecode(raw) as Json;
    } catch (_) {
      return;
    }
    switch (message['type']) {
      case 'auth_required':
        _send({'type': 'auth', 'access_token': token});
      case 'auth_ok':
        _retry = 0;
        unawaited(_bootstrap());
      case 'auth_invalid':
        _authFailed = true;
        _setStatus(LinkState.offline, 'Jeton d’accès refusé par Home Assistant');
        unawaited(_channel?.sink.close());
      case 'result':
        final completer = _pending.remove(message['id']);
        if (completer == null) return;
        if (message['success'] == true) {
          completer.complete(message['result']);
        } else {
          final error = message['error'];
          final text = error is Map ? (error['message'] ?? error['code']).toString() : 'erreur inconnue';
          completer.completeError(BackendException('Home Assistant : $text'));
        }
      case 'pong':
        _pending.remove(message['id'])?.complete(null);
      case 'event':
        _onEvent(message['event']);
    }
  }

  void _onEvent(dynamic event) {
    if (event is! Json || event['event_type'] != 'state_changed') return;
    final data = event['data'];
    if (data is! Json) return;
    final entityId = data['entity_id'];
    if (entityId is! String) return;
    final newState = data['new_state'];
    if (!haKeepEntity(entityId, newState is Json ? newState : _entities[entityId])) return;
    if (newState is Json) {
      _entities[entityId] = newState;
    } else {
      _entities.remove(entityId);
    }
    _scheduleEmit();
  }

  Future<void> _bootstrap() async {
    try {
      Future<List<dynamic>> list(String type) async {
        try {
          final result = await _call({'type': type});
          return result is List ? result : const [];
        } catch (_) {
          // Registres inaccessibles (utilisateur non administrateur) : pas de pièces.
          return const [];
        }
      }

      final results = await Future.wait([
        _call({'type': 'get_states'}),
        list('config/area_registry/list'),
        list('config/entity_registry/list'),
        list('config/device_registry/list'),
      ]);
      _entities.clear();
      for (final s in (results[0] as List? ?? const []).whereType<Json>()) {
        final id = s['entity_id'];
        if (id is String && haKeepEntity(id, s)) _entities[id] = s;
      }
      _registry = HaRegistry.fromLists(
        areas: results[1] as List,
        entities: results[2] as List,
        devices: results[3] as List,
      );
      await _call({'type': 'subscribe_events', 'event_type': 'state_changed'});
      _ready = true;
      _setStatus(LinkState.online, 'Connecté à Home Assistant');
      _emit();
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
      _energyTimer?.cancel();
      if (energySensor.trim().isNotEmpty) {
        unawaited(_refreshEnergy());
        _energyTimer = Timer.periodic(const Duration(minutes: 20), (_) => _refreshEnergy());
      }
    } catch (e) {
      _setStatus(LinkState.offline, 'Échec de l’initialisation (${_shortError(e)})');
      await _channel?.sink.close();
    }
  }

  Future<void> _ping() async {
    try {
      await _call({'type': 'ping'}, timeout: const Duration(seconds: 10));
    } catch (_) {
      await _channel?.sink.close();
    }
  }

  Future<void> _refreshEnergy() async {
    final sensor = energySensor.trim();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    try {
      final result = await _call({
        'type': 'recorder/statistics_during_period',
        'start_time': start.toUtc().toIso8601String(),
        'end_time': now.toUtc().toIso8601String(),
        'statistic_ids': [sensor],
        'period': 'day',
        'types': ['change'],
      });
      _energyWeek = parseEnergyWeek(result, sensor, now);
      final unit = (_entities[sensor]?['attributes'] as Json?)?['unit_of_measurement'];
      if (unit is String && unit.isNotEmpty) _energyUnit = unit;
      _emit();
    } catch (_) {
      // Statistiques indisponibles : la carte énergie affichera les températures.
    }
  }

  Future<dynamic> _call(Json payload, {Duration timeout = const Duration(seconds: 15)}) {
    if (_channel == null) {
      return Future.error(const BackendException('Home Assistant n’est pas connecté'));
    }
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _send({...payload, 'id': id});
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw const BackendException('Home Assistant ne répond pas');
      },
    );
  }

  void _scheduleEmit() {
    _emitTimer?.cancel();
    _emitTimer = Timer(const Duration(milliseconds: 120), _emit);
  }

  void _emit() {
    if (_states.isClosed || !_ready) return;
    _states.add(
      mapHomeAssistant(
        states: _entities,
        registry: _registry,
        computers: computers,
        energyWeek: _energyWeek,
        energyUnit: _energyUnit,
        brightnessMemory: _brightnessMemory,
      ),
    );
  }

  void _onClosed() {
    _ready = false;
    _pingTimer?.cancel();
    _energyTimer?.cancel();
    _channel = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(const BackendException('Connexion perdue'));
    }
    _pending.clear();
    if (_disposed || _authFailed) return;
    _setStatus(LinkState.offline, 'Connexion perdue, nouvelle tentative…');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _authFailed) return;
    _reconnectTimer?.cancel();
    final seconds = math.min(30, 1 << math.min(_retry, 5));
    _retry++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _open);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _energyTimer?.cancel();
    _emitTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _states.close();
    await _status.close();
  }

  Future<void> _service(String domain, String service, String entityId, [Json data = const {}]) async {
    await _call({
      'type': 'call_service',
      'domain': domain,
      'service': service,
      'service_data': data,
      'target': {'entity_id': entityId},
    });
  }

  @override
  Future<void> setLight(String id, {bool? on, double? brightness}) {
    if (on == false || (brightness != null && brightness <= 0.01)) {
      return _service('light', 'turn_off', id);
    }
    return _service('light', 'turn_on', id, {
      if (brightness != null) 'brightness_pct': (brightness * 100).round().clamp(1, 100),
    });
  }

  @override
  Future<void> setSwitch(String id, bool on) => _service(haDomain(id), on ? 'turn_on' : 'turn_off', id);

  @override
  Future<void> setClimateTarget(String id, double target) =>
      _service('climate', 'set_temperature', id, {'temperature': target});

  @override
  Future<void> setClimateMode(String id, ClimateMode mode) async {
    for (final (service, data) in climateModeCalls(_entities[id], mode)) {
      await _service('climate', service, id, data);
    }
  }

  @override
  Future<void> setCoverPosition(String id, int position) {
    final supportsPosition = (_entities[id]?['attributes'] as Json?)?['current_position'] != null;
    if (!supportsPosition) {
      return _service('cover', position > 50 ? 'open_cover' : 'close_cover', id);
    }
    return _service('cover', 'set_cover_position', id, {'position': position.clamp(0, 100)});
  }

  @override
  Future<void> coverCommand(String id, CoverCommand command) => _service('cover', switch (command) {
    CoverCommand.open => 'open_cover',
    CoverCommand.close => 'close_cover',
    CoverCommand.stop => 'stop_cover',
  }, id);

  @override
  Future<void> setComputerPower(String id, bool on) async {
    final config = computers.where((c) => 'pc:${c.id}' == id).firstOrNull;
    if (config == null) throw const BackendException('Ordinateur introuvable');
    final entity = config.haEntity.trim();
    final domain = haDomain(entity);
    final shutdown = config.haShutdownEntity.trim();
    if (!on && shutdown.isNotEmpty) return triggerEntity(shutdown);
    if (on && isShutdownEntity(entity)) {
      throw BackendException(
        '« $entity » éteint la machine : indiquez-la dans « Entité Home Assistant pour éteindre » (Réglages).',
      );
    }
    if (domain == 'button') {
      if (!on) throw const BackendException('Aucune commande d’extinction configurée pour cet ordinateur.');
      return _service('button', 'press', entity);
    }
    return _service(domain, on ? 'turn_on' : 'turn_off', entity);
  }

  @override
  Future<void> vacuumCommand(String id, VacuumCommand command) => _service('vacuum', switch (command) {
    VacuumCommand.start => 'start',
    VacuumCommand.pause => 'pause',
    VacuumCommand.returnHome => 'return_to_base',
  }, id);

  @override
  Future<void> triggerEntity(String entityId) {
    final (domain, service) = triggerService(entityId);
    return _service(domain, service, entityId);
  }

  @override
  Future<void> activateScene(String id) => _service(haDomain(id), 'turn_on', id);
}
