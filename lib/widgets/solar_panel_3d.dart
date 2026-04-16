// lib/widgets/solar_panel_3d.dart
//
// Pure Flutter CustomPainter isometric solar panel array.
// No WebView — works on all Android/iOS versions.
// Animates auto-rotation via AnimationController.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SolarPanel3DWidget extends StatefulWidget {
  final int panelCount;
  final double size;

  const SolarPanel3DWidget({
    super.key,
    required this.panelCount,
    this.size = 300,
  });

  @override
  State<SolarPanel3DWidget> createState() => _SolarPanel3DWidgetState();
}

class _SolarPanel3DWidgetState extends State<SolarPanel3DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotController;

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotController,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size * 0.75),
        painter: _SolarArrayPainter(
          panelCount: widget.panelCount,
          rotationAngle: _rotController.value * 2 * math.pi,
        ),
      ),
    );
  }
}

class _SolarArrayPainter extends CustomPainter {
  final int panelCount;
  final double rotationAngle;

  const _SolarArrayPainter({
    required this.panelCount,
    required this.rotationAngle,
  });

  // ── Isometric helpers ──────────────────────────────────────────────────────
  // Projects a 3D point (x, y, z) to 2D canvas using a slow-rotating
  // isometric view. x=right, y=depth, z=up.
  Offset _iso(double cx, double cy, double x, double y, double z) {
    // Rotate around the z-axis slowly
    final cos = math.cos(rotationAngle * 0.3);
    final sin = math.sin(rotationAngle * 0.3);
    final rx = x * cos - y * sin;
    final ry = x * sin + y * cos;

    // Isometric projection
    const scale = 1.0;
    final px = (rx - ry) * scale * 0.866; // cos(30°)
    final py = (rx + ry) * scale * 0.5 - z * 1.0; // sin(30°) and z lift

    return Offset(cx + px, cy + py);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 1.6;

    // Compute grid layout
    final cols = panelCount < 4 ? panelCount : (panelCount / 2).ceil();
    final rows = (panelCount / cols).ceil();

    final pw = 28.0; // panel width in 3D units
    final pd = 18.0; // panel depth in 3D units
    final gap = 4.0;
    final th = 1.8; // panel thickness

    // Draw shadow ellipse first
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 10),
        width: cols * (pw + gap) * 1.4,
        height: rows * (pd + gap) * 0.5,
      ),
      shadowPaint,
    );

    // Mount frame (tilt bracket)
    _drawMountFrame(canvas, cx, cy, cols, rows, pw, pd, gap);

    // Draw panels back-to-front for correct z-order
    for (int r = rows - 1; r >= 0; r--) {
      for (int c = cols - 1; c >= 0; c--) {
        final idx = r * cols + c;
        if (idx >= panelCount) continue;

        final ox = (c - cols / 2.0 + 0.5) * (pw + gap);
        final oy = (r - rows / 2.0 + 0.5) * (pd + gap);
        final oz = r * 3.0 + 4.0; // tilt elevation

        _drawPanel(canvas, cx, cy, ox, oy, oz, pw, pd, th);
      }
    }
  }

  void _drawPanel(Canvas canvas, double cx, double cy,
      double ox, double oy, double oz,
      double pw, double pd, double th) {
    // 8 vertices of the panel box
    // Top face (solar cell side)
    final tl = _iso(cx, cy, ox - pw / 2, oy + pd / 2, oz + th);
    final tr = _iso(cx, cy, ox + pw / 2, oy + pd / 2, oz + th);
    final br = _iso(cx, cy, ox + pw / 2, oy - pd / 2, oz + th);
    final bl = _iso(cx, cy, ox - pw / 2, oy - pd / 2, oz + th);

    // Bottom face
    final tl0 = _iso(cx, cy, ox - pw / 2, oy + pd / 2, oz);
    final tr0 = _iso(cx, cy, ox + pw / 2, oy + pd / 2, oz);
    final br0 = _iso(cx, cy, ox + pw / 2, oy - pd / 2, oz);
    final bl0 = _iso(cx, cy, ox - pw / 2, oy - pd / 2, oz);

    // ── Front face (right-facing in iso) ───────────────────────────────────
    final frontPath = Path()
      ..moveTo(br.dx, br.dy)
      ..lineTo(br0.dx, br0.dy)
      ..lineTo(bl0.dx, bl0.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(
      frontPath,
      Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.85),
    );

    // ── Right side face ────────────────────────────────────────────────────
    final rightPath = Path()
      ..moveTo(tr.dx, tr.dy)
      ..lineTo(tr0.dx, tr0.dy)
      ..lineTo(br0.dx, br0.dy)
      ..lineTo(br.dx, br.dy)
      ..close();
    canvas.drawPath(
      rightPath,
      Paint()..color = const Color(0xFF0D47A1).withValues(alpha: 0.9),
    );

    // ── Top face (solar panel surface) ─────────────────────────────────────
    final topPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // Base surface gradient simulation (darker at edges)
    canvas.drawPath(
      topPath,
      Paint()..color = const Color(0xFF1565C0),
    );

    // Solar cell grid lines on top face
    _drawCellGrid(canvas, tl, tr, br, bl);

    // Frame border on top face
    canvas.drawPath(
      topPath,
      Paint()
        ..color = const Color(0xFF90CAF9).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Highlight reflection streak
    final hlPath = Path()
      ..moveTo(tl.dx + (tr.dx - tl.dx) * 0.1, tl.dy + (tr.dy - tl.dy) * 0.1)
      ..lineTo(tl.dx + (tr.dx - tl.dx) * 0.35, tl.dy + (tr.dy - tl.dy) * 0.35)
      ..lineTo(bl.dx + (br.dx - bl.dx) * 0.35, bl.dy + (br.dy - bl.dy) * 0.35)
      ..lineTo(bl.dx + (br.dx - bl.dx) * 0.1, bl.dy + (br.dy - bl.dy) * 0.1)
      ..close();
    canvas.drawPath(
      hlPath,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    // Aluminium frame corners
    _drawFrame(canvas, tl, tr, br, bl, tl0, tr0, br0, bl0);
  }

  void _drawCellGrid(Canvas canvas, Offset tl, Offset tr, Offset br, Offset bl) {
    const cols = 6;
    const rows = 4;
    final linePaint = Paint()
      ..color = const Color(0xFF0D2B5E).withValues(alpha: 0.7)
      ..strokeWidth = 0.4;

    for (int i = 1; i < cols; i++) {
      final t = i / cols;
      final top = Offset.lerp(tl, tr, t)!;
      final bot = Offset.lerp(bl, br, t)!;
      canvas.drawLine(top, bot, linePaint);
    }
    for (int j = 1; j < rows; j++) {
      final t = j / rows;
      final left = Offset.lerp(tl, bl, t)!;
      final right = Offset.lerp(tr, br, t)!;
      canvas.drawLine(left, right, linePaint);
    }
  }

  void _drawFrame(Canvas canvas,
      Offset tl, Offset tr, Offset br, Offset bl,
      Offset tl0, Offset tr0, Offset br0, Offset bl0) {
    final framePaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Top edge verticals
    canvas.drawLine(tr, tr0, framePaint);
    canvas.drawLine(br, br0, framePaint);
  }

  void _drawMountFrame(Canvas canvas, double cx, double cy,
      int cols, int rows, double pw, double pd, double gap) {
    final mountPaint = Paint()
      ..color = const Color(0xFF546E7A).withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final totalW = cols * (pw + gap);
    final totalD = rows * (pd + gap);

    // Two horizontal rail lines
    for (final frac in [0.25, 0.75]) {
      final left = _iso(cx, cy, -totalW / 2, (-totalD / 2) + totalD * frac, 2.0);
      final right = _iso(cx, cy, totalW / 2, (-totalD / 2) + totalD * frac, 2.0 + rows * 2.0);
      canvas.drawLine(left, right, mountPaint);
    }
  }

  @override
  bool shouldRepaint(_SolarArrayPainter old) =>
      old.rotationAngle != rotationAngle || old.panelCount != panelCount;
}
