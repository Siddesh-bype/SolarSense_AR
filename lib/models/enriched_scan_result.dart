// lib/models/enriched_scan_result.dart
//
// Single result model holding the complete output of all on-device services.

import 'dart:typed_data';

import 'brand_recommendation.dart';
import 'obstacle_detection.dart';
import 'obstacle_summary.dart';

class EnrichedScanResult {
  // ── Scan geometry ──────────────────────────────────────────────────────────
  final double totalAreaM2;
  final double usableAreaM2;
  final int panelCount;
  final double systemSizeKw;

  // ── PVGIS irradiance ───────────────────────────────────────────────────────
  final double peakSunHours;   // daily PSH average
  final bool pvgisFallback;    // true → PVGIS failed, using regional fallback
  final double annualKwh;      // net generation after shading loss
  final double annualKwhGross; // generation before shading loss (for reporting)

  // ── Financial ──────────────────────────────────────────────────────────────
  final int centralSubsidy;    // ₹30,000 / ₹60,000 / ₹78,000
  final int stateSubsidy;      // from state_subsidies.json
  final int totalSubsidy;      // central + state
  final int estimatedCost;     // gross install cost before subsidy
  final int netCost;           // estimatedCost - totalSubsidy (floor 0)
  final double paybackYears;   // netCost / (annualKwh × avgTariff)
  final double annualSavingsInr;

  // ── Obstacles & shading ────────────────────────────────────────────────────
  final ObstacleSummary obstacleSummary; // reserved area + shading loss
  final List<ObstacleDetection> detectedObstacles;

  // ── Scan metadata ──────────────────────────────────────────────────────────
  final double? lat;              // scan latitude (drives monthly solar curve)
  final double? lon;
  final double? headingDeg;       // compass heading at scan time
  final Uint8List? captureJpeg;   // AR snapshot shown in the report
  final String stateDisplayName;
  final String statePortal;
  final String stateNotes;

  // ── Brands ─────────────────────────────────────────────────────────────────
  final List<BrandRecommendation> brandRecommendations;

  // ── Metadata ─────────────────────────────────────────────────────────────────
  final bool? isManualEntry;

  const EnrichedScanResult({
    required this.totalAreaM2,
    required this.usableAreaM2,
    required this.panelCount,
    required this.systemSizeKw,
    required this.peakSunHours,
    required this.pvgisFallback,
    required this.annualKwh,
    this.annualKwhGross = 0.0,
    required this.centralSubsidy,
    required this.stateSubsidy,
    required this.totalSubsidy,
    required this.estimatedCost,
    required this.netCost,
    required this.paybackYears,
    required this.annualSavingsInr,
    this.obstacleSummary = const ObstacleSummary(obstacleAreaM2: 0, shadingLossPct: 0),
    this.detectedObstacles = const [],
    this.lat,
    this.lon,
    this.headingDeg,
    this.captureJpeg,
    required this.stateDisplayName,
    required this.statePortal,
    required this.stateNotes,
    required this.brandRecommendations,
    this.isManualEntry,
  });

  double get obstacleAreaM2 => obstacleSummary.obstacleAreaM2;
  double get shadingLossPct => obstacleSummary.shadingLossPct;

  EnrichedScanResult copyWith({
    double? totalAreaM2,
    double? usableAreaM2,
    int? panelCount,
    double? systemSizeKw,
    double? peakSunHours,
    bool? pvgisFallback,
    double? annualKwh,
    double? annualKwhGross,
    int? centralSubsidy,
    int? stateSubsidy,
    int? totalSubsidy,
    int? estimatedCost,
    int? netCost,
    double? paybackYears,
    double? annualSavingsInr,
    ObstacleSummary? obstacleSummary,
    List<ObstacleDetection>? detectedObstacles,
    double? lat,
    double? lon,
    double? headingDeg,
    Uint8List? captureJpeg,
    String? stateDisplayName,
    String? statePortal,
    String? stateNotes,
    List<BrandRecommendation>? brandRecommendations,
    bool? isManualEntry,
  }) =>
      EnrichedScanResult(
         totalAreaM2: totalAreaM2 ?? this.totalAreaM2,
         usableAreaM2: usableAreaM2 ?? this.usableAreaM2,
         panelCount: panelCount ?? this.panelCount,
         systemSizeKw: systemSizeKw ?? this.systemSizeKw,
         peakSunHours: peakSunHours ?? this.peakSunHours,
         pvgisFallback: pvgisFallback ?? this.pvgisFallback,
         annualKwh: annualKwh ?? this.annualKwh,
         annualKwhGross: annualKwhGross ?? this.annualKwhGross,
         centralSubsidy: centralSubsidy ?? this.centralSubsidy,
         stateSubsidy: stateSubsidy ?? this.stateSubsidy,
         totalSubsidy: totalSubsidy ?? this.totalSubsidy,
         estimatedCost: estimatedCost ?? this.estimatedCost,
         netCost: netCost ?? this.netCost,
         paybackYears: paybackYears ?? this.paybackYears,
         annualSavingsInr: annualSavingsInr ?? this.annualSavingsInr,
         obstacleSummary: obstacleSummary ?? this.obstacleSummary,
         detectedObstacles: detectedObstacles ?? this.detectedObstacles,
         lat: lat ?? this.lat,
         lon: lon ?? this.lon,
         headingDeg: headingDeg ?? this.headingDeg,
         captureJpeg: captureJpeg ?? this.captureJpeg,
         stateDisplayName: stateDisplayName ?? this.stateDisplayName,
         statePortal: statePortal ?? this.statePortal,
          stateNotes: stateNotes ?? this.stateNotes,
          brandRecommendations: brandRecommendations ?? this.brandRecommendations,
          isManualEntry: isManualEntry ?? this.isManualEntry,
      );
}
