import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

enum _Role { none, host, guest }

class _ConnectionScreenState extends State<ConnectionScreen> {
  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;
  _Role _role = _Role.none;
  bool _connected = false;
  bool _busy = false;
  String _status = 'Noch nicht verbunden';

  String _localCode = '';
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

  String _encode(RTCSessionDescription d) =>
      base64Encode(utf8.encode(jsonEncode({'sdp': d.sdp, 'type': d.type})));

  RTCSessionDescription _decode(String code) {
    final map = jsonDecode(utf8.decode(base64Decode(code.trim())));
    return RTCSessionDescription(map['sdp'], map['type']);
  }

  Future<RTCSessionDescription> _gatherComplete() async {
    final completer = Completer<void>();
    _pc!.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) completer.complete();
      }
    };
    await completer.future
        .timeout(const Duration(seconds: 4), onTimeout: () {});
    final desc = await _pc!.getLocalDescription();
    return desc!;
  }

  void _setupCommon() {
    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() {
          _connected = true;
          _status = 'Verbunden!';
        });
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
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
    ch.onMessage = (RTCDataChannelMessage msg) {
      setState(() => _log.add('Freund: ${msg.text}'));
    };
    ch.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        setState(() {
          _connected = true;
          _status = 'Verbunden! Kanal offen.';
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
    _pc = await createPeerConnection(_config);
    _setupCommon();
    final ch = await _pc!.createDataChannel('chess', RTCDataChannelInit());
    _bindChannel(ch);
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    final full = await _gatherComplete();
    setState(() {
      _localCode = _encode(full);
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
      final answer = _decode(_remoteCtrl.text);
      await _pc!.setRemoteDescription(answer);
      setState(() {
        _busy = false;
        _status = 'Antwort angenommen, verbinde ...';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Fehler: Code ungueltig';
      });
    }
  }

  Future<void> _guestCreateAnswer() async {
    if (_remoteCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Erstelle Antwort ...';
    });
    try {
      _pc = await createPeerConnection(_config);
      _setupCommon();
      _pc!.onDataChannel = (RTCDataChannel ch) => _bindChannel(ch);
      final offer = _decode(_remoteCtrl.text);
      await _pc!.setRemoteDescription(offer);
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      final full = await _gatherComplete();
      setState(() {
        _localCode = _encode(full);
        _remoteCtrl.clear();
        _busy = false;
        _status = 'Antwort-Code bereit. Zurueck an Freund schicken.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Fehler: Einladungs-Code ungueltig';
      });
    }
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _channel == null) return;
    _channel!.send(RTCDataChannelMessage(text));
    setState(() {
      _log.add('Ich: $text');
      _msgCtrl.clear();
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Code kopiert'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online verbinden (Test)')),
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
              child: Text(_status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
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
          'Einer lädt ein, der andere tritt bei. Tausche die Codes einmal '
          'über WhatsApp o.ä. aus.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _startHost,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Einladen (Code erstellen)'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _busy ? null : () => setState(() => _role = _Role.guest),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14)),
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
          child: SelectableText(code,
              maxLines: 4, style: const TextStyle(fontSize: 11)),
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
          ..._codeBox('1. Diesen Einladungs-Code an den Freund schicken:',
              _localCode),
          const SizedBox(height: 20),
          const Text('2. Antwort-Code des Freundes hier einfügen:',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
        const Text('1. Einladungs-Code des Freundes einfügen:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _pasteField('Einladungs-Code einfügen ...'),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _busy ? null : _guestCreateAnswer,
          child: const Text('Antwort erstellen'),
        ),
        if (_localCode.isNotEmpty) ...[
          const SizedBox(height: 20),
          ..._codeBox('2. Diesen Antwort-Code zurück an den Freund schicken:',
              _localCode),
        ],
      ];

  List<Widget> _chatUi() => [
        const SizedBox(height: 20),
        const Divider(),
        const Text('Test-Nachricht (beweist, dass die Leitung steht):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 160,
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
      ];
}
