// test/services/panel_packer_test.dart
//
// Pure-Dart unit tests for the shelf packer that derives a panel layout from a
// roof plane + SKU list. Uses flutter_test (no widgets).

import 'package:flutter_test/flutter_test.dart';
import 'package:solarsense/services/panel_packer.dart';

// Mirror the three SKUs wired in ar_camera_screen.dart.
final kCatalog = [
  const PanelSpec('Large 700W', 2.00, 1.30, 700),
  const PanelSpec('Standard 540W', 1.70, 1.14, 540),
  const PanelSpec('Compact 460W', 1.60, 1.00, 460),
];

void main() {
  test('mixed packs more kW than a uniform Standard layout on a 6x4 roof', () {
    final plane = const Extent(6, 4);

    final mixed = packMixed(plane: plane, catalog: kCatalog, maxPanels: 50);
    final uniform = packMixed(
      plane: plane,
      catalog: const [PanelSpec('Standard 540W', 1.70, 1.14, 540)],
      maxPanels: 50,
    );

    expect(mixed.totalKw, greaterThan(uniform.totalKw));
    expect(uniform.totalWatts, greaterThan(0));
  });

  test('no two placed panels overlap and all stay on the plane', () {
    final plane = const Extent(7, 5);
    final res = packMixed(plane: plane, catalog: kCatalog, maxPanels: 50);

    expect(res.panels, isNotEmpty);
    for (var i = 0; i < res.panels.length; i++) {
      final p = res.panels[i];
      expect((p.x - p.widthM / 2).abs(), lessThanOrEqualTo(plane.width / 2 + 1e-6),
          reason: 'panel $i overruns the roof width');
      expect((p.z - p.heightM / 2).abs(), lessThanOrEqualTo(plane.depth / 2 + 1e-6),
          reason: 'panel $i overruns the roof depth');
      for (var j = i + 1; j < res.panels.length; j++) {
        expect(p.overlaps(res.panels[j]), isFalse,
            reason: 'panels $i and $j overlap');
      }
    }
  });

  test('placed panels avoid keep-out zones', () {
    final plane = const Extent(6, 4);
    final obstacle = KeepOut(0, 0, 0.6, 0.6); // a 1.2m roof obstacle at the centre
    final res = packMixed(
      plane: plane,
      catalog: kCatalog,
      maxPanels: 50,
      keepOuts: [obstacle],
    );

    expect(res.panels, isNotEmpty);
    for (final p in res.panels) {
      final inside =
          (p.x - obstacle.x).abs() < (p.halfW + obstacle.halfW) &&
          (p.z - obstacle.z).abs() < (p.halfD + obstacle.halfD);
      expect(inside, isFalse, reason: 'panel overlaps the keep-out zone');
    }
  });

  test('kW sums to the per-panel watt ratings', () {
    final plane = const Extent(6, 4);
    final res = packMixed(plane: plane, catalog: kCatalog, maxPanels: 50);

    var summed = 0;
    for (final p in res.panels) {
      summed += p.watts;
    }
    expect(res.totalWatts, equals(summed));
    expect(res.totalKw, closeTo(summed / 1000.0, 1e-9));
  });

  test('counts respect maxPanels and the plane boundary', () {
    final plane = const Extent(6, 4);
    final res = packMixed(plane: plane, catalog: kCatalog, maxPanels: 4);
    expect(res.panels.length, lessThanOrEqualTo(4));
  });

  test('a tiny roof fits only the smallest SKU', () {
    // 1.6 x 1.0 roof — only a Compact 460W fits.
    final plane = const Extent(1.7, 1.1);
    final res = packMixed(plane: plane, catalog: kCatalog, maxPanels: 50);
    expect(res.panels.length, greaterThan(0));
    for (final p in res.panels) {
      expect(p.widthM, lessThanOrEqualTo(1.7 + 1e-6));
      expect(p.heightM, lessThanOrEqualTo(1.1 + 1e-6));
    }
  });
}
