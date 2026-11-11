import 'dart:async';

import '../models/home.dart';
import 'home_backend.dart';

/// Maison simulée : permet d'utiliser et de découvrir l'application sans domotique.
class DemoBackend implements HomeBackend {
  DemoBackend({this.tick = const Duration(seconds: 1), this.latency = const Duration(milliseconds: 150)});

  final Duration tick;
  final Duration latency;

  final _states = StreamController<HomeState>.broadcast();
  final _status = StreamController<LinkStatus>.broadcast();

  HomeState _home = demoHome();
  HomeState get current => _home;

  final Map<String, int> _coverTargets = {};
  final Map<String, DateTime> _computerBusy = {};

  /// Pas de simulation restants avant que l'aspirateur rejoigne sa base.
  final Map<String, int> _vacuumReturn = {};

  /// Consignes mémorisées par mode, pour chaque thermostat.
  final Map<String, Map<ClimateMode, double>> _setpoints = {};
  Timer? _timer;

  @override
  String get label => 'Démo';

  @override
  Stream<HomeState> get states => _states.stream;

  @override
  Stream<LinkStatus> get status => _status.stream;

  @override
  Future<void> connect() async {
    _status.add(LinkStatus.connecting);
    await Future<void>.delayed(latency);
    _status.add(const LinkStatus(LinkState.online, 'Maison de démonstration'));
    _emit();
    _timer ??= Timer.periodic(tick, (_) => simulateStep());
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _states.close();
    await _status.close();
  }

  void _emit() {
    if (!_states.isClosed) _states.add(_home);
  }

  Future<void> _later() => Future<void>.delayed(latency);

  @override
  Future<void> setLight(String id, {bool? on, double? brightness}) async {
    await _later();
    _home = _home.copyWith(
      lights: [
        for (final l in _home.lights)
          if (l.id == id)
            l.copyWith(
              isOn: on ?? (brightness != null ? brightness > 0.01 : l.isOn),
              brightness: brightness != null && brightness > 0.01 ? brightness : null,
            )
          else
            l,
      ],
    );
    _emit();
  }

  @override
  Future<void> setSwitch(String id, bool on) async {
    await _later();
    _home = _home.copyWith(switches: [for (final s in _home.switches) s.id == id ? s.copyWith(isOn: on) : s]);
    _emit();
  }

  @override
  Future<void> setClimateTarget(String id, double target) async {
    await _later();
    _home = _home.copyWith(
      climates: [
        for (final c in _home.climates)
          if (c.id == id) _withTarget(c, c.clampTarget(target)) else c,
      ],
    );
    _emit();
  }

  ClimateDevice _withTarget(ClimateDevice c, double target) {
    _setpoints.putIfAbsent(c.id, () => {})[c.mode] = target;
    return c.copyWith(targetTemp: target);
  }

  @override
  Future<void> setClimateMode(String id, ClimateMode mode) async {
    await _later();
    _home = _home.copyWith(
      climates: [
        for (final c in _home.climates)
          if (c.id == id) _withMode(c, mode) else c,
      ],
    );
    _emit();
  }

  ClimateDevice _withMode(ClimateDevice c, ClimateMode mode) {
    final memory = _setpoints.putIfAbsent(c.id, () => {});
    memory[c.mode] = c.targetTemp;
    final defaults = {
      ClimateMode.comfort: 21.0,
      ClimateMode.eco: 18.0,
      ClimateMode.away: 8.0,
      ClimateMode.off: c.targetTemp,
    };
    final target = memory[mode] ?? defaults[mode]!;
    return c.copyWith(mode: mode, targetTemp: target, isHeating: mode == ClimateMode.off ? false : null);
  }

  @override
  Future<void> setCoverPosition(String id, int position) async {
    await _later();
    _coverTargets[id] = position.clamp(0, 100);
    _updateCoverMotion();
    _emit();
  }

  @override
  Future<void> coverCommand(String id, CoverCommand command) async {
    switch (command) {
      case CoverCommand.open:
        return setCoverPosition(id, 100);
      case CoverCommand.close:
        return setCoverPosition(id, 0);
      case CoverCommand.stop:
        await _later();
        _coverTargets.remove(id);
        _updateCoverMotion();
        _emit();
    }
  }

