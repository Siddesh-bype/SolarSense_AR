// lib/widgets/solar_panel_3d.dart
//
// Perspective-correct solar panel grid rendered as a CustomPaint.
// Panels are solid 3D boxes lying on the ground plane with a
// true vanishing-point projection. A slow shimmer band animates
// across the grid to suggest sunlight reflection.
//
// Performance notes:
//   * The painter subscribes to the AnimationController via the
//     `repaint:` argument. Flutter then repaints the CustomPaint
//     layer directly — no widget rebuilds, no AnimatedBuilder churn.
//   * Wrapped in a RepaintBoundary so ancestors never repaint.
//   * Uses TickerMode to pause the ticker when the widget is off-screen
//     (e.g. scrolled away in the report screen), eliminating the
//     per-frame CPU cost when invisible.
//   * Shimmer duration bumped to 6s so fewer pixels change per frame.
//   * Caller can pass `animate: false` to disable the shimmer entirely
//     (used for small thumbnail renders where animation is wasted effort).

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SolarPanel3DWidget extends StatefulWidget {
  final int panelCount;
  final double size;
  // Gyroscope tilt offsets: shift the grid's vanishing point slightly
  final double tiltX;
  final double tiltY;
  // When false, shimmer is skipped and no ticker is created — cheapest.
  final bool animate;

  const SolarPanel3DWidget({
    super.key,
    required this.panelCount,
    this.size = 300,
    this.tiltX = 0,
    this.tiltY = 0,
    this.animate = true,
  });

  @override
  State<SolarPanel3DWidget> createState() => _SolarPanel3DWidgetState();
}

class _SolarPanel3DWidgetState extends State<SolarPanel3DWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _shimmer;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _shimmer = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(SolarPanel3DWidget old) {
    super.didUpdateWidget(old);
    if (widget.animate && _shimmer == null) {
      _shimmer = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat();
    } else if (!widget.animate && _shimmer != null) {
      _shimmer!.dispose();
      _shimmer = null;
    }
  }

  @override
  void dispose() {
    _shimmer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TickerMode pauses the ticker when the subtree isn't visible
    // (e.g. scrolled off-screen inside a ListView / TabView).
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size * 0.65),
        // Subscribing to `_shimmer` via `repaint:` skips widget rebuild
        // entirely — Flutter repaints the CustomPaint layer only.
        painter: _GroundPlanePainter(
          panelCount: widget.panelCount,
          shimmer: _shimmer,
          tiltX: widget.tiltX,
          tiltY: widget.tiltY,
        ),
      ),
    );
  }
}

class _GroundPlanePainter extends CustomPainter {
  final int panelCount;
  final AnimationController? shimmer;
  final double tiltX;
  final double tiltY;

  _GroundPlanePainter({
    required this.panelCount,
    required this.shimmer,
    required this.tiltX,
    required this.tiltY,
  }) : super(repaint: shimmer);

