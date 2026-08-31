import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/visual_chess_cipher.dart';

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
      final moves = await encodeTextAsMoves('', 'pw');
      final decoded = await decodeMovesAsText(moves, 'pw');
      expect(decoded, '');
    });

    test('Unicode/Sonderzeichen ueberleben den Round-Trip', () async {
      const text = 'Schach♞ & Mätt – "Zitat" 🦡';
      final moves = await encodeTextAsMoves(text, 'pw');
      final decoded = await decodeMovesAsText(moves, 'pw');
      expect(decoded, text);
    });

    test('jeder erzeugte Zug ist ein gueltiges UCI-artiges Format', () async {
      final moves = await encodeTextAsMoves('Testnachricht', 'pw');
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
      final a = await encodeTextAsMoves('gleicher text', 'pw');
      final b = await encodeTextAsMoves('gleicher text', 'pw');
      expect(a, isNot(equals(b)));
    });

    test('falsches Passwort wirft VisualChessCipherError statt falschem '
        'Klartext', () async {
      final moves = await encodeTextAsMoves('geheime Nachricht', 'richtig');
      expect(
        () => decodeMovesAsText(moves, 'falsch'),
        throwsA(isA<VisualChessCipherError>()),
      );
    });

    test('manipulierte Zugfolge wirft VisualChessCipherError', () async {
      final moves = await encodeTextAsMoves('hallo', 'pw');
      final tampered = [...moves];
      tampered[0] = 'a1a1'; // kein legaler Eroeffnungszug
      expect(
        () => decodeMovesAsText(tampered, 'pw'),
        throwsA(isA<VisualChessCipherError>()),
      );
    });

    test('leere Zugliste wirft VisualChessCipherError beim Decode', () async {
      expect(
        () => decodeMovesAsText([], 'pw'),
        throwsA(isA<VisualChessCipherError>()),
      );
    });
  });
}
