import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset, Rect, Size;
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../data/services/area_calculation_service.dart';
import '../../data/services/obstacle_service.dart';
import '../../data/services/ar_node_service.dart';
import '../../data/services/panel_placement_service.dart';
import '../../domain/models/area_model.dart';
import '../../domain/models/obstacle_model.dart';
import '../../domain/models/panel_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/geometry_utils.dart';
import 'tracking_controller.dart';

// ── Interaction modes ──────────────────────────────────────────────────────────

enum PlacementState { none, fallback, refining, locked }

enum ARScanMode {
  /// Waiting for user to tap the first corner.
  scanning,

  /// User is tapping the 4 polygon corners one by one.
  definingCorners,

  /// 4 corners placed, panel grid rendered.
  complete,

  /// Next tap on the plane adds an obstacle.
  addingObstacle,
}

// ── Corner data class ──────────────────────────────────────────────────────────

/// Stores both the 3D world position (for area math) and the 2D screen
/// position at the moment of the tap (for immediate visual feedback).
class ARCornerPoint {
  ARCornerPoint({required this.worldPos, required this.screenPos});

  final Vector3 worldPos;
  Offset screenPos; // mutable — updated by camera projection loop
}

// ── Screen obstacle data class ───────────────────────────────────────────────

class ScreenObstacle {
  ScreenObstacle({
    required this.id,
    required this.screenRect,
    required this.worldX,
    required this.worldZ,
  });

  final String id;
  Rect screenRect;
  final double worldX;
  final double worldZ;
}

// ── Controller ────────────────────────────────────────────────────────────────

/// Central state hub for the AR module.
///
/// Strategy:
///   • World coordinates → used for all area / panel placement math (accurate).
///   • Screen coordinates → stored at tap-time for immediate visual feedback.
///   • Camera-loop projects world → screen every 150 ms so panels track the
///     surface as the camera moves.
class ARController extends ChangeNotifier {
  ARController()
      : _areaService = const AreaCalculationService(),
        _placementService = const PanelPlacementService(),
        _obstacleService = ObstacleService(),
        _nodeService = ARNodeService();

  // ── Services ───────────────────────────────────────────────────────────────
  final AreaCalculationService _areaService;
  final PanelPlacementService _placementService;
  final ObstacleService _obstacleService;
  final ARNodeService _nodeService;
  final Uuid _uuid = const Uuid();

  // ── AR manager references (set after ARView is created) ───────────────────
  ARSessionManager? _session;

  // ── Tracking controller (optional — set from ARScreen) ────────────────────
  /// Inject via [setTrackingController] so ARController can gate taps and
  /// report plane events without a circular dependency.
  ARTrackingController? _trackingCtrl;

  void setTrackingController(ARTrackingController ctrl) {
    _trackingCtrl = ctrl;
  }

  // ── Camera tracking ────────────────────────────────────────────────────────
  Matrix4? _cameraMatrix; // camera-to-world pose from ARCore
  bool _cameraLoopRunning = false;

  // ── Placement state ────────────────────────────────────────────────────────
  PlacementState placementState = PlacementState.none;
  Matrix4? _refineTargetTransform;    // lerp destination from ARCore
  Matrix4? _smoothedTransform;        // exponentially smoothed working pose
  Matrix3? _smoothedRotation;         // separately smoothed rotation (0.85/0.15)
  int _fallbackTimestamp = 0;         // ms when Stage-1 fallback was placed
  int _stablePlaneFrames = 0;         // consecutive frames with a stable plane hit
  Vector3? _lastPlaneHitPos;          // for jitter-filter comparison
  bool _isTrackingLost = false;       // freeze flag when ARCore drops
  Matrix3? _lockedRotation;           // orientation frozen at fallback tap-time
  double _placementDistance = 2.5;    // camera→panel distance used for scaling

  // Reference distance at which baseScale (0.05) looks correct.
  static const double _referenceDistance = 2.5;
  static const double _baseScale = 0.05;

