import 'package:flutter_test/flutter_test.dart';
import 'package:sdash/data/network/wake_on_lan.dart';

void main() {
  group('adresse MAC', () {
    test('accepte les formats courants', () {
      expect(isValidMac('AA:BB:CC:DD:EE:FF'), isTrue);
      expect(isValidMac('aa-bb-cc-dd-ee-ff'), isTrue);
      expect(isValidMac('aabbccddeeff'), isTrue);
      expect(isValidMac(' 01:23:45:67:89:ab '), isTrue);
    });

    test('refuse les adresses incorrectes', () {
      expect(isValidMac(''), isFalse);
      expect(isValidMac('AA:BB:CC:DD:EE'), isFalse);
      expect(isValidMac('GG:BB:CC:DD:EE:FF'), isFalse);
      expect(() => parseMac('pas une mac'), throwsFormatException);
    });
  });

  test('paquet magique : 6 × 0xFF puis 16 répétitions de la MAC', () {
    final packet = buildMagicPacket('01:23:45:67:89:AB');
    expect(packet.length, 102);
    expect(packet.sublist(0, 6), everyElement(0xFF));
    for (var i = 0; i < 16; i++) {
      expect(packet.sublist(6 + i * 6, 12 + i * 6), [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB]);
    }
  });
}
