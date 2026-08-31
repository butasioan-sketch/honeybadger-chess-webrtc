import 'dart:math' as math;

import 'package:flutter_cube/flutter_cube.dart' show Polygon;
import 'package:vector_math/vector_math_64.dart';

/// Ein Punkt eines Drechsel-Profils: Radius und Hoehe (von unten nach
/// oben, aufsteigend).
typedef ProfilePoint = ({double radius, double height});

/// Das rohe Vertex-/Index-Ergebnis einer Mesh-Erzeugung, bevor daraus ein
/// `flutter_cube`-`Mesh` (mit Farbe/Material) gebaut wird.
class RawMesh {
  final List<Vector3> vertices;
  final List<Polygon> indices;
  const RawMesh(this.vertices, this.indices);

  /// Verschiebt alle Vertices um [offset] (z.B. um mehrere Teile an
  /// verschiedenen Stellen zusammenzusetzen, bevor man daraus ein
  /// gemeinsames Mesh baut).
  RawMesh translated(Vector3 offset) {
    return RawMesh(vertices.map((v) => v + offset).toList(), indices);
  }

  /// Fuegt ein weiteres RawMesh hinzu (Indices werden um die aktuelle
  /// Vertex-Anzahl verschoben).
  RawMesh merge(RawMesh other) {
    final base = vertices.length;
    return RawMesh(
      [...vertices, ...other.vertices],
      [
        ...indices,
        ...other.indices.map(
          (p) => Polygon(p.vertex0 + base, p.vertex1 + base, p.vertex2 + base),
        ),
      ],
    );
  }
}

/// Baut ein rotationssymmetrisches ("gedrechseltes") Mesh: das [profile]
/// (Radius je Hoehe) wird um die Y-Achse mit [segments] Facetten rotiert.
/// Boden/Deckel werden automatisch geschlossen, ausser der Radius dort
/// bereits 0 ist (dann laeuft die Kontur ohnehin zu einer Spitze zusammen).
RawMesh buildLatheMesh(List<ProfilePoint> profile, {int segments = 20}) {
  assert(profile.length >= 2, 'Ein Drechsel-Profil braucht mind. 2 Punkte');
  assert(segments >= 3);

  final vertices = <Vector3>[];
  final indices = <Polygon>[];
  final ringStart = <int>[];

  for (final p in profile) {
    ringStart.add(vertices.length);
    for (var j = 0; j < segments; j++) {
      final theta = 2 * math.pi * j / segments;
      vertices.add(
        Vector3(
          p.radius * math.cos(theta),
          p.height,
          p.radius * math.sin(theta),
        ),
      );
    }
  }

  for (var r = 0; r < profile.length - 1; r++) {
    final a0 = ringStart[r];
    final b0 = ringStart[r + 1];
    for (var j = 0; j < segments; j++) {
      final jn = (j + 1) % segments;
      final a = a0 + j, aN = a0 + jn;
      final b = b0 + j, bN = b0 + jn;
      indices.add(Polygon(a, b, bN));
      indices.add(Polygon(a, bN, aN));
    }
  }

  if (profile.first.radius > 0) {
    final center = vertices.length;
    vertices.add(Vector3(0, profile.first.height, 0));
    final r0 = ringStart[0];
    for (var j = 0; j < segments; j++) {
      final jn = (j + 1) % segments;
      indices.add(Polygon(center, r0 + jn, r0 + j));
    }
  }

  if (profile.last.radius > 0) {
    final center = vertices.length;
    vertices.add(Vector3(0, profile.last.height, 0));
    final rL = ringStart.last;
    for (var j = 0; j < segments; j++) {
      final jn = (j + 1) % segments;
      indices.add(Polygon(center, rL + j, rL + jn));
    }
  }

  return RawMesh(vertices, indices);
}

/// Ein simpler Quader (fuer Handgemachtes wie das Kreuz auf dem Koenig),
/// zentriert auf der X/Z-Achse, von [yMin] bis [yMax] hoch.
RawMesh buildBox({
  required double width,
  required double depth,
  required double yMin,
  required double yMax,
}) {
  final hw = width / 2;
  final hd = depth / 2;
  final vertices = [
    Vector3(-hw, yMin, -hd),
    Vector3(hw, yMin, -hd),
    Vector3(hw, yMin, hd),
    Vector3(-hw, yMin, hd),
    Vector3(-hw, yMax, -hd),
    Vector3(hw, yMax, -hd),
    Vector3(hw, yMax, hd),
    Vector3(-hw, yMax, hd),
  ];
  const f = [
    [0, 1, 2, 3], // unten
    [4, 6, 5, 7], // oben (umgekehrte Reihenfolge zu unten)
    [0, 4, 5, 1], // -Z Seite
    [1, 5, 6, 2], // +X Seite
    [2, 6, 7, 3], // +Z Seite
    [3, 7, 4, 0], // -X Seite
  ];
  final indices = <Polygon>[];
  for (final quad in f) {
    indices.add(Polygon(quad[0], quad[1], quad[2]));
    indices.add(Polygon(quad[0], quad[2], quad[3]));
  }
  return RawMesh(vertices, indices);
}
