import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/solar/sun_path.dart';
import '../../models/obstacle_detection.dart';
import '../../services/obstacle_service.dart';
import '../../services/user_session.dart';

// ── Channel constants ────────────────────────────────────────────────────────
// All panel/area/system-kW values are produced by the native ARCore module
// and streamed through _kEventCh. Nothing about panels is hardcoded here.
const _kViewType = 'com.solarmitra/scene';
const _kMethodCh = MethodChannel('com.solarmitra/channel');
const _kEventCh  = EventChannel('com.solarmitra/events');

class ARCameraScreen extends StatefulWidget {
  const ARCameraScreen({super.key});
  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {

  // ── HUD state (driven by ARCore EventChannel) ────────────────────────────
  int    _panelCount = 0;
  int    _maxPanels  = 0;
  double _systemKw   = 0;
  double _areaSqm    = 0;
  bool   _planeFound = false;
  double _headingDeg = 0;   // compass heading streamed from native

  // Selected panel (-1 = none). Height edits apply to it, or to all panels
  // when nothing is selected.
  int _selectedPanelId = -1;

  // Mounting height in metres above the detected plane, 0 (floor) to 12 (roof).
  double _heightM = SunPath.mountingElevationM;

  // Obstacle detection — runs on DETECT and stays on this screen so the keep-out
  // zones can be seen before the report is generated.
  final _obstacleService = ObstacleService();
  List<ObstacleDetection> _obstacles = const [];
  bool _detecting = false;

  // ── Camera permission ───────────────────────────────────────────────────
  // null  → not yet known (assume granted-until-told-otherwise)
  // 'granted' / 'denied' come from the native side via EventChannel.
  String? _cameraPermission;
  bool    _cameraPermissionPermanent = false;

  /// null = still checking, true/false = ARCore verdict from the native side.
  bool? _arSupported;

  @override
  void initState() {
    super.initState();
    _kEventCh.receiveBroadcastStream().listen(_onArEvent, onError: (_) {});
    _checkArSupport();
    _pushOptimalPose();
    // Warm the detector so the first DETECT press isn't paying model-load cost.
    _obstacleService.init();
  }

  /// Older / non-ARCore phones still get a usable scan: we ask the native side
  /// whether ARCore can run at all and, if not, show manual roof-area entry
  /// instead of an AR view that would never track.
  Future<void> _checkArSupport() async {
    bool supported = false;
    try {
      final Map? r =
          await _kMethodCh.invokeMethod('checkArAvailability') as Map?;
      supported = (r?['supported'] as bool?) ?? false;
    } catch (_) {
      supported = false; // channel missing (e.g. iOS/desktop) → manual path
    }
    if (mounted) setState(() => _arSupported = supported);
  }

  /// Pushes the sun-path-optimal tilt + mounting elevation to the native
  /// AR side, so panels are placed elevated above the roof and tilted
  /// toward the sun. Computed from the user's GPS latitude (fallback
  /// latitude ≈ 20° when no GPS is available).
  Future<void> _pushOptimalPose() async {
    final lat = UserSession.instance.lat ?? 20.0; // fallback: central India
    final tilt = SunPath.optimalTiltDeg(lat);
    final azimuth = SunPath.optimalAzimuthDeg(lat);
    try {
      await _kMethodCh.invokeMethod('configurePanelPose', {
        'tiltDeg': tilt,
        'azimuthDeg': azimuth,
        'elevationM': SunPath.mountingElevationM,
        'latitude': lat,
      });
    } catch (_) {
      // Native side may not be ready yet — plane detection will still
      // fall back to flat-on-ground placement if this call is dropped.
    }
  }

  void _onArEvent(dynamic event) {
    if (event is Map && mounted) {
      setState(() {
        _panelCount = (event['panelCount'] as int?) ?? _panelCount;
        _maxPanels  = (event['maxPanels']  as int?) ?? _maxPanels;
        _systemKw   = (event['systemKw']   as double?) ?? _systemKw;
        _areaSqm    = (event['areaSqm']    as double?) ?? _areaSqm;
        _planeFound = (event['planeFound'] as bool?)  ?? _planeFound;
        _headingDeg = (event['headingDeg'] as double?) ?? _headingDeg;
        _selectedPanelId = (event['selectedId'] as int?) ?? _selectedPanelId;

        // Permission events are emitted on grant/deny only — absent keys
        // mean this is a normal HUD frame.
        final permStatus = event['cameraPermission'] as String?;
        if (permStatus != null) {
          _cameraPermission = permStatus;
          _cameraPermissionPermanent =
              (event['cameraPermissionPermanent'] as bool?) ?? false;
        }
      });
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await _kMethodCh.invokeMethod('openAppSettings');
    } catch (_) {
      // If the native shortcut fails the user can still reach settings via
      // the OS launcher — nothing sensible we can do here.
    }
  }

  // ── Channel helpers ───────────────────────────────────────────────────────

  Future<void> _addPanel()    => _kMethodCh.invokeMethod('addPanel');
  Future<void> _removePanel() => _kMethodCh.invokeMethod('removePanel');
  Future<void> _resetScan()   => _kMethodCh.invokeMethod('resetScan');

  /// Packs the plane with mixed module sizes — large modules first, then the
  /// smaller SKUs into the leftover strips.
  Future<void> _autoFillMixed() => _kMethodCh.invokeMethod('autoFillMixed');

  /// Applies the mounting height. Targets the selected panel if there is one,
  /// otherwise the whole array.
  Future<void> _applyHeight(double metres) {
    if (_selectedPanelId > 0) {
      return _kMethodCh.invokeMethod(
        'setPanelHeight',
        {'id': _selectedPanelId, 'elevationM': metres},
      );
    }
    return _kMethodCh.invokeMethod('setAllPanelHeight', {'elevationM': metres});
  }

  /// Switches the live 3D module size + layout on the native side.
  Future<void> _setPanelFlex({double widthM = 1.70, double heightM = 1.14, String? layout}) {
    return _kMethodCh.invokeMethod(
      'configurePanelFlex',
      {'widthM': widthM, 'heightM': heightM, 'layout': layout},
    );
  }

  Future<void> _capture() async {
    try {
      final Map snapshot = await _kMethodCh.invokeMethod('getScanSnapshot') ?? {};
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/scan/loading',
        arguments: {
          'panelCount': snapshot['panelCount'] ?? _panelCount,
          'systemKw'  : snapshot['systemKw']   ?? _systemKw,
          'areaSqm'   : snapshot['areaSqm']    ?? _areaSqm,
          'headingDeg': snapshot['headingDeg'] ?? _headingDeg,
        },
      );
    } catch (_) {
      // If Kotlin side not ready, navigate anyway
      if (mounted) Navigator.pushReplacementNamed(context, '/scan/loading');
    }
  }

