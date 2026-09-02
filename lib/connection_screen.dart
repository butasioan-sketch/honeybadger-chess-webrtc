import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'crypto_service.dart';
import 'online_game_screen.dart';

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
  bool _busy = false;
  String _status = 'Noch nicht verbunden';

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
      await _crypto.deriveSharedKey(base64Decode(data['pub']));
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
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
      await _crypto.deriveSharedKey(base64Decode(data['pub']));
      _pc = await createPeerConnection(_config);
      _setupCommon();
      _pc!.onDataChannel = (dc) => _bindChannel(dc);
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      final full = await _gatherComplete();
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
    if (text.isEmpty || _channel == null || !_crypto.isReady) return;
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
    final enc = await _crypto.encrypt('__START__');
    _channel!.send(RTCDataChannelMessage(enc));
    _openBoard(true);
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
                color: _connected ? Colors.green.shade800 : Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            if (_connected && _role == _Role.host)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _startAsHost,
                  icon: const Icon(Icons.sports_esports),
                  label: const Text('SCHACH STARTEN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            if (_role == _Role.none) ..._roleChooser(),
            if (_role == _Role.host) ..._hostUi(),
            if (_role == _Role.guest) ..._guestUi(),
            if (_connected) ..._chatUi(),
          ],
        ),
      ),
    );
  }

  List<Widget> _roleChooser() => [
    const Text(
      'Einer lädt ein, der andere tritt bei. Die Schluessel reisen im Code '
      'mit - ab dem Handschlag ist alles Ende-zu-Ende verschluesselt.',
      style: TextStyle(color: Colors.white70),
    ),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: _busy ? null : _startHost,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text('Einladen (Code erstellen)'),
    ),
    const SizedBox(height: 12),
    ElevatedButton(
      onPressed: _busy ? null : () => setState(() => _role = _Role.guest),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
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
        color: Colors.white10,
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
        color: Colors.white10,
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
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _lastCipher.length > 80
              ? '${_lastCipher.substring(0, 80)} ...'
              : _lastCipher,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.greenAccent,
            fontFamily: 'monospace',
          ),
        ),
      ),
    ],
  ];
}
