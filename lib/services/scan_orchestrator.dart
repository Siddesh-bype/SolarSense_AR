// lib/services/scan_orchestrator.dart
//
// Master service that coordinates all on-device services into a single call.
// Replaces the HTTP ApiService.enrichScan() call — no network backend required.
//
// PVGIS and obstacle detection run concurrently via Future.wait().
// Subsidy and brand calculation are synchronous after PVGIS resolves.

import 'dart:typed_data';

import '../models/enriched_scan_result.dart';
import 'brand_service.dart';
import 'obstacle_service.dart';
import 'pvgis_service.dart';
import 'subsidy_service.dart';

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
  /// PVGIS and obstacle detection run in parallel.
  /// Returns [EnrichedScanResult] — never throws.
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
  }) async {
    // ── Run PVGIS + obstacle detection concurrently ───────────────────────────
    final futures = await Future.wait([
      _pvgis.fetchIrradiance(lat, lon),
      _obstacles.detectObstacles(cameraFrame),
    ]);

    final irradiance = futures[0] as IrradianceResult;
    final obstacles = futures[1] as dynamic; // List<ObstacleDetection>

    // ── Annual generation ─────────────────────────────────────────────────────
    final annualKwh = systemKw * irradiance.annualKwhPerKw;

    // ── Subsidy calculation (synchronous) ─────────────────────────────────────
    final subsidyResult = _subsidy.calculate(
      systemKw: systemKw,
      stateName: stateName,
      annualKwh: annualKwh,
      avgTariff: avgTariff,
    );

    // ── Brand recommendations (synchronous) ───────────────────────────────────
    final brandList = _brands.getTopBrands(
      systemKw: systemKw,
      priceSensitivity: priceSensitivity,
    );

    return EnrichedScanResult(
      totalAreaM2: totalAreaM2,
      usableAreaM2: usableAreaM2,
      panelCount: panelCount,
      systemSizeKw: systemKw,
      peakSunHours: irradiance.peakSunHours,
      pvgisFallback: irradiance.isFallback,
      annualKwh: double.parse(annualKwh.toStringAsFixed(1)),
      centralSubsidy: subsidyResult.centralSubsidy,
      stateSubsidy: subsidyResult.stateSubsidy,
      totalSubsidy: subsidyResult.totalSubsidy,
      estimatedCost: subsidyResult.estimatedCost,
      netCost: subsidyResult.netCost,
      paybackYears: subsidyResult.paybackYears,
      annualSavingsInr: subsidyResult.annualSavingsInr,
      stateDisplayName: subsidyResult.stateDisplayName,
      statePortal: subsidyResult.statePortal,
      stateNotes: subsidyResult.stateNotes,
      brandRecommendations: brandList,
      detectedObstacles: obstacles as dynamic,
    );
  }
}
