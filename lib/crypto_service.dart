import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Ende-zu-Ende-Verschluesselung mit bewaehrten Bausteinen:
///   X25519            -> Schluesseltausch (gemeinsames Geheimnis ableiten)
///   ChaCha20-Poly1305 -> Nachrichten verschluesseln + Echtheit pruefen
class CryptoService {
  final X25519 _kex = X25519();
  final Cipher _cipher = Chacha20.poly1305Aead();

  SimpleKeyPair? _myKeyPair;
  SecretKey? _sharedKey;

  Future<void> generateKeyPair() async {
    _myKeyPair = await _kex.newKeyPair();
  }

  Future<List<int>> myPublicKeyBytes() async {
    final pub = await _myKeyPair!.extractPublicKey();
    return pub.bytes;
  }

  Future<void> deriveSharedKey(List<int> remotePublicKeyBytes) async {
    final remotePub =
        SimplePublicKey(remotePublicKeyBytes, type: KeyPairType.x25519);
    _sharedKey = await _kex.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: remotePub,
    );
  }

  bool get isReady => _sharedKey != null;

  Future<String> encrypt(String plainText) async {
    final box = await _cipher.encryptString(plainText, secretKey: _sharedKey!);
    return base64Encode(box.concatenation());
  }

  Future<String> decrypt(String encoded) async {
    final bytes = base64Decode(encoded);
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    return _cipher.decryptString(box, secretKey: _sharedKey!);
  }
}