  // Typical ARCore device horizontal FOV — used for fallback area estimation.
  // A typical phone FOV is 60–70 degrees. We use 60° as a conservative estimate.
  static const double _fovHorizontalRad = 60.0 * math.pi / 180.0;

  /// Distance-aware scale so panels look the same size at any depth.
  double get placementScale =>
      _baseScale * (_placementDistance / _referenceDistance).clamp(0.5, 3.0);

  // ── Scan state ─────────────────────────────────────────────────────────────
  ARScanMode _mode = ARScanMode.scanning;
  final List<ARCornerPoint> _corners = [];
  double _surfaceY = 0.0;
  Matrix4? _lastPlaneTransform;
  bool _quickMode = true;
  int _debugMarkersPlaced = 0;

  // ── Computed results ───────────────────────────────────────────────────────
  AreaModel _areaModel = AreaModel.zero;
  List<PanelModel> _panels = [];

  // ── Screen-space obstacles (for visual rendering) ─────────────────────────
  final List<ScreenObstacle> _screenObstacles = [];

  // ── Screen size (set from LayoutBuilder in ARScreen) ─────────────────────
  Size _screenSize = const Size(400, 800);

  // ── Public read-only access ───────────────────────────────────────────────

  ARScanMode get mode => _mode;
  int get cornerCount => _corners.length;
  bool get isPolygonComplete => _corners.length >= 4;
  AreaModel get areaModel => _areaModel;
  List<PanelModel> get panels => List.unmodifiable(_panels);
  List<ObstacleModel> get obstacles => _obstacleService.obstacles;
  double get surfaceY => _surfaceY;
  bool get quickMode => _quickMode;

  /// Live area estimate while corners are being defined (XZ projection).
  /// Uses current corner polygon only; obstacle subtraction applies after full recompute.
  double get estimatedAreaM2 {
    if (_corners.length < 3) return 0.0;
    final polygon = _corners.map((c) => c.worldPos).toList();
    return GeometryUtils.computePolygonAreaXZ(polygon);
  }

  // ── Tap visual feedback state ──────────────────────────────────────────────
  Offset? _latestTapPosition;
  Offset? get latestTapPosition => _latestTapPosition;

  void triggerTapFeedback(Offset pos) {
    _latestTapPosition = pos;
    notifyListeners();
  }

  /// Screen-space corner positions for the CustomPainter.
  List<Offset> get cornerScreenPositions =>
      _corners.map((c) => c.screenPos).toList();

  /// Screen-space obstacle rects for the CustomPainter.
  List<Rect> get obstacleScreenRects =>
      _screenObstacles.map((o) => o.screenRect).toList();

  /// Ids of screen obstacles (for removal).
  List<String> get obstacleIds => _screenObstacles.map((o) => o.id).toList();

  /// Grid dimensions for the painter — derived from area geometry.
  int get panelGridCols {
    if (_corners.length < 2) return 4;
    final w = (_corners[1].worldPos - _corners[0].worldPos).length;
    return math.max(
        2, (w / (AppConstants.panelWidthM + AppConstants.panelGapM)).floor());
  }

  int get panelGridRows {
    if (_corners.length < 4) return 5;
    final h = (_corners[3].worldPos - _corners[0].worldPos).length;
    return math.max(
        2, (h / (AppConstants.panelHeightM + AppConstants.panelGapM)).floor());
  }

  // ── Initialization ────────────────────────────────────────────────────────

  void setScreenSize(Size size) => _screenSize = size;

  /// Inject AR managers for 3D node placement. Call once from ARScreen.
  void initManagers({
    required ARObjectManager objectManager,
    required ARAnchorManager anchorManager,
  }) {
    _nodeService.init(
      objectManager: objectManager,
      anchorManager: anchorManager,
    );
  }

