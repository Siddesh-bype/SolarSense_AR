import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Channel constants ────────────────────────────────────────────────────────
const _kViewType = 'com.solarsense.ar/scene';
const _kMethodCh = MethodChannel('com.solarsense.ar/channel');
const _kEventCh  = EventChannel('com.solarsense.ar/events');

// Panel size constants (for local display only — real values come from ARCore)
const double _kPanelKw   = 0.54;  // 540 W panel

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

  @override
  void initState() {
    super.initState();
    _kEventCh.receiveBroadcastStream().listen(_onArEvent, onError: (_) {});
  }

  void _onArEvent(dynamic event) {
    if (event is Map && mounted) {
      setState(() {
        _panelCount = (event['panelCount'] as int?) ?? _panelCount;
        _maxPanels  = (event['maxPanels']  as int?) ?? _maxPanels;
        _systemKw   = (event['systemKw']   as double?) ?? _systemKw;
        _areaSqm    = (event['areaSqm']    as double?) ?? _areaSqm;
        _planeFound = (event['planeFound'] as bool?)  ?? _planeFound;
      });
    }
  }

  // ── Channel helpers ───────────────────────────────────────────────────────

  Future<void> _addPanel()    => _kMethodCh.invokeMethod('addPanel');
  Future<void> _removePanel() => _kMethodCh.invokeMethod('removePanel');
  Future<void> _resetScan()   => _kMethodCh.invokeMethod('resetScan');

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
        },
      );
    } catch (_) {
      // If Kotlin side not ready, navigate anyway
      if (mounted) Navigator.pushReplacementNamed(context, '/scan/loading');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── Layer 1: Real ARCore + SceneView (full screen, hardware) ──────
          Positioned.fill(
            child: AndroidView(
              viewType: _kViewType,
              creationParamsCodec: const StandardMessageCodec(),
              // Hybrid composition: the SurfaceView composites with Flutter's layer tree
              gestureRecognizers: const {},
            ),
          ),

          // ── Layer 2: "Point phone at surface" hint (before plane detected) ─
          if (!_planeFound)
            const Positioned.fill(child: _PlaneHint()),

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
                onMaxFill: () async {
                  // Fill up to max by calling addPanel repeatedly
                  for (int i = _panelCount; i < _maxPanels; i++) {
                    await _addPanel();
                  }
                },
                panelCount: _panelCount,
                maxPanels: _maxPanels,
              ),
            ),

          // ── Layer 6: Bottom shutter bar ────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _ShutterBar(
              safeBot: safeBot,
              planeFound: _planeFound,
              onCapture: _capture,
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
            Text('SolarSense AR',
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
  final double areaSqm, systemKw;
  final int panelCount, maxPanels;

  const _StatsRow({
    required this.areaSqm,
    required this.systemKw,
    required this.panelCount,
    required this.maxPanels,
  });

  @override
  Widget build(BuildContext context) {
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
  final VoidCallback onCapture, onReset;

  const _ShutterBar({
    required this.safeBot,
    required this.planeFound,
    required this.onCapture,
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
          _BarAction(icon: Icons.photo_library, label: 'GALLERY', onTap: () {}),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BarAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
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
                color: Colors.white60, fontSize: 9,
                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ]),
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
