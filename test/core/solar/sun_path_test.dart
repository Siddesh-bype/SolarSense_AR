// test/core/solar/sun_path_test.dart
//
// Unit tests for the pure-math sun-path helpers. No Flutter dependency —
// runs with `flutter test` out of the box using only flutter_test.

import 'package:flutter_test/flutter_test.dart';
import 'package:solarmitra/core/solar/sun_path.dart';

void main() {
  group('SunPath.optimalTiltDeg', () {
    test('applies the low-latitude branch below 25°', () {
      // Pune ≈ 18.5°N → tilt ≈ 16.1°
      expect(SunPath.optimalTiltDeg(18.5), closeTo(18.5 * 0.87, 0.001));
    });

    test('applies the mid-latitude branch at 25° and above', () {
      // New Delhi ≈ 28.6°N → tilt ≈ 24.8°
      expect(SunPath.optimalTiltDeg(28.6), closeTo(28.6 * 0.76 + 3.1, 0.001));
    });

    test('uses |lat| — southern hemisphere mirrors northern', () {
      expect(
        SunPath.optimalTiltDeg(-30.0),
        equals(SunPath.optimalTiltDeg(30.0)),
      );
    });

    test('clamps below 5° near the equator and above 60° at polar lats', () {
      expect(SunPath.optimalTiltDeg(0.0), equals(5.0));
      expect(SunPath.optimalTiltDeg(88.0), equals(60.0));
    });
  });

  group('SunPath.optimalAzimuthDeg', () {
    test('faces south (180°) in the northern hemisphere', () {
      expect(SunPath.optimalAzimuthDeg(18.5), equals(180.0));
      expect(SunPath.optimalAzimuthDeg(0.0), equals(180.0));
    });

    test('faces north (0°) in the southern hemisphere', () {
      expect(SunPath.optimalAzimuthDeg(-25.0), equals(0.0));
    });
  });

  group('SunPath.declinationDeg', () {
    test('is ~0 near the equinoxes (DOY 81 = March 22)', () {
      expect(SunPath.declinationDeg(81), closeTo(0.0, 0.001));
    });

    test('peaks at ~+23.45° near summer solstice (DOY 172)', () {
      expect(SunPath.declinationDeg(172), closeTo(23.45, 0.05));
    });

    test('bottoms out at ~-23.45° near winter solstice (DOY 355)', () {
      expect(SunPath.declinationDeg(355), closeTo(-23.45, 0.05));
    });
  });

  test('mountingElevationM is in the 1–2 ft band the UX spec requires', () {
    expect(SunPath.mountingElevationM, greaterThanOrEqualTo(0.30));
    expect(SunPath.mountingElevationM, lessThanOrEqualTo(0.61));
  });
}
