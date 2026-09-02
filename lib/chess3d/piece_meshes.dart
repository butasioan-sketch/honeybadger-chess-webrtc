import 'package:chess/chess.dart' as ch;
import 'package:flutter_cube/flutter_cube.dart' show Polygon;
import 'package:vector_math/vector_math_64.dart';

import 'lathe_mesh.dart';

/// Stilisierte, prozedural erzeugte Low-Poly-Schachfiguren (gedrechselt,
/// bis auf den Springer - der ist als flache extrudierte Silhouette
/// gebaut, weil ein Pferdekopf nicht rotationssymmetrisch ist). Alle
/// Figuren stehen auf einer 1x1-Feldflaeche zentriert bei (0,0) und
/// stehen mit der Basis bei y=0.

const double _baseRadius = 0.34;
const double _baseTopRadius = 0.32;
const double _baseHeight = 0.05;

List<ProfilePoint> _withBase(List<ProfilePoint> body) {
  return [
    (radius: _baseRadius, height: 0.0),
    (radius: _baseRadius, height: _baseHeight * 0.6),
    (radius: _baseTopRadius, height: _baseHeight),
    ...body,
  ];
}

RawMesh _pawnMesh() {
  return buildLatheMesh(
    _withBase([
      (radius: 0.20, height: 0.08),
      (radius: 0.15, height: 0.26),
      (radius: 0.23, height: 0.32),
      (radius: 0.15, height: 0.37),
      (radius: 0.15, height: 0.40),
      (radius: 0.12, height: 0.43),
      (radius: 0.16, height: 0.475),
      (radius: 0.11, height: 0.52),
      (radius: 0.0, height: 0.56),
    ]),
    segments: 16,
  );
}

RawMesh _rookMesh() {
  return buildLatheMesh(
    _withBase([
      (radius: 0.26, height: 0.09),
      (radius: 0.24, height: 0.40),
      (radius: 0.32, height: 0.46),
      (radius: 0.32, height: 0.56),
      (radius: 0.28, height: 0.60),
      (radius: 0.28, height: 0.63),
    ]),
    segments: 16,
  );
}

RawMesh _bishopMesh() {
  return buildLatheMesh(
    _withBase([
      (radius: 0.22, height: 0.09),
      (radius: 0.15, height: 0.42),
      (radius: 0.24, height: 0.46),
      (radius: 0.12, height: 0.50),
      (radius: 0.09, height: 0.62),
      (radius: 0.05, height: 0.68),
      (radius: 0.10, height: 0.705),
      (radius: 0.05, height: 0.73),
      (radius: 0.0, height: 0.76),
    ]),
    segments: 18,
  );
}

RawMesh _queenMesh() {
  return buildLatheMesh(
    _withBase([
      (radius: 0.26, height: 0.09),
      (radius: 0.17, height: 0.55),
      (radius: 0.27, height: 0.60),
      (radius: 0.15, height: 0.65),
      (radius: 0.22, height: 0.68),
      (radius: 0.13, height: 0.715),
      (radius: 0.22, height: 0.745),
      (radius: 0.13, height: 0.775),
      (radius: 0.20, height: 0.80),
      (radius: 0.10, height: 0.825),
      (radius: 0.145, height: 0.85),
      (radius: 0.0, height: 0.885),
    ]),
    segments: 20,
  );
}

RawMesh _kingMesh() {
  final body = buildLatheMesh(
    _withBase([
      (radius: 0.26, height: 0.09),
      (radius: 0.17, height: 0.60),
      (radius: 0.27, height: 0.65),
      (radius: 0.15, height: 0.70),
      (radius: 0.19, height: 0.735),
      (radius: 0.15, height: 0.77),
      (radius: 0.16, height: 0.80),
      (radius: 0.08, height: 0.83),
      (radius: 0.0, height: 0.86),
    ]),
    segments: 20,
  );
  // Kreuz oben auf der Kuppel - bewusst handgemacht, da nicht
  // rotationssymmetrisch.
  final vBar = buildBox(
    width: 0.045,
    depth: 0.045,
    yMin: 0.83,
    yMax: 0.965,
  ).translated(Vector3(0, 0, 0));
  final hBar = buildBox(width: 0.16, depth: 0.045, yMin: 0.885, yMax: 0.93);
  return body.merge(vBar).merge(hBar);
}

