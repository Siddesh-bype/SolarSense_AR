// lib/core/solar/monthly_profile.dart
//
// Latitude-aware monthly generation profile used by the report charts.
// Replaces the previous hardcoded 12-value seasonal curve.
//
// Model: a cosine curve peaking at the summer solstice (June in the
// northern hemisphere, December in the southern), with a seasonal swing
// that grows with |latitude|. For the India-focused product an optional
// monsoon attenuation is applied to Jun–Aug (the southwest-monsoon trough).
// The returned multipliers always average to 1.0 so generation sums correctly.

import 'dart:math' as math;

/// Returns 12 monthly multipliers (Jan..Dec) whose mean is 1.0.
List<double> monthlyGenerationProfile(
  double lat, {
  bool indiaMonsoonAdjust = true,
}) {
  const peakMonth = 5; // June — summer-solstice peak (northern hemisphere)
  final amp = (lat.abs() / 90.0 * 0.6).clamp(0.03, 0.30);
  final swing = lat >= 0 ? 1.0 : -1.0;

  final factors = List<double>.generate(12, (m) {
    return 1.0 + swing * amp * math.cos(2 * math.pi * (m - peakMonth) / 12);
  });

  if (indiaMonsoonAdjust) {
    // Southwest-monsoon trough (Jun, Jul, Aug) over the Indian grid.
    for (final m in const [5, 6, 7]) {
      factors[m] *= 0.88;
    }
  }

  // Normalise so the annual mean multiplier is exactly 1.0.
  final mean = factors.reduce((a, b) => a + b) / factors.length;
  return factors.map((f) => f / mean).toList(growable: false);
}