  void _updateCoverMotion() {
    _home = _home.copyWith(
      covers: [
        for (final c in _home.covers)
          c.copyWith(
            motion: switch (_coverTargets[c.id]) {
              null => CoverMotion.idle,
              final t when t > c.position => CoverMotion.opening,
              final t when t < c.position => CoverMotion.closing,
              _ => CoverMotion.idle,
            },
          ),
      ],
    );
  }

  @override
  Future<void> setComputerPower(String id, bool on) async {
    await _later();
    _computerBusy[id] = DateTime.now();
    _home = _home.copyWith(
      computers: [
        for (final c in _home.computers)
          if (c.id == id) c.copyWith(state: on ? PowerState.starting : PowerState.stopping) else c,
      ],
    );
    _emit();
  }

  @override
  Future<void> mediaCommand(String id, MediaCommand command) async {
    await _later();
    _home = _home.copyWith(media: [for (final m in _home.media) m.id == id ? m.applied(command) : m]);
    _emit();
  }

  @override
  Future<void> vacuumCommand(String id, VacuumCommand command) async {
    await _later();
    _home = _home.copyWith(
      vacuums: [
        for (final v in _home.vacuums)
          if (v.id == id)
            v.copyWith(
              state: switch (command) {
                VacuumCommand.start => VacuumState.cleaning,
                VacuumCommand.pause => VacuumState.paused,
                VacuumCommand.returnHome => VacuumState.returning,
              },
            )
          else
            v,
      ],
    );
    if (command == VacuumCommand.returnHome) {
      _vacuumReturn[id] = 4;
    } else {
      _vacuumReturn.remove(id);
    }
    _emit();
  }

  @override
  Future<void> triggerEntity(String entityId) async {
    throw const BackendException('Disponible uniquement avec Home Assistant.');
  }

  @override
  Future<void> activateScene(String id) async {
    await _later();
    final scene = _home.scenes.where((s) => s.id == id).firstOrNull;
    if (scene == null) throw const BackendException('Scène introuvable');
    _applyScene(scene.kind);
    _emit();
  }

  void _applyScene(SceneKind kind) {
    LightDevice light(LightDevice l, bool on, [double? b]) => l.copyWith(isOn: on, brightness: b);
    void covers(int position, {String? room}) {
      for (final c in _home.covers) {
        if (room == null || c.roomId == room) _coverTargets[c.id] = position;
      }
    }

    void climates(ClimateMode mode) {
      _home = _home.copyWith(climates: [for (final c in _home.climates) _withMode(c, mode)]);
    }

    switch (kind) {
      case SceneKind.cosy:
        _home = _home.copyWith(
          lights: [
            for (final l in _home.lights)
              switch (l.id) {
                'light.salon_lampe' => light(l, true, 0.55),
                'light.salon_led' => light(l, true, 0.35),
                'light.salon_plafond' => light(l, false),
                _ => l,
              },
          ],
        );
        covers(0, room: 'salon');
        climates(ClimateMode.comfort);
      case SceneKind.movie:
        _home = _home.copyWith(
          lights: [for (final l in _home.lights) l.roomId == 'salon' ? light(l, l.id == 'light.salon_led', 0.15) : l],
          media: [for (final m in _home.media) m.kind == MediaKind.tv ? m.copyWith(isOn: true, isPlaying: true) : m],
        );
        covers(0, room: 'salon');
      case SceneKind.night:
        _home = _home.copyWith(
          lights: [for (final l in _home.lights) light(l, false)],
          switches: [for (final s in _home.switches) s.kind == SwitchKind.coffee ? s.copyWith(isOn: false) : s],
          media: [for (final m in _home.media) m.applied(MediaCommand.turnOff)],
        );
        covers(0);
        climates(ClimateMode.eco);
      case SceneKind.morning:
        _home = _home.copyWith(
          lights: [for (final l in _home.lights) l.roomId == 'cuisine' ? light(l, true, 0.9) : l],
          switches: [for (final s in _home.switches) s.kind == SwitchKind.coffee ? s.copyWith(isOn: true) : s],
        );
        covers(100);
        climates(ClimateMode.comfort);
      case SceneKind.away:
        _home = _home.copyWith(
          lights: [for (final l in _home.lights) light(l, false)],
          switches: [for (final s in _home.switches) s.copyWith(isOn: false)],
        );
        climates(ClimateMode.away);
      case SceneKind.generic:
        break;
    }
    _updateCoverMotion();
  }

