import 'package:flutter_test/flutter_test.dart';
import 'package:solarsense/core/solar/monthly_profile.dart';

void main() {
  test('returns exactly 12 monthly multipliers', () {
    final p = monthlyGenerationProfile(20.0);
    expect(p.length, 12);
  });

  test('multipliers always average to 1.0 (so generation sums correctly)', () {
    for (final lat in [8.0, 20.0, 28.0, -20.0]) {
      final p = monthlyGenerationProfile(lat);
      final mean = p.reduce((a, b) => a + b) / p.length;
      expect(mean, closeTo(1.0, 1e-9), reason: 'lat=$lat');
    }
  });

  test('northern hemisphere peaks at June (index 5)', () {
    final p = monthlyGenerationProfile(28.0, indiaMonsoonAdjust: false);
    var maxIdx = 0;
    for (var i = 1; i < 12; i++) {
      if (p[i] > p[maxIdx]) maxIdx = i;
    }
    expect(maxIdx, 5);
  });

  test('southern hemisphere peaks at December (index 11)', () {
    final p = monthlyGenerationProfile(-20.0, indiaMonsoonAdjust: false);
    var maxIdx = 0;
    for (var i = 1; i < 12; i++) {
      if (p[i] > p[maxIdx]) maxIdx = i;
    }
    expect(maxIdx, 11);
  });

  test('monsoon attenuation lowers Jun–Aug vs no-adjustment', () {
    final wet = monthlyGenerationProfile(20.0, indiaMonsoonAdjust: true);
    final dry = monthlyGenerationProfile(20.0, indiaMonsoonAdjust: false);
    expect(wet[5], lessThan(dry[5])); // Jun
    expect(wet[6], lessThan(dry[6])); // Jul
    expect(wet[7], lessThan(dry[7])); // Aug
  });

  test('seasonal swing grows with latitude', () {
    final low = monthlyGenerationProfile(10.0, indiaMonsoonAdjust: false);
    final high = monthlyGenerationProfile(28.0, indiaMonsoonAdjust: false);
    double spread(List<double> p) => p.reduce((a, b) => a > b ? a : b) -
        p.reduce((a, b) => a < b ? a : b);
    expect(spread(high), greaterThan(spread(low)));
  });
}
