import 'dart:io';

import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../domain/models/panel_model.dart';

/// Manages real 3D solar panel [ARNode] objects anchored to detected surfaces.
///
/// Uses a bundled local GLB (`assets/models/10781_Solar-Panels_V1.glb`) that is a
/// dark-blue monocrystalline panel shape with PBR material — guaranteed to
/// load offline, no runtime network dependency.
///
/// Architecture:
///   • One [ARPlaneAnchor] per panel cell for correct surface tracking.
///   • Scale is derived from each [PanelModel]'s physical dimensions (1 m × 2 m).
///   • Panels are placed in batches to avoid overwhelming the platform channel.
class ARNodeService {
  ARNodeService();

  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;
  bool _panelAssetReady = false;
  Future<void>? _panelAssetPrepareTask;

  /// Tracks all active anchors so we can remove them on reset.
  final List<ARNode> _nodes = [];
  final List<ARAnchor> _anchors = [];
  
  // Track logic panel layouts to easily re-calculate positions during lerp
  List<PanelModel> _currentLogicalPanels = [];

  // ar_flutter_plugin loads local GLB via fileSystemAppFolderGLB.
  // We copy the bundled asset into app_flutter once, then reference by filename.
  static const String _panelBundledAssetPath =
      'assets/models/10781_Solar-Panels_V1.glb';
  static const String _panelFileName = '10781_Solar-Panels_V1.glb';

  // Batch size to avoid overloading the ar_flutter_plugin platform channel.
  static const int _batchSize = 4;

  // ── GLB asset calibration ─────────────────────────────────────────────────
  // 10781_Solar-Panels_V1.glb is authored in Blender with 1 unit = 1 cm.
  // Therefore a 1 m-wide panel needs scale = 1 / 100 = 0.01.
  // The model stands upright by default; a -90° X rotation lays it flat.
  static const double _glbUnitsPerMetre = 100.0;
  // ignore: non_constant_identifier_names
  static final Matrix3 _flatRotation = Matrix3.identity()
    ..setRotationX(-3.14159265358979 / 2); // -90° X: upright → floor-flat

  bool get isInitialised => _objectManager != null && _anchorManager != null;
  int get activePanelCount => _nodes.length;

  /// Inject AR managers once ARView is ready.
  void init({
    required ARObjectManager objectManager,
    required ARAnchorManager anchorManager,
  }) {
    _objectManager = objectManager;
    _anchorManager = anchorManager;
  }