  // ── Panel style (size + layout) ──────────────────────────────────────────
  static const _panelSizes = [
    (name: 'Standard 540W', width: 1.70, height: 1.14, watts: 540),
    (name: 'Compact 460W',  width: 1.60, height: 1.00, watts: 460),
    (name: 'Large 700W',    width: 2.00, height: 1.30, watts: 700),
  ];
  static const _layouts = [
    (name: 'Auto',        native: null),
    (name: 'Landscape',   native: 'landscape'),
    (name: 'Portrait',    native: 'portrait'),
  ];
  int _panelSizeIndex = 0;
  int _layoutIndex = 0;

  void _applyPanelStyle() {
    final size = _panelSizes[_panelSizeIndex];
    _setPanelFlex(
      widthM: size.width,
      heightM: size.height,
      layout: _layouts[_layoutIndex].native,
    );
  }

  /// Captures a real camera frame, runs on-device obstacle detection, and pushes
  /// the boxes to the native side so panels re-pack around the keep-out zones.
  /// Stays on this screen — the user sees the obstacles land in the live scene
  /// instead of the result appearing only in the report.
  Future<void> _scanObstacles() async {
    if (_detecting) return;
    setState(() => _detecting = true);
    try {
      final Map? frame = await _kMethodCh.invokeMethod('captureFrame') as Map?;
      final bytes = frame?['bytes'] as Uint8List?;
      final found = await _obstacleService.detectObstacles(bytes);
      if (!mounted) return;
      setState(() => _obstacles = found);
      if (found.isNotEmpty) {
        await _kMethodCh.invokeMethod('applyObstacles', {
          'boxes': [
            for (final o in found)
              {'x': o.x, 'y': o.y, 'w': o.w, 'h': o.h, 'label': o.label},
          ],
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(found.isEmpty
                ? 'No rooftop obstacles found — full area usable'
                : '${found.length} obstacle(s) found · panels re-packed around them'),
            backgroundColor: const Color(0xFF1F2937),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      // Detection is an enhancement, not a gate — a failure leaves the existing
      // layout untouched.
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;

    // Don't create the AR platform view on a phone that can't run ARCore —
    // it would show a permanent black surface. Manual entry instead.
    if (_arSupported == false) {
      return _ManualAreaScreen(
        onSubmit: (areaSqm) {
          // Area-only route: the manual-entry analysis path derives panel count
          // and system kW from a mixed-size packer in analysis_loading_screen.
          Navigator.pushReplacementNamed(context, '/scan/loading', arguments: {
            'areaSqm': areaSqm,
            'isManualEntry': true,
            'headingDeg': 0.0,
          });
        },
        onBack: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── Layer 1: ARSceneView via Hybrid Composition ───────────────────
          // AndroidView uses Virtual Display which cannot render SurfaceView.
          // PlatformViewLink + initSurfaceAndroidView uses Hybrid Composition:
          // the native SurfaceView renders in its own hardware layer, composited
          // on top of Flutter's layer tree — this is the correct approach for
          // any GLSurfaceView / ARCore / SurfaceView-based native view.
          Positioned.fill(
            child: PlatformViewLink(
              viewType: _kViewType,
              surfaceFactory: (context, controller) {
                return AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                  gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                );
              },
              onCreatePlatformView: (params) {
                return PlatformViewsService.initSurfaceAndroidView(
                  id: params.id,
                  viewType: _kViewType,
                  layoutDirection: TextDirection.ltr,
                  creationParamsCodec: const StandardMessageCodec(),
                )
                  ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
                  ..create();
              },
            ),
          ),

          // ── Layer 2: "Point phone at surface" hint (before plane detected) ─
          if (!_planeFound && _cameraPermission != 'denied')
            const Positioned.fill(child: _PlaneHint()),

          // ── Layer 2b: Camera permission denied fallback ──────────────────
          if (_cameraPermission == 'denied')
            Positioned.fill(
              child: _PermissionDeniedOverlay(
                permanent: _cameraPermissionPermanent,
                onOpenSettings: _openAppSettings,
                onBack: () => Navigator.pop(context),
              ),
            ),

          // ── Layer 3: Top HUD ─────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopBar(
              safeTop: safeTop,
              planeFound: _planeFound,
              onBack: () => Navigator.pop(context),
              onReset: _resetScan,
            ),
          ),

          // ── Layer 4: Stats row (area · panels · kW) ───────────────────────
          if (_planeFound)
            Positioned(
              top: safeTop + 88,
              left: 12, right: 12,
              child: _StatsRow(
                areaSqm: _areaSqm,
                panelCount: _panelCount,
                maxPanels: _maxPanels,
                systemKw: _systemKw,
                headingDeg: _headingDeg,
              ),
            ),

          // ── Layer 4b: Panel size + layout switcher ─────────────────────────
          if (_planeFound)
            Positioned(
              top: safeTop + 146,
              left: 12, right: 12,
              child: _PanelStyleBar(
                sizes: _panelSizes.map((s) => s.name).toList(),
                layouts: _layouts.map((l) => l.name).toList(),
                sizeIndex: _panelSizeIndex,
                layoutIndex: _layoutIndex,
                onSizeChanged: (i) {
                  setState(() => _panelSizeIndex = i);
                  _applyPanelStyle();
                },
                onLayoutChanged: (i) {
                  setState(() => _layoutIndex = i);
                  _applyPanelStyle();
                },
              ),
            ),

          // ── Layer 5: Right sidebar (+/−) ──────────────────────────────────
          if (_planeFound)
            Positioned(
              right: 14,
              bottom: safeBot + 140,
              child: _Sidebar(
                onAdd:     _addPanel,
                onRemove:  _removePanel,
                // Mixed-size packing happens natively in one pass: large modules
                // first, smaller SKUs into the leftover strips.
                onMaxFill: _autoFillMixed,
                panelCount: _panelCount,
                maxPanels: _maxPanels,
              ),
            ),

          // ── Layer 5b: Mounting height (0 m floor → 12 m roof) ─────────────
          if (_planeFound)
            Positioned(
              left: 14,
              bottom: safeBot + 140,
              child: _HeightBar(
                metres: _heightM,
                selectedId: _selectedPanelId,
                onChanged: (v) {
                  setState(() => _heightM = v);
                  _applyHeight(v);
                },
              ),
            ),

          // ── Layer 6: Bottom shutter bar ────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _ShutterBar(
              safeBot: safeBot,
              planeFound: _planeFound,
              detecting: _detecting,
              obstacleCount: _obstacles.length,
              onCapture: _capture,
              onDetect: _scanObstacles,
              onReset: _resetScan,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PlaneHint extends StatelessWidget {
  const _PlaneHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_android, color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.black.withValues(alpha: 0.5),
                child: Text(
                  'Move phone slowly over your rooftop\nSolar panels will auto-appear on detection',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double safeTop;
  final bool planeFound;
  final VoidCallback onBack, onReset;

  const _TopBar({
    required this.safeTop,
    required this.planeFound,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: safeTop + 14, bottom: 18, left: 18, right: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassBtn(icon: Icons.arrow_back, onTap: onBack),
          Column(children: [
            Text('SolarSense',
                style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                    color: planeFound
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5722),
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                planeFound ? 'SURFACE DETECTED' : 'SCANNING...',
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4),
              ),
            ]),
          ]),
          _GlassBtn(icon: Icons.refresh, onTap: onReset),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final double areaSqm, systemKw, headingDeg;
  final int panelCount, maxPanels;

  const _StatsRow({
    required this.areaSqm,
    required this.systemKw,
    required this.panelCount,
    required this.maxPanels,
    this.headingDeg = 0,
  });

  @override
  Widget build(BuildContext context) {
    final compass = headingDeg > 0
        ? '${(headingDeg % 360).toStringAsFixed(0)}°'
        : '—';
    return Row(
      children: [
        _Chip(
          icon: Icons.crop_free,
          label: 'Area',
          value: '${areaSqm.toStringAsFixed(0)} m²',
          color: const Color(0xFF66BB6A),
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.solar_power,
          label: 'Panels',
          value: '$panelCount / $maxPanels',
          color: const Color(0xFFf97316),
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.bolt,
          label: 'System',
          value: '${systemKw.toStringAsFixed(1)} kW',
          color: const Color(0xFF29B6F6),
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.explore,
          label: 'Heading',
          value: compass,
          color: const Color(0xFFAB47BC),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 11),
                const SizedBox(width: 4),
                Text(label,
                    style: GoogleFonts.inter(
                        color: color, fontSize: 9, fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 3),
              Text(value,
                  style: GoogleFonts.manrope(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final Future<void> Function() onAdd, onRemove, onMaxFill;
  final int panelCount, maxPanels;

  const _Sidebar({
    required this.onAdd,
    required this.onRemove,
    required this.onMaxFill,
    required this.panelCount,
    required this.maxPanels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassBtn(
            icon: Icons.add,
            onTap: panelCount < maxPanels ? () => onAdd() : null),
        const SizedBox(height: 12),
        _GlassBtn(
            icon: Icons.remove,
            onTap: panelCount > 1 ? () => onRemove() : null),
        const SizedBox(height: 12),
        Container(width: 36, height: 1, color: Colors.white24),
        const SizedBox(height: 12),
        // Fill-to-max
        _GlassBtn(
            icon: Icons.grid_view,
            color: const Color(0xFF4CAF50),
            onTap: () => onMaxFill()),
      ],
    );
  }
}

class _ShutterBar extends StatelessWidget {
  final double safeBot;
  final bool planeFound;
  final bool detecting;
  final int obstacleCount;
  final VoidCallback onCapture, onDetect, onReset;

  const _ShutterBar({
    required this.safeBot,
    required this.planeFound,
    required this.detecting,
    required this.obstacleCount,
    required this.onCapture,
    required this.onDetect,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: safeBot + 10, top: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarAction(icon: Icons.restart_alt, label: 'RESET', onTap: onReset),
          _BarAction(
            icon: obstacleCount > 0
                ? Icons.visibility
                : Icons.visibility_outlined,
            label: detecting
                ? '...'
                : (obstacleCount > 0 ? '$obstacleCount FOUND' : 'DETECT'),
            busy: detecting,
            tint: obstacleCount > 0 ? const Color(0xFFFBBF24) : null,
            onTap: (planeFound && !detecting) ? () => onDetect() : null,
          ),
          // Shutter
          GestureDetector(
            onTap: onCapture,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: planeFound ? Colors.white : Colors.white38,
                    width: 3),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: planeFound
                        ? [const Color(0xFFf97316), const Color(0xFF7C1F00)]
                        : [Colors.white24, Colors.white12],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    if (planeFound)
                      BoxShadow(
                          color: const Color(0xFFf97316).withValues(alpha: 0.5),
                          blurRadius: 12)
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: planeFound ? Colors.white : Colors.white38,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final Color? tint;
  final VoidCallback? onTap;

  const _BarAction({
    required this.icon,
    required this.label,
    this.busy = false,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null && !busy
        ? Colors.white38
        : (tint ?? Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 50, height: 50,
            color: Colors.white.withValues(alpha: 0.12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                        ),
                      )
                    : Icon(icon, color: fg, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label,
            style: GoogleFonts.inter(
                color: tint ?? Colors.white60, fontSize: 9,
                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ]),
    );
  }
}

class _PermissionDeniedOverlay extends StatelessWidget {
  final bool permanent;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  const _PermissionDeniedOverlay({
    required this.permanent,
    required this.onOpenSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final title = permanent
        ? 'Camera access is turned off'
        : 'Camera access required';
    final body = permanent
        ? 'You previously blocked the camera for SolarSense. '
          'Enable Camera under App permissions to run the AR scan.'
        : 'The AR scan uses your phone camera to measure the rooftop. '
          'Grant camera access to continue.';
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.orangeAccent, size: 64),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open app settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text(
                'Go back',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _GlassBtn({required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44, height: 44,
          color: (color ?? Colors.white).withValues(alpha: onTap != null ? 0.15 : 0.06),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Icon(icon,
                  color: onTap != null
                      ? (color ?? Colors.white)
                      : Colors.white38,
                  size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel module size + layout switcher that drives the native 3D grid.
class _PanelStyleBar extends StatelessWidget {
  final List<String> sizes, layouts;
  final int sizeIndex, layoutIndex;
  final ValueChanged<int> onSizeChanged, onLayoutChanged;

  const _PanelStyleBar({
    required this.sizes,
    required this.layouts,
    required this.sizeIndex,
    required this.layoutIndex,
    required this.onSizeChanged,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SegmentGroup(
                label: 'Module',
                icon: Icons.solar_power,
                options: sizes,
                active: sizeIndex,
                onTap: onSizeChanged,
              ),
              _SegmentGroup(
                label: 'Layout',
                icon: Icons.grid_view,
                options: layouts,
                active: layoutIndex,
                onTap: onLayoutChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final int active;
  final ValueChanged<int> onTap;

  const _SegmentGroup({
    required this.label,
    required this.icon,
    required this.options,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFFF97316), size: 12),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(options.length, (i) {
              final selected = i == active;
              return GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF97316)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFFF97316)
                            : Colors.white24),
                  ),
                  child: Text(
                    options[i],
                    style: GoogleFonts.inter(
                        color: selected ? Colors.black87 : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Vertical mounting-height control: 0 m sits the array flat on the detected
/// surface (floor mount), 12 m raises it to roof level. Applies to the selected
/// panel when one is tapped, otherwise to the whole array.
class _HeightBar extends StatelessWidget {
  final double metres;
  final int selectedId;
  final ValueChanged<double> onChanged;

  const _HeightBar({
    required this.metres,
    required this.selectedId,
    required this.onChanged,
  });

  static const _maxM = 12.0;

  @override
  Widget build(BuildContext context) {
    final scoped = selectedId > 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scoped
                  ? const Color(0xFFF97316).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.height,
                  color: scoped ? const Color(0xFFF97316) : const Color(0xFFFBBF24),
                  size: 14),
              const SizedBox(height: 2),
              Text(
                scoped ? 'ONE' : 'ALL',
                style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              // Rotated so the slider reads bottom-up: ground at the bottom.
              SizedBox(
                height: 150,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: const Color(0xFFFBBF24),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: metres.clamp(0.0, _maxM),
                      min: 0,
                      max: _maxM,
                      divisions: 48, // 0.25 m steps
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${metres.toStringAsFixed(2)} m',
                style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                metres < 0.5 ? 'FLOOR' : (metres >= 8 ? 'ROOF' : 'RAISED'),
                style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when ARCore isn't available (older phones, no Google Play Services for
/// AR): manual roof-area entry that still produces a full financial report, so
/// "old phone" doesn't mean "no scan".
class _ManualAreaScreen extends StatefulWidget {
  final void Function(double areaSqm) onSubmit;
  final VoidCallback onBack;

  const _ManualAreaScreen({required this.onSubmit, required this.onBack});

  @override
  State<_ManualAreaScreen> createState() => _ManualAreaScreenState();
}

class _ManualAreaScreenState extends State<_ManualAreaScreen> {
  final _area = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _area.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_area.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 100000) {
      setState(() => _error = 'Enter a roof area between 1 and 100000 m²');
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B16),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('SOLARMITRA',
                    style: GoogleFonts.manrope(
                        color: const Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 48),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.straighten,
                      color: Color(0xFFFBBF24), size: 44),
                ),
              ),
              const SizedBox(height: 22),
              Text("AR isn't available on this phone",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                "This device doesn't support Google ARCore, so the camera scan "
                "can't run. You still get a full solar report — just enter your "
                "roof area.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _area,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Roof area',
                  labelStyle: const TextStyle(color: Colors.white54),
                  suffixText: 'm²',
                  suffixStyle: const TextStyle(color: Colors.white38),
                  errorText: _error,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFBBF24)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.bolt),
                label: const Text('Generate solar report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
