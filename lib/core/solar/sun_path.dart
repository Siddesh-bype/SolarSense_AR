// lib/core/solar/sun_path.dart
//
// Sun-path math for fixed-tilt PV panels.
// Used to compute the optimum year-round panel tilt and azimuth from the
// site's latitude, and the physical mounting elevation used by the AR
// visualisation.
//
// References
// ──────────
//  • Landau (ASES) annual-optimal tilt regression — widely-cited piecewise
//    fit to hourly irradiance simulations across all continental latitudes:
//
//        |lat| <  25°  ⟶  tilt ≈ |lat| · 0.87
//        25° ≤ |lat| < 50° ⟶  tilt ≈ |lat| · 0.76 + 3.1°
//        |lat| ≥ 50°   ⟶  tilt ≈ |lat| · 0.76 + 3.1°  (capped at 60°)
//
//  • Cooper (1969) solar-declination formula — used for sanity checks and
//    for seasonal-tilt alternatives the caller may want later.
//
//  • Azimuth convention: measured clockwise from true north (0° = N,
//    90° = E, 180° = S, 270° = W). Fixed panels in the Northern hemisphere
//    achieve max annual yield facing due south (180°); in the Southern
//    hemisphere they face due north (0°).

import 'dart:math' as math;

class SunPath {
  SunPath._();

  /// Year-round optimal tilt angle in degrees, for a fixed-tilt array
  /// at the given latitude. Never returns negative — uses |lat|.
  static double optimalTiltDeg(double latitudeDeg) {
    final absLat = latitudeDeg.abs();
    final double tilt;
    if (absLat < 25.0) {
      tilt = absLat * 0.87;
    } else {
      tilt = absLat * 0.76 + 3.1;
    }
    // Clamp to a mechanically sensible range. Panels past ~60° catch
    // too much wind load and too little summer sun.
    return tilt.clamp(5.0, 60.0);
  }

  /// Optimal azimuth (clockwise from true north) for a fixed-tilt array.
  /// 180° south in the Northern hemisphere, 0° north in the Southern.
  /// Returns 180° at the equator (arbitrary but conventional).
  static double optimalAzimuthDeg(double latitudeDeg) {
    return latitudeDeg >= 0 ? 180.0 : 0.0;
  }

  /// Physical mounting height of the panel above the roof plane, in metres.
  /// 0.45 m ≈ 1.5 ft — a low-profile rail mount that still leaves enough
  /// clearance for airflow under the module without the bulky ballast stack.
  static const double mountingElevationM = 0.45;

  /// Solar declination in degrees for day-of-year `n` (Cooper 1969).
  /// Positive = sun north of equator (N-hemisphere summer).
  static double declinationDeg(int dayOfYear) {
    final b = 2 * math.pi * (dayOfYear - 81) / 365.0;
    return 23.45 * math.sin(b);
  }
}
