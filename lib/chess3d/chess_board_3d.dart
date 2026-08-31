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

final Map<String, RawMesh> _pieceMeshCache = {};
RawMesh _cachedPieceMesh(ch.PieceType type) {
  return _pieceMeshCache.putIfAbsent(type.name, () => pieceMesh(type));
}

/// Echtes 3D-Schachbrett (prozedural erzeugte Low-Poly-Figuren, echte
/// Phong-Beleuchtung, freie Orbit-Kamera per Drag/Pinch). Bietet dieselbe
/// Schnittstelle wie [ChessBoardView] (siehe widgets/chess_board_view.dart),
/// damit beide Darstellungen austauschbar sind.
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

  void _onSceneCreated(cube.Scene scene) {
    _scene = scene;
    scene.light.position.setValues(2.5, 9.0, -4.0);
    scene.light.setColor(Colors.white, 0.35, 0.8, 0.35);
    _resetCamera();
    if (mounted) setState(() {});
  }

  void _resetCamera() {
    final scene = _scene;
    if (scene == null) return;
    // Weiss steht auf Rang 1 bei Z=+3.5 (siehe squareCenter3D) - die
    // Kamera muss also per Default auf der positiven Z-Seite stehen,
    // damit Weiss unten/nah erscheint (wie beim 2D-Brett).
    scene.camera.position.setValues(0, 7.6, widget.flipped ? -9.4 : 9.4);
    scene.camera.target.setValues(0, 0, 0);
    scene.camera.up.setValues(0, 1, 0);
    scene.camera.fov = 42;
    scene.camera.zoom = 1.0;
  }

  @override
  void didUpdateWidget(covariant ChessBoard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped != widget.flipped) _resetCamera();
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

  cube.Mesh _flatSquareMesh(Color color) {
    const h = 0.5;
    return cube.Mesh(
      vertices: [
        vm.Vector3(-h, 0, -h),
        vm.Vector3(h, 0, -h),
        vm.Vector3(h, 0, h),
        vm.Vector3(-h, 0, h),
      ],
      indices: [cube.Polygon(0, 1, 2), cube.Polygon(0, 2, 3)],
      material: _materialForColor(color),
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

  void _addBoardSquares(cube.Scene scene) {
    for (var file = 0; file < 8; file++) {
      for (var rank = 1; rank <= 8; rank++) {
        final square = '${String.fromCharCode(97 + file)}$rank';
        final isLight = (file + rank) % 2 == 0;
        final center = squareCenter3D(square);
        final obj = cube.Object(
          name: 'square_$square',
          position: vm.Vector3(center.x, 0.0, center.z),
          mesh: _flatSquareMesh(_squareColor(square, isLight)),
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
            isWhite ? const Color(0xFFF3EFE4) : const Color(0xFF262220),
            ambientFactor: isWhite ? 0.55 : 0.45,
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

  @override
  Widget build(BuildContext context) {
    _syncSceneObjects();
    return GestureDetector(
      onTapUp: _handleTap,
      child: cube.Cube(onSceneCreated: _onSceneCreated),
    );
  }
}
