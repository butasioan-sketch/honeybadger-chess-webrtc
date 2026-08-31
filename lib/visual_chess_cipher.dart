import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:chess/chess.dart' as ch;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;

/// Der "visuelle Cipher": eine mit Passwort verschluesselte Nachricht wird
/// als Folge legaler Schachzuege ab der Grundstellung dargestellt (UCI-
/// Notation, z.B. "e2e4"). Wer die Zugfolge und das Passwort hat, kann sie
/// zurueck in Klartext verwandeln - fuer alle anderen sieht es wie eine
/// gewoehnliche Schachpartie aus.
///
/// Kodierungs-Idee: die verschluesselten Bytes werden als eine grosse
/// Ganzzahl interpretiert. Bei jedem Halbzug hat die Stellung eine
/// bestimmte Anzahl legaler Zuege (die "Basis" an dieser Stelle); die
/// Ganzzahl wird schrittweise durch diese Basis geteilt (Rest = Index des
/// gespielten Zugs in der deterministischen Zugliste). Das ist eine
/// bijektive gemischt-radix-Kodierung: aus der Zugfolge laesst sich die
/// Ganzzahl exakt zurueckrechnen, wenn man beim Nachspielen an jeder
/// Stelle wieder dieselbe legale Zugliste erzeugt.
class VisualChessCipherError implements Exception {
  final String message;
  VisualChessCipherError(this.message);
  @override
  String toString() => message;
}

const int maxCipherPlies = 900;
const int _saltLength = 16;
const int _pbkdf2Iterations = 100000;
const int minPassphraseLength = 8;

final Cipher _cipher = Chacha20.poly1305Aead();

List<int> _randomBytes(int length) {
  final rnd = Random.secure();
  return List<int>.generate(length, (_) => rnd.nextInt(256));
}

/// Parameter fuer die PBKDF2-Ableitung in einem separaten Isolate (siehe
/// [_deriveKey]) - muessen isolate-sicher (keine Closures) sein. Nur wegen
/// [deriveKeyBytesRunner]/[deriveKeyBytesInline] (Test-Ersatz fuer
/// [compute]) oeffentlich, kein Teil der eigentlichen API.
@visibleForTesting
class KdfRequest {
  final List<int> passphraseBytes;
  final List<int> salt;
  const KdfRequest(this.passphraseBytes, this.salt);
}

Future<List<int>> _deriveKeyBytesInIsolate(KdfRequest req) async {
  final kdf = Pbkdf2.hmacSha256(iterations: _pbkdf2Iterations, bits: 256);
  final key = await kdf.deriveKey(
    secretKey: SecretKey(req.passphraseBytes),
    nonce: req.salt,
  );
  return key.extractBytes();
}

/// Fuehrt die PBKDF2-Berechnung aus - per Default in einem separaten
/// Isolate ueber [compute], damit die rechenintensiven Runden nicht die UI
/// blockieren. `compute()` haengt sich innerhalb von `testWidgets()`
/// (TestWidgetsFlutterBinding) nachweislich auf (bestaetigt mit einem
/// Minimal-Repro ganz ohne Cipher-Code - ein Flutter-Testumgebungs-Problem,
/// kein Fehler in dieser Datei); Widget-Tests koennen diese Funktion daher
/// durch eine Variante ohne echtes Isolate ersetzen.
@visibleForTesting
Future<List<int>> Function(KdfRequest request) deriveKeyBytesRunner = (req) =>
    compute(_deriveKeyBytesInIsolate, req);

/// Direkter Aufruf ohne Isolate - fuer Tests, die [deriveKeyBytesRunner]
/// ueberschreiben wollen.
@visibleForTesting
Future<List<int>> deriveKeyBytesInline(KdfRequest req) =>
    _deriveKeyBytesInIsolate(req);

Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
  final bytes = await deriveKeyBytesRunner(
    KdfRequest(utf8.encode(passphrase), salt),
  );
  return SecretKey(bytes);
}

BigInt _bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt n) {
  if (n == BigInt.zero) return Uint8List.fromList([0]);
  final bytes = <int>[];
  var v = n;
  final mask = BigInt.from(0xff);
  while (v > BigInt.zero) {
    bytes.add((v & mask).toInt());
    v = v >> 8;
  }
  return Uint8List.fromList(bytes.reversed.toList());
}

/// Eindeutiger Schluessel fuer einen Zug innerhalb einer legalen Zugliste
/// (UCI-artig: von+nach+Umwandlungsfigur).
String moveKey(ch.Move m) =>
    '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.toString() ?? ''}';

/// Prueft, ob [move] die Stellung sofort beendet (Matt oder Patt fuer den
/// Gegner - danach gibt es keine legalen Zuege mehr). Zieht auf demselben
/// Objekt und macht den Zug direkt danach rueckgaengig (wie die KI-Suche in
/// chess_ai.dart) statt `game.copy()` zu nutzen - bei ~900 moeglichen
/// Halbzuegen x ~20-40 Kandidatenzuegen je Halbzug macht das den
/// Unterschied zwischen Millisekunden und einem spuerbaren Einfrieren.
bool _endsGame(ch.Chess game, ch.Move move) {
  game.make_move(move);
  final blocked = game.generate_moves().isEmpty;
  game.undo_move();
  return blocked;
}

