// lib/widgets/solar_panel_3d.dart
//
// Perspective-correct solar panel grid.
// Panels are rendered as solid 3D boxes lying on the ground plane,
// with a true vanishing-point perspective projection (not isometric).
// Light shimmer animation simulates sunlight reflections.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SolarPanel3DWidget extends StatefulWidget {
  final int panelCount;
  final double size;
  // Gyroscope tilt offsets: shift the grid's vanishing point slightly
  final double tiltX;  // lateral tilt (left/right phone)
  final double tiltY;  // fore/aft tilt (phone facing down/up)

  const SolarPanel3DWidget({
    super.key,
    required this.panelCount,
    this.size = 300,
    this.tiltX = 0,
    this.tiltY = 0,
  });

  @override
  State<SolarPanel3DWidget> createState() => _SolarPanel3DWidgetState();
}

class _SolarPanel3DWidgetState extends State<SolarPanel3DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size * 0.65),
        painter: _GroundPlanePainter(
          panelCount: widget.panelCount,
          shimmer: _shimmer.value,
          tiltX: widget.tiltX,
          tiltY: widget.tiltY,
        ),
      ),
    );
  }
}

/// Renders an N-panel grid in vanishing-point perspective, lying flat on an
/// implied ground plane. Each panel is a solid 3D box:
///   top face  = navy-blue solar cell surface with 6×4 grid lines
///   front face = darker side (visible thickness)
class _GroundPlanePainter extends CustomPainter {
  final int panelCount;
  final double shimmer;   // 0..1 animation value
  final double tiltX;
  final double tiltY;

  const _GroundPlanePainter({
    required this.panelCount,
    required this.shimmer,
    required this.tiltX,
    required this.tiltY,
  });

  // ── Perspective helpers ────────────────────────────────────────────────────

