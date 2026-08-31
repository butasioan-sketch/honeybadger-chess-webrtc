import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math_64.dart';

/// Geometrie des 3D-Bretts: 8x8 Felder à 1x1 Einheiten, zentriert auf den
/// Ursprung, in der X/Z-Ebene bei y=0. Datei a..h liegt auf der X-Achse,
/// Reihe 1..8 auf der Z-Achse (Reihe 1 bei +Z, Reihe 8 bei -Z).
///
/// Diese Datei enthaelt reine Mathe-Funktionen (kein Rendering), damit sie
/// unabhaengig vom 3D-Renderer getestet werden kann.

/// Weltkoordinaten (x, z) des Mittelpunkts eines Feldes, y=0.
Vector3 squareCenter3D(String square) {
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1)) - 1;
  return Vector3(file - 3.5, 0.0, 3.5 - rank);
}

/// Feld-Code fuer eine Weltposition (x, z), oder `null`, wenn sie
/// ausserhalb des 8x8-Bretts liegt.
String? squareAtWorldXZ(double x, double z) {
  final fileIdx = (x + 3.5).round();
  final rankIdx = (3.5 - z).round();
  if (fileIdx < 0 || fileIdx > 7 || rankIdx < 0 || rankIdx > 7) return null;
  final file = String.fromCharCode('a'.codeUnitAt(0) + fileIdx);
  return '$file${rankIdx + 1}';
}

Vector4 _unproject(double ndcX, double ndcY, double ndcZ, Matrix4 invViewProj) {
  final v = Vector4(ndcX, ndcY, ndcZ, 1.0)..applyMatrix4(invViewProj);
  return v;
}

/// Wandelt einen Tap-Punkt in lokalen Widget-Pixelkoordinaten in das
/// getroffene Brettfeld um (Strahl von der Kamera durch den Tap-Punkt,
/// geschnitten mit der Brettebene y=0). Gibt `null` zurueck, wenn der
/// Strahl das Brett verfehlt (z.B. Tap am Rand/Hintergrund) oder
/// nach hinten zeigt.
String? screenPointToSquare({
  required Offset localPosition,
  required Size viewportSize,
  required Matrix4 projectionMatrix,
  required Matrix4 viewMatrix,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) return null;
  final ndcX = 2.0 * localPosition.dx / viewportSize.width - 1.0;
  final ndcY = 1.0 - 2.0 * localPosition.dy / viewportSize.height;

  final viewProj = projectionMatrix.multiplied(viewMatrix);
  final invViewProj = Matrix4.inverted(viewProj);

  final nearH = _unproject(ndcX, ndcY, -1.0, invViewProj);
  final farH = _unproject(ndcX, ndcY, 1.0, invViewProj);
  if (nearH.w == 0 || farH.w == 0) return null;
  final near = Vector3(nearH.x / nearH.w, nearH.y / nearH.w, nearH.z / nearH.w);
  final far = Vector3(farH.x / farH.w, farH.y / farH.w, farH.z / farH.w);

  final dir = far - near;
  if (dir.y.abs() < 1e-9) return null; // Strahl parallel zur Brettebene
  final t = -near.y / dir.y;
  if (t < 0) return null; // Brettebene liegt "hinter" der Kamera

  final hit = near + dir * t;
  return squareAtWorldXZ(hit.x, hit.z);
}
