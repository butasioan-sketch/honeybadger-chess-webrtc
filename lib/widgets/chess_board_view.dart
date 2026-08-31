import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;

/// Unicode-Glyphe fuer eine Schachfigur (fuer alle Brett-Darstellungen der
/// App gleich).
String pieceGlyph(ch.PieceType t) {
  if (t == ch.Chess.KING) return '♚';
  if (t == ch.Chess.QUEEN) return '♛';
  if (t == ch.Chess.ROOK) return '♜';
  if (t == ch.Chess.BISHOP) return '♝';
  if (t == ch.Chess.KNIGHT) return '♞';
  return '♟';
}

/// Wiederverwendbares 8x8-Schachbrett. Enthaelt keine Spiellogik - die
/// liefert der Aufrufer ueber [game] (aktuelle Stellung) und die
/// Highlight-/Callback-Parameter. Wird von der lokalen Partie, der
/// Online-Partie und dem Cipher-Playback gemeinsam genutzt.
class ChessBoardView extends StatelessWidget {
  final ch.Chess game;
  final String? selected;
  final Set<String> targets;
  final String? lastFrom;
  final String? lastTo;
  final bool flipped;
  final void Function(String square)? onSquareTap;

  const ChessBoardView({
    super.key,
    required this.game,
    this.selected,
    this.targets = const {},
    this.lastFrom,
    this.lastTo,
    this.flipped = false,
    this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(8, (r) {
        final row = flipped ? 7 - r : r;
        return Expanded(
          child: Row(
            children: List.generate(8, (c) {
              final col = flipped ? 7 - c : c;
              final rank = 8 - row;
              final file = String.fromCharCode('a'.codeUnitAt(0) + col);
              final square = '$file$rank';
              return Expanded(
                child: _ChessSquare(
                  key: ValueKey('square_$square'),
                  square: square,
                  row: row,
                  col: col,
                  piece: game.get(square),
                  isSelected: square == selected,
                  isTarget: targets.contains(square),
                  isLastMove: square == lastFrom || square == lastTo,
                  onTap: onSquareTap == null
                      ? null
                      : () => onSquareTap!(square),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _ChessSquare extends StatelessWidget {
  final String square;
  final int row;
  final int col;
  final ch.Piece? piece;
  final bool isSelected;
  final bool isTarget;
  final bool isLastMove;
  final VoidCallback? onTap;

  const _ChessSquare({
    super.key,
    required this.square,
    required this.row,
    required this.col,
    required this.piece,
    required this.isSelected,
    required this.isTarget,
    required this.isLastMove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = (row + col) % 2 == 0;
    final base = isLight ? const Color(0xFFEEEED2) : const Color(0xFF769656);
    final labelColor = isLight
        ? const Color(0xFF769656)
        : const Color(0xFFEEEED2);
    final rank = 8 - row;
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);

    return GestureDetector(
      onTap: onTap,
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
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
              ),
            if (row == 7)
              Positioned(
                bottom: 1,
                right: 2,
                child: Text(
                  file,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
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
                      color: const Color(0xCCD32F2F),
                      width: 3,
                    ),
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
                      pieceGlyph(piece!.type),
                      style: TextStyle(
                        fontSize: 100,
                        height: 1,
                        color: piece!.color == ch.Chess.WHITE
                            ? const Color(0xFFFAFAFA)
                            : const Color(0xFF1A1A1A),
                        shadows: const [
                          Shadow(
                            blurRadius: 1.5,
                            color: Color(0x99000000),
                            offset: Offset(0, 1),
                          ),
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
