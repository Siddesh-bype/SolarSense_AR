import 'dart:async';

import 'package:flutter/foundation.dart';

// ── Tracking state enum ────────────────────────────────────────────────────────

/// Mirrors ARCore's tracking state, plus an app-level warm-up phase.
enum TrackingState {
  /// AR session is warming up (first 3–5 seconds). Interactions disabled.
  warmingUp,

  /// ARCore VIO is not tracking (insufficient inliers, no feature points).
  notTracking,

  /// ARCore is tracking but no qualifying plane has been detected yet.
  limitedTracking,

  /// A qualifying plane is detected and VIO is stable — ready for interaction.
  trackingReady,
}

// ── Constants ─────────────────────────────────────────────────────────────────

/// Warm-up grace period before we start gating on tracking state.
const Duration _kWarmUpDuration = Duration(seconds: 4);

/// Minimum plane area (m²) required to consider tracking "stable".
/// Accepts planes slightly below 1 m² to handle AR unit scale variation.
const double kMinPlaneAreaM2 = 0.5;

/// Maximum feature-point count used to normalise scan progress to 100 %.
const int _kMaxFeaturePoints = 120;

// ── Controller ────────────────────────────────────────────────────────────────

/// Manages ARCore tracking state, warm-up phase, plane validation, and
/// exposes reactive state for the UI overlay and tap gate.
///
/// Lifecycle:
///   1. `startWarmUp()` called when ARView is created.
///   2. `reportVioTracking(bool)` called each frame (or 150 ms loop) with
///      the session's tracking status.
///   3. `reportPlaneDetected(double areaM2)` called whenever a plane
///      polygon is detected by ARCore.
///   4. UI subscribes via [ChangeNotifier] to render the correct overlay.
class ARTrackingController extends ChangeNotifier {
  // ── Internal state ────────────────────────────────────────────────────────

  TrackingState _state = TrackingState.warmingUp;
  bool _warmUpDone = false;
  bool _vioTracking = false;
  bool _planeDetected = false;
  double _largestPlaneAreaM2 = 0.0;

  /// 0.0 – 1.0, used for the scan-progress indicator.
  double _scanProgress = 0.0;

  int _featurePointCount = 0;

  Timer? _warmUpTimer;
  Timer? _vioBypassTimer; // force-opens gate if VIO never stabilises

  // ── Public getters ────────────────────────────────────────────────────────

  TrackingState get state => _state;

  /// True only when [TrackingState.trackingReady] — the tap gate reads this.
  bool get isTrackingStable => _state == TrackingState.trackingReady;

  /// Progress value 0.0–1.0 for the scan-progress indicator.
  double get scanProgress => _scanProgress;

  /// Raw feature point count (for debug / advanced UIs).
  int get featurePointCount => _featurePointCount;

  double get largestPlaneAreaM2 => _largestPlaneAreaM2;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once when ARView is first created to start the warm-up grace period.
  void startWarmUp() {
    _state = TrackingState.warmingUp;
    _warmUpDone = false;
    notifyListeners();

    _warmUpTimer?.cancel();
    _warmUpTimer = Timer(_kWarmUpDuration, _onWarmUpComplete);

    // Safety bypass: if VIO never locks within 8 seconds (textureless room,
    // poor lighting, etc.), force-open the gate so the app stays usable.
    // The user will see plane visualisations and can tap to test.
    _vioBypassTimer?.cancel();
    _vioBypassTimer = Timer(const Duration(seconds: 8), () {
      if (!isTrackingStable) {
        debugPrint(
            '[ARTracking] VIO bypass: forcing trackingReady after 8 s '
            '(VIO never locked — low-texture environment?).');
        _vioTracking = true;
        _planeDetected = true;
        _scanProgress = 1.0;
        _updateState();
      }
    });
  }

  void _onWarmUpComplete() {
    _warmUpDone = true;
    _updateState();
  }

  // ── External event reporters ──────────────────────────────────────────────

  /// Called from the camera-pose loop whenever we have (or lose) VIO tracking.
  ///
  /// [isTracking] — true if ARCore returned a valid camera pose this cycle.
  void reportVioTracking({required bool isTracking}) {
    if (_vioTracking == isTracking) return; // no change → skip notify
    _vioTracking = isTracking;
    _updateState();
  }

  /// Called whenever the AR session detects a plane polygon.
  ///
  /// [areaM2] — estimated plane area in square metres from [PlaneService].
  /// [featurePoints] — current feature-point count for scan progress (optional).
  void reportPlaneDetected({
    required double areaM2,
    int featurePoints = 0,
  }) {
    // Keep track of the largest qualifying plane seen this session.
    if (areaM2 > _largestPlaneAreaM2) {
      _largestPlaneAreaM2 = areaM2;
    }

    final wasDetected = _planeDetected;
    _planeDetected = _largestPlaneAreaM2 >= kMinPlaneAreaM2;

    _featurePointCount = featurePoints;
    _updateScanProgress(featurePoints, areaM2);

    if (wasDetected != _planeDetected) {
      _updateState();
    } else {
      // Even if state didn't change, update progress UI.
      notifyListeners();
    }
  }

  /// Call when ARCore reports a tracking reset (VIO reset / insufficient
  /// inliers) so the gate reacts immediately.
  void reportTrackingReset() {
    _vioTracking = false;
    _planeDetected = false;
    _updateState();
    debugPrint('[ARTracking] Tracking reset — gate closed.');
  }

  // ── State machine ─────────────────────────────────────────────────────────

  void _updateState() {
    final TrackingState next;

    if (!_warmUpDone) {
      next = TrackingState.warmingUp;
    } else if (!_vioTracking) {
      next = TrackingState.notTracking;
    } else if (!_planeDetected) {
      // VIO is tracking but we haven't built enough confidence yet.
      // After a short stable-VIO streak the polling loop will call
      // reportPlaneDetected() and flip _planeDetected, opening the gate.
      next = TrackingState.limitedTracking;
    } else {
      next = TrackingState.trackingReady;
    }

    if (_state != next) {
      _state = next;
      debugPrint('[ARTracking] State → $next');
      notifyListeners();
    }
  }

  void _updateScanProgress(int featurePoints, double planeAreaM2) {
    // Blend feature-point count and plane area into a 0–1 progress value.
    final fpProgress = (featurePoints / _kMaxFeaturePoints).clamp(0.0, 1.0);
    final areaProgress = (planeAreaM2 / (kMinPlaneAreaM2 * 2)).clamp(0.0, 1.0);

    // Weight area more heavily — having a plane matters more than raw points.
    final raw = fpProgress * 0.35 + areaProgress * 0.65;

    // Only advance progress, never retreat (feels more stable to the user).
    if (raw > _scanProgress) {
      _scanProgress = raw;
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Full reset for when the user restarts a scan session.
  void reset() {
    _vioTracking = false;
    _planeDetected = false;
    _largestPlaneAreaM2 = 0.0;
    _scanProgress = 0.0;
    _featurePointCount = 0;
    startWarmUp(); // re-enter warm-up
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _warmUpTimer?.cancel();
    _vioBypassTimer?.cancel();
    super.dispose();
  }
}
