import 'dart:ui';

import 'package:flutter_cube/flutter_cube.dart' show Camera;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:honey_badger_chess/chess3d/board_raycast.dart';

void main() {
  group('squareCenter3D / squareAtWorldXZ', () {
    test('Rundreise fuer alle 64 Felder liefert dasselbe Feld zurueck', () {
      for (var file = 0; file < 8; file++) {
        for (var rank = 1; rank <= 8; rank++) {
          final square = '${String.fromCharCode(97 + file)}$rank';
          final center = squareCenter3D(square);
          expect(squareAtWorldXZ(center.x, center.z), square);
        }
      }
    });

    test('a1 und h8 liegen an gegenueberliegenden Brettecken', () {
      final a1 = squareCenter3D('a1');
      final h8 = squareCenter3D('h8');
      expect(a1.x, lessThan(0));
      expect(a1.z, greaterThan(0));
      expect(h8.x, greaterThan(0));
      expect(h8.z, lessThan(0));
    });

    test('Punkte weit ausserhalb des Bretts liefern null', () {
      expect(squareAtWorldXZ(100, 100), isNull);
      expect(squareAtWorldXZ(-100, 0), isNull);
    });
  });

  group('screenPointToSquare', () {
    test('Kamera senkrecht ueber dem Brett trifft das erwartete Feld', () {
      final camera = Camera(
        position: Vector3(0, 10, 0),
        target: Vector3(0, 0, 0),
        up: Vector3(0, 0, -1),
        fov: 30,
        viewportWidth: 400,
        viewportHeight: 400,
      );
      // e2 liegt bei x = 4-3.5 = 0.5, z = 3.5-1 = 2.5.
      final e2 = squareCenter3D('e2');
      // Projiziere e2 in Bildschirmkoordinaten, um den passenden Tap-Punkt
      // zu bestimmen (statt den Bildschirmmittelpunkt zu raten, der bei
      // einer Draufsicht exakt auf eine Feldecke faellt).
      final viewProj = camera.projectionMatrix.multiplied(camera.lookAtMatrix);
      final clip = Vector4(e2.x, e2.y, e2.z, 1.0)..applyMatrix4(viewProj);
      final ndcX = clip.x / clip.w;
      final ndcY = clip.y / clip.w;
      final screenX = (ndcX + 1) / 2 * 400;
      final screenY = (1 - ndcY) / 2 * 400;

      final square = screenPointToSquare(
        localPosition: Offset(screenX, screenY),
        viewportSize: const Size(400, 400),
        projectionMatrix: camera.projectionMatrix,
        viewMatrix: camera.lookAtMatrix,
      );
      expect(square, 'e2');
    });

    test('leere Viewport-Groesse liefert null statt eines Fehlers', () {
      final camera = Camera(viewportWidth: 0, viewportHeight: 0);
      final square = screenPointToSquare(
        localPosition: const Offset(10, 10),
        viewportSize: const Size(0, 0),
        projectionMatrix: camera.projectionMatrix,
        viewMatrix: camera.lookAtMatrix,
      );
      expect(square, isNull);
    });
  });
}
