import '../models/home.dart';

enum LinkState { connecting, online, offline }

/// État de la liaison avec le système domotique.
class LinkStatus {
  const LinkStatus(this.state, [this.message]);

  final LinkState state;
  final String? message;

  static const connecting = LinkStatus(LinkState.connecting);
  static const online = LinkStatus(LinkState.online);
}

/// Contrat commun à toutes les sources domotiques (démo, Home Assistant…).
///
/// Un backend publie des photographies complètes de la maison via [states]
/// et exécute les commandes demandées par l'interface.
abstract class HomeBackend {
  /// Nom lisible affiché dans l'interface (« Démo », « Home Assistant »).
  String get label;

  Stream<HomeState> get states;

  Stream<LinkStatus> get status;

  Future<void> connect();

  Future<void> dispose();

  Future<void> setLight(String id, {bool? on, double? brightness});

  Future<void> setSwitch(String id, bool on);

  Future<void> setClimateTarget(String id, double target);

  Future<void> setClimateMode(String id, ClimateMode mode);

  Future<void> setCoverPosition(String id, int position);

  Future<void> coverCommand(String id, CoverCommand command);

  Future<void> setComputerPower(String id, bool on);

  Future<void> vacuumCommand(String id, VacuumCommand command);

  /// Télé ou enceinte : marche / arrêt, lecture, volume.
  Future<void> mediaCommand(String id, MediaCommand command);

  /// Déclenche une entité d'action (bouton, script, interrupteur à éteindre),
  /// par exemple le bouton d'extinction d'un NAS.
  Future<void> triggerEntity(String entityId);

  Future<void> activateScene(String id);
}

/// Erreur affichable telle quelle à l'utilisateur.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}
