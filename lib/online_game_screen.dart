import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'crypto_service.dart';
import 'move_codec.dart';

/// Schach ueber die bereits verbundene, verschluesselte WebRTC-Leitung.
/// Der Host spielt Weiss, der Gast Schwarz. Jeder Zug wird verschluesselt
/// uebertragen.
class OnlineGameScreen extends StatefulWidget {
  final RTCDataChannel channel;
  final CryptoService crypto;
  final bool amWhite; // Host = true (Weiss), Gast = false (Schwarz)

  const OnlineGameScreen({
    super.key,
    required this.channel,
    required this.crypto,
    required this.amWhite,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late ch.Chess _game;
  String? _selected;
  Set<String> _targets = {};
  String? _lastFrom;
  String? _lastTo;

  @override
  void initState() {
    super.initState();
    _game = ch.Chess();
    // Eingehende Nachrichten dieser Leitung ab jetzt hier verarbeiten.
    widget.channel.onMessage = (RTCDataChannelMessage msg) async {
      try {
        final clear = await widget.crypto.decrypt(msg.text);
        final move = decodeMovePayload(clear);
        if (move != null) {
          _applyRemoteMove(move.from, move.to);
        }
      } catch (_) {
        // Nachricht ignorieren, wenn sie nicht lesbar ist.
      }
    };
  }

  bool get _myTurn => (_game.turn == ch.Chess.WHITE) == widget.amWhite;

  void _onSquareTap(String square) {
    if (_game.game_over || !_myTurn) return;

    if (_selected != null && _targets.contains(square)) {
      _makeLocalMove(_selected!, square);
      return;
    }

    final piece = _game.get(square);
    // Nur eigene Figuren auswaehlen.
    final myColor = widget.amWhite ? ch.Chess.WHITE : ch.Chess.BLACK;
    if (piece != null && piece.color == myColor && _game.turn == myColor) {
      final moves = _game.generate_moves({'square': square});
      setState(() {
        _selected = square;
        _targets = moves.map((m) => m.toAlgebraic).toSet();
      });
    } else {
      setState(() {
        _selected = null;
        _targets = {};
      });
    }
  }

  Future<void> _makeLocalMove(String from, String to) async {
    final chosen = resolveMove(_game, from, to);
    if (chosen == null) return;
    _game.move(chosen);
    setState(() {
      _lastFrom = from;
      _lastTo = to;
      _selected = null;
      _targets = {};
    });
    // Zug verschluesselt an den Gegner schicken.
    final payload = encodeMovePayload(from, to);
    final encrypted = await widget.crypto.encrypt(payload);
    widget.channel.send(RTCDataChannelMessage(encrypted));
    _checkEnd();
  }

  void _applyRemoteMove(String from, String to) {
    final chosen = resolveMove(_game, from, to);
    if (chosen == null) return;
    _game.move(chosen);
    if (!mounted) return;
    setState(() {
      _lastFrom = from;
      _lastTo = to;
      _selected = null;
      _targets = {};
    });
    _checkEnd();
  }

  void _checkEnd() {
    if (!_game.game_over) return;
    String msg;
    if (_game.in_checkmate) {
      final winnerWhite = _game.turn != ch.Chess.WHITE;
      final iWon = winnerWhite == widget.amWhite;
      msg = iWon ? 'Schachmatt - du gewinnst!' : 'Schachmatt - du verlierst.';
    } else {
      msg = 'Remis.';
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spiel beendet'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Zurueck'),
          ),
        ],
      ),
    );
  }

  String _status() {
    if (_game.game_over) {
      if (_game.in_checkmate) return 'Schachmatt';
      return 'Remis';
    }
    final check = _game.in_check ? '  -  Schach!' : '';
    return (_myTurn ? 'Du bist am Zug' : 'Gegner ist am Zug') + check;
  }

  String _glyph(ch.PieceType t) {
    if (t == ch.Chess.KING) return '\u265A';
    if (t == ch.Chess.QUEEN) return '\u265B';
    if (t == ch.Chess.ROOK) return '\u265C';
    if (t == ch.Chess.BISHOP) return '\u265D';
    if (t == ch.Chess.KNIGHT) return '\u265E';
    return '\u265F';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Online-Schach (${widget.amWhite ? "Weiss" : "Schwarz"})'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              _status(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: (_game.in_check && !_game.game_over)
                    ? Colors.redAccent
                    : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildBoard(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Verschluesselte Partie - jeder Zug geht E2E ueber die Leitung.',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    // Schwarz sieht das Brett gedreht.
    return Column(
      children: List.generate(8, (r) {
        final row = widget.amWhite ? r : 7 - r;
        return Expanded(
          child: Row(
            children: List.generate(8, (c) {
              final col = widget.amWhite ? c : 7 - c;
              final rank = 8 - row;
              final file = String.fromCharCode('a'.codeUnitAt(0) + col);
              final square = '$file$rank';
              return Expanded(child: _buildSquare(square, row, col));
            }),
          ),
        );
      }),
    );
  }

  Widget _buildSquare(String square, int row, int col) {
    final isLight = (row + col) % 2 == 0;
    final base = isLight ? const Color(0xFFEEEED2) : const Color(0xFF769656);
    final piece = _game.get(square);
    final isSelected = square == _selected;
    final isTarget = _targets.contains(square);
    final isLastMove = square == _lastFrom || square == _lastTo;

    return GestureDetector(
      onTap: () => _onSquareTap(square),
      child: Container(
        color: isSelected ? const Color(0xFFBBCB2B) : base,
        child: Stack(
          children: [
            if (isLastMove && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xAAB58B00), width: 3),
                  ),
                ),
              ),
            if (isTarget && piece == null)
              Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0x55000000),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isTarget && piece != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xCCD32F2F), width: 3),
                  ),
                ),
              ),
            if (piece != null)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      _glyph(piece.type),
                      style: TextStyle(
                        fontSize: 100,
                        height: 1,
                        color: piece.color == ch.Chess.WHITE
                            ? const Color(0xFFFAFAFA)
                            : const Color(0xFF1A1A1A),
                        shadows: const [
                          Shadow(
                              blurRadius: 1.5,
                              color: Color(0x99000000),
                              offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
