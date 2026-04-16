import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../../widgets/solar_panel_3d.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';

class ARCameraScreen extends StatefulWidget {
  const ARCameraScreen({super.key});

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = true;
  int _panelCount = 12;
  late AnimationController _scanController;
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    
    _initCamera();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  Future<void> _initCamera() async {
    if (globalCameras.isNotEmpty) {
      _cameraController = CameraController(globalCameras[0], ResolutionPreset.max, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background feed
          Positioned.fill(
            child: _cameraController != null && _cameraController!.value.isInitialized
                ? CameraPreview(_cameraController!)
                : Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: AppColors.primary))),
          ),
          
          // Panel Grid Simulation in perspective
          Center(
            child: _isScanning ? _buildScanningUI() : _buildPanelGrid(),
          ),

          // Top Header Layer
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 24, left: 24, right: 24),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glassButton(Icons.arrow_back, () => Navigator.pop(context)),
                  Column(
                    children: [
                      Text('Point at your rooftop', style: GoogleFonts.manrope(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFf97316), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('SCANNING ACTIVE', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      )
                    ],
                  ),
                  _glassButton(Icons.notifications, () {}),
                ],
              ),
            ),
          ),

          // Status Badge
          if (!_isScanning)
            Positioned(
              top: 100, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFf97316), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.grid_view, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('$_panelCount panels placed', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

          // Right Sidebar Controls
          if (!_isScanning)
            Positioned(
              right: 24, top: MediaQuery.of(context).size.height / 2 - 80,
              child: Column(
                children: [
                  _glassButton(Icons.add, () => setState(() => _panelCount++)),
                  const SizedBox(height: 16),
                  _glassButton(Icons.remove, () { if (_panelCount > 1) setState(() => _panelCount--); }),
                  const SizedBox(height: 16),
                  Container(width: 40, height: 1, color: Colors.white24),
                  const SizedBox(height: 16),
                  _glassButton(Icons.rotate_right, () {}),
                ],
              ),
            ),

          // Bottom Shutter Overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 48),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: Column(
                children: [
                  Text('Tap capture when satisfied', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16, shadows: [const Shadow(color: Colors.black54, blurRadius: 4)])),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomAction(Icons.restart_alt, 'Reset', () => setState(() => _isScanning = true)),
                      // Shutter
                      GestureDetector(
                        onTap: () { if (!_isScanning) Navigator.pushReplacementNamed(context, '/scan/loading'); },
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, 
                              gradient: LinearGradient(colors: [Color(0xFFf97316), Color(0xFF9d4300)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                      _buildBottomAction(Icons.photo_library, 'Gallery', () {}),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1)),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Center(child: Icon(icon, color: Colors.white))),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Center(child: Icon(icon, color: Colors.white))),
            ),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildScanningUI() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 250, height: 250,
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFf97316).withValues(alpha: 0.4), width: 2), borderRadius: BorderRadius.circular(24)),
        ),
        Positioned(top: 0, left: 0, child: _cornerBracket(true, true)),
        Positioned(top: 0, right: 0, child: _cornerBracket(true, false)),
        Positioned(bottom: 0, left: 0, child: _cornerBracket(false, true)),
        Positioned(bottom: 0, right: 0, child: _cornerBracket(false, false)),
        AnimatedBuilder(
          animation: _scanController,
          builder: (context, child) => Positioned(
            top: _scanController.value * 230, left: 0, right: 0,
            child: Container(height: 2, decoration: BoxDecoration(color: const Color(0xFFf97316), boxShadow: [BoxShadow(color: const Color(0xFFf97316).withValues(alpha: 0.8), blurRadius: 12, spreadRadius: 4)])),
          ),
        )
      ],
    );
  }

  Widget _cornerBracket(bool top, bool left) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: top ? const BorderSide(color: Color(0xFFf97316), width: 4) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xFFf97316), width: 4) : BorderSide.none,
          left: left ? const BorderSide(color: Color(0xFFf97316), width: 4) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xFFf97316), width: 4) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(8) : Radius.zero,
          topRight: top && !left ? const Radius.circular(8) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(8) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(8) : Radius.zero,
        ),
      ),
    );
  }

  /// Renders the real 3D solar panel GLB model overlaid on the camera feed.
  /// The ModelViewer handles rotation, scaling, AR placement shadow internally.
  Widget _buildPanelGrid() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Panel count badge above the 3D model
        Positioned(
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFf97316).withValues(alpha: 0.8), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.solar_power, color: Color(0xFFf97316), size: 14),
                const SizedBox(width: 6),
                Text(
                  '$_panelCount × 250W panels',
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        // 3D Solar Panel — pure Flutter, no WebView
        SolarPanel3DWidget(
          panelCount: _panelCount,
          size: 300,
        ),

        // kW output label below the model
        Positioned(
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFf97316), Color(0xFF9d4300)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFFf97316).withValues(alpha: 0.4), blurRadius: 12)],
            ),
            child: Text(
              '${(_panelCount * 0.25).toStringAsFixed(1)} kW System',
              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