/// Springer: flache, extrudierte Pferdekopf-Silhouette (nicht
/// rotationssymmetrisch, daher kein Drechsel-Profil).
RawMesh _knightMesh() {
  // Silhouette in der X/Y-Ebene (von der Seite gesehen), grob ein
  // stilisierter Pferdekopf. Wird entlang Z extrudiert.
  final outline = <Vector3>[
    Vector3(0.00, 0.00, 0),
    Vector3(0.20, 0.00, 0),
    Vector3(0.20, 0.10, 0),
    Vector3(0.10, 0.22, 0),
    Vector3(0.12, 0.40, 0),
    Vector3(0.02, 0.52, 0),
    Vector3(-0.06, 0.56, 0), // Stirn
    Vector3(-0.17, 0.58, 0), // Nase
    Vector3(-0.20, 0.52, 0), // Maul unten
    Vector3(-0.10, 0.50, 0),
    Vector3(-0.14, 0.44, 0), // Kinn-Kerbe
    Vector3(-0.03, 0.40, 0),
    Vector3(-0.02, 0.30, 0),
    Vector3(-0.14, 0.20, 0), // Maehne
    Vector3(-0.20, 0.00, 0),
  ];
  return _extrudeOutline(
    outline,
    depth: 0.30,
    baseRadius: _baseRadius,
    baseHeight: _baseHeight,
  );
}

/// Extrudiert eine 2D-Silhouette (X/Y, im Uhrzeigersinn von vorne
/// gesehen definiert) entlang Z zu einem geschlossenen Koerper und
/// setzt sie auf einen gedrechselten Rundsockel.
RawMesh _extrudeOutline(
  List<Vector3> outline, {
  required double depth,
  required double baseRadius,
  required double baseHeight,
}) {
  final n = outline.length;
  final front = <Vector3>[];
  final back = <Vector3>[];
  for (final p in outline) {
    front.add(Vector3(p.x, p.y, depth / 2));
    back.add(Vector3(p.x, p.y, -depth / 2));
  }
  final vertices = [...front, ...back];
  final indices = <Polygon>[];

  // Vorder-/Rueckwand als einfacher Fan (die Silhouette ist ausreichend
  // konvex-nah, kleinere Unregelmaessigkeiten fallen bei einem
  // stilisierten Low-Poly-Modell nicht ins Gewicht).
  for (var i = 1; i < n - 1; i++) {
    indices.add(Polygon(0, i, i + 1)); // vorne
    indices.add(Polygon(n, n + i + 1, n + i)); // hinten (umgekehrt)
  }

  // Seitenwaende zwischen Vorder- und Rueckkontur.
  for (var i = 0; i < n; i++) {
    final iN = (i + 1) % n;
    final a = i, aN = iN;
    final b = n + i, bN = n + iN;
    indices.add(Polygon(a, aN, bN));
    indices.add(Polygon(a, bN, b));
  }

  final body = RawMesh(vertices, indices).translated(Vector3(0, baseHeight, 0));
  final base = buildLatheMesh([
    (radius: baseRadius, height: 0.0),
    (radius: baseRadius, height: baseHeight * 0.6),
    (radius: baseRadius * 0.94, height: baseHeight),
  ], segments: 16);
  return base.merge(body);
}

/// Liefert das prozedurale Mesh fuer einen Figurentyp.
RawMesh pieceMesh(ch.PieceType type) {
  if (type == ch.Chess.PAWN) return _pawnMesh();
  if (type == ch.Chess.ROOK) return _rookMesh();
  if (type == ch.Chess.KNIGHT) return _knightMesh();
  if (type == ch.Chess.BISHOP) return _bishopMesh();
  if (type == ch.Chess.QUEEN) return _queenMesh();
  return _kingMesh();
}
