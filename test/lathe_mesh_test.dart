import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:honey_badger_chess/chess3d/lathe_mesh.dart';

bool _isFinite(Vector3 v) => v.x.isFinite && v.y.isFinite && v.z.isFinite;

void main() {
  group('buildLatheMesh', () {
    test('einfacher Zylinder hat plausible Vertex-/Face-Anzahl', () {
      final mesh = buildLatheMesh([
        (radius: 1.0, height: 0.0),
        (radius: 1.0, height: 1.0),
      ], segments: 8);
      // 2 Ringe x 8 + 2 Kappen-Mittelpunkte
      expect(mesh.vertices.length, 8 * 2 + 2);
      // Seitenflaechen: 8 Quads x 2 Dreiecke + 2 Kappen x 8 Dreiecke
      expect(mesh.indices.length, 8 * 2 + 8 + 8);
    });

    test('alle Dreieck-Indices verweisen auf existierende Vertices', () {
      final mesh = buildLatheMesh([
        (radius: 0.3, height: 0.0),
        (radius: 0.2, height: 0.5),
        (radius: 0.0, height: 1.0),
      ], segments: 12);
      for (final p in mesh.indices) {
        for (final i in [p.vertex0, p.vertex1, p.vertex2]) {
          expect(i, greaterThanOrEqualTo(0));
          expect(i, lessThan(mesh.vertices.length));
        }
      }
    });

    test('alle Vertex-Koordinaten sind endlich (keine NaN/Inf)', () {
      final mesh = buildLatheMesh([
        (radius: 0.3, height: 0.0),
        (radius: 0.0, height: 1.0),
      ], segments: 10);
      expect(mesh.vertices.every(_isFinite), isTrue);
    });

    test('Radius 0 am oberen Ende erzeugt keine separate Deckel-Kappe '
        '(Spitze laeuft von selbst zusammen)', () {
      final withPoint = buildLatheMesh([
        (radius: 0.3, height: 0.0),
        (radius: 0.0, height: 1.0),
      ], segments: 10);
      final withFlatTop = buildLatheMesh([
        (radius: 0.3, height: 0.0),
        (radius: 0.2, height: 1.0),
      ], segments: 10);
      // Die spitz zulaufende Variante hat einen Vertex weniger (keine
      // Deckel-Mittelpunkt-Kappe oben).
      expect(withPoint.vertices.length, withFlatTop.vertices.length - 1);
    });

    test('Bounding Box entspricht dem angegebenen Profil', () {
      final mesh = buildLatheMesh([
        (radius: 0.4, height: 0.0),
        (radius: 0.15, height: 0.9),
      ], segments: 16);
      final maxRadius = mesh.vertices
          .map((v) => math.sqrt(v.x * v.x + v.z * v.z))
          .reduce((a, b) => a > b ? a : b);
      final maxHeight = mesh.vertices
          .map((v) => v.y)
          .reduce((a, b) => a > b ? a : b);
      final minHeight = mesh.vertices
          .map((v) => v.y)
          .reduce((a, b) => a < b ? a : b);
      expect(maxRadius, closeTo(0.4, 1e-9));
      expect(maxHeight, closeTo(0.9, 1e-9));
      expect(minHeight, closeTo(0.0, 1e-9));
    });
  });

  group('buildBox', () {
    test('erzeugt 8 Vertices und 12 Dreiecke (6 Seiten x 2)', () {
      final box = buildBox(width: 0.1, depth: 0.1, yMin: 0.0, yMax: 0.2);
      expect(box.vertices.length, 8);
      expect(box.indices.length, 12);
    });
  });

  group('RawMesh.merge / translated', () {
    test('merge haengt Vertices/Indices korrekt mit Offset an', () {
      final a = buildBox(width: 1, depth: 1, yMin: 0, yMax: 1);
      final b = buildBox(width: 1, depth: 1, yMin: 0, yMax: 1);
      final merged = a.merge(b);
      expect(merged.vertices.length, a.vertices.length + b.vertices.length);
      for (final p in merged.indices) {
        for (final i in [p.vertex0, p.vertex1, p.vertex2]) {
          expect(i, lessThan(merged.vertices.length));
        }
      }
    });

    test('translated verschiebt alle Vertices um den Offset', () {
      final a = buildBox(width: 1, depth: 1, yMin: 0, yMax: 1);
      final moved = a.translated(Vector3(5, 0, 0));
      for (var i = 0; i < a.vertices.length; i++) {
        expect(moved.vertices[i].x, closeTo(a.vertices[i].x + 5, 1e-9));
      }
    });
  });
}
