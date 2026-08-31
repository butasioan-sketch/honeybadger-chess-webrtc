import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/chess3d/piece_meshes.dart';

void main() {
  final types = [
    ch.Chess.PAWN,
    ch.Chess.ROOK,
    ch.Chess.KNIGHT,
    ch.Chess.BISHOP,
    ch.Chess.QUEEN,
    ch.Chess.KING,
  ];

  for (final type in types) {
    test(
      'pieceMesh(${type.name}) liefert ein gueltiges, nicht-leeres Mesh',
      () {
        final mesh = pieceMesh(type);
        expect(mesh.vertices, isNotEmpty);
        expect(mesh.indices, isNotEmpty);
        for (final v in mesh.vertices) {
          expect(v.x.isFinite, isTrue);
          expect(v.y.isFinite, isTrue);
          expect(v.z.isFinite, isTrue);
        }
        for (final p in mesh.indices) {
          for (final i in [p.vertex0, p.vertex1, p.vertex2]) {
            expect(i, greaterThanOrEqualTo(0));
            expect(i, lessThan(mesh.vertices.length));
          }
        }
      },
    );

    test('pieceMesh(${type.name}) steht auf der Grundflaeche (min. y ~ 0) '
        'und passt in ein Schachfeld (max. Radius < 0.5)', () {
      final mesh = pieceMesh(type);
      final minY = mesh.vertices
          .map((v) => v.y)
          .reduce((a, b) => a < b ? a : b);
      final maxRadiusSq = mesh.vertices
          .map((v) => v.x * v.x + v.z * v.z)
          .reduce((a, b) => a > b ? a : b);
      expect(minY, closeTo(0.0, 1e-9));
      expect(maxRadiusSq, lessThan(0.25));
    });
  }

  test('König ist die höchste Figur, Bauer die niedrigste', () {
    double maxHeight(ch.PieceType t) =>
        pieceMesh(t).vertices.map((v) => v.y).reduce((a, b) => a > b ? a : b);

    final king = maxHeight(ch.Chess.KING);
    final pawn = maxHeight(ch.Chess.PAWN);
    for (final t in types) {
      expect(maxHeight(t), lessThanOrEqualTo(king));
    }
    expect(pawn, lessThan(king));
  });
}
