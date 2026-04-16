// lib/services/brand_service.dart
//
// Loads solar_brands.json ONCE at init.
// Filters by price_tier and sorts by value score (efficiency / avg_price_per_watt).
// Returns top N BrandRecommendation objects.

import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/brand_recommendation.dart';

class BrandService {
  List<Map<String, dynamic>> _brands = [];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final raw = await rootBundle.loadString('assets/data/solar_brands.json');
    final decoded = jsonDecode(raw);
    // Support both a top-level list OR a map with a key
    if (decoded is List) {
      _brands = decoded.cast<Map<String, dynamic>>();
    } else if (decoded is Map) {
      // Try common wrapper keys
      final inner = decoded['brands'] ?? decoded['data'] ?? decoded.values.first;
      _brands = (inner as List).cast<Map<String, dynamic>>();
    }
    _initialized = true;
  }

  /// Returns top [topN] brands for the given [priceSensitivity].
  ///
  /// [priceSensitivity] must be one of: 'budget', 'mid', 'premium'.
  /// Falls back to returning the best value brands across all tiers if the
  /// filtered list has fewer than [topN] results.
  List<BrandRecommendation> getTopBrands({
    required double systemKw,
    required String priceSensitivity,
    int topN = 3,
  }) {
    assert(_initialized, 'BrandService.init() must be called first');

    final sensitivity = priceSensitivity.toLowerCase();

    // Map sensitivity → price_tier values stored in JSON
    final matchTiers = <String>{};
    switch (sensitivity) {
      case 'budget':
        matchTiers.addAll(['low', 'budget']);
        break;
      case 'premium':
        matchTiers.addAll(['high', 'premium']);
        break;
      default:
        matchTiers.addAll(['medium', 'mid']);
    }

    // Filter by tier
    var filtered = _brands.where((b) {
      final tier = (b['price_tier'] as String? ?? 'medium').toLowerCase();
      return matchTiers.contains(tier);
    }).toList();

    // Not enough after filtering → use all brands
    if (filtered.length < topN) filtered = List.of(_brands);

    // Sort by value score: efficiency / avg_price_per_watt (higher = better value)
    filtered.sort((a, b) {
      final scoreA = _valueScore(a, sensitivity);
      final scoreB = _valueScore(b, sensitivity);
      return scoreB.compareTo(scoreA);
    });

    return filtered
        .take(topN)
        .toList()
        .asMap()
        .entries
        .map((e) => BrandRecommendation.fromJson(e.value, e.key + 1, sensitivity))
        .toList();
  }

  double _valueScore(Map<String, dynamic> brand, String sensitivity) {
    final avgPpw =
        ((brand['price_per_watt_min'] as num) + (brand['price_per_watt_max'] as num)) /
            2;
    final eff = (brand['best_efficiency_pct'] as num).toDouble();
    final rating = (brand['rating'] as num).toDouble();
    final warranty = (brand['panel_warranty_years'] as num).toDouble();

    switch (sensitivity) {
      case 'budget':
        return -avgPpw * 2 + eff * 0.5 + rating * 0.3;
      case 'premium':
        return eff * 2 + rating * 1.5 + warranty * 0.1 - avgPpw * 0.5;
      default:
        return -avgPpw + eff + rating + warranty * 0.05;
    }
  }
}
