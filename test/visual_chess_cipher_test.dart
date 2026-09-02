import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/visual_chess_cipher.dart';

const _pw = 'test-passwort'; // >= minPassphraseLength (8), fuer alle Tests

void main() {
  group('encodeTextAsMoves / decodeMovesAsText', () {
    test('Round-Trip liefert den urspruenglichen Text zurueck', () async {
      const text = 'Der Honigdachs schlaegt um Mitternacht zu.';
      const passphrase = 'sehr-geheim-123';
      final moves = await encodeTextAsMoves(text, passphrase);
      expect(moves, isNotEmpty);
      final decoded = await decodeMovesAsText(moves, passphrase);
      expect(decoded, text);
    });

    test('leerer Text laesst sich verschluesseln und entschluesseln', () async {
      final moves = await encodeTextAsMoves('', _pw);
      final decoded = await decodeMovesAsText(moves, _pw);
      expect(decoded, '');
    });

    test('Unicode/Sonderzeichen ueberleben den Round-Trip', () async {
      const text = 'Schach♞ & Mätt – "Zitat" 🦡';
      final moves = await encodeTextAsMoves(text, _pw);
      final decoded = await decodeMovesAsText(moves, _pw);
      expect(decoded, text);
    });

    test('jeder erzeugte Zug ist ein gueltiges UCI-artiges Format', () async {
      final moves = await encodeTextAsMoves('Testnachricht', _pw);
      for (final m in moves) {
        expect(
          RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(m),
          isTrue,
          reason: 'unerwartetes Zugformat: $m',
        );
      }
    });

    test('zwei Verschluesselungen derselben Nachricht ergeben wegen '
        'zufaelligem Salz unterschiedliche Zugfolgen', () async {
      final a = await encodeTextAsMoves('gleicher text', _pw);
      final b = await encodeTextAsMoves('gleicher text', _pw);
      expect(a, isNot(equals(b)));
    });

    test('falsches Passwort wirft VisualChessCipherError statt falschem '
        'Klartext', () async {
      final moves = await encodeTextAsMoves(
        'geheime Nachricht',
        'geheim-richtig',
      );
      expect(
        () => decodeMovesAsText(moves, 'geheim-falsch'),
        throwsA(isA<VisualChessCipherError>()),
      );
    });

    test('manipulierte Zugfolge wirft VisualChessCipherError', () async {
      final moves = await encodeTextAsMoves('hallo', _pw);
      final tampered = [...moves];
      tampered[0] = 'a1a1'; // kein legaler Eroeffnungszug
      expect(
        () => decodeMovesAsText(tampered, _pw),
        throwsA(isA<VisualChessCipherError>()),
      );
    });

    test('leere Zugliste wirft VisualChessCipherError beim Decode', () async {
      expect(
        () => decodeMovesAsText([], _pw),
        throwsA(isA<VisualChessCipherError>()),
      );
    });

    test('~300 Zeichen lange Nachricht kodiert zuverlaessig ohne '
        'Matt/Patt-Abbruch (Endstellungen werden aktiv vermieden)', () async {
      final text = 'Der Honigdachs schlaegt zu. ' * 11; // ~308 Zeichen
      for (var i = 0; i < 5; i++) {
        final moves = await encodeTextAsMoves(text, 'ein-langes-passwort');
        final decoded = await decodeMovesAsText(moves, 'ein-langes-passwort');
        expect(decoded, text);
      }
    });
  });

  group('Passwortlaenge im Core (Audit S5)', () {
    test('encodeTextAsMoves lehnt ein zu kurzes Passwort ab', () async {
      expect(
        () => encodeTextAsMoves('hallo', 'kurz'),
        throwsA(isA<VisualChessCipherError>()),
      );
    });

    test('decodeMovesAsText lehnt ein zu kurzes Passwort ab, bevor es '
        'ueberhaupt Zuege verarbeitet', () async {
      // Eine leere Zugliste wuerde ohnehin einen Fehler werfen (siehe
      // oben) - hier zaehlt, dass die Passwortlaenge zuerst geprueft wird
      // und die Fehlermeldung entsprechend lautet.
      await expectLater(
        decodeMovesAsText([], '1234567'), // 7 Zeichen, zu kurz
        throwsA(
          isA<VisualChessCipherError>().having(
            (e) => e.message,
            'message',
            contains('Passwort zu kurz'),
          ),
        ),
      );
    });

    test(
      'genau minPassphraseLength Zeichen werden akzeptiert (Grenzwert)',
      () async {
        final passphrase = 'a' * minPassphraseLength;
        final moves = await encodeTextAsMoves('grenzwertig', passphrase);
        final decoded = await decodeMovesAsText(moves, passphrase);
        expect(decoded, 'grenzwertig');
      },
    );
  });

  group('Decode-Cap gegen ueberlange Zugliste (Audit S8)', () {
    test(
      'mehr als maxCipherPlies Zuege werden ohne Verarbeitung abgelehnt',
      () async {
        final tooMany = List<String>.generate(
          maxCipherPlies + 1,
          (_) => 'e2e4',
        );
        await expectLater(
          decodeMovesAsText(tooMany, _pw),
          throwsA(isA<VisualChessCipherError>()),
        );
      },
    );
  });
}
