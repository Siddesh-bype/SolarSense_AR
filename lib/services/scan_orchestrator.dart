// lib/services/scan_orchestrator.dart
//
// Master service that coordinates all on-device services into a single call.
// No network backend required — every input (irradiance, subsidy, obstacles,
// brands) is computed on-device.
//
// PVGIS and obstacle detection run concurrently via Future.wait().
// Subsidy and brand calculation are synchronous after PVGIS resolves.

import 'dart:typed_data';

import '../models/enriched_scan_result.dart';
import '../models/obstacle_detection.dart';
import 'brand_service.dart';
import 'obstacle_service.dart';
import 'pvgis_service.dart';
import 'subsidy_service.dart';

/// Usable roof area occupied by one 540 Wp panel + setback (matches the
/// native PanelGridCalculator PANEL_AREA = 1.70 × 1.14 m).
const double _kPanelAreaM2 = 1.938;

class ScanOrchestrator {
  final PvgisService _pvgis;
  final SubsidyService _subsidy;
  final BrandService _brands;
  final ObstacleService _obstacles;

  ScanOrchestrator({
    PvgisService? pvgis,
    SubsidyService? subsidy,
    BrandService? brands,
    ObstacleService? obstacles,
  })  : _pvgis = pvgis ?? PvgisService(),
        _subsidy = subsidy ?? SubsidyService(),
        _brands = brands ?? BrandService(),
        _obstacles = obstacles ?? ObstacleService();

  /// Initialise all services (loads assets, warms up model).
  /// Call this once — ideally from main() or a SplashScreen.
  Future<void> init() async {
    await Future.wait([
      _subsidy.init(),
      _brands.init(),
      _obstacles.init(),
    ]);
  }

  /// Runs the full on-device analysis pipeline.
  ///
  /// PVGIS and obstacle detection run in parallel. Obstacles subtract their
  /// reserved area from [usableAreaM2] and reduce generation by their
  /// combined shading loss. Returns [EnrichedScanResult] — never throws.
  Future<EnrichedScanResult> enrichScan({
    required double lat,
    required double lon,
    required double systemKw,
    required String stateName,
    required double totalAreaM2,
    required double usableAreaM2,
    required int panelCount,
    required double avgTariff,
    required String priceSensitivity,
    Uint8List? cameraFrame,
    double? headingDeg,
  }) async {
    // ── Run PVGIS + obstacle detection concurrently ───────────────────────────
    final stateKey = stateName.toLowerCase().trim().replaceAll(' ', '_');
    final futures = await Future.wait([
      _pvgis.fetchIrradiance(lat, lon, stateKey),
      _obstacles.detectObstacles(cameraFrame),
    ]);

    final irradiance = futures[0] as IrradianceResult;
    final obstacles = futures[1] as List<ObstacleDetection>;

    final obstacleSummary = _obstacles.aggregate(obstacles);

    // ── Obstacle-aware usable area & panel cap ─────────────────────────────────
    final effectiveUsable = (usableAreaM2 - obstacleSummary.obstacleAreaM2)
        .clamp(0.0, usableAreaM2);
    final maxPanelsByArea = (effectiveUsable / _kPanelAreaM2).floor();
    final cappedPanels = maxPanelsByArea < panelCount ? maxPanelsByArea : panelCount;
    final effectiveKw = systemKw > 0 ? systemKw : (cappedPanels * 0.54);

    // ── Annual generation (gross → net of shading loss) ───────────────────────
    final annualKwhGross = effectiveKw * irradiance.annualKwhPerKw;
    final annualKwh = annualKwhGross * (1 - obstacleSummary.shadingLossPct);

    // ── Subsidy calculation (synchronous) ─────────────────────────────────────
    final subsidyResult = _subsidy.calculate(
      systemKw: effectiveKw,
      stateName: stateName,
      annualKwh: annualKwh,
      avgTariff: avgTariff,
    );

    // ── Brand recommendations (synchronous) ───────────────────────────────────
    final brandList = _brands.getTopBrands(
      systemKw: effectiveKw,
      priceSensitivity: priceSensitivity,
    );

    return EnrichedScanResult(
      totalAreaM2: totalAreaM2,
      usableAreaM2: effectiveUsable,
      panelCount: cappedPanels,
      systemSizeKw: double.parse(effectiveKw.toStringAsFixed(2)),
      peakSunHours: irradiance.peakSunHours,
      pvgisFallback: irradiance.isFallback,
      annualKwh: double.parse(annualKwh.toStringAsFixed(1)),
      annualKwhGross: double.parse(annualKwhGross.toStringAsFixed(1)),
      centralSubsidy: subsidyResult.centralSubsidy,
      stateSubsidy: subsidyResult.stateSubsidy,
      totalSubsidy: subsidyResult.totalSubsidy,
      estimatedCost: subsidyResult.estimatedCost,
      netCost: subsidyResult.netCost,
      paybackYears: subsidyResult.paybackYears,
      annualSavingsInr: subsidyResult.annualSavingsInr,
      obstacleSummary: obstacleSummary,
      detectedObstacles: obstacles,
      lat: lat,
      lon: lon,
      headingDeg: headingDeg,
      captureJpeg: cameraFrame,
      stateDisplayName: subsidyResult.stateDisplayName,
      statePortal: subsidyResult.statePortal,
      stateNotes: subsidyResult.stateNotes,
      brandRecommendations: brandList,
    );
  }
}
