// lib/models/enriched_scan_result.dart
//
// Single result model holding the complete output of all on-device services.
// Replaces the backend-shaped EnrichedScanResponse for the on-device pipeline.

import 'brand_recommendation.dart';
import 'obstacle_detection.dart';

class EnrichedScanResult {
  // ── Scan geometry ──────────────────────────────────────────────────────────
  final double totalAreaM2;
  final double usableAreaM2;
  final int panelCount;
  final double systemSizeKw;

  // ── PVGIS irradiance ───────────────────────────────────────────────────────
  final double peakSunHours;   // daily PSH average
  final bool pvgisFallback;    // true → PVGIS failed, using 4.5 default
  final double annualKwh;      // systemSizeKw × peakSunHours × 365

  // ── Financial ──────────────────────────────────────────────────────────────
  final int centralSubsidy;    // ₹30,000 / ₹60,000 / ₹78,000
  final int stateSubsidy;      // from state_subsidies.json
  final int totalSubsidy;      // central + state
  final int estimatedCost;     // gross install cost before subsidy
  final int netCost;           // estimatedCost - totalSubsidy (floor 0)
  final double paybackYears;   // netCost / (annualKwh × avgTariff)
  final double annualSavingsInr;

  // ── State info ─────────────────────────────────────────────────────────────
  final String stateDisplayName;
  final String statePortal;
  final String stateNotes;

  // ── Brands & obstacles ─────────────────────────────────────────────────────
  final List<BrandRecommendation> brandRecommendations;
  final List<ObstacleDetection> detectedObstacles;

  const EnrichedScanResult({
    required this.totalAreaM2,
    required this.usableAreaM2,
    required this.panelCount,
    required this.systemSizeKw,
    required this.peakSunHours,
    required this.pvgisFallback,
    required this.annualKwh,
    required this.centralSubsidy,
    required this.stateSubsidy,
    required this.totalSubsidy,
    required this.estimatedCost,
    required this.netCost,
    required this.paybackYears,
    required this.annualSavingsInr,
    required this.stateDisplayName,
    required this.statePortal,
    required this.stateNotes,
    required this.brandRecommendations,
    required this.detectedObstacles,
  });
}
