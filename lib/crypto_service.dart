import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Baut eine eindeutige, kollisionsfreie Kodierung der vier Bytefolgen, die
/// den Handschlag ausmachen (Laengenpraefix vor jedem Stueck, damit ein
/// Trennzeichen in einer SDP nicht mit der naechsten Bytefolge verschmelzen
/// kann).
List<int> _handshakeTranscript({
  required List<int> hostPub,
  required String hostSdp,
  required List<int> guestPub,
  required String guestSdp,
}) {
  final out = <int>[];
  void addChunk(List<int> bytes) {
    final len = bytes.length;
    out.addAll([
      (len >> 24) & 0xff,
      (len >> 16) & 0xff,
      (len >> 8) & 0xff,
      len & 0xff,
    ]);
    out.addAll(bytes);
  }

  addChunk(hostPub);
  addChunk(utf8.encode(hostSdp));
  addChunk(guestPub);
  addChunk(utf8.encode(guestSdp));
  return out;
}

/// Ende-zu-Ende-Verschluesselung mit bewaehrten Bausteinen:
///   X25519            -> Schluesseltausch (gemeinsames Geheimnis ableiten)
///   ChaCha20-Poly1305 -> Nachrichten verschluesseln + Echtheit pruefen
///
/// Audit S1 (MITM-Schutz): der Sitzungsschluessel ist nicht das rohe
/// X25519-Geheimnis, sondern per HKDF an den kompletten Handschlag-
/// Transkript gebunden (beide Public Keys + beide SDPs). Veraendert ein
/// Mittelsmann auch nur ein Byte der ausgetauschten Signaling-Codes,
/// leiten Host und Gast unterschiedliche Schluessel (und Fingerprints) ab -
/// die UI-Schicht zeigt den Fingerprint vor dem ersten Chat/Zug an, damit
/// die Nutzer das ausserhalb des Signaling-Kanals abgleichen koennen.
///
/// Audit S2 (Replay-Schutz): jede Nachricht bindet eine pro Senderichtung
/// monoton steigende Sequenznummer plus die Richtung (Host/Gast) als
/// Associated Authenticated Data (AAD) ein. Ein mitgeschnittener alter
/// Geheimtext scheitert damit schon an der AEAD-Pruefung in [decrypt],
/// sobald die erwartete Sequenznummer weitergezaehlt ist - nicht erst an
/// App-Logik. Das deckt nebenbei auch `__START__` und `resign` ab: jede
/// Nachricht laesst sich nur genau einmal, in genau der gesendeten
/// Reihenfolge, entschluesseln. Die Richtung verhindert zusaetzlich, dass
/// eine eigene, an einen selbst zurueckgespiegelte Nachricht (Reflection)
/// als eingehend durchgeht, obwohl beide Seiten denselben symmetrischen
/// Schluessel benutzen.
class CryptoService {
  static const _domain = 'hbc-dc-v1';

  final X25519 _kex = X25519();
  final Cipher _cipher = Chacha20.poly1305Aead();

  SimpleKeyPair? _myKeyPair;
  SecretKey? _sharedKey;
  bool? _isHost;
  int _sendSeq = 0;
  int _expectedRecvSeq = 0;
  String? _fingerprint;

  Future<void> generateKeyPair() async {
    _myKeyPair = await _kex.newKeyPair();
  }

  Future<List<int>> myPublicKeyBytes() async {
    final pub = await _myKeyPair!.extractPublicKey();
    return pub.bytes;
  }