/// Liefert die legalen Zuege an der aktuellen Stelle, deterministisch
/// sortiert (nicht auf die interne Reihenfolge von `generate_moves()`
/// verlassen - die ist nirgends als stabile Schnittstelle dokumentiert).
/// Zuege, die die Partie sofort beenden (Matt/Patt), werden herausgefiltert,
/// solange es noch mindestens einen anderen Zug gibt - sonst koennte der
/// Zufallsweg durchs Brett vorzeitig abbrechen, obwohl noch Daten fehlen.
/// Encoder und Decoder rufen exakt dieselbe Funktion auf, das Ergebnis
/// bleibt also bijektiv.
List<ch.Move> _cipherAlphabet(ch.Chess game) {
  final legal = game.generate_moves()
    ..sort((a, b) => moveKey(a).compareTo(moveKey(b)));
  if (legal.isEmpty) return legal;
  final nonTerminal = legal.where((m) => !_endsGame(game, m)).toList();
  return nonTerminal.isNotEmpty ? nonTerminal : legal;
}

List<String> _bigIntToMoves(BigInt value) {
  final game = ch.Chess();
  final moves = <String>[];
  var remaining = value;
  while (remaining > BigInt.zero) {
    if (moves.length >= maxCipherPlies) {
      throw VisualChessCipherError(
        'Nachricht zu lang fuer den visuellen Cipher (Limit: '
        '$maxCipherPlies Halbzuege). Bitte kuerzere Nachricht oder '
        'kuerzeres Passwort verwenden.',
      );
    }
    final alphabet = _cipherAlphabet(game);
    if (alphabet.isEmpty) {
      throw VisualChessCipherError(
        'Der Cipher ist mitten in der Kodierung in eine Endstellung '
        '(Matt/Patt) geraten. Bitte Nachricht oder Passwort aendern.',
      );
    }
    final count = BigInt.from(alphabet.length);
    final idx = (remaining % count).toInt();
    remaining = remaining ~/ count;
    final chosen = alphabet[idx];
    moves.add(moveKey(chosen));
    game.move(chosen);
  }
  return moves;
}

BigInt _movesToBigInt(List<String> moves) {
  final game = ch.Chess();
  final counts = <int>[];
  final indices = <int>[];
  for (final key in moves) {
    final alphabet = _cipherAlphabet(game);
    final idx = alphabet.indexWhere((m) => moveKey(m) == key);
    if (idx == -1) {
      throw VisualChessCipherError(
        'Ungueltiger oder an dieser Stelle unmoeglicher Zug in der '
        'Zugfolge: "$key".',
      );
    }
    counts.add(alphabet.length);
    indices.add(idx);
    game.move(alphabet[idx]);
  }
  var value = BigInt.zero;
  for (var i = moves.length - 1; i >= 0; i--) {
    value = value * BigInt.from(counts[i]) + BigInt.from(indices[i]);
  }
  return value;
}

const int _maxEncodeAttempts = 20;

/// Verschluesselt [plainText] mit [passphrase] und kodiert das Ergebnis als
/// Folge legaler Schachzuege ab der Grundstellung.
///
/// Da die Zugfolge ein zufaelliger Weg durch den Zugbaum ist, kann sie
/// - je nach Salz/Nonce - vorzeitig in einer echten Matt- oder Pattstellung
/// enden, bevor alle Daten kodiert sind. In diesem Fall wird automatisch
/// mit frischem Salz/Nonce erneut versucht, bevor ein Fehler geworfen wird.
Future<List<String>> encodeTextAsMoves(
  String plainText,
  String passphrase,
) async {
  VisualChessCipherError? lastError;
  for (var attempt = 0; attempt < _maxEncodeAttempts; attempt++) {
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(passphrase, salt);
    final box = await _cipher.encrypt(utf8.encode(plainText), secretKey: key);
    final payload = [...salt, ...box.concatenation()];
    final len = payload.length;
    final framed = [
      0x01,
      (len >> 24) & 0xff,
      (len >> 16) & 0xff,
      (len >> 8) & 0xff,
      len & 0xff,
      ...payload,
    ];
    try {
      return _bigIntToMoves(_bytesToBigInt(framed));
    } on VisualChessCipherError catch (e) {
      lastError = e;
    }
  }
  throw lastError ??
      VisualChessCipherError('Unbekannter Fehler bei der Cipher-Kodierung.');
}

/// Entschluesselt eine mit [encodeTextAsMoves] erzeugte Zugfolge. Wirft
/// [VisualChessCipherError] bei ungueltigen Zuegen, falschem Passwort oder
/// beschaedigten Daten.
Future<String> decodeMovesAsText(List<String> moves, String passphrase) async {
  final framed = _bigIntToBytes(_movesToBigInt(moves));
  if (framed.length < 5 || framed[0] != 0x01) {
    throw VisualChessCipherError(
      'Keine gueltige Cipher-Zugfolge (Kopfdaten fehlen oder falsch).',
    );
  }
  final payloadLength =
      (framed[1] << 24) | (framed[2] << 16) | (framed[3] << 8) | framed[4];
  if (framed.length != 5 + payloadLength || payloadLength < _saltLength) {
    throw VisualChessCipherError(
      'Beschaedigte Cipher-Daten (Laenge passt nicht zur Kopfangabe).',
    );
  }
  final payload = framed.sublist(5);
  final salt = payload.sublist(0, _saltLength);
  final boxBytes = payload.sublist(_saltLength);
  final key = await _deriveKey(passphrase, salt);
  try {
    final box = SecretBox.fromConcatenation(
      boxBytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clear = await _cipher.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  } catch (_) {
    throw VisualChessCipherError('Falsches Passwort oder beschaedigte Daten.');
  }
}
