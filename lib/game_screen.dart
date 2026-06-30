import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import 'chess_ai.dart';

class GameScreen extends StatefulWidget {
  final bool vsComputer;
  const GameScreen({super.key, required this.vsComputer});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ch.Chess _game;
  int _aiDepth = 2; // 1 = leicht, 2 = mittel, 3 = schwer
  String? _selected;
  Set<String> _targets = {};
  bool _aiThinking = false;
  String? _lastFrom;
  String? _lastTo;

  @override
  void initState() {
    super.initState();
    _game = ch.Chess();
  }

  bool get _isHumanTurn {
    if (!widget.vsComputer) return true;
    return _game.turn == ch.Chess.WHITE;
  }

  void _onSquareTap(String square) {
    if (_aiThinking || _game.game_over || !_isHumanTurn) return;

    if (_selected != null && _targets.contains(square)) {
      _applyHumanMove(_selected!, square);
      return;
    }

    final piece = _game.get(square);
    if (piece != null && piece.color == _game.turn) {
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

  void _applyHumanMove(String from, String to) {
    final moves = _game.generate_moves({'square': from});
    ch.Move? chosen;
    for (final m in moves) {
      if (m.toAlgebraic == to) {
        if (m.promotion == null || m.promotion == ch.Chess.QUEEN) {
          chosen = m;
          break;
        }
        chosen ??= m;
      }
    }
    if (chosen == null) return;
    _game.move(chosen);
    setState(() {
      _lastFrom = from;
      _lastTo = to;
      _selected = null;
      _targets = {};
    });
    _afterMove();
  }

  void _afterMove() {
    if (_game.game_over) {
      _showResult();
      return;
    }
    if (widget.vsComputer && _game.turn == ch.Chess.BLACK) {
      _makeAiMove();
    }
  }

  Future<void> _makeAiMove() async {
    setState(() => _aiThinking = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final move = ChessAI(depth: _aiDepth).findBestMove(_game);
    if (move != null) {
      _game.move({
        'from': move.fromAlgebraic,
        'to': move.toAlgebraic,
        if (move.promotion != null) 'promotion': 'q',
      });
      _lastFrom = move.fromAlgebraic;
      _lastTo = move.toAlgebraic;
    }
    if (!mounted) return;
    setState(() => _aiThinking = false);
    if (_game.game_over) _showResult();
  }

  void _newGame() {
    setState(() {
      _game = ch.Chess();
      _selected = null;
      _targets = {};
      _aiThinking = false;
      _lastFrom = null;
      _lastTo = null;
    });
  }

  void _undo() {
    if (_aiThinking) return;
    final undone = _game.undo();
    if (undone == null) return;
    if (widget.vsComputer && _game.turn == ch.Chess.BLACK) {
      _game.undo();
    }
    setState(() {
      _selected = null;
      _targets = {};
      _lastFrom = null;
      _lastTo = null;
    });
  }

  void _showResult() {
    String msg;
    if (_game.in_checkmate) {
      final winner = _game.turn == ch.Chess.WHITE ? 'Schwarz' : 'Weiss';
      msg = 'Schachmatt! $winner gewinnt.';
    } else if (_game.in_stalemate) {
      msg = 'Patt - unentschieden.';
    } else if (_game.in_threefold_repetition) {
      msg = 'Remis durch Stellungswiederholung.';
    } else if (_game.insufficient_material) {
      msg = 'Remis - zu wenig Material.';
    } else {
      msg = 'Unentschieden.';
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
              _newGame();
            },
            child: const Text('Neues Spiel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Zum Menue'),
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
    if (_aiThinking) return 'Computer denkt ...';
    final side = _game.turn == ch.Chess.WHITE ? 'Weiss' : 'Schwarz';
    final check = _game.in_check ? '  -  Schach!' : '';
    return '$side am Zug$check';
  }

  String _glyph(ch.PieceType t) {
    if (t == ch.Chess.KING) return '\u265A';
    if (t == ch.Chess.QUEEN) return '\u265B';
    if (t == ch.Chess.ROOK) return '\u265C';
    if (t == ch.Chess.BISHOP) return '\u265D';
    if (t == ch.Chess.KNIGHT) return '\u265E';
    return '\u265F';
  }

  String _difficultyLabel() {
    if (_aiDepth == 1) return 'Leicht';
    if (_aiDepth == 3) return 'Schwer';
    return 'Mittel';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Honey Badger Chess'),
        actions: [
          if (widget.vsComputer)
            PopupMenuButton<int>(
              tooltip: 'Schwierigkeit',
              initialValue: _aiDepth,
              icon: const Icon(Icons.tune),
              onSelected: (v) => setState(() => _aiDepth = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('Leicht')),
                PopupMenuItem(value: 2, child: Text('Mittel')),
                PopupMenuItem(value: 3, child: Text('Schwer')),
              ],
            ),
          IconButton(
            tooltip: 'Zug zurueck',
            icon: const Icon(Icons.undo),
            onPressed: _undo,
          ),
          IconButton(
            tooltip: 'Neues Spiel',
            icon: const Icon(Icons.refresh),
            onPressed: _newGame,
          ),
        ],
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
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.vsComputer
                  ? 'Du spielst Weiss (unten)  -  Stufe: ${_difficultyLabel()}'
                  : 'Lokales 2-Spieler-Spiel',
              style: const TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Column(
      children: List.generate(8, (row) {
        return Expanded(
          child: Row(
            children: List.generate(8, (col) {
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
    final labelColor =
        isLight ? const Color(0xFF769656) : const Color(0xFFEEEED2);
    final piece = _game.get(square);
    final isSelected = square == _selected;
    final isTarget = _targets.contains(square);
    final isLastMove = square == _lastFrom || square == _lastTo;
    final rank = 8 - row;
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);

    return GestureDetector(
      onTap: () => _onSquareTap(square),
      child: Container(
        color: isSelected ? const Color(0xFFBBCB2B) : base,
        child: Stack(
          children: [
            // Letzter Zug: dezenter goldener Rahmen statt greller Flaeche.
            if (isLastMove && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xAAB58B00),
                      width: 3,
                    ),
                  ),
                ),
              ),
            if (col == 0)
              Positioned(
                top: 1,
                left: 2,
                child: Text('$rank',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: labelColor)),
              ),
            if (row == 7)
              Positioned(
                bottom: 1,
                right: 2,
                child: Text(file,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: labelColor)),
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
                    border:
                        Border.all(color: const Color(0xCCD32F2F), width: 3),
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
