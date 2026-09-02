import 'dart:convert';
import 'package:chess/chess.dart' as ch;

final RegExp _squarePattern = RegExp(r'^[a-h][1-8]$');

/// Findet den zu [from] -> [to] passenden legalen Zug im aktuellen
/// Brettzustand. Bei einer Bauernumwandlung wird, falls moeglich, die
/// Umwandlung zur Dame gewaehlt (wie in der Online-Partie gewuenscht).
/// Gibt `null` zurueck, wenn kein legaler Zug existiert.
ch.Move? resolveMove(ch.Chess game, String from, String to) {
  final moves = game.generate_moves({'square': from});
  ch.Move? fallback;
  for (final m in moves) {
    if (m.toAlgebraic != to) continue;
    if (m.promotion == null || m.promotion == ch.Chess.QUEEN) {
      return m;
    }
    fallback ??= m;
  }
  return fallback;
}

/// Baut die verschluesselbare JSON-Nutzlast fuer einen gesendeten Zug.
/// [ply] ist die Halbzugnummer, die dieser Zug im Spiel einnimmt (1-basiert,
/// also `history.length` direkt nach dem lokalen Anwenden des Zugs) - der
/// Empfaenger nutzt das, um Doppelzuege und Replays einer alten Nachricht
/// zu erkennen.
String encodeMovePayload(String from, String to, int ply) {
  return jsonEncode({'t': 'move', 'from': from, 'to': to, 'ply': ply});
}

/// Liest eine entschluesselte Zug-Nachricht aus. Gibt `null` zurueck, wenn
/// die Nachricht kein gueltiger Zug ist (falscher Typ, fehlende/falsch
/// typisierte Felder, kein gueltiges Schachfeld, kaputtes JSON).
({String from, String to, int ply})? decodeMovePayload(String clearText) {
  try {
    final data = jsonDecode(clearText);
    if (data is! Map || data['t'] != 'move') return null;
    final from = data['from'];
    final to = data['to'];
    final ply = data['ply'];
    if (from is! String || to is! String || ply is! int) return null;
    if (!_squarePattern.hasMatch(from) || !_squarePattern.hasMatch(to)) {
      return null;
    }
    return (from: from, to: to, ply: ply);
  } catch (_) {
    return null;
  }
}

/// Prueft, ob ein ueber die Leitung empfangener Zug angewendet werden darf.
/// Schuetzt gegen den Fund aus dem Security-Audit: ohne diese Pruefung
/// nimmt `resolveMove` klaglos jeden legalen Zug der gerade ziehenden
/// Farbe an, egal von wem die Nachricht kam - ein boesartiger oder
/// verwirrter Gegenpart kann so beide Farben ziehen oder doppelt ziehen.
///
/// Bedingungen: Spiel darf nicht vorbei sein, es darf NICHT die eigene
/// Zugseite sein (sonst zieht der Gegner fuer mich), und [ply] muss exakt
/// der naechste Halbzug sein (verhindert Doppelzuege und Replays).
bool canAcceptRemoteMove({
  required ch.Chess game,
  required bool amWhite,
  required bool gameEnded,
  required int ply,
}) {
  if (gameEnded || game.game_over) return false;
  final myTurn = (game.turn == ch.Chess.WHITE) == amWhite;
  if (myTurn) return false;
  return ply == game.history.length + 1;
}

/// Baut die verschluesselbare Nutzlast fuer eine Aufgabe.
String encodeResignPayload() => jsonEncode({'t': 'resign'});

/// Prueft, ob eine entschluesselte Nachricht eine Aufgabe ist.
bool isResignPayload(String clearText) {
  try {
    final data = jsonDecode(clearText);
    return data is Map && data['t'] == 'resign';
  } catch (_) {
    return false;
  }
}
