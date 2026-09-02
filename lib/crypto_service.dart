import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Ende-zu-Ende-Verschluesselung mit bewaehrten Bausteinen:
///   X25519            -> Schluesseltausch (gemeinsames Geheimnis ableiten)
///   ChaCha20-Poly1305 -> Nachrichten verschluesseln + Echtheit pruefen
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

  Future<void> generateKeyPair() async {
    _myKeyPair = await _kex.newKeyPair();
  }

  Future<List<int>> myPublicKeyBytes() async {
    final pub = await _myKeyPair!.extractPublicKey();
    return pub.bytes;
  }

  Future<void> deriveSharedKey(List<int> remotePublicKeyBytes) async {
    final remotePub = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );
    _sharedKey = await _kex.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: remotePub,
    );
  }

  /// Legt fest, ob diese Seite Host oder Gast ist - muss vor der ersten
  /// [encrypt]/[decrypt]-Nutzung gesetzt sein, sonst werfen beide.
  void setRole({required bool isHost}) => _isHost = isHost;

  bool get isReady => _sharedKey != null;

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