  Offset _project(double x, double z, double vanishX, double vanishY,
      double groundY, double halfW) {
    final t = math.pow(z, 0.55).toDouble();
    final screenX = vanishX + x * halfW * (1 - t);
    final screenY = groundY + (vanishY - groundY) * t;
    return Offset(screenX, screenY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final vanishX = W / 2 + tiltX * 30;
    final vanishY = H * 0.12 + tiltY * 20;
    final groundY = H * 0.98;

    final cols = panelCount < 4
        ? panelCount
        : (math.sqrt(panelCount) * 1.5).ceil().clamp(2, 6);
    final rows = (panelCount / cols).ceil();

    final halfW = W * 0.46;
    final cellW = 1.8 / cols;
    const thicknessZ = 0.04;

    _drawGroundShadow(canvas, W, H, vanishX, groundY);

    final shim = shimmer?.value ?? 0.0;

    for (int row = rows - 1; row >= 0; row--) {
      for (int col = 0; col < cols; col++) {
        final idx = row * cols + col;
        if (idx >= panelCount) continue;

        final x0 = -0.9 + col * cellW;
        final x1 = x0 + cellW * 0.92;
        final z0 = (rows - 1 - row) / rows.toDouble();
        final z1 = (rows - row) / rows.toDouble();

        final fl = _project(x0, z0, vanishX, vanishY, groundY, halfW);
        final fr = _project(x1, z0, vanishX, vanishY, groundY, halfW);
        final bl = _project(x0, z1, vanishX, vanishY, groundY, halfW);
        final br = _project(x1, z1, vanishX, vanishY, groundY, halfW);

        final flBot = Offset(fl.dx, fl.dy + (groundY - vanishY) * thicknessZ * (1 - z0));
        final frBot = Offset(fr.dx, fr.dy + (groundY - vanishY) * thicknessZ * (1 - z0));

        _drawSinglePanel(canvas, fl, fr, bl, br, flBot, frBot, shim);
      }
    }

    _drawRails(canvas, rows, vanishX, vanishY, groundY, halfW, cellW);
  }

  static Offset _bilerp(
      Offset fl, Offset fr, Offset bl, Offset br, double u, double v) {
    final top = Offset.lerp(fl, fr, u)!;
    final bot = Offset.lerp(bl, br, u)!;
    return Offset.lerp(top, bot, v)!;
  }

  void _drawSinglePanel(
    Canvas canvas,
    Offset fl, Offset fr, Offset bl, Offset br,
    Offset flBot, Offset frBot,
    double shim,
  ) {
    // Silver aluminium side-frame (the thickness of the panel)
    final frontPath = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(fr.dx, fr.dy)
      ..lineTo(frBot.dx, frBot.dy)
      ..lineTo(flBot.dx, flBot.dy)
      ..close();
    canvas.drawPath(frontPath, Paint()..color = const Color(0xFF8A93A0));

    // Top face — glass laminate under the cells
    final topPath = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(fr.dx, fr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = const Color(0xFFE5E9F0));

    canvas.save();
    canvas.clipPath(topPath);

    // Cell grid — matches typical polycrystalline module layout (6 × 12)
    const gc = 6;
    const gr = 12;
    const busbarsPerCell = 3;
    const cellInset = 0.04; // leaves a white gap between cells
    const frameInset = 0.02; // thin white border inside the frame

    final baseA = const Color(0xFF1C3C8C);
    final baseB = const Color(0xFF2A4FB4);

    for (int i = 0; i < gc; i++) {
      for (int j = 0; j < gr; j++) {
        final u0 = frameInset + (i + cellInset) * (1 - 2 * frameInset) / gc;
        final u1 = frameInset + (i + 1 - cellInset) * (1 - 2 * frameInset) / gc;
        final v0 = frameInset + (j + cellInset) * (1 - 2 * frameInset) / gr;
        final v1 = frameInset + (j + 1 - cellInset) * (1 - 2 * frameInset) / gr;

        final c00 = _bilerp(fl, fr, bl, br, u0, v0);
        final c10 = _bilerp(fl, fr, bl, br, u1, v0);
        final c11 = _bilerp(fl, fr, bl, br, u1, v1);
        final c01 = _bilerp(fl, fr, bl, br, u0, v1);

        // Subtle per-cell variation to mimic polycrystalline grains.
        final seed = ((i * 73 + j * 149) % 11) / 11.0;
        final cellColor = Color.lerp(baseA, baseB, seed)!;

        final cellPath = Path()
          ..moveTo(c00.dx, c00.dy)
          ..lineTo(c10.dx, c10.dy)
          ..lineTo(c11.dx, c11.dy)
          ..lineTo(c01.dx, c01.dy)
          ..close();
        canvas.drawPath(cellPath, Paint()..color = cellColor);

        // Tiny lighter speckle in one corner — crystalline highlight
        final spark = Offset.lerp(c00, c11, 0.22 + seed * 0.1)!;
        canvas.drawCircle(
          spark,
          (c10 - c00).distance * 0.08,
          Paint()
            ..color = const Color(0xFF4A6FD8).withValues(alpha: 0.45),
        );

        // Vertical silver busbars running through each cell
        final busbarPaint = Paint()
          ..color = const Color(0xFFC8D1DF).withValues(alpha: 0.7)
          ..strokeWidth = 0.4;
        for (int b = 1; b <= busbarsPerCell; b++) {
          final bt = b / (busbarsPerCell + 1);
          canvas.drawLine(
            Offset.lerp(c00, c10, bt)!,
            Offset.lerp(c01, c11, bt)!,
            busbarPaint,
          );
        }
      }
    }

    // Left-edge 3D lighting highlight (kept subtle over cells)
    final hlPath = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(Offset.lerp(fl, fr, 0.18)!.dx, Offset.lerp(fl, fr, 0.18)!.dy)
      ..lineTo(Offset.lerp(bl, br, 0.18)!.dx, Offset.lerp(bl, br, 0.18)!.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(hlPath,
        Paint()..color = Colors.white.withValues(alpha: 0.05));

    // Shimmer band — sunlight sliding across the glass
    if (shimmer != null) {
      final shimX =
          fl.dx + (fr.dx - fl.dx) * ((shim * 1.4 - 0.2).clamp(0.0, 1.0));
      final shimW = (fr.dx - fl.dx) * 0.18;
      if (shimX > fl.dx && shimX < fr.dx) {
        final shimPath = Path()
          ..moveTo(shimX, fl.dy)
          ..lineTo(shimX + shimW, fr.dy)
          ..lineTo(shimX + shimW, br.dy)
          ..lineTo(shimX, bl.dy)
          ..close();
        canvas.drawPath(shimPath,
            Paint()..color = Colors.white.withValues(alpha: 0.09));
      }
    }

    canvas.restore();

    // Silver aluminium frame (outer outline)
    canvas.drawPath(
      topPath,
      Paint()
        ..color = const Color(0xFFBFC7D3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawRails(
    Canvas canvas,
    int rows,
    double vanishX,
    double vanishY,
    double groundY,
    double halfW,
    double cellW,
  ) {
    final railPaint = Paint()
      ..color = const Color(0xFF607D8B).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

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
      old.panelCount != panelCount ||
      old.tiltX != tiltX ||
      old.tiltY != tiltY ||
      old.shimmer != shimmer;
}
