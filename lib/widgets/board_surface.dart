import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../chess3d/chess_board_3d.dart';
import 'chess_board_view.dart';

/// Gemeinsamer Contract fuer die 2D- und die 3D-Brettdarstellung. Screens
/// reichen genau diese Parameter durch und muessen weder `ChessBoard3D`
/// noch `flutter_cube` kennen noch zwei fast identische Aufrufe pflegen -
/// das Umschalten zwischen 2D/3D passiert ausschliesslich hier.
class BoardSurface extends StatelessWidget {
  final ch.Chess game;
  final bool use3D;
  final String? selected;
  final Set<String> targets;
  final String? lastFrom;
  final String? lastTo;
  final bool flipped;
  final void Function(String square)? onSquareTap;

  const BoardSurface({
    super.key,
    required this.game,
    required this.use3D,
    this.selected,
    this.targets = const {},
    this.lastFrom,
    this.lastTo,
    this.flipped = false,
    this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    return use3D
        ? ChessBoard3D(
            game: game,
            selected: selected,
            targets: targets,
            lastFrom: lastFrom,
            lastTo: lastTo,
            flipped: flipped,
            onSquareTap: onSquareTap,
          )
        : ChessBoardView(
            game: game,
            selected: selected,
            targets: targets,
            lastFrom: lastFrom,
            lastTo: lastTo,
            flipped: flipped,
            onSquareTap: onSquareTap,
          );
  }
}