  /// STAGE 1 & 2: Places floating (un-anchored) panels for smooth interpolation.
  Future<void> placePanelsFloating(
      List<PanelModel> panels, Matrix4 baseTransform, {double scale = 0.05}) async {
    _currentLogicalPanels = panels;
    clearAll();

    try {
      await _ensurePanelAssetReady();
    } catch (e) {
      debugPrint('[ARNodeService] Failed to prepare GLB asset: $e');
      return;
    }

    for (int start = 0; start < panels.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, panels.length);
      final batch = panels.sublist(start, end);

      await Future.wait(
        batch.map((panel) => _placeOneFloatingPanel(panel, baseTransform, scale: scale)),
      );

      // Node limit management: remove oldest if exceeding 20 nodes
      while (_nodes.length > 20) {
        final oldestNode = _nodes.removeAt(0);
        _objectManager?.removeNode(oldestNode);
      }
    }
    debugPrint('[ARNodeService] Added ${panels.length} floating panels (scale: ${scale.toStringAsFixed(3)}).');
  }

  /// STAGE 2: Smoothly updates floating panel transforms over time.
  void updateFloatingPanels(Matrix4 currentTransform) {
    if (_nodes.length != _currentLogicalPanels.length) return;

    for (int i = 0; i < _nodes.length; i++) {
       final panel = _currentLogicalPanels[i];
       final panelTransform = currentTransform.clone();
       panelTransform.setTranslation(panel.position);
       _nodes[i].transform = panelTransform; // updates the ValueNotifier instantly
    }
  }

  /// STAGE 3: Formalises floating nodes into permanent ARCore anchors.
  ///
  /// Uses the OVERLAP STRATEGY to eliminate flicker:
  ///   1. Spawn new anchored nodes.
  ///   2. Only THEN remove the old floating nodes.
  /// The user never sees a blank frame.
  Future<void> lockFloatingPanels(Matrix4 finalTransform) async {
    if (_anchorManager == null || _objectManager == null) return;

    final tempPanels = List<PanelModel>.from(_currentLogicalPanels);
    if (tempPanels.isEmpty) return;

    try {
      await _ensurePanelAssetReady();
    } catch (e) {
      debugPrint('[ARNodeService] GLB asset not ready for locking: $e');
      return;
    }

    // Keep a reference to old floating nodes so we can remove them AFTER
    // the new anchored nodes are successfully spawned.
    final oldFloatingNodes = List<ARNode>.from(_nodes);
    final oldAnchors = List<ARAnchor>.from(_anchors);

    // Clear tracking lists so the new anchored panels are tracked freshly.
    _nodes.clear();
    _anchors.clear();
    _currentLogicalPanels.clear();

    // Spawn anchored panels first (overlap phase).
    for (int start = 0; start < tempPanels.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, tempPanels.length);
      final batch = tempPanels.sublist(start, end);
      await Future.wait(
        batch.map((panel) => _placeOneAnchoredPanel(panel, finalTransform)),
      );
    }

    // Enforce node cap on the newly anchored set.
    while (_nodes.length > 20) {
      final oldest = _nodes.removeAt(0);
      _objectManager?.removeNode(oldest);
      if (_anchors.isNotEmpty) {
        _anchorManager?.removeAnchor(_anchors.removeAt(0));
      }
    }

    // NOW safely remove the old floating nodes — anchored nodes are visible.
    for (final node in oldFloatingNodes) {
      try {
        _objectManager?.removeNode(node);
      } catch (_) {}
    }
    for (final anchor in oldAnchors) {
      try {
        await _anchorManager?.removeAnchor(anchor);
      } catch (_) {}
    }

    debugPrint('[ARNodeService] Soft-locked ${tempPanels.length} panels (overlap transition complete).');
  }

  Future<void> _placeOneFloatingPanel(
      PanelModel panel, Matrix4 surfaceTransform, {double scale = 0.05}) async {
    // `scale` param kept for signature compat but actual scale comes from panel dims.
    try {
      final t = _buildPanelTransform(panel, surfaceTransform);
      final node = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: _panelFileName,
        scale: t.scaleVec,
        transformation: t.matrix,
      );
      final added = await _objectManager?.addNode(node) ?? false;
      if (added) {
        _nodes.add(node);
      } else {
        debugPrint('[ARNodeService] Failed to add floating panel node');
      }
    } catch (e) {
      debugPrint('[ARNodeService] Error adding floating panel: $e');
    }
  }

  Future<void> _placeOneAnchoredPanel(
      PanelModel panel, Matrix4 anchorTransform) async {
    try {
      final t = _buildPanelTransform(panel, anchorTransform);

      final anchor = ARPlaneAnchor(transformation: t.matrix);
      final added = await _anchorManager!.addAnchor(anchor) ?? false;
      if (!added) return;
      _anchors.add(anchor);

      final node = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: _panelFileName,
        scale: t.scaleVec,
        position: Vector3(0, 0, 0),
        rotation: Vector4(0, 0, 0, 1),
        name: 'solar_panel_${panel.id}',
      );

      final didAdd = await _objectManager!.addNode(node, planeAnchor: anchor);
      if (didAdd == true) _nodes.add(node);
    } catch (e) {
      debugPrint('[ARNodeService] Panel ${panel.id} failed: $e');
    }
  }

  /// Builds a physically-sized, floor-flat world-space transform for one panel.
  ///
  /// Key design decisions:
  ///  • Rotation: always [_flatRotation] (Y-up, floor-horizontal).
  ///    We deliberately IGNORE the camera's rotation so panels never tilt
  ///    with the phone — they always lie flat on the detected/estimated surface.
  ///  • Translation: panel.position XZ from AR world coords; Y from surfaceY.
  ///  • Scale: derived from real physical widthM so 1 m in the app = 1 m IRL.
  ({Matrix4 matrix, Vector3 scaleVec}) _buildPanelTransform(
      PanelModel panel, Matrix4 surfaceTransform) {
    // ── Scale ──────────────────────────────────────────────────────────────
    final scaleX = panel.widthM / _glbUnitsPerMetre;
    final scaleZ = panel.heightM / _glbUnitsPerMetre;
    final scaleY = scaleX * 0.05; // thin slab, looks realistic
    final scaleVec = Vector3(scaleX, scaleY, scaleZ);

    // ── Position ───────────────────────────────────────────────────────────
    // Use panel.position (world XYZ set by _placementService) but prefer the
    // surface transform's Y when ARCore has a real plane (avoids Z-fighting).
    final worldPos = panel.position.clone();
    final surfaceY = surfaceTransform.getTranslation().y;
    if (surfaceY.abs() > 0.001) worldPos.y = surfaceY;

    // ── Matrix ─────────────────────────────────────────────────────────────
    // Start from identity, apply the flat rotation, then set translation.
    // This guarantees NO camera rotation leaks into the panel pose.
    final matrix = Matrix4.identity()
      ..setRotation(_flatRotation)
      ..setTranslation(worldPos);

    return (matrix: matrix, scaleVec: scaleVec);
  }


  Future<void> _ensurePanelAssetReady() async {
    if (_panelAssetReady) return;
    _panelAssetPrepareTask ??= _copyBundledGlbToAppFolder();
    await _panelAssetPrepareTask;
    _panelAssetReady = true;
  }

  Future<void> _copyBundledGlbToAppFolder() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final targetFile = File('${appDocsDir.path}/$_panelFileName');

    if (await targetFile.exists() && await targetFile.length() > 0) {
      debugPrint('[ARNodeService] Reusing cached GLB: ${targetFile.path}');
      return;
    }

    final data = await rootBundle.load(_panelBundledAssetPath);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await targetFile.writeAsBytes(bytes, flush: true);

    debugPrint('[ARNodeService] Copied GLB asset to: ${targetFile.path}');
  }

  /// Places a debug marker at the given transform to visually validate tap hits.
  /// Uses a bright red cube from Khronos Sample Models.
  Future<void> placeDebugMarker(Matrix4 transform) async {
    if (!isInitialised) return;

    final anchor = ARPlaneAnchor(transformation: transform);
    final added = await _anchorManager!.addAnchor(anchor) ?? false;
    if (!added) {
      debugPrint('[ARNodeService] Failed to add debug anchor');
      return;
    }
    _anchors.add(anchor);

    // Using a known Box model scaled very small. Since it's from the web, colors might be default,
    // but the geometry provides visual validation of the hit.
    final node = ARNode(
      type: NodeType.webGLB,
      uri: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Box/glTF-Binary/Box.glb',
      scale: Vector3(0.05, 0.05, 0.05), // A tiny 5cm cube
      position: Vector3(0, 0, 0),
      rotation: Vector4(0, 0, 0, 1),
      name: 'debug_marker_${DateTime.now().millisecondsSinceEpoch}',
    );

    final didAdd = await _objectManager!.addNode(node, planeAnchor: anchor);
    if (didAdd == true) {
      _nodes.add(node);
      debugPrint('[ARNodeService] Debug marker placed successfully');
    } else {
      debugPrint('[ARNodeService] Failed to place debug marker');
    }
  }

  /// Removes every 3D panel node and its anchor from the scene.
  Future<void> clearAll() async {
    for (final node in _nodes) {
      try {
        _objectManager?.removeNode(node);
      } catch (_) {}
    }
    _nodes.clear();

    for (final anchor in _anchors) {
      try {
        await _anchorManager?.removeAnchor(anchor);
      } catch (_) {}
    }
    _anchors.clear();
    _currentLogicalPanels.clear();

    debugPrint('[ARNodeService] Cleared all AR panel nodes and anchors');
  }

  Future<void> dispose() async {
    await clearAll();
    _objectManager = null;
    _anchorManager = null;
    _panelAssetPrepareTask = null;
    _panelAssetReady = false;
  }
}
