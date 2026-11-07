import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pont vers le code Android natif (voir `MainActivity.kt`).
class SystemBridge {
  static const _channel = MethodChannel('sdash/system');

  /// Empêche la mise en veille de l'écran (tablette murale).
  static Future<void> setKeepScreenOn(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'enabled': enabled});
    } on MissingPluginException {
      // Plateforme sans implémentation native : rien à faire.
    } on PlatformException {
      // Ignoré : fonctionnalité de confort uniquement.
    }
  }

  /// Plein écran immersif (barres système masquées, réapparaissent d'un glissement).
  static Future<void> setImmersive(bool enabled) =>
      SystemChrome.setEnabledSystemUIMode(enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
}
