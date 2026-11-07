// Version sans `dart:io` (aperçu web) : les fonctions réseau locales sont indisponibles.

const bool netToolsSupported = false;

Future<void> sendMagicPacket(String mac, {String broadcast = '255.255.255.255', int port = 9}) {
  throw UnsupportedError('Le réveil réseau n’est disponible que sur la tablette.');
}

Future<bool> isHostReachable(String host, {Duration timeout = const Duration(milliseconds: 900)}) async => false;

Future<void> sendHttpCommand(String url, {String method = 'POST'}) {
  throw UnsupportedError('Commande indisponible dans l’aperçu web.');
}