  /// Fait avancer la simulation d'un pas (volets, températures, ordinateurs).
  void simulateStep() {
    var changed = false;

    if (_coverTargets.isNotEmpty) {
      final covers = <CoverDevice>[];
      for (final c in _home.covers) {
        final target = _coverTargets[c.id];
        if (target == null) {
          covers.add(c);
          continue;
        }
        final delta = target - c.position;
        final next = delta.abs() <= 6 ? target : c.position + (delta.sign * 6);
        if (next == target) _coverTargets.remove(c.id);
        covers.add(c.copyWith(position: next));
        changed = true;
      }
      _home = _home.copyWith(covers: covers);
      _updateCoverMotion();
    }

    final climates = <ClimateDevice>[];
    for (final c in _home.climates) {
      final current = c.currentTemp ?? c.targetTemp;
      double next;
      if (c.mode == ClimateMode.off) {
        next = current > 16 ? current - 0.01 : current;
      } else if (current < c.targetTemp - 0.05) {
        next = current + 0.04;
      } else if (current > c.targetTemp + 0.05) {
        next = current - 0.02;
      } else {
        next = current;
      }
      final heating = c.mode != ClimateMode.off && next < c.targetTemp - 0.1;
      final rounded = (next * 100).round() / 100;
      if ((rounded * 10).round() != (current * 10).round() || heating != c.isHeating) changed = true;
      climates.add(c.copyWith(currentTemp: rounded, isHeating: heating));
    }
    _home = _home.copyWith(climates: climates);

    if (_computerBusy.isNotEmpty) {
      final now = DateTime.now();
      final done = _computerBusy.entries
          .where((e) => now.difference(e.value) > const Duration(seconds: 5))
          .map((e) => e.key)
          .toSet();
      if (done.isNotEmpty) {
        _computerBusy.removeWhere((k, _) => done.contains(k));
        _home = _home.copyWith(
          computers: [
            for (final c in _home.computers)
              if (done.contains(c.id))
                c.copyWith(state: c.state == PowerState.starting ? PowerState.on : PowerState.off)
              else
                c,
          ],
        );
        changed = true;
      }
    }

    // Aspirateur : la batterie se vide en nettoyage, se recharge à la base.
    if (_home.vacuums.isNotEmpty) {
      final vacuums = <VacuumDevice>[];
      for (final v in _home.vacuums) {
        var next = v;
        final battery = v.battery ?? 100;
        if (v.state == VacuumState.cleaning) {
          next = battery <= 20 ? v.copyWith(state: VacuumState.returning) : v.copyWith(battery: battery - 1);
          if (battery <= 20) _vacuumReturn[v.id] = 4;
        } else if (v.state == VacuumState.returning) {
          final left = (_vacuumReturn[v.id] ?? 1) - 1;
          if (left <= 0) {
            _vacuumReturn.remove(v.id);
            next = v.copyWith(state: VacuumState.docked);
          } else {
            _vacuumReturn[v.id] = left;
          }
        } else if (v.state == VacuumState.docked && battery < 100) {
          next = v.copyWith(battery: battery + 1);
        }
        if (!identical(next, v)) changed = true;
        vacuums.add(next);
      }
      _home = _home.copyWith(vacuums: vacuums);
    }

    if (changed) _emit();
  }
}