  /// Toggle between Quick (single-tap) and Manual (4-tap) corner modes.
  void toggleQuickMode() {
    _quickMode = !_quickMode;
    notifyListeners();
  }

  /// Called once ARView's managers are ready.
  void startSession(ARSessionManager session) {
    _session = session;
    if (!_cameraLoopRunning) _startCameraLoop();
  }

  // ── Camera projection loop ────────────────────────────────────────────────

  Future<void> _startCameraLoop() async {
    _cameraLoopRunning = true;
    while (_cameraLoopRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 16)); // ~60 FPS
      if (_session == null) break;
      try {
        final pose = await _session!.getCameraPose();
        if (pose != null) {

          // ── Hard freeze: locked panels need zero updates ────────────────
          if (placementState == PlacementState.locked) {
            // Only keep screen-space projections current for the painter.
            _cameraMatrix = pose; // still need camera for screen projection
            _refreshScreenPositions();
            notifyListeners();
            continue;
          }

          // ── Exponential translation smoothing (80/20) ──────────────────
          if (_smoothedTransform == null) {
            _smoothedTransform = pose.clone();
            _smoothedRotation = pose.getRotation();
          } else {
            // Translation lerp
            final sp = _smoothedTransform!.getTranslation();
            final np = pose.getTranslation();
            sp.x = sp.x * 0.8 + np.x * 0.2;
            sp.y = sp.y * 0.8 + np.y * 0.2;
            sp.z = sp.z * 0.8 + np.z * 0.2;
            _smoothedTransform!.setTranslation(sp);

            // ── Camera rotation damping (85/15) ───────────────────────
            // Blend each rotation column to smooth rapid head movements.
            final newRot = pose.getRotation();
            final sr = _smoothedRotation!;
            for (int col = 0; col < 3; col++) {
              final sv = sr.getColumn(col);
              final nv = newRot.getColumn(col);
              sr.setColumn(col,
                  Vector3(sv.x * 0.85 + nv.x * 0.15,
                          sv.y * 0.85 + nv.y * 0.15,
                          sv.z * 0.85 + nv.z * 0.15));
            }
            _smoothedRotation = sr;
            _smoothedTransform!.setRotation(sr);
          }
          _cameraMatrix = _smoothedTransform;

          // ── Tracking-loss freeze ──────────────────────────────────────
          final trackingOk =
              _trackingCtrl == null || _trackingCtrl!.isTrackingStable;
          if (!trackingOk) {
            _isTrackingLost = true;
            // Freeze node positions; keep screen overlays live.
            _refreshScreenPositions();
            notifyListeners();
            continue;
          }
          if (_isTrackingLost) {
            _isTrackingLost = false;
            debugPrint('[ARController] Tracking recovered.');
          }

          // ── 2-second fallback auto-lock ─────────────────────────────────
          if (placementState == PlacementState.fallback &&
              _fallbackTimestamp > 0) {
            final elapsed =
                DateTime.now().millisecondsSinceEpoch - _fallbackTimestamp;
            if (elapsed > 2000) {
              debugPrint('[ARController] Fallback timeout – auto-locking.');
              _doLock();
            }
          }

          // ── Refinement glide ────────────────────────────────────────────
          if (placementState == PlacementState.refining &&
              _lastPlaneTransform != null &&
              _refineTargetTransform != null) {
            final currentPos = _lastPlaneTransform!.getTranslation();
            final targetPos = _refineTargetTransform!.getTranslation();

            // Exponential lerp toward target
            currentPos.x += (targetPos.x - currentPos.x) * 0.15;
            currentPos.y += (targetPos.y - currentPos.y) * 0.15;
            currentPos.z += (targetPos.z - currentPos.z) * 0.15;

            _lastPlaneTransform!.setTranslation(currentPos);
            _surfaceY = currentPos.y;
            _nodeService.updateFloatingPanels(_lastPlaneTransform!);

            if (currentPos.distanceTo(targetPos) < 0.01) {
              _lastPlaneTransform = _refineTargetTransform;
              debugPrint('[ARController] Glide complete – locking.');
              _doLock();
            }
          }

          _refreshScreenPositions();
          notifyListeners();
        }
      } catch (_) {
        // Session not ready yet – ignore silently.
      }
    }
  }

  /// Transitions to locked state and replaces floating nodes with ARAnchors.
  void _doLock() {
    placementState = PlacementState.locked;
    _stablePlaneFrames = 0;
    if (_lastPlaneTransform != null) {
      _nodeService.lockFloatingPanels(_lastPlaneTransform!);
    }
    notifyListeners();
  }

  void _refreshScreenPositions() {
    // Update corner screen positions.
    for (final c in _corners) {
      final s = _projectToScreen(c.worldPos);
      if (s != null) c.screenPos = s;
    }
    // Update obstacle screen rects.
    for (final obs in _screenObstacles) {
      final center = Vector3(obs.worldX, _surfaceY, obs.worldZ);
      final s = _projectToScreen(center);
      if (s != null) {
        // Scale: keep 80×80 screen pixels for the obstacle hit area.
        obs.screenRect = Rect.fromCenter(
          center: s,
          width: obs.screenRect.width,
          height: obs.screenRect.height,
        );
      }
    }
  }

  /// Simple perspective projection:  world space → screen space.
  ///
  /// Returns null if the point is behind the camera or projection math fails.
  /// [_focalLength] can be tuned if panels appear mis-aligned on a specific device.
  static const double _focalLength = 1.15;

  Offset? _projectToScreen(Vector3 worldPoint) {
    final cam = _cameraMatrix;
    if (cam == null) return null;
    try {
      // camera-to-world → world-to-camera
      final wtc = Matrix4.inverted(cam);
      final p = wtc.transform3(worldPoint.clone());

      // ARCore: -Z is forward; points with z >= 0 are behind the camera.
      if (p.z >= -0.05) return null;

      final aspect = _screenSize.width / _screenSize.height;
      final ndcX = (p.x / -p.z) * _focalLength / aspect;
      final ndcY = (p.y / -p.z) * _focalLength;

      return Offset(
        (ndcX + 1.0) * _screenSize.width / 2.0,
        (1.0 - ndcY) * _screenSize.height / 2.0,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Tap handling ──────────────────────────────────────────────────────────

  /// Called by ARView's `onPlaneOrPointTap` callback.
  void handlePlaneHit(List<ARHitTestResult> hitResults) {
    if (placementState == PlacementState.locked) return;
    if (hitResults.isEmpty) return;

    final ARHitTestResult hit = hitResults.firstWhere(
      (r) => r.type == ARHitTestResultType.plane,
      orElse: () => hitResults.first,
    );
    final hitPos = hit.worldTransform.getTranslation();

    // ── Direct hit with no prior fallback ──────────────────────────────────
    if (placementState == PlacementState.none) {
      placementState = PlacementState.locked;
      _processGuaranteedTap(hit.worldTransform, null);
      _nodeService.lockFloatingPanels(_lastPlaneTransform ?? hit.worldTransform);
      return;
    }

    // ── Only proceed if in fallback state ──────────────────────────────────
    if (placementState != PlacementState.fallback) return;

    // ── Jitter filter: ignore micro-movements < 10 cm ──────────────────────
    if (_lastPlaneHitPos != null) {
      final drift = hitPos.distanceTo(_lastPlaneHitPos!);
      if (drift < 0.10) {
        // Tiny movement – increment confidence but don't act yet.
        _stablePlaneFrames++;
        debugPrint(
            '[ARController] Plane stable frame $_stablePlaneFrames (drift ${drift.toStringAsFixed(3)}m).');
      } else {
        // Big jump – reset confidence counter, accept the new position.
        _stablePlaneFrames = 1;
        _lastPlaneHitPos = hitPos.clone();
        debugPrint('[ARController] New plane position accepted.');
        return;
      }
    } else {
      _stablePlaneFrames = 1;
      _lastPlaneHitPos = hitPos.clone();
      return;
    }

    // ── Anchor confidence: require 3 stable frames before refining ─────────
    if (_stablePlaneFrames < 3) return;

    // ── Start refinement glide ─────────────────────────────────────────────
    debugPrint('[ARController] Plane confirmed – starting refinement glide.');
    placementState = PlacementState.refining;
    _refineTargetTransform = hit.worldTransform;
    _stablePlaneFrames = 0;

    // Upgrade the fallback area estimate with the real-world plane position.
    _refreshCornersFromPlane(hitPos);

    notifyListeners();
  }

  /// Called by the Listener overlay on EVERY raw screen tap.
  /// STAGE 1: Instant Fallback Placement.
  void handleRawScreenTap(Offset screenPos) {
    if (placementState != PlacementState.none) return;

    triggerTapFeedback(screenPos);
    placementState = PlacementState.fallback;
    _fallbackTimestamp = DateTime.now().millisecondsSinceEpoch; // start timeout
    _stablePlaneFrames = 0;
    _lastPlaneHitPos = null;

    debugPrint('[ARController] Instant fallback placement triggered.');
    final pose = _getCameraForwardPose();
    _processGuaranteedTap(pose, screenPos);
    notifyListeners();
  }

  /// Calculates a valid 3D pose pushing out from the camera.
  /// Applies dynamic distance (tilt-aware), height clamping, and
  /// locks the orientation at tap-time so panels don't rotate with the camera.
  Matrix4 _getCameraForwardPose() {
    final cam = _cameraMatrix;
    if (cam == null) return Matrix4.identity();

    final translation = cam.getTranslation();
    final forward = -cam.getColumn(2).xyz;

    // Tilt factor: how much the camera looks downward (0 = forward, 1 = floor).
    final lookDownFactor = (-forward.y).clamp(0.0, 1.0);

    // Distance: ranges from 1.0m (looking straight down) to 3.5m (forward).
    _placementDistance = 3.5 - (lookDownFactor * 2.5);

    // World position of the panel (no rotation applied yet).
    final panelWorldPos = translation + (forward * _placementDistance);

    // ── Height clamping: keep panels within realistic floor band ──────────
    // Assume phone is held ~1.2m above the floor. Clamp panel Y so it never
    // appears above the phone or more than 2m below it.
    final phoneY = translation.y;
    final clampedY = panelWorldPos.y
        .clamp(phoneY - 2.0,   // max 2m below phone
               phoneY - 0.3);  // min 30cm below phone (avoids eye-level spawn)
    panelWorldPos.y = clampedY;

    // ── Fallback orientation lock ───────────────────────────────────
    // Capture the world-upright orientation once and reuse it so panels
    // don't spin as the user moves the camera during fallback.
    _lockedRotation ??= Matrix3.identity(); // world-aligned (Y-up, flat panel)

    final result = Matrix4.identity();
    result.setRotation(_lockedRotation!);
    result.setTranslation(panelWorldPos);
    return result;
  }

  void _processGuaranteedTap(Matrix4 worldTransform, Offset? screenPosFallback) {
    _lastPlaneTransform = worldTransform;
    final worldPos = worldTransform.getTranslation();
    _surfaceY = worldPos.y;

    // DEBUG MARKER SYSTEM (CRITICAL)
    if (_debugMarkersPlaced == 0) {
      _nodeService.placeDebugMarker(worldTransform);
      _debugMarkersPlaced++;
    }

    // Use camera projection to derive screen-space feedback, fallback to provided tap pos or center.
    final screenPos = _projectToScreen(worldPos) ?? screenPosFallback ??
        Offset(_screenSize.width / 2, _screenSize.height / 2);

    switch (_mode) {
      case ARScanMode.scanning:
        if (_quickMode) {
          _autoFillCorners(worldPos, screenPos);
        } else {
          _addCorner(worldPos, screenPos);
        }
        break;
      case ARScanMode.definingCorners:
        _addCorner(worldPos, screenPos);
        break;
      case ARScanMode.addingObstacle:
        _addObstacle(worldPos, screenPos);
        break;
      case ARScanMode.complete:
        break; // taps do nothing in view mode
    }
  }

  // ── Corner management ─────────────────────────────────────────────────────

  void _addCorner(Vector3 worldPos, Offset screenPos) {
    _corners.add(ARCornerPoint(worldPos: worldPos, screenPos: screenPos));

    if (_corners.length >= 4) {
      _mode = ARScanMode.complete;
      _recompute();
    } else {
      _mode = ARScanMode.definingCorners;
    }
    notifyListeners();
  }

  /// Auto-fills all 4 corners using a FOV-derived area estimate.
  ///
  /// The visible world width at distance [_placementDistance] is:
  ///   visibleWidth = 2 * distance * tan(FOV / 2)
  /// We use 60% of that as the rooftop footprint so panels don't bleed
  /// to the very edge of the frame, which would look unrealistic.
  void _autoFillCorners(Vector3 tapWorldPos, Offset tapScreenPos) {
    _corners.clear();
    _corners.addAll(_buildCornersForArea(tapWorldPos, tapScreenPos));
    _mode = ARScanMode.complete;
    _recompute();
    notifyListeners();
  }

  /// Computes the 4 world-corner points for a rooftop rectangle centred on
  /// [centre], sized using the current [_placementDistance] and camera FOV.
  List<ARCornerPoint> _buildCornersForArea(
      Vector3 centre, Offset fallbackScreenPos) {
    final aspect = _screenSize.width / _screenSize.height;

    // Visible extents at the current placement distance.
    final visibleW = 2.0 * _placementDistance * math.tan(_fovHorizontalRad / 2);
    final visibleH = visibleW / aspect;

    // Use 60% of the visible frame — realistic rooftop coverage.
    final halfW = (visibleW * 0.6 / 2).clamp(1.0, 6.0);
    final halfD = (visibleH * 0.6 / 2).clamp(0.8, 5.0);

    final worldCorners = [
      Vector3(centre.x - halfW, _surfaceY, centre.z - halfD),
      Vector3(centre.x + halfW, _surfaceY, centre.z - halfD),
      Vector3(centre.x + halfW, _surfaceY, centre.z + halfD),
      Vector3(centre.x - halfW, _surfaceY, centre.z + halfD),
    ];

    return worldCorners.map((wc) {
      final sp = _projectToScreen(wc) ?? fallbackScreenPos;
      return ARCornerPoint(worldPos: wc, screenPos: sp);
    }).toList();
  }

  /// Called when ARCore provides a real-world plane hit during refinement.
  /// Re-generates the corner polygon from the confirmed surface position,
  /// giving the user a physically accurate area estimate.
  void _refreshCornersFromPlane(Vector3 planePos) {
    if (_corners.isEmpty) return;

    // Use screen centre as a stable fallback for reprojection.
    final screenCentre =
        Offset(_screenSize.width / 2, _screenSize.height / 2);
    final newCorners =
        _buildCornersForArea(planePos, screenCentre);

    _corners
      ..clear()
      ..addAll(newCorners);

    _recompute();
    notifyListeners();
  }

  void undoLastCorner() {
    if (_corners.isEmpty) return;
    _corners.removeLast();
    _panels = [];
    _areaModel = AreaModel.zero;
    _mode = _corners.isEmpty ? ARScanMode.scanning : ARScanMode.definingCorners;
    notifyListeners();
  }

  // ── Obstacle management ───────────────────────────────────────────────────

  void toggleObstacleMode() {
    _mode = _mode == ARScanMode.addingObstacle
        ? ARScanMode.complete
        : ARScanMode.addingObstacle;
    notifyListeners();
  }

  void _addObstacle(Vector3 worldPos, Offset screenPos) {
    const double sizePx = 80.0; // visual size on screen
    final id = _uuid.v4();

    _screenObstacles.add(ScreenObstacle(
      id: id,
      screenRect:
          Rect.fromCenter(center: screenPos, width: sizePx, height: sizePx),
      worldX: worldPos.x,
      worldZ: worldPos.z,
    ));

    // Also register in ObstacleService for area/panel calculations
    // (screen pixels → world meters ratio ≈ 1 screen obstacle ≈ 0.6m × 0.6m)
    _obstacleService.addObstacle(
      id: id,
      centerX: worldPos.x,
      centerZ: worldPos.z,
      widthM: 0.6,
      depthM: 0.6,
    );

    _recompute();
    notifyListeners();
  }

  void removeObstacleById(String id) {
    _screenObstacles.removeWhere((o) => o.id == id);
    _obstacleService.removeObstacle(id);
    _recompute();
    notifyListeners();
  }

  // ── Layout recomputation ──────────────────────────────────────────────────

  void _recompute() {
    Future.microtask(() {
      final polygon = _corners.map((c) => c.worldPos).toList();
      if (polygon.length < 3) return;

      final newPanels = _placementService.computeLayout(
        polygon: polygon,
        obstacles: _obstacleService.obstacles,
        surfaceY: _surfaceY,
      );
      final newArea = _areaService.calculate(
        polygon: polygon,
        obstacles: _obstacleService.obstacles,
        panelCount: newPanels.length,
      );
      _panels = newPanels;
      _areaModel = newArea;
      notifyListeners();

      // Place STAGE 1 / STAGE 2 floating panels 
      // (will be locked to AR anchors at the end of the glide).
      if (_lastPlaneTransform != null && _nodeService.isInitialised) {
        final panelsFor3D = newPanels.length > AppConstants.maxPanelNodes
            ? newPanels.sublist(0, AppConstants.maxPanelNodes)
            : newPanels;
            
        if (placementState == PlacementState.locked) {
            _nodeService.placePanelsFloating(panelsFor3D, _lastPlaneTransform!, scale: placementScale)
              .then((_) => _nodeService.lockFloatingPanels(_lastPlaneTransform!));
        } else {
            _nodeService.placePanelsFloating(panelsFor3D, _lastPlaneTransform!, scale: placementScale);
        }
      }
    });
  }

  // ── Session controls ──────────────────────────────────────────────────────

  void resetScan() {
    placementState = PlacementState.none;
    _refineTargetTransform = null;
    _smoothedTransform = null;
    _smoothedRotation = null;
    _lockedRotation = null;
    _placementDistance = 2.5;
    _fallbackTimestamp = 0;
    _stablePlaneFrames = 0;
    _lastPlaneHitPos = null;
    _isTrackingLost = false;
    _corners.clear();
    _screenObstacles.clear();
    _panels = [];
    _areaModel = AreaModel.zero;
    _obstacleService.clearAll();
    _nodeService.clearAll();
    _lastPlaneTransform = null;
    _mode = ARScanMode.scanning;
    _debugMarkersPlaced = 0;
    _trackingCtrl?.reset();
    notifyListeners();
  }

  void confirmLayout() {
    debugPrint('[SolarSense AR] Confirmed scan:\n${exportScanData()}');
    notifyListeners();
  }

  // ── Backend-integration surface ───────────────────────────────────────────

  Map<String, dynamic> exportScanData() => {
        ..._areaModel.toJson(),
        'obstacles': _obstacleService.toJsonList(),
        'layout_coordinates': _panels.map((p) => p.toJson()).toList(),
      };

  List<Map<String, dynamic>> getLayoutData() =>
      _panels.map((p) => p.toJson()).toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cameraLoopRunning = false;
    _nodeService.dispose();
    super.dispose();
  }
}
