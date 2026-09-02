import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/crypto_service.dart';

/// Baut ein handschlags-bereites Paar (Alice=Host, Bob=Gast) mit
/// Testschluesseln und den gegebenen SDP-Platzhaltern.
Future<(CryptoService, CryptoService)> _connectedPair({
  String hostSdp = 'v=0\r\no=- 1 1 IN IP4 0.0.0.0\r\n... offer ...',
  String guestSdp = 'v=0\r\no=- 2 2 IN IP4 0.0.0.0\r\n... answer ...',
}) async {
  final alice = CryptoService();
  final bob = CryptoService();
  await alice.generateKeyPair();
  await bob.generateKeyPair();
  alice.setRole(isHost: true);
  bob.setRole(isHost: false);
  final alicePub = await alice.myPublicKeyBytes();
  final bobPub = await bob.myPublicKeyBytes();
  await alice.deriveSharedKey(
    remotePublicKeyBytes: bobPub,
    myPublicKeyBytes: alicePub,
    mySdp: hostSdp,
    remoteSdp: guestSdp,
  );
  await bob.deriveSharedKey(
    remotePublicKeyBytes: alicePub,
    myPublicKeyBytes: bobPub,
    mySdp: guestSdp,
    remoteSdp: hostSdp,
  );
  return (alice, bob);
}

void main() {
  test('Alice und Bob koennen verschluesselt kommunizieren', () async {
    final (alice, bob) = await _connectedPair();

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
    alice.setRole(isHost: true);
    eve.setRole(isHost: false);

    const hostSdp = 'offer-sdp';
    const guestSdp = 'answer-sdp';
    final alicePub = await alice.myPublicKeyBytes();
    final bobPub = await bob.myPublicKeyBytes();
    final evePub = await eve.myPublicKeyBytes();

    // Alice spricht mit Bob ...
    await alice.deriveSharedKey(
      remotePublicKeyBytes: bobPub,
      myPublicKeyBytes: alicePub,
      mySdp: hostSdp,
      remoteSdp: guestSdp,
    );
    // ... aber Eve haengt sich mit ihrem EIGENEN Schluesselpaar rein
    // (nicht Bobs) und leitet dadurch ein anderes ECDH-Geheimnis ab.
    await eve.deriveSharedKey(
      remotePublicKeyBytes: alicePub,
      myPublicKeyBytes: evePub,
      mySdp: guestSdp,
      remoteSdp: hostSdp,
    );

    final encrypted = await alice.encrypt('Geheime Nachricht');

    // Eve kann nicht entschluesseln -> Exception erwartet
    await expectLater(eve.decrypt(encrypted), throwsA(anything));
  });

  group('MITM-Fingerprint (Audit S1)', () {
    test('Host und Gast leiten denselben Fingerprint ab', () async {
      final (alice, bob) = await _connectedPair();

      expect(alice.fingerprint, isNotNull);
      expect(alice.fingerprint, bob.fingerprint);
      expect(RegExp(r'^\d{6}$').hasMatch(alice.fingerprint!), isTrue);
    });

    test('ein veraendertes Transkript (manipulierte SDP) ergibt einen anderen '
        'Fingerprint und einen anderen Schluessel', () async {
      final alice = CryptoService();
      final bob = CryptoService();
      await alice.generateKeyPair();
      await bob.generateKeyPair();
      alice.setRole(isHost: true);
      bob.setRole(isHost: false);
      final alicePub = await alice.myPublicKeyBytes();
      final bobPub = await bob.myPublicKeyBytes();

      // Ein Mittelsmann veraendert die Angebots-SDP unterwegs: Alice hat
      // die Original-SDP gesendet, Bob hat eine andere empfangen.
      await alice.deriveSharedKey(
        remotePublicKeyBytes: bobPub,
        myPublicKeyBytes: alicePub,
        mySdp: 'original-angebot',
        remoteSdp: 'antwort',
      );
      await bob.deriveSharedKey(
        remotePublicKeyBytes: alicePub,
        myPublicKeyBytes: bobPub,
        mySdp: 'antwort',
        remoteSdp: 'manipuliertes-angebot',
      );

      expect(alice.fingerprint, isNot(bob.fingerprint));
      final encrypted = await alice.encrypt('Zug');
      await expectLater(bob.decrypt(encrypted), throwsA(anything));
    });
  });

  group('Replay-Schutz (Audit S2)', () {
    test(
      'ein alter, wiederholt gesendeter Geheimtext wird abgelehnt',
      () async {
        final (alice, bob) = await _connectedPair();

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
      final (alice, bob) = await _connectedPair();

      await alice.encrypt('Zug 1'); // wird nie an Bob geliefert
      final second = await alice.encrypt('Zug 2');

      // Bob bekommt Zug 2, ohne Zug 1 gesehen zu haben - Sequenzluecke.
      await expectLater(bob.decrypt(second), throwsA(anything));
    });

    test(
      'eine an den Absender zurueckgespiegelte eigene Nachricht wird abgelehnt',
      () async {
        final (alice, bob) = await _connectedPair();

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
