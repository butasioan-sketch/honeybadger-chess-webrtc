import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'board_mode_prefs.dart';
import 'chess3d/chess_board_3d.dart';
import 'crypto_service.dart';
import 'move_codec.dart';
import 'widgets/chess_board_view.dart';

/// Schach ueber die bereits verbundene, verschluesselte WebRTC-Leitung.
/// Der Host spielt Weiss, der Gast Schwarz. Jeder Zug wird verschluesselt
/// uebertragen.
class OnlineGameScreen extends StatefulWidget {
  final RTCDataChannel channel;
  final CryptoService crypto;
  final bool amWhite; // Host = true (Weiss), Gast = false (Schwarz)
  final RTCPeerConnection? peerConnection;

  const OnlineGameScreen({
    super.key,
    required this.channel,
    required this.crypto,
    required this.amWhite,
    this.peerConnection,
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
  bool _gameEnded = false;
  bool _peerConnected = true;
  bool _use3D = false;

  @override
  void initState() {
    super.initState();
    _game = ch.Chess();
    _loadBoardMode();
    // Eingehende Nachrichten dieser Leitung ab jetzt hier verarbeiten.
    widget.channel.onMessage = (RTCDataChannelMessage msg) async {
      try {
        final clear = await widget.crypto.decrypt(msg.text);
        if (isResignPayload(clear)) {
          // Eine Aufgabe nach Spielende ist kein gueltiges Ereignis mehr
          // (z.B. eine verspaetete/wiederholte Nachricht) - ignorieren.
          if (_gameEnded || _game.game_over) return;
          _endGame('Der Gegner hat aufgegeben - du gewinnst!');
          return;
        }
        final move = decodeMovePayload(clear);
        if (move != null) {
          _applyRemoteMove(move.from, move.to, move.ply);
        }
      } catch (_) {
        // Nachricht ignorieren, wenn sie nicht lesbar ist.
      }
    };
    widget.channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelClosed ||
          state == RTCDataChannelState.RTCDataChannelClosing) {
        _handleDisconnect();
      }
    };
    widget.peerConnection?.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _handleDisconnect();
      }
    };
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

  void _handleDisconnect() {
    if (!mounted || _gameEnded) return;
    setState(() => _peerConnected = false);
    _endGame('Verbindung zum Gegner verloren.');
  }

  Future<void> _resign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aufgeben?'),
        content: const Text('Willst du die Partie wirklich aufgeben?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aufgeben'),
          ),
        ],
      ),
    );
    if (confirmed != true || _gameEnded) return;
    if (_peerConnected) {
      try {
        final payload = encodeResignPayload();
        final encrypted = await widget.crypto.encrypt(payload);
        widget.channel.send(RTCDataChannelMessage(encrypted));
      } catch (_) {
        // Wenn das Senden fehlschlaegt, trotzdem lokal beenden.
      }
    }
    _endGame('Du hast aufgegeben.');
  }

  void _endGame(String msg) {
    if (!mounted || _gameEnded) return;
    _gameEnded = true;
    setState(() {});
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

  bool get _myTurn => (_game.turn == ch.Chess.WHITE) == widget.amWhite;

  void _onSquareTap(String square) {
    if (_game.game_over || !_myTurn || _gameEnded) return;

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
    final payload = encodeMovePayload(from, to, _game.history.length);
    final encrypted = await widget.crypto.encrypt(payload);
    widget.channel.send(RTCDataChannelMessage(encrypted));
    _checkEnd();
  }

  void _applyRemoteMove(String from, String to, int ply) {
    if (!canAcceptRemoteMove(
      game: _game,
      amWhite: widget.amWhite,
      gameEnded: _gameEnded,
      ply: ply,
    )) {
      return;
    }
    // Zusaetzlich zur Zugrecht-Pruefung oben: die gezogene Figur muss dem
    // Gegner gehoeren (Verteidigung in der Tiefe, falls die Turn-Logik
    // irgendwo anders einmal falsch verdrahtet wird).
    final opponentColor = widget.amWhite ? ch.Chess.BLACK : ch.Chess.WHITE;
    final piece = _game.get(from);
    if (piece == null || piece.color != opponentColor) return;
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
    _endGame(msg);
  }

  String _status() {
    if (!_peerConnected) return 'Verbindung verloren';
    if (_game.game_over) {
      if (_game.in_checkmate) return 'Schachmatt';
      return 'Remis';
    }
    final check = _game.in_check ? '  -  Schach!' : '';
    return (_myTurn ? 'Du bist am Zug' : 'Gegner ist am Zug') + check;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Online-Schach (${widget.amWhite ? "Weiss" : "Schwarz"})'),
        actions: [
          IconButton(
            tooltip: _use3D ? 'Zu 2D wechseln' : 'Zu 3D wechseln',
            icon: Icon(_use3D ? Icons.grid_on : Icons.view_in_ar),
            onPressed: _toggleBoardMode,
          ),
          IconButton(
            tooltip: 'Aufgeben',
            icon: const Icon(Icons.flag),
            onPressed: (_gameEnded || _game.game_over) ? null : _resign,
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
                  child: _use3D
                      ? ChessBoard3D(
                          game: _game,
                          selected: _selected,
                          targets: _targets,
                          lastFrom: _lastFrom,
                          lastTo: _lastTo,
                          flipped: !widget.amWhite,
                          onSquareTap: _onSquareTap,
                        )
                      : ChessBoardView(
                          game: _game,
                          selected: _selected,
                          targets: _targets,
                          lastFrom: _lastFrom,
                          lastTo: _lastTo,
                          flipped: !widget.amWhite,
                          onSquareTap: _onSquareTap,
                        ),
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
}
