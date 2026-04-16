import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints a photorealistic solar panel grid directly on the Flutter canvas.
///
/// Visual design matches the `10781_Solar-Panels_V1.glb` model:
///   • Dark monocrystalline cells (near-black with subtle blue tint)
///   • Silver aluminium outer frame per panel
///   • 3 × horizontal bus bars across each cell
///   • Dense thin finger lines running perpendicular to bus bars
///   • Subtle gloss shimmer sweep (animated)
///   • Cyan glow border around the whole array
class ARSolarPainter extends CustomPainter {
  ARSolarPainter({
    required this.corners,
    required this.cornerCount,
    required this.obstacleRects,
    required this.animationValue,
    required this.panelCols,
    required this.panelRows,
  });

  final List<Offset> corners;
  final int cornerCount;
  final List<Rect> obstacleRects;
  final double animationValue;
  final int panelCols;
  final int panelRows;

  // ── Palette ────────────────────────────────────────────────────────────────
  // Matches the GLB's PBR material colours:

  /// Dark monocrystalline silicon cell body — nearly black with cold-blue tint.
  static const _cellColor = Color(0xFF0D1B2A);

  /// Slight reflective tint across the cell surface.
  static const _cellSheen = Color(0xFF1A2A40);

  /// Silver aluminium frame/border around each individual panel.
  static const _frameColor = Color(0xFFB0BEC5); // Material BlueGrey 200

  /// Thin bright silver finger lines running horizontally across each cell.
  static const _fingerColor = Color(0x88CFD8DC);

  /// Thicker bus-bar lines (3 per panel, vertical to cell top).
  static const _busBarColor = Color(0xCCB0BEC5);

  // ── Paint objects (allocated once) ────────────────────────────────────────

  static final _cellFill = Paint()
    ..color = _cellColor
    ..style = PaintingStyle.fill;

  static final _framePaint = Paint()
    ..color = _frameColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;

  static final _innerFramePaint = Paint()
    ..color = _frameColor.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  static final _busPaint = Paint()
    ..color = _busBarColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  static final _fingerPaint = Paint()
    ..color = _fingerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  static final _obstacleFill = Paint()
    ..color = const Color(0xAAD32F2F)
    ..style = PaintingStyle.fill;

  static final _obstacleStroke = Paint()
    ..color = const Color(0xFFFF5252)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final _obstacleStripe = Paint()
    ..color = const Color(0x88FF5252)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final _cornerFill = Paint()..color = const Color(0xFF00E5FF);

  // ── Entry point ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawConnectionLines(canvas);
    for (int i = 0; i < cornerCount && i < corners.length; i++) {
      _drawCornerMarker(canvas, corners[i], i + 1);
    }

    if (cornerCount < 4 || corners.length < 4) return;

    final tl = corners[0];
    final tr = corners[1];
    final br = corners[2];
    final bl = corners[3];

    final arrayPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    canvas.save();
    canvas.clipPath(arrayPath);

    // Base fill — very dark, slightly blue, like the GLB backsheet colour.
    canvas.drawPath(
      arrayPath,
      Paint()
        ..color = const Color(0xE00A1420)
        ..style = PaintingStyle.fill,
    );

    _drawPanelGrid(canvas, tl, tr, br, bl);
    _drawShimmer(canvas, tl, tr, br, bl);

    for (final rect in obstacleRects) {
      _drawObstacle(canvas, rect);
    }

    canvas.restore();

    _drawGlowBorder(canvas, arrayPath);

