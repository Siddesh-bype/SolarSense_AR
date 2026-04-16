import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sense_ar/modules/ar_module/data/services/area_calculation_service.dart';
import 'package:solar_sense_ar/modules/ar_module/data/services/panel_placement_service.dart';
import 'package:solar_sense_ar/modules/ar_module/domain/models/obstacle_model.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('AreaCalculationService', () {
    const service = AreaCalculationService();

    test('returns zero for empty polygon', () {
      final result = service.calculate(
        polygon: [],
        obstacles: [],
        panelCount: 0,
      );
      expect(result.totalAreaM2, 0.0);
    });

    test('computes 12 m² for 3×4 rectangle', () {
      final polygon = [
        Vector3(0, 0, 0),
        Vector3(3, 0, 0),
        Vector3(3, 0, 4),
        Vector3(0, 0, 4),
      ];
      final result = service.calculate(
        polygon: polygon,
        obstacles: [],
        panelCount: 0,
      );
      expect(result.totalAreaM2, closeTo(12.0, 0.01));
    });

    test('usable area reduces by obstacle area', () {
      final polygon = [
        Vector3(0, 0, 0),
        Vector3(4, 0, 0),
        Vector3(4, 0, 4),
        Vector3(0, 0, 4),
      ];
      const obs = ObstacleModel(
        id: 'test_obs',
        centerX: 2,
        centerZ: 2,
        widthM: 1,
        depthM: 1,
      );
      final result = service.calculate(
        polygon: polygon,
        obstacles: [obs],
        panelCount: 0,
      );
      expect(result.usableAreaM2, closeTo(15.0, 0.01)); // 16 - 1
    });
  });

  group('PanelPlacementService', () {
    const service = PanelPlacementService();

    test('returns empty list for polygon with fewer than 3 points', () {
      final panels = service.computeLayout(polygon: [], obstacles: []);
      expect(panels, isEmpty);
    });

    test('places at least 1 panel in a 4×6 polygon', () {
      final polygon = [
        Vector3(0, 0, 0),
        Vector3(4, 0, 0),
        Vector3(4, 0, 6),
        Vector3(0, 0, 6),
      ];
      final panels = service.computeLayout(polygon: polygon, obstacles: []);
      expect(panels.length, greaterThan(0));
    });
  });
}
