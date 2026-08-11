// test/services/subsidy_service_test.dart
//
// Verifies the PM Surya Ghar subsidy-slab + payback math. Uses the real
// `assets/data/state_subsidies.json` so the regression also protects the
// state-top-up lookup path.

import 'package:flutter_test/flutter_test.dart';
import 'package:solarsense/services/subsidy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SubsidyService service;

  setUpAll(() async {
    service = SubsidyService();
    await service.init();
  });

  group('SubsidyService.calculate — central slabs', () {
    test('1 kW system falls into the ₹30 000 bracket', () {
      final r = service.calculate(
        systemKw: 1.0,
        stateName: 'maharashtra',
        annualKwh: 1500,
        avgTariff: 8.0,
      );
      expect(r.centralSubsidy, equals(30000));
    });

    test('2 kW system falls into the ₹60 000 bracket', () {
      final r = service.calculate(
        systemKw: 2.0,
        stateName: 'maharashtra',
        annualKwh: 3000,
        avgTariff: 8.0,
      );
      expect(r.centralSubsidy, equals(60000));
    });

    test('3 kW and above cap at ₹78 000', () {
      final r3 = service.calculate(
        systemKw: 3.0, stateName: 'maharashtra',
        annualKwh: 4500, avgTariff: 8.0,
      );
      final r10 = service.calculate(
        systemKw: 10.0, stateName: 'maharashtra',
        annualKwh: 15000, avgTariff: 8.0,
      );
      expect(r3.centralSubsidy, equals(78000));
      expect(r10.centralSubsidy, equals(78000));
    });
  });

  group('SubsidyService.calculate — gross + net cost', () {
    test('gross cost applies the 2–5 kW tier at ₹72 000 / kW', () {
      final r = service.calculate(
        systemKw: 4.0, stateName: 'gujarat',
        annualKwh: 6000, avgTariff: 7.0,
      );
      expect(r.estimatedCost, equals(288000));
    });

    test('net cost never falls below zero', () {
      // Tiny systems where central+state can exceed the gross cost — we
      // clamp net to zero instead of going negative.
      final r = service.calculate(
        systemKw: 0.5, stateName: 'gujarat',
        annualKwh: 750, avgTariff: 7.0,
      );
      expect(r.netCost, greaterThanOrEqualTo(0));
    });
  });

  group('SubsidyService.calculate — payback', () {
    test('payback = net / (annualKwh × tariff)', () {
      final r = service.calculate(
        systemKw: 3.0,
        stateName: 'maharashtra',
        annualKwh: 4500,
        avgTariff: 8.0,
      );
      final expected = r.netCost / (4500 * 8.0);
      expect(r.paybackYears, closeTo(expected, 0.01));
    });

    test('payback is 0 when annual savings would be 0', () {
      final r = service.calculate(
        systemKw: 3.0, stateName: 'maharashtra',
        annualKwh: 0, avgTariff: 0,
      );
      expect(r.paybackYears, equals(0.0));
    });
  });

  test('unknown state → zero state subsidy, no crash', () {
    final r = service.calculate(
      systemKw: 2.0,
      stateName: 'atlantis',
      annualKwh: 3000,
      avgTariff: 8.0,
    );
    expect(r.stateSubsidy, equals(0));
    expect(r.centralSubsidy, equals(60000));
  });
}