  /// Leitet den Sitzungsschluessel ab. [remotePublicKeyBytes] und
  /// [remoteSdp] gehoeren der Gegenseite, [myPublicKeyBytes]/[mySdp] mir
  /// selbst - [setRole] muss vorher aufgerufen worden sein, damit die
  /// beiden Seiten in der richtigen Reihenfolge (Host zuerst) ins
  /// Transkript einsortiert werden koennen; sonst leiten Host und Gast
  /// unterschiedliche Schluessel ab, obwohl niemand manipuliert hat.
  Future<void> deriveSharedKey({
    required List<int> remotePublicKeyBytes,
    required List<int> myPublicKeyBytes,
    required String mySdp,
    required String remoteSdp,
  }) async {
    final isHost = _requireHostRole;
    final remotePub = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );
    final rawShared = await _kex.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: remotePub,
    );
    final rawSharedBytes = await rawShared.extractBytes();

    final transcript = _handshakeTranscript(
      hostPub: isHost ? myPublicKeyBytes : remotePublicKeyBytes,
      hostSdp: isHost ? mySdp : remoteSdp,
      guestPub: isHost ? remotePublicKeyBytes : myPublicKeyBytes,
      guestSdp: isHost ? remoteSdp : mySdp,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    _sharedKey = await hkdf.deriveKey(
      secretKey: SecretKey(rawSharedBytes),
      info: utf8.encode('$_domain|session') + transcript,
    );
    final sasKey = await hkdf.deriveKey(
      secretKey: SecretKey(rawSharedBytes),
      info: utf8.encode('$_domain|sas') + transcript,
    );
    _fingerprint = _formatFingerprint(await sasKey.extractBytes());
  }

  /// Legt fest, ob diese Seite Host oder Gast ist - muss vor
  /// [deriveSharedKey] und der ersten [encrypt]/[decrypt]-Nutzung gesetzt
  /// sein, sonst werfen alle drei.
  void setRole({required bool isHost}) => _isHost = isHost;

  bool get isReady => _sharedKey != null;

  /// 6-stellige Kurzpruefsumme (Short Authentication String) ueber den
  /// Handschlag-Transkript. Erst nach [deriveSharedKey] gesetzt. Beide
  /// Seiten muessen denselben Code sehen, ausserhalb des Signaling-Kanals
  /// verglichen (z.B. am Telefon vorgelesen) - stimmt er nicht ueberein,
  /// hat jemand den Einladungs-/Antwort-Code unterwegs manipuliert.
  String? get fingerprint => _fingerprint;

  String _formatFingerprint(List<int> bytes) {
    final n = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    final code = n.toUnsigned(32) % 1000000;
    return code.toString().padLeft(6, '0');
  }

  List<int> _aad(int seq, {required bool fromHost}) =>
      utf8.encode('$_domain|${fromHost ? 'H' : 'G'}|$seq');

  bool get _requireHostRole {
    final isHost = _isHost;
    if (isHost == null) {
      throw StateError('CryptoService.setRole() wurde nicht aufgerufen.');
    }
    return isHost;
  }

  Future<String> encrypt(String plainText) async {
    final isHost = _requireHostRole;
    final seq = _sendSeq + 1;
    final box = await _cipher.encrypt(
      utf8.encode(plainText),
      secretKey: _sharedKey!,
      aad: _aad(seq, fromHost: isHost),
    );
    _sendSeq = seq;
    return base64Encode(box.concatenation());
  }

  /// Entschluesselt und prueft dabei die naechste erwartete Sequenznummer
  /// der Gegenseite. Wirft [SecretBoxAuthenticationError], wenn die
  /// Nachricht kein gueltiges naechstes Glied der Kette ist (Replay,
  /// uebersprungene/vertauschte Reihenfolge, oder eine zurueckgespiegelte
  /// eigene Nachricht) - der Sequenzzaehler rueckt dann nicht vor.
  Future<String> decrypt(String encoded) async {
    final isHost = _requireHostRole;
    final seq = _expectedRecvSeq + 1;
    final bytes = base64Decode(encoded);
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clearBytes = await _cipher.decrypt(
      box,
      secretKey: _sharedKey!,
      aad: _aad(seq, fromHost: !isHost),
    );
    _expectedRecvSeq = seq;
    return utf8.decode(clearBytes);
  }
}
