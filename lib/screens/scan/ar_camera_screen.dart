import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../widgets/solar_panel_3d.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';

// Panel physical size (metres)
const double _kPanelW = 1.70;
const double _kPanelD = 1.14;
const double _kPanelArea = _kPanelW * _kPanelD; // 1.938 m²

class ARCameraScreen extends StatefulWidget {
  const ARCameraScreen({super.key});
  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen>
    with SingleTickerProviderStateMixin {

  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _cameraController;

  // ── Scan state ────────────────────────────────────────────────────────────
  bool _isScanning  = true;
  bool _scanDone    = false;

  // ── Surface measurements (computed from tilt angle when scan completes) ───
  double _distanceMetre  = 0;   // estimated distance to surface
  double _surfaceAreaM2  = 0;   // estimated usable roof area
  int    _maxPanels      = 0;   // floor(area / panel area)
  int    _panelCount     = 0;   // user adjusted (starts = maxPanels)
  int    _obstacleCount  = 0;   // detected movable obstacles

  // ── Accelerometer tilt ────────────────────────────────────────────────────
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _rawTiltY = 5.0; // phone angle used for distance estimate

  // ── Scan line animation ───────────────────────────────────────────────────
  late AnimationController _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initCamera();
    _listenSensors();

    // Simulate plane detection after 4 seconds
    Future.delayed(const Duration(seconds: 4), _onScanComplete);
  }

  Future<void> _initCamera() async {
    if (globalCameras.isEmpty) return;
    _cameraController = CameraController(
      globalCameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  void _listenSensors() {
    accelerometerEventStream().listen((e) {
      if (!mounted) return;
      final tx = (e.x / 5.0).clamp(-1.0, 1.0);
      final ty = ((e.y - 5.0) / 5.0).clamp(-1.0, 1.0);
      if ((tx - _tiltX).abs() > 0.015 || (ty - _tiltY).abs() > 0.015) {
        setState(() {
          _tiltX    = tx;
          _tiltY    = ty;
          _rawTiltY = e.y; // raw for distance calc
        });
      }
    });
  }

  /// Called when the 4-second scan completes.
  /// Uses phone tilt angle to estimate surface distance and area.
  void _onScanComplete() {
    if (!mounted) return;

    // Distance estimate: when phone held at ~45° down, surface ~1.5m away.
    // Clamp between 1 and 6 metres (realistic handheld range).
    final tiltDeg = (_rawTiltY / 9.8 * 90).clamp(15.0, 75.0);
    final dist = (1.5 / math.sin(tiltDeg * math.pi / 180)).clamp(1.0, 6.0);

    // Area estimate: camera FOV ≈ 60°. Visible ground = (2 * dist * tan30°)²
    // We use 70% as "usable" roof portion
    final fovHalf = math.tan(30 * math.pi / 180);
    final visibleSide = 2 * dist * fovHalf;
    final rawArea = visibleSide * visibleSide * 0.70;
    // Realistic floor: 8–80 m²
    final area = rawArea.clamp(8.0, 80.0);

    // Simulate 1–3 movable obstacles (AC units, water tanks etc.)
    final obstacles = (dist / 2).round().clamp(1, 3);

    // Usable area after subtracting estimated obstacle footprint (1.5 m² each)
    final usableArea = (area - obstacles * 1.5).clamp(4.0, 70.0);
    final maxPanels  = (usableArea / _kPanelArea).floor().clamp(1, 30);

    setState(() {
      _isScanning      = false;
      _scanDone        = true;
      _distanceMetre   = double.parse(dist.toStringAsFixed(1));
      _surfaceAreaM2   = double.parse(area.toStringAsFixed(1));
      _obstacleCount   = obstacles;
      _maxPanels       = maxPanels;
      _panelCount      = maxPanels; // auto-fill
    });
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenW  = MediaQuery.of(context).size.width;
    final screenH  = MediaQuery.of(context).size.height;
    final safeTop  = MediaQuery.of(context).padding.top;
    final safeBot  = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── Camera feed ───────────────────────────────────────────────────
          Positioned.fill(
            child: _cameraController?.value.isInitialized == true
                ? CameraPreview(_cameraController!)
                : Container(
                    color: const Color(0xFF070710),
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFf97316))),
                  ),
          ),

          // ── Scan phase ────────────────────────────────────────────────────
          if (_isScanning) Positioned.fill(child: _buildScanOverlay(screenH)),

          // ── Panel grid — bottom 55% (floor / rooftop position) ────────────
          if (_scanDone)
            Positioned(
              left: 0, right: 0,
              bottom: safeBot + 76,
              child: SizedBox(
                width: screenW,
                height: screenW * 0.65,
                child: SolarPanel3DWidget(
                  panelCount: _panelCount,
                  size: screenW,
                  tiltX: _tiltX,
                  tiltY: _tiltY,
                ),
              ),
            ),

          // ── Surface edge (green AR line) ──────────────────────────────────
          if (_scanDone)
            Positioned(
              left: screenW * 0.06,
              right: screenW * 0.06,
              bottom: safeBot + 76 + screenW * 0.645,
              child: _surfaceEdge(),
            ),

