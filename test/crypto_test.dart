import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/crypto_service.dart';

void main() {
  test('Alice und Bob koennen verschluesselt kommunizieren', () async {
    final alice = CryptoService();
    final bob = CryptoService();

    await alice.generateKeyPair();
    await bob.generateKeyPair();

    // Oeffentliche Schluessel tauschen
    final alicePub = await alice.myPublicKeyBytes();
    final bobPub = await bob.myPublicKeyBytes();

    // Beide leiten dasselbe Geheimnis ab
    await alice.deriveSharedKey(bobPub);
    await bob.deriveSharedKey(alicePub);

    expect(alice.isReady, true);
    expect(bob.isReady, true);

    const message = 'Treffen um 18 Uhr. Honey Badger gibt nie auf.';

    final encrypted = await alice.encrypt(message);
    final decrypted = await bob.decrypt(encrypted);

    // Bob bekommt exakt den Originaltext
    expect(decrypted, message);
    // Der verschluesselte Text enthaelt den Klartext NICHT
    expect(encrypted.contains('Treffen'), false);
  });

  test('Ein Lauscher mit falschem Schluessel kann NICHT mitlesen', () async {
    final alice = CryptoService();
    final bob = CryptoService();
    final eve = CryptoService();

    await alice.generateKeyPair();
    await bob.generateKeyPair();
    await eve.generateKeyPair();

    // Alice spricht mit Bob
    await alice.deriveSharedKey(await bob.myPublicKeyBytes());
    // Eve versucht sich reinzudraengen
    await eve.deriveSharedKey(await alice.myPublicKeyBytes());

    final encrypted = await alice.encrypt('Geheime Nachricht');

    // Eve kann nicht entschluesseln -> Exception erwartet
    await expectLater(eve.decrypt(encrypted), throwsA(anything));
  });
}
