import 'package:chess/chess.dart';

/// Einfache Schach-KI: Negamax mit Alpha-Beta-Pruning und Materialbewertung.
class ChessAI {
  final int depth;
  const ChessAI({this.depth = 2});

  int _pieceValue(PieceType t) {
    if (t == Chess.PAWN) return 100;
    if (t == Chess.KNIGHT) return 320;
    if (t == Chess.BISHOP) return 330;
    if (t == Chess.ROOK) return 500;
    if (t == Chess.QUEEN) return 900;
    if (t == Chess.KING) return 20000;
    return 0;
  }

  int _evaluate(Chess game) {
    int score = 0;
    final board = game.board;
    for (int i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece == null) continue;
      final v = _pieceValue(piece.type);
      score += (piece.color == Chess.WHITE) ? v : -v;
    }
    return score;
  }

  int _relativeEval(Chess game) {
    if (game.in_checkmate) return -99999;
    if (game.in_stalemate ||
        game.in_draw ||
        game.insufficient_material ||
        game.in_threefold_repetition) {
      return 0;
    }
    final base = _evaluate(game);
    return (game.turn == Chess.WHITE) ? base : -base;
  }

  int _negamax(Chess game, int d, int alpha, int beta) {
    if (d == 0 || game.game_over) {
      return _relativeEval(game);
    }
    final moves = game.generate_moves();
    if (moves.isEmpty) {
      return _relativeEval(game);
    }
    moves.sort((a, b) =>
        (b.captured != null ? 1 : 0) - (a.captured != null ? 1 : 0));
    int best = -1000000;
    for (final m in moves) {
      game.make_move(m);
      final score = -_negamax(game, d - 1, -beta, -alpha);
      game.undo_move();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  Move? findBestMove(Chess game) {
    final sim = game.copy();
    final moves = sim.generate_moves();
    if (moves.isEmpty) return null;
    moves.sort((a, b) =>
        (b.captured != null ? 1 : 0) - (a.captured != null ? 1 : 0));
    Move? best;
    int bestScore = -1000000;
    int alpha = -1000000;
    const int beta = 1000000;
    for (final m in moves) {
      sim.make_move(m);
      final score = -_negamax(sim, depth - 1, -beta, -alpha);
      sim.undo_move();
      if (best == null || score > bestScore) {
        bestScore = score;
        best = m;
      }
      if (score > alpha) alpha = score;
    }
    return best;
  }
}
