import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as ch;
import 'package:honey_badger_chess/move_codec.dart';

void main() {
  group('resolveMove', () {
    test('findet einen legalen Standardzug', () {
      final game = ch.Chess();
      final move = resolveMove(game, 'e2', 'e4');
      expect(move, isNotNull);
      expect(move!.fromAlgebraic, 'e2');
      expect(move.toAlgebraic, 'e4');
    });

    test('gibt null zurueck fuer ein leeres Feld', () {
      final game = ch.Chess();
      final move = resolveMove(game, 'e4', 'e5');
      expect(move, isNull);
    });

    test('gibt null zurueck fuer ein illegales Ziel', () {
      final game = ch.Chess();
      // Der Bauer auf e2 kann nicht nach e5 ziehen.
      final move = resolveMove(game, 'e2', 'e5');
      expect(move, isNull);
    });

    test('waehlt bei Bauernumwandlung die Dame', () {
      // Weisser Bauer kurz vor der Umwandlung, schwarzer Koenig weit weg.
      final game = ch.Chess.fromFEN('7k/4P3/8/8/8/8/8/7K w - - 0 1');
      final move = resolveMove(game, 'e7', 'e8');
      expect(move, isNotNull);
      expect(move!.promotion, ch.Chess.QUEEN);
    });
  });

  group('encodeMovePayload / decodeMovePayload', () {
    test('Round-Trip liefert die urspruenglichen Felder', () {
      final payload = encodeMovePayload('g1', 'f3');
      final decoded = decodeMovePayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!.from, 'g1');
      expect(decoded.to, 'f3');
    });

    test('kaputtes JSON ergibt null statt einer Exception', () {
      expect(decodeMovePayload('{nicht valides json'), isNull);
    });

    test('falscher Nachrichtentyp wird ignoriert', () {
      final decoded = decodeMovePayload('{"t":"chat","text":"hallo"}');
      expect(decoded, isNull);
    });

    test('fehlendes Feld ergibt null', () {
      final decoded = decodeMovePayload('{"t":"move","from":"e2"}');
      expect(decoded, isNull);
    });
  });

  group('encodeResignPayload / isResignPayload', () {
    test('Round-Trip erkennt eine Aufgabe', () {
      final payload = encodeResignPayload();
      expect(isResignPayload(payload), isTrue);
    });

    test('ein Zug ist keine Aufgabe', () {
      final payload = encodeMovePayload('e2', 'e4');
      expect(isResignPayload(payload), isFalse);
    });

    test('kaputtes JSON ergibt false statt einer Exception', () {
      expect(isResignPayload('{nicht valides json'), isFalse);
    });
  });
}
