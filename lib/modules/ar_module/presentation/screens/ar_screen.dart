import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../application/controllers/ar_controller.dart';
import '../../application/controllers/tracking_controller.dart';
import '../painters/ar_solar_painter.dart';
import '../widgets/ar_overlay_ui.dart';
import '../widgets/control_buttons.dart';
import '../widgets/tracking_overlay.dart';
import '../widgets/tap_feedback_overlay.dart';

/// Main AR experience screen.
///
/// Flow:
///   1. Camera permission gate.
///   2. ARView initialises ARCore (plane detection visible immediately).
///   3. User taps 4 corners of the rooftop → polygon defined.
///   4. Solar panel grid appears via [ARSolarPainter] CustomPaint overlay.
///   5. User taps to add obstacles → grid recalculates.
///   6. Confirm → [ARController.exportScanData()] ready for backend.
class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen>
    with SingleTickerProviderStateMixin {
  // ── AR managers ─────────────────────────────────────────────────────────────
  ARSessionManager? _sessionManager;

  // ── Tracking controller ────────────────────────────────────────────────────
  late final ARTrackingController _trackingController;

  // ── Permission state ────────────────────────────────────────────────────────
  bool _cameraGranted = false;
  bool _permissionChecked = false;

  // ── Not-ready toast ─────────────────────────────────────────────────────
  bool _showNotReadyToast = false;

  // ── Shimmer animation ────────────────────────────────────────────────────────
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _trackingController = ARTrackingController();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _cameraGranted = status.isGranted;
      _permissionChecked = true;
    });
  }

  // ── ARView created callback ───────────────────────────────────────────────

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _sessionManager = sessionManager;

    // Capture ctrl once — avoids context-across-async-gap.
    final ctrl = context.read<ARController>();
    ctrl.setScreenSize(MediaQuery.of(context).size);

    // Inject AR managers for 3D node placement.
    ctrl.initManagers(
      objectManager: objectManager,
      anchorManager: anchorManager,
    );

    // Inject tracking controller so ARController can gate taps.
    ctrl.setTrackingController(_trackingController);

    // Start the 4-second warm-up grace period.
    _trackingController.startWarmUp();

    // Wire tap callback BEFORE onInitialize so ARCore's very first
    // hit-test result is never missed due to a race condition.
    sessionManager.onPlaneOrPointTap = (hits) {
      if (hits.isNotEmpty) {
        // If the user taps while tracking is not stable, show the toast.
        if (!_trackingController.isTrackingStable) {
          _showNotReadyMessage();
        }
        ctrl.handlePlaneHit(hits);
      }
    };

    sessionManager.onInitialize(
      showAnimatedGuide: false, // can delay plane detection on MIUI
      showFeaturePoints: true,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: false,
      handleRotation: false,
    );
    objectManager.onInitialize();

    ctrl.startSession(sessionManager);

    // Begin polling VIO tracking state from the camera-pose loop.
    _startVioPolling(sessionManager);
  }

  // ── VIO polling ─────────────────────────────────────────────────────────────

  /// Polls the camera pose every 300 ms and reports VIO tracking state.
  ///
  /// DEADLOCK FIX: The tracking gate requires both VIO stable AND plane
  /// detected. Since ar_flutter_plugin has no plane-detection callback, we
  /// auto-report plane detected after 3 consecutive stable poses (≈900 ms of
  /// continuous tracking). This breaks the chicken-and-egg loop where the gate
  /// blocks taps, but taps were the only way to report planes.
  Future<void> _startVioPolling(ARSessionManager session) async {
    int stablePoseCount = 0;
    const int stableThreshold = 3; // 3 × 300 ms = 900 ms of continuous VIO

    while (mounted && _sessionManager != null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) break;
      try {
        final pose = await session.getCameraPose();
        final isTracking = pose != null;
        _trackingController.reportVioTracking(isTracking: isTracking);

        if (isTracking) {
          stablePoseCount++;
          // After N consecutive stable poses, auto-open the plane gate.
          // This prevents the deadlock where the gate blocks taps but taps
          // were the only source of plane-detected events.
          if (stablePoseCount >= stableThreshold &&
              !_trackingController.isTrackingStable) {
            _trackingController.reportPlaneDetected(
              areaM2: 1.5, // 1.5 m² — conservative heuristic for open gate
            );
          }
        } else {
          stablePoseCount = 0; // reset counter on tracking loss
        }
      } catch (_) {
        stablePoseCount = 0;
        _trackingController.reportVioTracking(isTracking: false);
      }
    }
  }

  // ── Not-ready toast ───────────────────────────────────────────────────────────

  void _showNotReadyMessage() {
    if (_showNotReadyToast) return; // debounce
    setState(() => _showNotReadyToast = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showNotReadyToast = false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_permissionChecked) return _buildLoader('Requesting camera…');
    if (!_cameraGranted) return _buildPermissionDenied();

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          // Keep screen size updated (handles orientation changes).
          // Use a local capture of ctrl to avoid context across async gap.
          final ctrl = context.read<ARController>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ctrl.setScreenSize(size);
          });

          return Stack(
            children: [
              // ── Real ARCore camera + plane detection ──────────────────
              ARView(
                onARViewCreated: _onARViewCreated,
                planeDetectionConfig:
                    PlaneDetectionConfig.horizontalAndVertical,
              ),

              // ── Catch raw taps for visual feedback ──────────────────────
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    // Trigger visual ripple and guarantee a placement fallback
                    context.read<ARController>().handleRawScreenTap(event.localPosition);
                  },
                  child: const SizedBox.expand(),
                ),
              ),

              // ── Solar panel CustomPaint overlay ───────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  // Important: do not block native ARView touch handling.
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, __) {
                      return Consumer<ARController>(
                        builder: (_, ctrl, __) {
                          return CustomPaint(
                            painter: ARSolarPainter(
                              corners: ctrl.cornerScreenPositions,
                              cornerCount: ctrl.cornerCount,
                              obstacleRects: ctrl.obstacleScreenRects,
                              animationValue: _shimmer.value,
                              panelCols: ctrl.panelGridCols,
                              panelRows: ctrl.panelGridRows,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // ── Tracking state overlay (warm-up / not tracking / limited) ──
              ChangeNotifierProvider<ARTrackingController>.value(
                value: _trackingController,
                child: const TrackingOverlay(),
              ),

              // ── Tap Feedback Overlay (Ripple effect) ─────────────────────
              Consumer<ARController>(
                builder: (_, ctrl, __) {
                  final pos = ctrl.latestTapPosition;
                  if (pos == null) return const SizedBox.shrink();
                  return TapFeedbackOverlay(
                    // Unique key forces a complete restart of the animation for every tap
                    key: ValueKey('tap_${pos.dx}_${pos.dy}_${DateTime.now().millisecondsSinceEpoch}'),
                    tapPosition: pos,
                    onComplete: () {}, 
                  );
                },
              ),

              // ── "Surface not ready" toast ────────────────────────────
              if (_showNotReadyToast)
                const Center(child: SurfaceNotReadySnack()),

              // ── Scanning ring (shown until first corner tapped) ─────────
              Consumer<ARController>(
                builder: (_, ctrl, __) => ctrl.mode == ARScanMode.scanning
                    ? Center(
                        child: _ScanningRing(
                          text: ctrl.quickMode
                              ? 'Point at a rooftop & tap once'
                              : 'Point at a rooftop & tap corner 1 of 4',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Corner definition guide ───────────────────────────────
              Consumer<ARController>(
                builder: (_, ctrl, __) {
                  if (ctrl.mode != ARScanMode.definingCorners) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    bottom: 160,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _GuideChip(
                        text: 'Tap corner ${ctrl.cornerCount + 1} of 4',
                      ),
                    ),
                  );
                },
              ),

              // ── Obstacle mode banner ──────────────────────────────────
              Consumer<ARController>(
                builder: (_, ctrl, __) => ctrl.mode == ARScanMode.addingObstacle
                    ? const Positioned(
                        bottom: 150,
                        left: 24,
                        right: 24,
                        child: _ObstacleBanner(),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Metrics HUD (top) ─────────────────────────────────────
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AROverlayUI(),
              ),

              // ── Control buttons (bottom) ──────────────────────────────
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ControlButtons(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helper scaffolds ──────────────────────────────────────────────────────

  Widget _buildLoader(String msg) => Scaffold(
        backgroundColor: const Color(0xFF050B18),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00E5FF)),
              const SizedBox(height: 20),
              Text(msg,
                  style:
                      GoogleFonts.outfit(color: Colors.white60, fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _buildPermissionDenied() => Scaffold(
        backgroundColor: const Color(0xFF050B18),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF00E5FF), size: 72),
                const SizedBox(height: 28),
                Text(
                  'Camera Access Required',
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  'SolarSense AR uses your camera to detect rooftop surfaces and overlay solar panel layouts in real time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: Colors.white54, height: 1.6),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: Text('Open Settings',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _shimmer.dispose();
    _trackingController.dispose();
    _sessionManager?.dispose();
    super.dispose();
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ScanningRing extends StatefulWidget {
  const _ScanningRing({required this.text});
  final String text;

  @override
  State<_ScanningRing> createState() => _ScanningRingState();
}

class _ScanningRingState extends State<_ScanningRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _scale = Tween<double>(begin: 0.6, end: 1.2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.8, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
            ),
            child: Text(
              widget.text,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, color: Color(0xFF00E5FF), size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ObstacleBanner extends StatelessWidget {
  const _ObstacleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap on the detected surface to place an obstacle (AC, vent, chimney…)',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
