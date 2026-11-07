import 'dart:typed_data';

final _macPattern = RegExp(r'^([0-9A-Fa-f]{2}[:\-.]?){5}[0-9A-Fa-f]{2}$');

/// Vérifie le format d'une adresse MAC (`AA:BB:CC:DD:EE:FF`, `AA-BB-…` ou `AABBCC…`).
bool isValidMac(String mac) => _macPattern.hasMatch(mac.trim());

/// Convertit une adresse MAC en 6 octets.
Uint8List parseMac(String mac) {
  final hex = mac.trim().replaceAll(RegExp(r'[:\-.]'), '');
  if (!isValidMac(mac) || hex.length != 12) {
    throw FormatException('Adresse MAC invalide : $mac');
  }
  return Uint8List.fromList([for (var i = 0; i < 12; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
}

/// Construit le « paquet magique » Wake-on-LAN : 6 × 0xFF puis 16 fois la MAC.
Uint8List buildMagicPacket(String mac) {
  final macBytes = parseMac(mac);
  final packet = Uint8List(6 + 16 * 6);
  packet.fillRange(0, 6, 0xFF);
  for (var i = 0; i < 16; i++) {
    packet.setRange(6 + i * 6, 12 + i * 6, macBytes);
  }
  return packet;
}
