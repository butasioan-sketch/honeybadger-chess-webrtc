import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'crypto_service.dart';
import 'hbc_feedback.dart';
import 'online_game_screen.dart';
import 'ui/hbc_theme.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

enum _Role { none, host, guest }

class _ConnectionScreenState extends State<ConnectionScreen> {
  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;
  final CryptoService _crypto = CryptoService();
  _Role _role = _Role.none;
  bool _connected = false;
  bool _fingerprintConfirmed = false;
  bool _busy = false;
  String _status = 'Noch nicht verbunden';

  // Nur als Host gesetzt: eigener Public Key + eigene Angebots-SDP, damit
  // _hostAcceptAnswer() spaeter das vollstaendige Handschlag-Transkript
  // fuer die MITM-Fingerprint-Ableitung bauen kann (Audit S1).
  List<int>? _myPubBytes;
  String? _mySdp;

  String _localCode = '';
  String _lastCipher = '';
  final TextEditingController _remoteCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  final List<String> _log = [];

  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  @override
  void dispose() {
    _remoteCtrl.dispose();
    _msgCtrl.dispose();
    _channel?.close();
    _pc?.close();
    super.dispose();
  }

  // Signal-Code = SDP + Typ + oeffentlicher Schluessel, alles in einem Base64-Blob.
  String _encodeSignal(RTCSessionDescription d, List<int> pub) => base64Encode(
    utf8.encode(
      jsonEncode({'sdp': d.sdp, 'type': d.type, 'pub': base64Encode(pub)}),
    ),
  );

  Map<String, dynamic> _decodeSignal(String code) =>
      jsonDecode(utf8.decode(base64Decode(code.trim())));

