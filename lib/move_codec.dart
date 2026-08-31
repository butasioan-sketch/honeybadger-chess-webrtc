import 'dart:convert';
import 'package:chess/chess.dart' as ch;

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
String encodeMovePayload(String from, String to) {
  return jsonEncode({'t': 'move', 'from': from, 'to': to});
}

/// Liest eine entschluesselte Zug-Nachricht aus. Gibt `null` zurueck, wenn
/// die Nachricht kein gueltiger Zug ist (falscher Typ, fehlende Felder,
/// kaputtes JSON).
({String from, String to})? decodeMovePayload(String clearText) {
  try {
    final data = jsonDecode(clearText);
    if (data is! Map || data['t'] != 'move') return null;
    final from = data['from'];
    final to = data['to'];
    if (from is! String || to is! String) return null;
    return (from: from, to: to);
  } catch (_) {
    return null;
  }
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