    for (int i = 0; i < corners.length; i++) {
      _drawCornerMarker(canvas, corners[i], i + 1);
    }
  }

  // ── Panel grid ────────────────────────────────────────────────────────────

  void _drawPanelGrid(Canvas canvas, Offset tl, Offset tr, Offset br, Offset bl) {
    final cols = math.max(panelCols, 1);
    final rows = math.max(panelRows, 1);

    // Gap fraction between panels (simulates aluminium rail gap).
    const gapFrac = 0.025;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final u0 = c / cols + gapFrac;
        final u1 = (c + 1) / cols - gapFrac;
        final v0 = r / rows + gapFrac;
        final v1 = (r + 1) / rows - gapFrac;

        final cTL = _bi(tl, tr, br, bl, u0, v0);
        final cTR = _bi(tl, tr, br, bl, u1, v0);
        final cBR = _bi(tl, tr, br, bl, u1, v1);
        final cBL = _bi(tl, tr, br, bl, u0, v1);

        _drawSinglePanel(canvas, cTL, cTR, cBR, cBL);
      }
    }
  }

  /// Draws one individual solar panel with frame, cell grid, bus bars,
  /// and finger lines — matching the GLB model's appearance.
  void _drawSinglePanel(
      Canvas canvas, Offset tl, Offset tr, Offset br, Offset bl) {
    final panelPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // ── Cell body ─────────────────────────────────────────────────────────
    canvas.drawPath(panelPath, _cellFill);

    // Subtle gradient sheen across the cell (simulates PBR reflection).
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _cellSheen.withValues(alpha: 0.0),
          _cellSheen.withValues(alpha: 0.35),
          _cellSheen.withValues(alpha: 0.0),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromPoints(tl, br));
    canvas.save();
    canvas.clipPath(panelPath);
    canvas.drawPath(panelPath, sheenPaint);

    // ── Cell sub-grid (internal cell lines) ───────────────────────────────
    // Solar panels have a 6×10 or 6×12 internal cell grid (60 or 72 cells).
    // We draw a simplified 6×10 internal grid matching the GLB appearance.
    const subCols = 6;
    const subRows = 10;
    for (int sc = 1; sc < subCols; sc++) {
      final f = sc / subCols;
      final top = Offset.lerp(tl, tr, f)!;
      final bot = Offset.lerp(bl, br, f)!;
      canvas.drawLine(top, bot, _fingerPaint);
    }
    for (int sr = 1; sr < subRows; sr++) {
      final f = sr / subRows;
      final left = Offset.lerp(tl, bl, f)!;
      final right = Offset.lerp(tr, br, f)!;
      canvas.drawLine(left, right, _fingerPaint);
    }

    // ── Bus bars (3 per panel, matching GLB model) ────────────────────────
    // Evenly spaced at 25%, 50%, 75% of the panel height.
    for (final vFrac in [0.25, 0.50, 0.75]) {
      final left = Offset.lerp(tl, bl, vFrac)!;
      final right = Offset.lerp(tr, br, vFrac)!;
      canvas.drawLine(left, right, _busPaint);
    }

    canvas.restore();

    // ── Silver aluminium frame ─────────────────────────────────────────────
    // Outer frame — bright silver, wider stroke.
    canvas.drawPath(panelPath, _framePaint);

    // Inner chamfer line (simulates the anodised inset frame detail).
    const inset = 2.5;
    final framePath = Path()
      ..moveTo(tl.dx + inset, tl.dy + inset)
      ..lineTo(tr.dx - inset, tr.dy + inset)
      ..lineTo(br.dx - inset, br.dy - inset)
      ..lineTo(bl.dx + inset, bl.dy - inset)
      ..close();
    canvas.drawPath(framePath, _innerFramePaint);
  }

  // ── Shimmer (animated gloss sweep) ────────────────────────────────────────

  void _drawShimmer(Canvas canvas, Offset tl, Offset tr, Offset br, Offset bl) {
    final u = animationValue;
    const half = 0.06;

    final sL0 = _bi(tl, tr, br, bl, (u - half).clamp(0, 1), 0);
    final sR0 = _bi(tl, tr, br, bl, (u + half).clamp(0, 1), 0);
    final sR1 = _bi(tl, tr, br, bl, (u + half).clamp(0, 1), 1);
    final sL1 = _bi(tl, tr, br, bl, (u - half).clamp(0, 1), 1);

    final shimmerPath = Path()
      ..moveTo(sL0.dx, sL0.dy)
      ..lineTo(sR0.dx, sR0.dy)
      ..lineTo(sR1.dx, sR1.dy)
      ..lineTo(sL1.dx, sL1.dy)
      ..close();

    canvas.drawPath(
      shimmerPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromPoints(sL0, sR1)),
    );
  }

  // ── Obstacle overlay ──────────────────────────────────────────────────────

  void _drawObstacle(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, _obstacleFill);

    canvas.save();
    canvas.clipRect(rect);
    for (double x = rect.left - rect.height; x < rect.right; x += 14) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        _obstacleStripe,
      );
    }
    canvas.restore();

    canvas.drawRect(rect, _obstacleStroke);

    final tp = TextPainter(
      text: const TextSpan(
        text: '⊘',
        style: TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
  }

  // ── Glow border ───────────────────────────────────────────────────────────

  void _drawGlowBorder(Canvas canvas, Path path) {
    for (int i = 4; i >= 1; i--) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.05 * i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i * 5.0,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  // ── Connection lines between tapped corners ───────────────────────────────

  void _drawConnectionLines(Canvas canvas) {
    if (cornerCount < 2) return;
    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < cornerCount - 1 && i < corners.length - 1; i++) {
      canvas.drawLine(corners[i], corners[i + 1], linePaint);
    }
    if (cornerCount == 4 && corners.length >= 4) {
      canvas.drawLine(corners[3], corners[0], linePaint);
    }
  }

  // ── Corner number markers ──────────────────────────────────────────────────

  void _drawCornerMarker(Canvas canvas, Offset pos, int number) {
    const double r = 14;

    final pulsePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25 * (1 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, r + 8 * animationValue, pulsePaint);
    canvas.drawCircle(pos, r, _cornerFill);

    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
            color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  // ── Bilinear quad interpolation ───────────────────────────────────────────

  Offset _bi(Offset tl, Offset tr, Offset br, Offset bl, double u, double v) {
    final top = Offset.lerp(tl, tr, u)!;
    final bot = Offset.lerp(bl, br, u)!;
    return Offset.lerp(top, bot, v)!;
  }

  @override
  bool shouldRepaint(ARSolarPainter old) =>
      old.animationValue != animationValue ||
      old.cornerCount != cornerCount ||
      old.corners != corners ||
      old.obstacleRects != obstacleRects ||
      old.panelCols != panelCols ||
      old.panelRows != panelRows;
}
