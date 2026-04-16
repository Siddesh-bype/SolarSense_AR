import 'package:vector_math/vector_math_64.dart';
import '../../domain/models/area_model.dart';
import '../../domain/models/obstacle_model.dart';
import '../../../../core/utils/geometry_utils.dart';
import '../../../../core/constants/app_constants.dart';

/// Stateless service that computes rooftop area metrics.
///
/// Design: pure functions only — inject inputs, receive outputs.
/// No ARCore dependency; operates on plain Vector3 data.
class AreaCalculationService {
  const AreaCalculationService();

  /// Computes [AreaModel] from a detected [polygon] and current [obstacles].
  AreaModel calculate({
    required List<Vector3> polygon,
    required List<ObstacleModel> obstacles,
    required int panelCount,
  }) {
    if (polygon.length < 3) return AreaModel.zero;

    final double totalArea = GeometryUtils.computePolygonAreaXZ(polygon);

    final double obstacleArea =
        obstacles.fold(0.0, (sum, obs) => sum + obs.areaM2);

    final double usableArea =
        (totalArea - obstacleArea).clamp(0.0, double.maxFinite);

    return AreaModel(
      totalAreaM2: totalArea,
      usableAreaM2: usableArea,
      panelCount: panelCount,
    );
  }

  bool isSufficient(double areaM2) =>
      areaM2 >= AppConstants.minDetectableAreaM2;
}
