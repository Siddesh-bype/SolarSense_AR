// lib/models/enriched_scan_response.dart
//
// Dart mirror of the backend EnrichedScanResponse Pydantic schema.
// All fields match the JSON keys returned by POST /enrich-scan.

class MonthlyIrradiance {
  final int month;
  final String monthName;
  final double dailyIrradiationKwhM2;
  final double peakSunHours;

  const MonthlyIrradiance({
    required this.month,
    required this.monthName,
    required this.dailyIrradiationKwhM2,
    required this.peakSunHours,
  });

  factory MonthlyIrradiance.fromJson(Map<String, dynamic> j) =>
      MonthlyIrradiance(
        month: j['month'] as int,
        monthName: j['month_name'] as String,
        dailyIrradiationKwhM2: (j['daily_irradiation_kwh_m2'] as num).toDouble(),
        peakSunHours: (j['peak_sun_hours'] as num).toDouble(),
      );
}

class IrradianceData {
  final double latitude;
  final double longitude;
  final double peakSunHours;
  final double annualKwhPerKw;
  final List<MonthlyIrradiance> monthlyBreakdown;
  final String dataSource;

  const IrradianceData({
    required this.latitude,
    required this.longitude,
    required this.peakSunHours,
    required this.annualKwhPerKw,
    required this.monthlyBreakdown,
    required this.dataSource,
  });

  factory IrradianceData.fromJson(Map<String, dynamic> j) => IrradianceData(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        peakSunHours: (j['peak_sun_hours'] as num).toDouble(),
        annualKwhPerKw: (j['annual_kwh_per_kw'] as num).toDouble(),
        monthlyBreakdown: (j['monthly_breakdown'] as List)
            .map((e) => MonthlyIrradiance.fromJson(e as Map<String, dynamic>))
            .toList(),
        dataSource: j['data_source'] as String,
      );
}

class SubsidyBreakdown {
  final int centralSubsidyInr;
  final int stateSubsidyInr;
  final int totalSubsidyInr;
  final double netCostInr;
  final double annualSavingsInr;
  final double paybackYears;
  final String stateDisplayName;
  final String statePortal;
  final String stateNotes;
  final bool subsidyCapApplied;

  const SubsidyBreakdown({
    required this.centralSubsidyInr,
    required this.stateSubsidyInr,
    required this.totalSubsidyInr,
    required this.netCostInr,
    required this.annualSavingsInr,
    required this.paybackYears,
    required this.stateDisplayName,
    required this.statePortal,
    required this.stateNotes,
    required this.subsidyCapApplied,
  });

  factory SubsidyBreakdown.fromJson(Map<String, dynamic> j) => SubsidyBreakdown(
        centralSubsidyInr: j['central_subsidy_inr'] as int,
        stateSubsidyInr: j['state_subsidy_inr'] as int,
        totalSubsidyInr: j['total_subsidy_inr'] as int,
        netCostInr: (j['net_cost_inr'] as num).toDouble(),
        annualSavingsInr: (j['annual_savings_inr'] as num).toDouble(),
        paybackYears: (j['payback_years'] as num).toDouble(),
        stateDisplayName: j['state_display_name'] as String,
        statePortal: j['state_portal'] as String,
        stateNotes: j['state_notes'] as String,
        subsidyCapApplied: j['subsidy_cap_applied'] as bool,
      );
}

class BrandRecommendation {
  final int rank;
  final String id;
  final String displayName;
  final String website;
  final String customerCare;
  final double rating;
  final int pricePerWattMin;
  final int pricePerWattMax;
  final int estimatedSystemCostMin;
  final int estimatedSystemCostMax;
  final double bestEfficiencyPct;
  final int panelWarrantyYears;
  final bool almmListed;
  final String strength;
  final String bestFor;
  final String reason;

  const BrandRecommendation({
    required this.rank,
    required this.id,
    required this.displayName,
    required this.website,
    required this.customerCare,
    required this.rating,
    required this.pricePerWattMin,
    required this.pricePerWattMax,
    required this.estimatedSystemCostMin,
    required this.estimatedSystemCostMax,
    required this.bestEfficiencyPct,
    required this.panelWarrantyYears,
    required this.almmListed,
    required this.strength,
    required this.bestFor,
    required this.reason,
  });

  factory BrandRecommendation.fromJson(Map<String, dynamic> j) =>
      BrandRecommendation(
        rank: j['rank'] as int,
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        website: j['website'] as String,
        customerCare: j['customer_care'] as String,
        rating: (j['rating'] as num).toDouble(),
        pricePerWattMin: j['price_per_watt_min'] as int,
        pricePerWattMax: j['price_per_watt_max'] as int,
        estimatedSystemCostMin: j['estimated_system_cost_min'] as int,
        estimatedSystemCostMax: j['estimated_system_cost_max'] as int,
        bestEfficiencyPct: (j['best_efficiency_pct'] as num).toDouble(),
        panelWarrantyYears: j['panel_warranty_years'] as int,
        almmListed: j['almm_listed'] as bool,
        strength: j['strength'] as String,
        bestFor: j['best_for'] as String,
        reason: j['reason'] as String,
      );
}

class EnrichedScanResponse {
  final double totalAreaM2;
  final double usableAreaM2;
  final int panelCount;
  final double systemSizeKw;
  final IrradianceData irradiance;
  final double actualDailyKwh;
  final double actualAnnualKwh;
  final SubsidyBreakdown subsidy;
  final List<BrandRecommendation> brandRecommendations;

  const EnrichedScanResponse({
    required this.totalAreaM2,
    required this.usableAreaM2,
    required this.panelCount,
    required this.systemSizeKw,
    required this.irradiance,
    required this.actualDailyKwh,
    required this.actualAnnualKwh,
    required this.subsidy,
    required this.brandRecommendations,
  });

  factory EnrichedScanResponse.fromJson(Map<String, dynamic> j) =>
      EnrichedScanResponse(
        totalAreaM2: (j['total_area_m2'] as num).toDouble(),
        usableAreaM2: (j['usable_area_m2'] as num).toDouble(),
        panelCount: j['panel_count'] as int,
        systemSizeKw: (j['system_size_kw'] as num).toDouble(),
        irradiance: IrradianceData.fromJson(j['irradiance'] as Map<String, dynamic>),
        actualDailyKwh: (j['actual_daily_kwh'] as num).toDouble(),
        actualAnnualKwh: (j['actual_annual_kwh'] as num).toDouble(),
        subsidy: SubsidyBreakdown.fromJson(j['subsidy'] as Map<String, dynamic>),
        brandRecommendations: (j['brand_recommendations'] as List)
            .map((e) => BrandRecommendation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
