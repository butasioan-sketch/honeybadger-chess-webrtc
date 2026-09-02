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
      final payload = encodeMovePayload('g1', 'f3', 1);
      final decoded = decodeMovePayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!.from, 'g1');
      expect(decoded.to, 'f3');
      expect(decoded.ply, 1);
    });

    test('kaputtes JSON ergibt null statt einer Exception', () {
      expect(decodeMovePayload('{nicht valides json'), isNull);
    });

    test('falscher Nachrichtentyp wird ignoriert', () {
      final decoded = decodeMovePayload('{"t":"chat","text":"hallo"}');
      expect(decoded, isNull);
    });

    test('fehlendes Feld ergibt null', () {
      final decoded = decodeMovePayload('{"t":"move","from":"e2","ply":1}');
      expect(decoded, isNull);
    });

    test('fehlender ply ergibt null', () {
      final decoded = decodeMovePayload('{"t":"move","from":"e2","to":"e4"}');
      expect(decoded, isNull);
    });

    test('ply als String statt Zahl ergibt null', () {
      final decoded = decodeMovePayload(
        '{"t":"move","from":"e2","to":"e4","ply":"1"}',
      );
      expect(decoded, isNull);
    });

    test('ungueltiges Feldformat (z.B. "e9") ergibt null', () {
      final decoded = decodeMovePayload(
        '{"t":"move","from":"e2","to":"e9","ply":1}',
      );
      expect(decoded, isNull);
    });

    test('feld mit Zusatzzeichen (Injection-Versuch) ergibt null', () {
      final decoded = decodeMovePayload(
        '{"t":"move","from":"e2","to":"e4;drop","ply":1}',
      );
      expect(decoded, isNull);
    });
  });

  group('encodeResignPayload / isResignPayload', () {
    test('Round-Trip erkennt eine Aufgabe', () {
      final payload = encodeResignPayload();
      expect(isResignPayload(payload), isTrue);
    });

    test('ein Zug ist keine Aufgabe', () {
      final payload = encodeMovePayload('e2', 'e4', 1);
      expect(isResignPayload(payload), isFalse);
    });

    test('kaputtes JSON ergibt false statt einer Exception', () {
      expect(isResignPayload('{nicht valides json'), isFalse);
    });
  });

  group('canAcceptRemoteMove (Audit S3: Zugrecht-Pruefung)', () {
    test('lehnt ab, wenn es die eigene Zugseite ist', () {
      // Host (Weiss) hat noch nicht gezogen - _game.turn ist Weiss, also
      // ist es amWhite=true's eigener Zug, kein gueltiger Remote-Zug.
      final game = ch.Chess();
      final ok = canAcceptRemoteMove(
        game: game,
        amWhite: true,
        gameEnded: false,
        ply: 1,
      );
      expect(ok, isFalse);
    });

    test('erlaubt den naechsten Zug der Gegenseite', () {
      final game = ch.Chess(); // Weiss am Zug, history.length == 0
      final ok = canAcceptRemoteMove(
        game: game,
        amWhite: false, // ich bin Schwarz, Weiss (Gegner) ist am Zug
        gameEnded: false,
        ply: 1,
      );
      expect(ok, isTrue);
    });

    test(
      'lehnt einen zweiten Remote-Zug in Folge ab, bevor ich selbst gezogen habe',
      () {
        // Nach einem bereits angewendeten Zug (Weiss e2-e4) ist Schwarz am
        // Zug. Bin ich Schwarz, ist genau das jetzt MEIN Zug - ein zweiter
        // "Remote"-Zug direkt hintereinander (der Kern des S3-Cheat-Bugs:
        // der Gegner zieht doppelt / fuer beide Farben) muss abgelehnt
        // werden, weil `!_myTurn` nicht mehr gilt.
        final game = ch.Chess()..move(resolveMove(ch.Chess(), 'e2', 'e4'));
        final ok = canAcceptRemoteMove(
          game: game,
          amWhite: false,
          gameEnded: false,
          ply: 2,
        );
        expect(ok, isFalse);
      },
    );

    test('lehnt eine alte/wiederholte ply-Nummer ab (Replay)', () {
      final game = ch.Chess();
      // history.length == 0, naechster gueltiger ply waere 1, nicht 0.
      final ok = canAcceptRemoteMove(
        game: game,
        amWhite: false,
        gameEnded: false,
        ply: 0,
      );
      expect(ok, isFalse);
    });

    test('lehnt jeden Remote-Zug nach Spielende ab', () {
      final game = ch.Chess();
      final ok = canAcceptRemoteMove(
        game: game,
        amWhite: false,
        gameEnded: true,
        ply: 1,
      );
      expect(ok, isFalse);
    });
  });
}