/// État initial de la maison de démonstration.
HomeState demoHome() => const HomeState(
  rooms: [
    Room(id: 'salon', name: 'Salon', kind: RoomKind.living),
    Room(id: 'cuisine', name: 'Cuisine', kind: RoomKind.kitchen),
    Room(id: 'chambre', name: 'Chambre', kind: RoomKind.bedroom),
    Room(id: 'bureau', name: 'Bureau', kind: RoomKind.office),
    Room(id: 'sdb', name: 'Salle de bain', kind: RoomKind.bathroom),
    Room(id: 'entree', name: 'Entrée', kind: RoomKind.entrance),
  ],
  lights: [
    LightDevice(id: 'light.salon_plafond', name: 'Plafonnier', roomId: 'salon', isOn: true, brightness: 0.8),
    LightDevice(id: 'light.salon_lampe', name: 'Lampe de lecture', roomId: 'salon', isOn: true, brightness: 0.45),
    LightDevice(id: 'light.salon_led', name: 'Ruban LED', roomId: 'salon', brightness: 0.35),
    LightDevice(id: 'light.cuisine_suspensions', name: 'Suspensions', roomId: 'cuisine', brightness: 1),
    LightDevice(id: 'light.cuisine_plan', name: 'Plan de travail', roomId: 'cuisine', isOn: true, dimmable: false),
    LightDevice(id: 'light.chambre_chevet', name: 'Chevet', roomId: 'chambre', brightness: 0.3),
    LightDevice(id: 'light.bureau_lampe', name: 'Lampe de bureau', roomId: 'bureau', isOn: true, brightness: 0.7),
    LightDevice(id: 'light.sdb_miroir', name: 'Miroir', roomId: 'sdb', brightness: 0.9),
    LightDevice(id: 'light.entree_applique', name: 'Applique', roomId: 'entree', dimmable: false),
  ],
  climates: [
    ClimateDevice(
      id: 'climate.salon',
      name: 'Salon',
      roomId: 'salon',
      currentTemp: 20.6,
      targetTemp: 21.5,
      isHeating: true,
      humidity: 46,
    ),
    ClimateDevice(
      id: 'climate.chambre',
      name: 'Chambre',
      roomId: 'chambre',
      currentTemp: 18.3,
      targetTemp: 18.0,
      mode: ClimateMode.eco,
      humidity: 51,
    ),
    ClimateDevice(id: 'climate.bureau', name: 'Bureau', roomId: 'bureau', currentTemp: 19.8, targetTemp: 20.0),
    ClimateDevice(
      id: 'climate.sdb',
      name: 'Salle de bain',
      roomId: 'sdb',
      currentTemp: 21.4,
      targetTemp: 22.0,
      humidity: 63,
    ),
  ],
  covers: [
    CoverDevice(id: 'cover.salon_baie', name: 'Baie vitrée', roomId: 'salon', position: 100),
    CoverDevice(id: 'cover.salon_fenetre', name: 'Fenêtre', roomId: 'salon', position: 65),
    CoverDevice(id: 'cover.chambre', name: 'Fenêtre', roomId: 'chambre', position: 0),
    CoverDevice(id: 'cover.bureau', name: 'Velux', roomId: 'bureau', position: 40),
    CoverDevice(id: 'cover.cuisine', name: 'Fenêtre', roomId: 'cuisine', position: 100),
  ],
  switches: [
    SwitchDevice(id: 'switch.enceinte', name: 'Enceinte', roomId: 'salon', isOn: true, kind: SwitchKind.speaker),
    SwitchDevice(id: 'switch.cafe', name: 'Machine à café', roomId: 'cuisine', kind: SwitchKind.coffee),
    SwitchDevice(id: 'switch.ventilo', name: 'Ventilateur', roomId: 'chambre', kind: SwitchKind.fan),
  ],
  computers: [
    ComputerDevice(
      id: 'pc.demo_gamer',
      name: 'PC du bureau',
      state: PowerState.off,
      detail: '192.168.1.42',
      canShutdown: true,
    ),
    ComputerDevice(
      id: 'pc.demo_nas',
      name: 'NAS',
      state: PowerState.on,
      detail: '192.168.1.10',
      canShutdown: true,
      isServer: true,
    ),
  ],
  vacuums: [
    VacuumDevice(
      id: 'vacuum.robot',
      name: 'Robot aspirateur',
      roomId: 'salon',
      state: VacuumState.docked,
      battery: 100,
    ),
  ],
  media: [
    MediaDevice(
      id: 'media_player.tele',
      name: 'Télévision',
      roomId: 'salon',
      kind: MediaKind.tv,
      volume: 0.25,
      title: 'Netflix',
      canTurnOn: true,
      canTurnOff: true,
      canVolume: true,
      canMute: true,
      canPlayPause: true,
    ),
  ],
  scenes: [
    SceneItem(id: 'scene.cosy', name: 'Soirée cosy', kind: SceneKind.cosy),
    SceneItem(id: 'scene.cinema', name: 'Cinéma', kind: SceneKind.movie),
    SceneItem(id: 'scene.nuit', name: 'Bonne nuit', kind: SceneKind.night),
    SceneItem(id: 'scene.reveil', name: 'Réveil', kind: SceneKind.morning),
    SceneItem(id: 'scene.depart', name: 'Départ', kind: SceneKind.away),
  ],
  outdoorTemp: 8.5,
  weather: WeatherKind.partlyCloudy,
  energyWeek: [5.8, 6.4, 7.9, 6.1, 8.7, 9.6, 4.2],
);