  Future<RTCSessionDescription> _gatherComplete() async {
    final completer = Completer<void>();
    _pc!.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) completer.complete();
      }
    };
    await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
    final desc = await _pc!.getLocalDescription();
    return desc!;
  }

  void _setupCommon() {
    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _connected = true);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() {
          _connected = false;
          _fingerprintConfirmed = false;
          _status = 'Verbindung getrennt';
        });
      }
    };
  }

  void _bindChannel(RTCDataChannel ch) {
    _channel = ch;
    ch.onMessage = (RTCDataChannelMessage msg) async {
      if (!_crypto.isReady) return;
      try {
        final clear = await _crypto.decrypt(msg.text);
        if (clear == '__START__') {
          // Audit S1: vor der Sicherheitscode-Bestaetigung ist die
          // Verbindung nicht als MITM-frei erwiesen - Spielstart ignorieren.
          if (!_fingerprintConfirmed) return;
          _openBoard(false);
          return;
        }
        if (!mounted) return;
        setState(() => _log.add('Freund:  $clear'));
      } catch (e) {
        if (!mounted) return;
        setState(() => _log.add('[nicht entschluesselbar]'));
      }
    };
    ch.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        setState(() {
          _connected = true;
          _status = _crypto.isReady
              ? 'Verbunden & Ende-zu-Ende verschluesselt.'
              : 'Verbunden (kein Schluessel!).';
        });
      }
    };
  }

  Future<void> _startHost() async {
    setState(() {
      _busy = true;
      _role = _Role.host;
      _status = 'Erstelle Einladung ...';
    });
    _crypto.setRole(isHost: true);
    await _crypto.generateKeyPair();
    final myPub = await _crypto.myPublicKeyBytes();
    _pc = await createPeerConnection(_config);
    _setupCommon();
    final dc = await _pc!.createDataChannel('chess', RTCDataChannelInit());
    _bindChannel(dc);
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    final full = await _gatherComplete();
    _myPubBytes = myPub;
    _mySdp = full.sdp;
    setState(() {
      _localCode = _encodeSignal(full, myPub);
      _busy = false;
      _status = 'Einladungs-Code bereit. An Freund schicken.';
    });
  }

  Future<void> _hostAcceptAnswer() async {
    if (_remoteCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Verbinde ...';
    });
    try {
      final data = _decodeSignal(_remoteCtrl.text);
      final guestPub = base64Decode(data['pub'] as String);
      // Audit S1: pub muss ein echter X25519-Public-Key sein (32 Byte) und
      // der Code-Typ muss zur erwarteten Rolle passen - sonst kein
      // manipulierter/vertauschter Code als gueltige Antwort durchgehen.
      if (guestPub.length != 32) {
        throw const FormatException(
          'Oeffentlicher Schluessel hat nicht die erwartete Laenge.',
        );
      }
      if (data['type'] != 'answer') {
        throw const FormatException(
          'Das ist keine Antwort auf eine Einladung.',
        );
      }
      final guestSdp = data['sdp'] as String;
      await _crypto.deriveSharedKey(
        remotePublicKeyBytes: guestPub,
        myPublicKeyBytes: _myPubBytes!,
        mySdp: _mySdp!,
        remoteSdp: guestSdp,
      );
      await _pc!.setRemoteDescription(
        RTCSessionDescription(guestSdp, data['type']),
      );
      setState(() {
        _busy = false;
        _status = 'Schluessel ausgetauscht, verbinde ...';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Fehler: Antwort-Code ungueltig';
      });
    }
  }

  Future<void> _guestCreateAnswer() async {
    if (_remoteCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _role = _Role.guest;
      _status = 'Erstelle Antwort ...';
    });
    _crypto.setRole(isHost: false);
    try {
      await _crypto.generateKeyPair();
      final myPub = await _crypto.myPublicKeyBytes();
      final data = _decodeSignal(_remoteCtrl.text);
      final hostPub = base64Decode(data['pub'] as String);
      // Audit S1: siehe _hostAcceptAnswer - dieselbe Pruefung spiegelverkehrt.
      if (hostPub.length != 32) {
        throw const FormatException(
          'Oeffentlicher Schluessel hat nicht die erwartete Laenge.',
        );
      }
      if (data['type'] != 'offer') {
        throw const FormatException('Das ist keine Einladung.');
      }
      final hostSdp = data['sdp'] as String;
      _pc = await createPeerConnection(_config);
      _setupCommon();
      _pc!.onDataChannel = (dc) => _bindChannel(dc);
      await _pc!.setRemoteDescription(
        RTCSessionDescription(hostSdp, data['type']),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      final full = await _gatherComplete();
      // Erst jetzt ist die eigene Antwort-SDP bekannt - das Handschlag-
      // Transkript fuer den Fingerprint braucht alle vier Stuecke.
      await _crypto.deriveSharedKey(
        remotePublicKeyBytes: hostPub,
        myPublicKeyBytes: myPub,
        mySdp: full.sdp!,
        remoteSdp: hostSdp,
      );
      setState(() {
        _localCode = _encodeSignal(full, myPub);
        _remoteCtrl.clear();
        _busy = false;
        _status = 'Antwort-Code bereit. Zurueck schicken.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Fehler: Einladungs-Code ungueltig';
      });
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty ||
        _channel == null ||
        !_crypto.isReady ||
        !_fingerprintConfirmed) {
      return;
    }
    final encrypted = await _crypto.encrypt(text);
    _channel!.send(RTCDataChannelMessage(encrypted));
    if (!mounted) return;
    setState(() {
      _log.add('Ich:  $text');
      _lastCipher = encrypted;
      _msgCtrl.clear();
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code kopiert'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _startAsHost() async {
    if (!_fingerprintConfirmed) return;
    final enc = await _crypto.encrypt('__START__');
    _channel!.send(RTCDataChannelMessage(enc));
    _openBoard(true);
  }

  void _confirmFingerprint() {
    HbcFeedback.fingerprintConfirmed();
    setState(() => _fingerprintConfirmed = true);
  }

  Future<void> _rejectFingerprint() async {
    HbcFeedback.fingerprintRejected();
    await _channel?.close();
    await _pc?.close();
    if (!mounted) return;
    setState(() {
      _channel = null;
      _pc = null;
      _connected = false;
      _fingerprintConfirmed = false;
      _role = _Role.none;
      _localCode = '';
      _status =
          'Verbindung abgebrochen - Sicherheitscode stimmte nicht ueberein.';
    });
  }

  void _openBoard(bool amWhite) {
    if (!mounted || _channel == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          channel: _channel!,
          crypto: _crypto,
          amWhite: amWhite,
          peerConnection: _pc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online verbinden (verschluesselt)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _connected ? HbcColors.success : HbcColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            if (_connected && _crypto.isReady && !_fingerprintConfirmed)
              ..._fingerprintUi(),
            if (_connected && _fingerprintConfirmed && _role == _Role.host)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _startAsHost,
                  icon: const Icon(Icons.sports_esports),
                  label: const Text('SCHACH STARTEN'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            if (_role == _Role.none) ..._roleChooser(),
            if (_role == _Role.host) ..._hostUi(),
            if (_role == _Role.guest) ..._guestUi(),
            if (_connected && _fingerprintConfirmed) ..._chatUi(),
          ],
        ),
      ),
    );
  }

  List<Widget> _fingerprintUi() => [
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HbcColors.goldDim,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Text(
              'Sicherheitscode vergleichen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lies diesen Code deinem Freund vor - persoenlich oder ueber '
              'einen anderen Kanal als den Einladungs-Code. Nur wenn beide '
              'Seiten denselben Code sehen, ist die Verbindung sicher vor '
              'einem Mittelsmann.',
              style: TextStyle(color: HbcColors.inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              _crypto.fingerprint ?? '------',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _rejectFingerprint,
                    child: const Text('Stimmt NICHT ueberein'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmFingerprint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HbcColors.success,
                      foregroundColor: HbcColors.obsidian,
                    ),
                    child: const Text('Stimmt ueberein'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _roleChooser() => [
    const Text(
      'Einer lädt ein, der andere tritt bei. Die Schluessel reisen im Code '
      'mit - ab dem Handschlag ist alles Ende-zu-Ende verschluesselt.',
      style: TextStyle(color: HbcColors.inkMuted),
    ),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: _busy ? null : _startHost,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text('Einladen (Code erstellen)'),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed: _busy ? null : () => setState(() => _role = _Role.guest),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text('Beitreten (Code eingeben)'),
    ),
  ];

  List<Widget> _codeBox(String label, String code) => [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HbcColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        code,
        maxLines: 4,
        style: const TextStyle(fontSize: 11),
      ),
    ),
    const SizedBox(height: 6),
    OutlinedButton.icon(
      onPressed: () => _copy(code),
      icon: const Icon(Icons.copy, size: 18),
      label: const Text('Code kopieren'),
    ),
    const SizedBox(height: 6),
    // Audit S4: ehrlich sagen, was tatsaechlich im Code steckt - nicht nur
    // der Schluessel. Der Verbindungsaufbau selbst (STUN, ICE) ist noch
    // nicht verschluesselt.
    const Text(
      'Dieser Code enthaelt auch Netzwerk-Informationen (u.a. lokale '
      'IP-Adressen deines Geraets) und nutzt einen oeffentlichen '
      'Google-STUN-Server (stun.l.google.com) fuer den Verbindungsaufbau - '
      'nicht nur den Schluessel. Teile ihn nur mit der Person, mit der du '
      'wirklich spielen willst.',
      style: TextStyle(fontSize: 11, color: HbcColors.inkMuted),
    ),
  ];

  Widget _pasteField(String hint) => TextField(
    controller: _remoteCtrl,
    maxLines: 3,
    decoration: InputDecoration(
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  List<Widget> _hostUi() => [
    if (_busy && _localCode.isEmpty)
      const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (_localCode.isNotEmpty) ...[
      ..._codeBox(
        '1. Diesen Einladungs-Code an den Freund schicken:',
        _localCode,
      ),
      const SizedBox(height: 20),
      const Text(
        '2. Antwort-Code des Freundes hier einfügen:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      _pasteField('Antwort-Code einfügen ...'),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: _busy ? null : _hostAcceptAnswer,
        child: const Text('Verbinden'),
      ),
    ],
  ];

  List<Widget> _guestUi() => [
    const Text(
      '1. Einladungs-Code des Freundes einfügen:',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 6),
    _pasteField('Einladungs-Code einfügen ...'),
    const SizedBox(height: 8),
    ElevatedButton(
      onPressed: _busy ? null : _guestCreateAnswer,
      child: const Text('Antwort erstellen'),
    ),
    if (_localCode.isNotEmpty) ...[
      const SizedBox(height: 20),
      ..._codeBox(
        '2. Diesen Antwort-Code zurück an den Freund schicken:',
        _localCode,
      ),
    ],
  ];

  List<Widget> _chatUi() => [
    const SizedBox(height: 20),
    const Divider(),
    const Text(
      'Verschluesselter Test-Chat:',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 8),
    Container(
      height: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HbcColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _log.map((l) => Text(l)).toList(),
        ),
      ),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _msgCtrl,
            decoration: const InputDecoration(
              hintText: 'Nachricht ...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _send, child: const Text('Senden')),
      ],
    ),
    if (_lastCipher.isNotEmpty) ...[
      const SizedBox(height: 12),
      const Text(
        'Das ging WIRKLICH ueber die Leitung (Geheimtext):',
        style: TextStyle(fontSize: 12, color: HbcColors.inkMuted),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HbcColors.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _lastCipher.length > 80
              ? '${_lastCipher.substring(0, 80)} ...'
              : _lastCipher,
          style: hbcMono.copyWith(fontSize: 10, color: HbcColors.gold),
        ),
      ),
    ],
  ];
}
