import 'dart:math' as math;

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'package:vector_math/vector_math_64.dart' as vm;

import 'board_raycast.dart';
import 'lathe_mesh.dart' show RawMesh;
import 'piece_meshes.dart';

const Color _lightSquare = Color(0xFFEEEED2);
const Color _darkSquare = Color(0xFF769656);
const Color _selectedSquare = Color(0xFFBBCB2B);
const Color _lightSquareTarget = Color(0xFFE8A33D);
const Color _darkSquareTarget = Color(0xFFB5762A);
const Color _lightSquareLastMove = Color(0xFFF5E08A);
const Color _darkSquareLastMove = Color(0xFFB59B3C);
const Color _tableColor = Color(0xFF241A12);
const Color _boardBackground = Color(0xFF14100C);

// Kamera-Grenzen: nie unter das Brett, nie auf die Kante kippen und nie
// spiegelverkehrt "von unten" enden - Elevation ist der Winkel ueber der
// Brettebene, in Radiant.
const double _minElevation = 0.28; // ~16 Grad ueber dem Brett
const double _maxElevation = 1.45; // ~83 Grad, knapp unter der Draufsicht
const double _minDistance = 6.0;
const double _maxDistance = 20.0;
const double _defaultDistance = 12.08;
const double _defaultElevation = 0.68; // entspricht der alten Kamera-Pose

final Map<String, RawMesh> _pieceMeshCache = {};
RawMesh _cachedPieceMesh(ch.PieceType type) {
  return _pieceMeshCache.putIfAbsent(type.name, () => pieceMesh(type));
}

/// Echtes 3D-Schachbrett (prozedural erzeugte Low-Poly-Figuren, echte
/// Phong-Beleuchtung, freie Orbit-Kamera per Drag/Pinch mit festen
/// Grenzen). Bietet dieselbe Schnittstelle wie [ChessBoardView] (siehe
/// widgets/chess_board_view.dart), damit beide Darstellungen austauschbar
/// sind.
class ChessBoard3D extends StatefulWidget {
  final ch.Chess game;
  final String? selected;
  final Set<String> targets;
  final String? lastFrom;
  final String? lastTo;
  final bool flipped;
  final void Function(String square)? onSquareTap;

