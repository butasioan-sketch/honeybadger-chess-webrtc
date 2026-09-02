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
    alice.setRole(isHost: true);
    bob.setRole(isHost: false);

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
    alice.setRole(isHost: true);
    eve.setRole(isHost: false);

    final encrypted = await alice.encrypt('Geheime Nachricht');

    // Eve kann nicht entschluesseln -> Exception erwartet
    await expectLater(eve.decrypt(encrypted), throwsA(anything));
  });

  group('Replay-Schutz (Audit S2)', () {
    Future<(CryptoService, CryptoService)> connectedPair() async {
      final alice = CryptoService();
      final bob = CryptoService();
      await alice.generateKeyPair();
      await bob.generateKeyPair();
      await alice.deriveSharedKey(await bob.myPublicKeyBytes());
      await bob.deriveSharedKey(await alice.myPublicKeyBytes());
      alice.setRole(isHost: true);
      bob.setRole(isHost: false);
      return (alice, bob);
    }

    test(
      'ein alter, wiederholt gesendeter Geheimtext wird abgelehnt',
      () async {
        final (alice, bob) = await connectedPair();

        final first = await alice.encrypt('Zug 1');
        expect(await bob.decrypt(first), 'Zug 1');

        final second = await alice.encrypt('Zug 2');
        expect(await bob.decrypt(second), 'Zug 2');

        // Ein Angreifer spielt den ersten (laengst verarbeiteten) Geheimtext
        // erneut ein - Bobs erwartete Sequenznummer ist inzwischen weiter.
        await expectLater(bob.decrypt(first), throwsA(anything));
      },
    );

    test('eine uebersprungene Nachricht wird abgelehnt', () async {
      final (alice, bob) = await connectedPair();

      await alice.encrypt('Zug 1'); // wird nie an Bob geliefert
      final second = await alice.encrypt('Zug 2');

      // Bob bekommt Zug 2, ohne Zug 1 gesehen zu haben - Sequenzluecke.
      await expectLater(bob.decrypt(second), throwsA(anything));
    });

    test(
      'eine an den Absender zurueckgespiegelte eigene Nachricht wird abgelehnt',
      () async {
        final (alice, bob) = await connectedPair();

        final fromAlice = await alice.encrypt('Hallo Bob');
        // Ein Angreifer spiegelt Alices eigenen Geheimtext an Alice zurueck.
        // Trotz identischem symmetrischen Schluessel muss das scheitern,
        // weil die AAD die Senderichtung (Host) traegt und Alice als Host
        // nur Nachrichten von der Gast-Richtung akzeptiert.
        await expectLater(alice.decrypt(fromAlice), throwsA(anything));
      },
    );

    test('encrypt/decrypt ohne setRole werfen einen klaren Fehler', () async {
      final noRole = CryptoService();
      await noRole.generateKeyPair();
      await expectLater(noRole.encrypt('x'), throwsA(isA<StateError>()));
      await expectLater(noRole.decrypt('x'), throwsA(isA<StateError>()));
    });
  });
}
