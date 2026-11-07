import 'dart:async';
import 'dart:io';

import 'wake_on_lan.dart';

const bool netToolsSupported = true;

/// Ports testés pour savoir si une machine répond (RDP, SMB, SSH, NetBIOS, HTTP).
const _probePorts = [3389, 445, 22, 139, 80, 5900];

/// Envoie le paquet magique en diffusion UDP sur le réseau local.
Future<void> sendMagicPacket(String mac, {String broadcast = '255.255.255.255', int port = 9}) async {
  final packet = buildMagicPacket(mac);
  final target =
      InternetAddress.tryParse(broadcast.trim().isEmpty ? '255.255.255.255' : broadcast.trim()) ??
      InternetAddress('255.255.255.255');
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.broadcastEnabled = true;
    // Envoi sur les ports 9 et 7 avec quelques répétitions : l'UDP n'est pas fiable.
    for (var attempt = 0; attempt < 3; attempt++) {
      socket.send(packet, target, port);
      if (port != 7) socket.send(packet, target, 7);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  } finally {
    socket.close();
  }
}

/// Indique si l'hôte répond. Une connexion refusée prouve aussi que la machine est allumée.
Future<bool> isHostReachable(String host, {Duration timeout = const Duration(milliseconds: 900)}) async {
  if (host.trim().isEmpty) return false;
  final attempts = _probePorts.map((port) async {
    try {
      final socket = await Socket.connect(host.trim(), port, timeout: timeout);
      socket.destroy();
      return true;
    } on SocketException catch (e) {
      final code = e.osError?.errorCode;
      // ECONNREFUSED (111 sous Linux/Android) : la machine a répondu.
      return code == 111 || code == 61 || code == 10061;
    } catch (_) {
      return false;
    }
  });
  final results = await Future.wait(attempts);
  return results.any((ok) => ok);
}

/// Appelle une URL locale (ex. service d'extinction à distance installé sur le PC).
Future<void> sendHttpCommand(String url, {String method = 'POST'}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.openUrl(method, Uri.parse(url.trim()));
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    if (response.statusCode >= 400) {
      throw HttpException('Réponse ${response.statusCode}', uri: Uri.parse(url));
    }
  } finally {
    client.close(force: true);
  }
}
