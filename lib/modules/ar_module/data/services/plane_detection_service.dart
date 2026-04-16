import 'dart:async';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart';

/// Wraps ARCore plane-detection lifecycle.
///
/// Responsibilities:
///   • Maintain references to AR managers (injected, not created here).
///   • Emit detected plane polygon vertices via [planePolygonStream].
///   • Place a visual anchor node on the detected surface.
///
/// This class owns NO business logic — it is purely an AR data adapter.
class PlaneDetectionService {
  PlaneDetectionService();

  // ── Injected managers ──────────────────────────────────────────────────────
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;

  // ── Internal state ─────────────────────────────────────────────────────────
  final StreamController<List<Vector3>> _polygonController =
      StreamController<List<Vector3>>.broadcast();

  ARPlaneAnchor? _currentAnchor;
  ARNode? _planeNode;

  bool _isActive = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Stream of detected polygon vertices in AR world coordinates (XZ plane).
  Stream<List<Vector3>> get planePolygonStream => _polygonController.stream;

  bool get isActive => _isActive;

  /// Call once after ARView initialises its managers.
  void initialise({
    required ARSessionManager sessionManager,
    required ARObjectManager objectManager,
    required ARAnchorManager anchorManager,
  }) {
    _objectManager = objectManager;
    _anchorManager = anchorManager;
    _isActive = true;
  }

  /// Called by ARView when a plane hit-test succeeds (e.g. on tap).
  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitResults) async {
    if (!_isActive || _objectManager == null || _anchorManager == null) return;

    // Take the first plane hit — most confident detection.
    final ARHitTestResult? planeHit = hitResults
        .cast<ARHitTestResult?>()
        .firstWhere(
          (r) => r?.type == ARHitTestResultType.plane,
          orElse: () => null,
        );

    if (planeHit == null) return;

    // Remove previous anchor/node before placing new one.
    await _clearCurrentAnchor();

    // Create a new plane anchor at the hit location.
    final ARPlaneAnchor newAnchor = ARPlaneAnchor(
      transformation: planeHit.worldTransform,
    );
    final bool anchorAdded =
        await _anchorManager!.addAnchor(newAnchor) ?? false;
    if (!anchorAdded) return;
    _currentAnchor = newAnchor;

    // Place a visual marker node attached to the anchor.
    final ARNode markerNode = ARNode(
      type: NodeType.webGLB,
      uri: 'https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Box/glTF-Binary/Box.glb',
      scale: Vector3(0.5, 0.02, 1.0), // flat panel shape: 0.5m × 2cm × 1m
      position: Vector3(0, 0.01, 0),
      rotation: Vector4(1, 0, 0, 0),
      name: 'solar_panel_marker',
    );
    await _objectManager!.addNode(markerNode, planeAnchor: newAnchor);
    _planeNode = markerNode;

    // Emit synthesised polygon from the detected plane extent.
    final List<Vector3> polygon =
        _extractPlanePolygon(planeHit.worldTransform);
    if (!_polygonController.isClosed) {
      _polygonController.add(polygon);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Constructs an approximate rectangular polygon from the plane's
  /// world transform. Default half-extents of 1.5m × 1m represent a
  /// minimal detected surface; these grow as ARCore tracks more of the plane.
  List<Vector3> _extractPlanePolygon(Matrix4 worldTransform) {
    final Vector3 origin = worldTransform.getTranslation();

    const double halfW = 1.5;
    const double halfH = 1.0;

    return [
      Vector3(origin.x - halfW, origin.y, origin.z - halfH),
      Vector3(origin.x + halfW, origin.y, origin.z - halfH),
      Vector3(origin.x + halfW, origin.y, origin.z + halfH),
      Vector3(origin.x - halfW, origin.y, origin.z + halfH),
    ];
  }

  Future<void> _clearCurrentAnchor() async {
    if (_planeNode != null) {
      _objectManager?.removeNode(_planeNode!);
      _planeNode = null;
    }
    if (_currentAnchor != null) {
      await _anchorManager?.removeAnchor(_currentAnchor!);
      _currentAnchor = null;
    }
  }

  /// Clean up streams and AR resources.
  Future<void> dispose() async {
    _isActive = false;
    await _clearCurrentAnchor();
    if (!_polygonController.isClosed) {
      await _polygonController.close();
    }
  }
}