  const ChessBoard3D({
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
  State<ChessBoard3D> createState() => _ChessBoard3DState();
}

class _ChessBoard3DState extends State<ChessBoard3D> {
  cube.Scene? _scene;
  double _azimuth = 0;
  double _elevation = _defaultElevation;
  double _distance = _defaultDistance;
  double _gestureStartDistance = _defaultDistance;

  // Audit-Fund (3D-Perf): build() rief bisher bedingungslos
  // _syncSceneObjects() auf, was bei JEDEM Orbit-Drag/Pinch-Frame (ueber
  // setState in _handleScaleUpdate) alle 64 Felder + bis zu 32 Figuren neu
  // erzeugt hat - nur um die Kamera zu bewegen. Jetzt wird der Inhalt nur
  // noch neu aufgebaut, wenn sich die Stellung/Auswahl/Hervorhebung
  // tatsaechlich geaendert hat (Signatur-Vergleich in didUpdateWidget),
  // waehrend Kamera-Aenderungen ausschliesslich scene.update() ausloesen -
  // das triggert direkt den internen Repaint von flutter_cube's Cube-
  // Widget, ohne dass unser eigenes build() (und damit _syncSceneObjects)
  // je laufen muss.
  String? _lastSyncedSignature;

  String _computeSignature() {
    final sortedTargets = widget.targets.toList()..sort();
    return '${widget.game.generate_fen()}|${widget.selected}|'
        '${sortedTargets.join(",")}|${widget.lastFrom}|${widget.lastTo}';
  }

  void _onSceneCreated(cube.Scene scene) {
    _scene = scene;
    scene.light.position.setValues(2.5, 9.0, -4.0);
    scene.light.setColor(Colors.white, 0.5, 0.85, 0.35);
    _resetCamera();
    _syncSceneObjects();
    _lastSyncedSignature = _computeSignature();
    if (mounted) setState(() {});
  }

  void _resetCamera() {
    _azimuth = widget.flipped ? math.pi : 0;
    _elevation = _defaultElevation;
    _distance = _defaultDistance;
    _applyCamera();
  }

  void _applyCamera() {
    final scene = _scene;
    if (scene == null) return;
    final x = _distance * math.cos(_elevation) * math.sin(_azimuth);
    final y = _distance * math.sin(_elevation);
    final z = _distance * math.cos(_elevation) * math.cos(_azimuth);
    scene.camera.position.setValues(x, y, z);
    scene.camera.target.setValues(0, 0, 0);
    scene.camera.up.setValues(0, 1, 0);
    scene.camera.fov = 42;
    // Loest den Repaint direkt ueber flutter_cube's eigenen onUpdate-Hook
    // aus (siehe Klassendoc) - kein setState auf diesem Widget noetig.
    scene.update();
  }

  @override
  void didUpdateWidget(covariant ChessBoard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped != widget.flipped) {
      _resetCamera();
    }
    final signature = _computeSignature();
    if (_scene != null && signature != _lastSyncedSignature) {
      _syncSceneObjects();
      _lastSyncedSignature = signature;
    }
  }

  cube.Material _materialForColor(
    Color color, {
    double ambientFactor = 0.75,
    double specular = 0.06,
    double shininess = 4,
  }) {
    final m = cube.Material();
    final base = vm.Vector3(
      color.r.toDouble(),
      color.g.toDouble(),
      color.b.toDouble(),
    );
    m.diffuse = base;
    m.ambient = base * ambientFactor;
    m.specular = vm.Vector3.all(specular);
    m.shininess = shininess;
    return m;
  }

  cube.Mesh _flatQuadMesh(Color color, double halfSize) {
    final h = halfSize;
    return cube.Mesh(
      vertices: [
        vm.Vector3(-h, 0, -h),
        vm.Vector3(h, 0, -h),
        vm.Vector3(h, 0, h),
        vm.Vector3(-h, 0, h),
      ],
      indices: [cube.Polygon(0, 1, 2), cube.Polygon(0, 2, 3)],
      material: _materialForColor(color, ambientFactor: 0.6, shininess: 2),
    );
  }

  Color _squareColor(String square, bool isLight) {
    if (square == widget.selected) return _selectedSquare;
    if (square == widget.lastFrom || square == widget.lastTo) {
      return isLight ? _lightSquareLastMove : _darkSquareLastMove;
    }
    if (widget.targets.contains(square)) {
      return isLight ? _lightSquareTarget : _darkSquareTarget;
    }
    return isLight ? _lightSquare : _darkSquare;
  }

  void _addTable(cube.Scene scene) {
    // Ein einfacher, etwas groesserer Untergrund, damit das Brett nicht
    // frei im schwarzen Nichts zu schweben scheint.
    final obj = cube.Object(
      name: 'table',
      position: vm.Vector3(0, -0.03, 0),
      mesh: _flatQuadMesh(_tableColor, 5.2),
      lighting: true,
      backfaceCulling: false,
    );
    scene.world.add(obj);
  }

  void _addBoardSquares(cube.Scene scene) {
    for (var file = 0; file < 8; file++) {
      for (var rank = 1; rank <= 8; rank++) {
        final square = '${String.fromCharCode(97 + file)}$rank';
        final isLight = (file + rank) % 2 == 0;
        final center = squareCenter3D(square);
        final obj = cube.Object(
          name: 'square_$square',
          position: vm.Vector3(center.x, 0.0, center.z),
          mesh: _flatQuadMesh(_squareColor(square, isLight), 0.5),
          lighting: true,
          backfaceCulling: false,
        );
        scene.world.add(obj);
      }
    }
  }

  void _addPieces(cube.Scene scene) {
    for (var file = 0; file < 8; file++) {
      for (var rank = 1; rank <= 8; rank++) {
        final square = '${String.fromCharCode(97 + file)}$rank';
        final piece = widget.game.get(square);
        if (piece == null) continue;
        final raw = _cachedPieceMesh(piece.type);
        final isWhite = piece.color == ch.Chess.WHITE;
        final mesh = cube.Mesh(
          vertices: raw.vertices,
          indices: raw.indices,
          material: _materialForColor(
            isWhite ? const Color(0xFFF5F1E6) : const Color(0xFF3A342E),
            ambientFactor: isWhite ? 0.6 : 0.62,
            specular: 0.35,
            shininess: 22,
          ),
        );
        final center = squareCenter3D(square);
        final obj = cube.Object(
          name: 'piece_$square',
          position: vm.Vector3(center.x, 0.0, center.z),
          mesh: mesh,
          lighting: true,
          backfaceCulling: false,
        );
        scene.world.add(obj);
      }
    }
  }

  void _syncSceneObjects() {
    final scene = _scene;
    if (scene == null) return;
    scene.world.children.clear();
    _addTable(scene);
    _addBoardSquares(scene);
    _addPieces(scene);
  }

  void _handleTap(TapUpDetails details) {
    final scene = _scene;
    if (scene == null || widget.onSquareTap == null) return;
    final square = screenPointToSquare(
      localPosition: details.localPosition,
      viewportSize: Size(
        scene.camera.viewportWidth,
        scene.camera.viewportHeight,
      ),
      projectionMatrix: scene.camera.projectionMatrix,
      viewMatrix: scene.camera.lookAtMatrix,
    );
    if (square != null) widget.onSquareTap!(square);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureStartDistance = _distance;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Bewusst KEIN setState hier - das wuerde build() (und damit
    // _syncSceneObjects) auf jedem Drag-Frame erneut laufen lassen.
    // _applyCamera() loest den Repaint direkt ueber scene.update() aus.
    _azimuth -= details.focalPointDelta.dx * 0.012;
    _elevation = (_elevation - details.focalPointDelta.dy * 0.012).clamp(
      _minElevation,
      _maxElevation,
    );
    if (details.scale != 1.0) {
      _distance = (_gestureStartDistance / details.scale).clamp(
        _minDistance,
        _maxDistance,
      );
    }
    _applyCamera();
  }

  @override
  Widget build(BuildContext context) {
    // Absichtlich KEIN _syncSceneObjects() hier - der Szeneninhalt wird
    // ausschliesslich in _onSceneCreated (einmalig) und didUpdateWidget
    // (nur bei tatsaechlicher Stellungsaenderung) aktualisiert. build()
    // liefert nur noch das statische Geruest.
    return Container(
      color: _boardBackground,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTapUp: _handleTap,
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              child: cube.Cube(
                interactive: false,
                onSceneCreated: _onSceneCreated,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: _ResetCameraButton(onPressed: _resetCamera),
          ),
        ],
      ),
    );
  }
}

class _ResetCameraButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ResetCameraButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Kamera zuruecksetzen',
        icon: const Icon(Icons.center_focus_strong, color: Colors.white70),
        onPressed: onPressed,
      ),
    );
  }
}
