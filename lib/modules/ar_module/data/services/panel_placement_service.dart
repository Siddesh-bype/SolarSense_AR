import 'package:vector_math/vector_math_64.dart';
import '../../domain/models/panel_model.dart';
import '../../domain/models/obstacle_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/geometry_utils.dart';

/// Deterministic grid-based solar panel placement engine.
///
/// Algorithm:
///   1. Compute bounding box of the detected polygon (XZ plane).
///   2. Step through grid cells at (panelWidth + gap) × (panelHeight + gap).
///   3. Reject cells whose centre lies outside the polygon.
///   4. Reject cells whose corners lie outside the polygon.
///   5. Reject cells that overlap any obstacle AABB.
///   6. Return the remaining cells as [PanelModel] list.
class PanelPlacementService {
  const PanelPlacementService();

  /// Generates the panel layout for [polygon] excluding [obstacles].
  List<PanelModel> computeLayout({
    required List<Vector3> polygon,
    required List<ObstacleModel> obstacles,
    double surfaceY = 0.0,
  }) {
    if (polygon.length < 3) return <PanelModel>[];

    final bbox = GeometryUtils.boundingBoxXZ(polygon);
    const double stepX = AppConstants.panelWidthM + AppConstants.panelGapM;
    const double stepZ = AppConstants.panelHeightM + AppConstants.panelGapM;
    const double halfW = AppConstants.panelWidthM / 2;
    const double halfH = AppConstants.panelHeightM / 2;

    final List<PanelModel> panels = <PanelModel>[];
    int id = 0;

    for (double x = bbox.minX + halfW; x + halfW <= bbox.maxX; x += stepX) {
      for (double z = bbox.minZ + halfH; z + halfH <= bbox.maxZ; z += stepZ) {
        // Gate 1: centre point must be inside the polygon.
        if (!GeometryUtils.pointInPolygonXZ(x, z, polygon)) continue;

        // Gate 2: all four corners must be inside the polygon.
        if (!_allCornersInPolygon(
            cx: x, cz: z, hw: halfW, hh: halfH, polygon: polygon)) {
          continue;
        }

        // Gate 3: panel may not overlap any obstacle.
        final bool blocked = obstacles.any(
          (obs) =>
              _panelOverlapsObstacle(px: x, pz: z, hw: halfW, hh: halfH, obs: obs),
        );
        if (blocked) continue;

        panels.add(PanelModel(
          id: id++,
          position: Vector3(x, surfaceY, z),
          widthM: AppConstants.panelWidthM,
          heightM: AppConstants.panelHeightM,
        ));
      }
    }

    return panels;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  bool _allCornersInPolygon({
    required double cx,
    required double cz,
    required double hw,
    required double hh,
    required List<Vector3> polygon,
  }) {
    final List<(double, double)> corners = [
      (cx - hw, cz - hh),
      (cx + hw, cz - hh),
      (cx + hw, cz + hh),
      (cx - hw, cz + hh),
    ];
    return corners.every(
      (c) => GeometryUtils.pointInPolygonXZ(c.$1, c.$2, polygon),
    );
  }

  bool _panelOverlapsObstacle({
    required double px,
    required double pz,
    required double hw,
    required double hh,
    required ObstacleModel obs,
  }) {
    final bool noOverlapX = (px + hw) <= obs.minX || (px - hw) >= obs.maxX;
    final bool noOverlapZ = (pz + hh) <= obs.minZ || (pz - hh) >= obs.maxZ;
    return !(noOverlapX || noOverlapZ);
  }
}
