import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import 'package:shared_preferences/shared_preferences.dart';
import 'board_mode_prefs.dart';
import 'chess_ai.dart';
import 'hbc_feedback.dart';
import 'ui/hbc_theme.dart';
import 'widgets/board_surface.dart';

const _aiDepthPrefsKey = 'ai_depth';

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
  bool _use3D = false;

  @override
  void initState() {
    super.initState();
    _game = ch.Chess();
    _loadDifficulty();
    _loadBoardMode();
  }

  Future<void> _loadDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_aiDepthPrefsKey);
    if (saved == null || !mounted) return;
    setState(() => _aiDepth = saved);
  }

  Future<void> _loadBoardMode() async {
    final use3D = await loadUse3DBoard();
    if (!mounted) return;
    setState(() => _use3D = use3D);
  }

  void _toggleBoardMode() {
    setState(() => _use3D = !_use3D);
    saveUse3DBoard(_use3D);
  }

  Future<void> _setDifficulty(int depth) async {
    setState(() => _aiDepth = depth);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiDepthPrefsKey, depth);
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
    final captured = chosen.captured != null;
    _game.move(chosen);
    captured ? HbcFeedback.capture() : HbcFeedback.move();
    if (_game.in_check) HbcFeedback.check();
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
      final captured = move.captured != null;
      _game.move({
        'from': move.fromAlgebraic,
        'to': move.toAlgebraic,
        if (move.promotion != null) 'promotion': 'q',
      });
      captured ? HbcFeedback.capture() : HbcFeedback.move();
      if (_game.in_check) HbcFeedback.check();
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
    HbcFeedback.gameEnd();
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
          IconButton(
            tooltip: _use3D ? 'Zu 2D wechseln' : 'Zu 3D wechseln',
            icon: Icon(_use3D ? Icons.grid_on : Icons.view_in_ar),
            onPressed: _toggleBoardMode,
          ),
          if (widget.vsComputer)
            PopupMenuButton<int>(
              tooltip: 'Schwierigkeit',
              initialValue: _aiDepth,
              icon: const Icon(Icons.tune),
              onSelected: _setDifficulty,
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
            color: HbcColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              _status(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: (_game.in_check && !_game.game_over)
                    ? HbcColors.danger
                    : HbcColors.ink,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: BoardSurface(
                    game: _game,
                    use3D: _use3D,
                    selected: _selected,
                    targets: _targets,
                    lastFrom: _lastFrom,
                    lastTo: _lastTo,
                    onSquareTap: _onSquareTap,
                  ),
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
              style: const TextStyle(color: HbcColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