  // Maps a 3D (x, z) coordinate on the ground plane to canvas 2D.
  // x = left/right  z = depth (0=front, 1=back)
  // vanishX/vanishY = vanishing point (horizon)
  // groundY = y position of the foreground edge
  Offset _project(double x, double z, double vanishX, double vanishY,
      double groundY, double halfW) {
    // Perspective lerp: as z→1 everything converges to the vanishing point
    final t = math.pow(z, 0.55).toDouble(); // non-linear for stronger depth
    final screenX = vanishX + x * halfW * (1 - t);
    final screenY = groundY + (vanishY - groundY) * t;
    return Offset(screenX, screenY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    // Vanishing point: shifted by tilt, sits at ~15% from top
    final vanishX = W / 2 + tiltX * 30;
    final vanishY = H * 0.12 + tiltY * 20;
    final groundY = H * 0.98; // foreground edge at bottom

    // Grid layout
    final cols = panelCount < 4 ? panelCount : (math.sqrt(panelCount) * 1.5).ceil().clamp(2, 6);
    final rows = (panelCount / cols).ceil();

    // Cell spacing in "ground" units (0..1 space mapped to halfW)
    final halfW = W * 0.46;
    final cellW = 1.8 / cols;  // width of one cell in ground units
    final cellD = 1.0 / rows;  // depth of one cell
    // Panel thickness — visible as the front face
    const thicknessZ = 0.04;

    // Draw ground shadow first
    _drawGroundShadow(canvas, W, H, vanishX, groundY);

    // Draw panels back → front (painter's algorithm)
    for (int row = rows - 1; row >= 0; row--) {
      for (int col = 0; col < cols; col++) {
        final idx = row * cols + col;
        if (idx >= panelCount) continue;

        // Normalised x position: -0.9..+0.9
        final x0 = -0.9 + col * cellW;
        final x1 = x0 + cellW * 0.92; // slight gap between panels

        // z positions: 0=front (near camera) 1=back (horizon)
        // row 0 = front, row N = back
        final z0 = (rows - 1 - row) / rows.toDouble();
        final z1 = (rows - row) / rows.toDouble();

        // 4 corners of the TOP FACE
        final fl = _project(x0, z0, vanishX, vanishY, groundY, halfW); // front-left
        final fr = _project(x1, z0, vanishX, vanishY, groundY, halfW); // front-right
        final bl = _project(x0, z1, vanishX, vanishY, groundY, halfW); // back-left
        final br = _project(x1, z1, vanishX, vanishY, groundY, halfW); // back-right

        // Front face bottom (same x, z0 but shifted down by thickness)
        final flBot = Offset(fl.dx, fl.dy + (groundY - vanishY) * thicknessZ * (1 - z0));
        final frBot = Offset(fr.dx, fr.dy + (groundY - vanishY) * thicknessZ * (1 - z0));

        _drawSinglePanel(
          canvas, fl, fr, bl, br, flBot, frBot,
          idx, shimmer,
        );
      }
    }

    // Mounting rails (two horizontal bars)
    _drawRails(canvas, cols, rows, vanishX, vanishY, groundY, halfW, cellW, cellD);
  }

  void _drawSinglePanel(
    Canvas canvas,
    Offset fl, Offset fr, Offset bl, Offset br,
    Offset flBot, Offset frBot,
    int idx, double shimmer,
  ) {
    // ── Front face (visible thickness — this is what makes it look solid) ────
    final frontPath = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(fr.dx, fr.dy)
      ..lineTo(frBot.dx, frBot.dy)
      ..lineTo(flBot.dx, flBot.dy)
      ..close();

    canvas.drawPath(
      frontPath,
      Paint()..color = const Color(0xFF061035),
    );

    // ── Top face (the solar panel surface) ───────────────────────────────────
    final topPath = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(fr.dx, fr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // Base navy blue fill
    canvas.drawPath(topPath, Paint()..color = const Color(0xFF0D2060));

    // Shimmer band — moves across all panels together
    final shimX = fl.dx + (fr.dx - fl.dx) * ((shimmer * 1.4 - 0.2).clamp(0.0, 1.0));
    final shimW = (fr.dx - fl.dx) * 0.18;
    if (shimX > fl.dx && shimX < fr.dx) {
      final shimPath = Path()
        ..moveTo(shimX, fl.dy)
        ..lineTo(shimX + shimW, fr.dy)
        ..lineTo(shimX + shimW, br.dy)
        ..lineTo(shimX, bl.dy)
        ..close();
      canvas.drawPath(shimPath,
          Paint()..color = Colors.white.withValues(alpha: 0.08));
    }

    // Reflection highlight at top-left quadrant
    final hlPath = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(Offset.lerp(fl, fr, 0.28)!.dx, Offset.lerp(fl, fr, 0.28)!.dy)
      ..lineTo(Offset.lerp(bl, br, 0.28)!.dx, Offset.lerp(bl, br, 0.28)!.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(hlPath,
        Paint()..color = Colors.white.withValues(alpha: 0.07));

    // ── Cell grid lines on top face ──────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFF0A1850).withValues(alpha: 0.9)
      ..strokeWidth = 0.5;

    const gc = 6; // columns
    const gr = 4; // rows
    for (int i = 1; i < gc; i++) {
      final t = i / gc;
      canvas.drawLine(
        Offset.lerp(fl, fr, t)!,
        Offset.lerp(bl, br, t)!,
        gridPaint,
      );
    }
    for (int j = 1; j < gr; j++) {
      final t = j / gr;
      canvas.drawLine(
        Offset.lerp(fl, bl, t)!,
        Offset.lerp(fr, br, t)!,
        gridPaint,
      );
    }

    // ── Panel outline (aluminium frame) ──────────────────────────────────────
    canvas.drawPath(
      topPath,
      Paint()
        ..color = const Color(0xFF4A7BC8).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  void _drawRails(
    Canvas canvas,
    int cols,
    int rows,
    double vanishX,
    double vanishY,
    double groundY,
    double halfW,
    double cellW,
    double cellD,
  ) {
    final railPaint = Paint()
      ..color = const Color(0xFF607D8B).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Two horizontal mounting rails at 33% and 67% depth
    for (final zFrac in [0.33, 0.67]) {
      final left  = _project(-0.9, zFrac, vanishX, vanishY, groundY, halfW);
      final right = _project(0.9 + cellW, zFrac, vanishX, vanishY, groundY, halfW);
      canvas.drawLine(left, right, railPaint);
    }
  }

  void _drawGroundShadow(
      Canvas canvas, double W, double H, double vanishX, double groundY) {
    final rect = Rect.fromLTWH(W * 0.05, groundY - H * 0.04, W * 0.9, H * 0.06);
    final shader = RadialGradient(
      center: Alignment.topCenter,
      radius: 1.0,
      colors: [
        Colors.black.withValues(alpha: 0.35),
        Colors.transparent,
      ],
    ).createShader(rect);

    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_GroundPlanePainter old) =>
      old.shimmer != shimmer     ||
      old.panelCount != panelCount ||
      old.tiltX != tiltX         ||
      old.tiltY != tiltY;
}
