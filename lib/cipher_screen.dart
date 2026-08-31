import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'visual_chess_cipher.dart';
import 'widgets/chess_board_view.dart';

final RegExp _uciMovePattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');

/// Formatiert eine Zugfolge als lesbaren, nummerierten Text (wie eine
/// kurze Partie-Notation), z.B. "1. e2e4 e7e5\n2. g1f3 ...".
String formatMoveList(List<String> moves) {
  final buf = StringBuffer();
  for (var i = 0; i < moves.length; i += 2) {
    final number = (i ~/ 2) + 1;
    buf.write('$number. ${moves[i]}');
    if (i + 1 < moves.length) buf.write(' ${moves[i + 1]}');
    buf.write('\n');
  }
  return buf.toString().trim();
}

/// Liest die einzelnen Zug-Token aus beliebig formatiertem Text heraus
/// (Zugnummern wie "1." werden automatisch verworfen, da sie nicht ins
/// UCI-artige Zugformat passen).
List<String> parseMoveList(String input) {
  return input
      .split(RegExp(r'\s+'))
      .map((t) => t.trim())
      .where(_uciMovePattern.hasMatch)
      .toList();
}

/// Encoder/Decoder fuer den visuellen Chess-Cipher: eine mit Passwort
/// verschluesselte Nachricht wird als Folge legaler Schachzuege dargestellt
/// und kann auf einem Brett abgespielt werden.
class CipherScreen extends StatelessWidget {
  const CipherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visueller Cipher'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Verschlüsseln'),
              Tab(text: 'Entschlüsseln'),
            ],
          ),
        ),
        body: const TabBarView(children: [_EncoderTab(), _DecoderTab()]),
      ),
    );
  }
}

class _EncoderTab extends StatefulWidget {
  const _EncoderTab();
  @override
  State<_EncoderTab> createState() => _EncoderTabState();
}

class _EncoderTabState extends State<_EncoderTab> {
  final _textCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  List<String>? _moves;

  @override
  void dispose() {
    _textCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _encode() async {
    setState(() {
      _busy = true;
      _error = null;
      _moves = null;
    });
    try {
      final moves = await encodeTextAsMoves(_textCtrl.text, _passCtrl.text);
      if (!mounted) return;
      setState(() => _moves = moves);
    } on VisualChessCipherError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy() {
    if (_moves == null) return;
    Clipboard.setData(ClipboardData(text: formatMoveList(_moves!)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zugfolge kopiert'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Text mit Passwort verschlüsseln - das Ergebnis sieht wie eine '
            'ganz normale Schachpartie aus. Kurze Nachrichten (grob bis '
            '~200 Zeichen) funktionieren am zuverlässigsten: der Zufallsweg '
            'durchs Schachbrett kann bei längeren Nachrichten vorzeitig in '
            'einem Matt/Patt enden.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Nachricht',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Passwort',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _encode,
            child: const Text('Verschlüsseln & als Schachpartie zeigen'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!),
            ),
          if (_moves != null) ...[
            const SizedBox(height: 20),
            Text(
              '${_moves!.length} Halbzüge',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                formatMoveList(_moves!),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Zugfolge kopieren'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Playback:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _CipherPlaybackBoard(moves: _moves!),
          ],
        ],
      ),
    );
  }
}

class _DecoderTab extends StatefulWidget {
  const _DecoderTab();
  @override
  State<_DecoderTab> createState() => _DecoderTabState();
}

class _DecoderTabState extends State<_DecoderTab> {
  final _movesCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _plainText;
  List<String>? _parsedMoves;

  @override
  void dispose() {
    _movesCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    setState(() {
      _busy = true;
      _error = null;
      _plainText = null;
      _parsedMoves = null;
    });
    final moves = parseMoveList(_movesCtrl.text);
    if (moves.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Keine gültigen Züge in der Eingabe gefunden.';
      });
      return;
    }
    try {
      final text = await decodeMovesAsText(moves, _passCtrl.text);
      if (!mounted) return;
      setState(() {
        _plainText = text;
        _parsedMoves = moves;
      });
    } on VisualChessCipherError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Zugfolge (aus dem Verschlüsseln-Tab) und Passwort einfügen, '
            'um die Nachricht zurückzubekommen.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _movesCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Zugfolge einfügen',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Passwort',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _decode,
            child: const Text('Nachricht entschlüsseln'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!),
            ),
          if (_plainText != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Entschlüsselte Nachricht:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(_plainText!),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Playback:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _CipherPlaybackBoard(moves: _parsedMoves!),
          ],
        ],
      ),
    );
  }
}

/// Spielt eine Zugfolge (UCI-artige Strings) auf einem Brett ab - Play,
/// Stop und eine Geschwindigkeit zum Umschalten.
class _CipherPlaybackBoard extends StatefulWidget {
  final List<String> moves;
  const _CipherPlaybackBoard({required this.moves});

  @override
  State<_CipherPlaybackBoard> createState() => _CipherPlaybackBoardState();
}

class _CipherPlaybackBoardState extends State<_CipherPlaybackBoard> {
  static const _normalStep = Duration(milliseconds: 500);
  static const _fastStep = Duration(milliseconds: 120);

  late ch.Chess _game;
  int _ply = 0;
  String? _lastFrom;
  String? _lastTo;
  Timer? _timer;
  bool _playing = false;
  Duration _step = _normalStep;

  @override
  void initState() {
    super.initState();
    _game = ch.Chess();
  }

  @override
  void didUpdateWidget(covariant _CipherPlaybackBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moves != widget.moves) {
      _stop();
      _reset();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _game = ch.Chess();
      _ply = 0;
      _lastFrom = null;
      _lastTo = null;
    });
  }

  void _stepForward() {
    if (_ply >= widget.moves.length) {
      _stop();
      return;
    }
    final key = widget.moves[_ply];
    final legal = _game.generate_moves();
    final idx = legal.indexWhere((m) => moveKey(m) == key);
    if (idx == -1) {
      _stop();
      return;
    }
    final mv = legal[idx];
    _game.move(mv);
    setState(() {
      _lastFrom = mv.fromAlgebraic;
      _lastTo = mv.toAlgebraic;
      _ply++;
    });
    if (_ply >= widget.moves.length) _stop();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_step, (_) => _stepForward());
  }

  void _play() {
    if (widget.moves.isEmpty) return;
    if (_ply >= widget.moves.length) _reset();
    setState(() => _playing = true);
    _startTimer();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _toggleSpeed() {
    setState(() {
      _step = _step == _normalStep ? _fastStep : _normalStep;
    });
    if (_playing) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ChessBoardView(
            game: _game,
            lastFrom: _lastFrom,
            lastTo: _lastTo,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Zug $_ply / ${widget.moves.length}',
          style: const TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: _playing ? 'Pause' : 'Abspielen',
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              onPressed: widget.moves.isEmpty
                  ? null
                  : (_playing ? _stop : _play),
            ),
            IconButton(
              tooltip: 'Stop & zurücksetzen',
              icon: const Icon(Icons.stop),
              onPressed: () {
                _stop();
                _reset();
              },
            ),
            TextButton(
              onPressed: _toggleSpeed,
              child: Text(_step == _fastStep ? 'Schnell' : 'Normal'),
            ),
          ],
        ),
      ],
    );
  }
}