          // ── Top HUD ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopHUD(safeTop),
          ),

          // ── Scan stats bar (area · distance · obstacles) ──────────────────
          if (_scanDone)
            Positioned(
              top: safeTop + 88,
              left: 12, right: 12,
              child: _buildStatsBar(),
            ),

          // ── Auto-calculated panel badge ────────────────────────────────────
          if (_scanDone)
            Positioned(
              top: safeTop + 164,
              left: 0, right: 0,
              child: Center(child: _buildPanelBadge()),
            ),

          // ── Right sidebar (+/−) ───────────────────────────────────────────
          if (_scanDone)
            Positioned(
              right: 14,
              bottom: safeBot + 160,
              child: _buildSidebar(),
            ),

          // ── Bottom shutter bar ────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildShutterBar(safeBot),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  /// Stats row: area / distance / obstacles
  Widget _buildStatsBar() {
    final usable = (_surfaceAreaM2 - _obstacleCount * 1.5).clamp(4.0, 70.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          _statChip(
            icon: Icons.straighten,
            label: 'Distance',
            value: '${_distanceMetre.toStringAsFixed(1)} m',
            color: const Color(0xFF29B6F6),
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.crop_free,
            label: 'Area',
            value: '${_surfaceAreaM2.toStringAsFixed(0)} m²',
            color: const Color(0xFF66BB6A),
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.warning_amber_rounded,
            label: 'Obstacles',
            value: '$_obstacleCount removed',
            color: const Color(0xFFFFB300),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
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
              border: Border.all(
                  color: color.withValues(alpha: 0.4), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: color, size: 11),
                  const SizedBox(width: 4),
                  Text(label,
                      style: GoogleFonts.inter(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 3),
                Text(value,
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelBadge() {
    final kw = (_panelCount * 0.25).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFf97316),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFf97316).withValues(alpha: 0.5),
              blurRadius: 14)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.solar_power, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '$_panelCount / $_maxPanels panels  ·  $kw kW',
            style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHUD(double safeTop) {
    return Container(
      padding: EdgeInsets.only(
          top: safeTop + 14, bottom: 18, left: 18, right: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.78),
            Colors.transparent
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _glassBtn(Icons.arrow_back, () => Navigator.pop(context)),
          Column(children: [
            Text('SolarSense AR',
                style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: _isScanning
                          ? const Color(0xFFFF5722)
                          : const Color(0xFF4CAF50),
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                _isScanning
                    ? 'SCANNING SURFACE...'
                    : 'SURFACE DETECTED',
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4),
              ),
            ]),
          ]),
          _glassBtn(Icons.refresh, () {
            setState(() {
              _isScanning  = true;
              _scanDone    = false;
              _panelCount  = 0;
            });
            Future.delayed(const Duration(seconds: 4), _onScanComplete);
          }),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        _glassBtn(Icons.add, () {
          if (_panelCount < _maxPanels) setState(() => _panelCount++);
        }),
        const SizedBox(height: 12),
        _glassBtn(Icons.remove, () {
          if (_panelCount > 1) setState(() => _panelCount--);
        }),
        const SizedBox(height: 12),
        Container(width: 36, height: 1, color: Colors.white24),
        const SizedBox(height: 12),
        // Max fill button
        GestureDetector(
          onTap: () => setState(() => _panelCount = _maxPanels),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44, height: 44,
              color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const Center(
                  child: Icon(Icons.grid_view,
                      color: Color(0xFF4CAF50), size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShutterBar(double safeBot) {
    return Container(
      padding: EdgeInsets.only(
          bottom: safeBot + 10, top: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.88)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAction(Icons.photo_library, 'GALLERY', () {}),
          _buildShutter(),
          _buildAction(Icons.info_outline, 'DETAILS', () {}),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(double screenH) {
    return Stack(
      children: [
        // Corner brackets
        Positioned(top: 100, left: 40, child: _bracket(true, true)),
        Positioned(top: 100, right: 40, child: _bracket(true, false)),
        Positioned(bottom: 170, left: 40, child: _bracket(false, true)),
        Positioned(bottom: 170, right: 40, child: _bracket(false, false)),

        // Animated scan line
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (_, __) {
            final top = 100 + _scanAnim.value * (screenH - 270);
            return Positioned(
              top: top, left: 40, right: 40,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Colors.transparent,
                    Color(0xFFf97316),
                    Color(0xFFf97316),
                    Colors.transparent,
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFf97316).withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 4)
                  ],
                ),
              ),
            );
          },
        ),

        // Instruction
        Positioned(
          bottom: 180,
          left: 0, right: 0,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Text(
                    'Point at your rooftop surface',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Surface edge line ─────────────────────────────────────────────────────
  Widget _surfaceEdge() {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0xFF4CAF50),
            Color(0xFF4CAF50),
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.88, 1.0],
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
              blurRadius: 6)
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44, height: 44,
          color: Colors.white.withValues(alpha: 0.12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(child: Icon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }

  Widget _bracket(bool top, bool left) {
    return SizedBox(
      width: 36, height: 36,
      child: CustomPaint(
        painter: _BracketPainter(top: top, left: left),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
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
              child: Center(child: Icon(icon, color: Colors.white, size: 22)),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _buildShutter() {
    return GestureDetector(
      onTap: () {
        if (_scanDone) {
          Navigator.pushReplacementNamed(context, '/scan/loading');
        }
      },
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFf97316), Color(0xFF7C1F00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFf97316).withValues(alpha: 0.5),
                  blurRadius: 12)
            ],
          ),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ── Corner bracket painter ────────────────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final bool top, left;
  const _BracketPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFf97316)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x  = left ? 0.0 : size.width;
    final y  = top  ? 0.0 : size.height;
    final dx = left ? size.width * 0.65 : -size.width * 0.65;
    final dy = top  ? size.height * 0.65 : -size.height * 0.65;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}
