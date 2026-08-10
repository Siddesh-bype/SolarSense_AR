// lib/models/brand_recommendation.dart
//
// Represents a solar brand recommendation produced by BrandService.
// Loaded from assets/data/solar_brands.json.

/// Price sensitivity tier — matches the 'price_tier' field in solar_brands.json.
enum BrandTier { budget, mid, premium }

class BrandRecommendation {
  final int rank;
  final String name;
  final String website;
  final String customerCare;
  final double rating;
  final int pricePerWattMin;
  final int pricePerWattMax;
  final double bestEfficiencyPct;
  final int panelWarrantyYears;
  final bool almmListed;
  final String strength;
  final String bestFor;
  final BrandTier tier;
  final String reason;

  const BrandRecommendation({
    required this.rank,
    required this.name,
    required this.website,
    required this.customerCare,
    required this.rating,
    required this.pricePerWattMin,
    required this.pricePerWattMax,
    required this.bestEfficiencyPct,
    required this.panelWarrantyYears,
    required this.almmListed,
    required this.strength,
    required this.bestFor,
    required this.tier,
    required this.reason,
  });

  /// Returns estimated 3kW system cost scaled to [systemKw].
  int estimatedCostMin(double systemKw) =>
      (pricePerWattMin * systemKw * 1000 * 1.35).toInt(); // panels + BOS ~35%

  int estimatedCostMax(double systemKw) =>
      (pricePerWattMax * systemKw * 1000 * 1.35).toInt();

  /// Builds a human-readable recommendation reason based on tier.
  static String buildReason(Map<String, dynamic> brand, String sensitivity) {
    final ppwMin = brand['price_per_watt_min'] as int;
    final eff = brand['best_efficiency_pct'] as double;
    final warranty = brand['panel_warranty_years'] as int;
    final rating = (brand['rating'] as num).toDouble();

    switch (sensitivity) {
      case 'budget':
        return 'Budget pick — starts at ₹$ppwMin/W. ALMM-listed, qualifies for PM Surya Ghar subsidy.';
      case 'premium':
        return 'Premium choice — $eff% efficiency, $warranty-year warranty. Rated ${rating.toStringAsFixed(1)}/10.';
      default:
        return 'Balanced pick — ${rating.toStringAsFixed(1)}/10 rated, ALMM-listed, ₹$ppwMin–₹${brand['price_per_watt_max']}/W.';
    }
  }

  factory BrandRecommendation.fromJson(
      Map<String, dynamic> j, int rank, String sensitivity) {
    final tierStr = (j['price_tier'] as String? ?? 'medium').toLowerCase();
    final tier = tierStr == 'low'
        ? BrandTier.budget
        : tierStr == 'high'
            ? BrandTier.premium
            : BrandTier.mid;

    return BrandRecommendation(
      rank: rank,
      name: j['display_name'] as String,
      website: j['website'] as String,
      customerCare: j['customer_care'] as String? ?? '',
      rating: (j['rating'] as num).toDouble(),
      pricePerWattMin: j['price_per_watt_min'] as int,
      pricePerWattMax: j['price_per_watt_max'] as int,
      bestEfficiencyPct: (j['best_efficiency_pct'] as num).toDouble(),
      panelWarrantyYears: j['panel_warranty_years'] as int,
      almmListed: j['almm_listed'] as bool? ?? true,
      strength: j['strength'] as String? ?? '',
      bestFor: j['best_for'] as String? ?? '',
      tier: tier,
      reason: buildReason(j, sensitivity),
    );
  }
}
