import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../application/controllers/ar_controller.dart';
import '../../domain/models/area_model.dart';
import '../../../../core/converters/unit_converter.dart';

/// Live metrics HUD displayed at the top of the AR screen.
///
/// Shows different states depending on [ARScanMode].
class AROverlayUI extends StatelessWidget {
  const AROverlayUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARController>(
      builder: (_, ctrl, __) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top bar (always shown)
                _TopBar(mode: ctrl.mode, cornerCount: ctrl.cornerCount, placementState: ctrl.placementState),
                const SizedBox(height: 10),

                // Metrics (shown only after polygon complete)
                if (ctrl.isPolygonComplete) ...[
                  _MetricRow(area: ctrl.areaModel),
                  const SizedBox(height: 8),
                  _SystemCard(area: ctrl.areaModel),
                ] else if (ctrl.cornerCount >= 3) ...[
                  _EstimateChip(estimatedAreaM2: ctrl.estimatedAreaM2),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mode, required this.cornerCount, required this.placementState});
  final ARScanMode mode;
  final int cornerCount;
  final PlacementState placementState;

  String get _modeLabel {
    if (placementState == PlacementState.fallback) return 'Placing panels...';
    if (placementState == PlacementState.refining) return 'Adjusting to surface...';
    if (placementState == PlacementState.locked) return 'Locked to roof';

    switch (mode) {
      case ARScanMode.scanning:
        return 'Scanning…';
      case ARScanMode.definingCorners:
        return 'Corner $cornerCount / 4';
      case ARScanMode.complete:
        return 'Layout Ready';
      case ARScanMode.addingObstacle:
        return 'Add Obstacle';
    }
  }

  Color get _modeColor {
    if (placementState == PlacementState.fallback) return const Color(0xFFFFD600); // Yellow
    if (placementState == PlacementState.refining) return const Color(0xFF00E5FF); // Cyan
    if (placementState == PlacementState.locked) return const Color(0xFF69FF47); // Green

    switch (mode) {
      case ARScanMode.scanning:
        return const Color(0xFF00E5FF);
      case ARScanMode.definingCorners:
        return const Color(0xFFFFD600);
      case ARScanMode.complete:
        return const Color(0xFF69FF47);
      case ARScanMode.addingObstacle:
        return const Color(0xFFFF5252);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // App title
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_rounded,
                  color: Color(0xFFFFD600), size: 16),
              const SizedBox(width: 8),
              Text(
                'SolarSense AR',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Mode badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _modeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _modeColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _modeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                _modeLabel,
                style: GoogleFonts.outfit(
                  color: _modeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Metric row ────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.area});
  final AreaModel area;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.crop_free_rounded,
            iconColor: const Color(0xFF00E5FF),
            label: 'Total Area',
            primary: '${UnitConverter.format2dp(area.totalAreaM2)} m²',
            secondary: '${UnitConverter.format2dp(area.totalAreaFt2)} ft²',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF69FF47),
            label: 'Usable Area',
            primary: '${UnitConverter.format2dp(area.usableAreaM2)} m²',
            secondary: '${UnitConverter.format2dp(area.usableAreaFt2)} ft²',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 13),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 5),
          Text(primary,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
          Text(secondary,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── System size card ──────────────────────────────────────────────────────────

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.area});
  final AreaModel area;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoChip(
            icon: Icons.solar_power_rounded,
            label: 'Panels',
            value: '${area.panelCount}',
            color: const Color(0xFFFFD600),
          ),
          Container(width: 1, height: 36, color: Colors.white12),
          _InfoChip(
            icon: Icons.bolt_rounded,
            label: 'System Size',
            value: '${UnitConverter.format2dp(area.systemSizeKw)} kW',
            color: const Color(0xFF00E5FF),
          ),
          Container(width: 1, height: 36, color: Colors.white12),
          _InfoChip(
            icon: Icons.wb_sunny_outlined,
            label: 'Daily Est.',
            value: '${UnitConverter.format2dp(area.systemSizeKw * 4.5)} kWh',
            color: const Color(0xFF69FF47),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            )),
      ],
    );
  }
}

class _EstimateChip extends StatelessWidget {
  const _EstimateChip({required this.estimatedAreaM2});

  final double estimatedAreaM2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.straighten_rounded,
              color: Color(0xFF00E5FF), size: 14),
          const SizedBox(width: 8),
          Text(
            'Estimated area: ${UnitConverter.format2dp(estimatedAreaM2)} m²',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
