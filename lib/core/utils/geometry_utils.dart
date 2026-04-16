import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Pure geometric utility functions.
/// All functions are stateless and side-effect free — safe to unit-test.
class GeometryUtils {
  GeometryUtils._();

  /// Computes the signed area of a polygon using the Shoelace formula.
  /// Points must be in order (CW or CCW). Returns absolute value in m².
  ///
  /// [polygon] — list of 3D world-space positions projected onto XZ plane.
  static double computePolygonAreaXZ(List<Vector3> polygon) {
    if (polygon.length < 3) return 0.0;
    double area = 0.0;
    final int n = polygon.length;
    for (int i = 0; i < n; i++) {
      final Vector3 curr = polygon[i];
      final Vector3 next = polygon[(i + 1) % n];
      area += curr.x * next.z;
      area -= next.x * curr.z;
    }
    return (area / 2.0).abs();
  }

  /// Returns the axis-aligned bounding box of [polygon] as
  /// (minX, minZ, maxX, maxZ) — used for grid iteration.
  static ({double minX, double minZ, double maxX, double maxZ})
      boundingBoxXZ(List<Vector3> polygon) {
    double minX = double.infinity, minZ = double.infinity;
    double maxX = double.negativeInfinity, maxZ = double.negativeInfinity;
    for (final v in polygon) {
      if (v.x < minX) minX = v.x;
      if (v.z < minZ) minZ = v.z;
      if (v.x > maxX) maxX = v.x;
      if (v.z > maxZ) maxZ = v.z;
    }
    return (minX: minX, minZ: minZ, maxX: maxX, maxZ: maxZ);
  }

  /// Ray-casting point-in-polygon test on XZ plane.
  /// Returns true if (px, pz) is inside [polygon].
  static bool pointInPolygonXZ(
    double px,
    double pz,
    List<Vector3> polygon,
  ) {
    bool inside = false;
    final int n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final double xi = polygon[i].x, zi = polygon[i].z;
      final double xj = polygon[j].x, zj = polygon[j].z;
      final bool intersect =
          ((zi > pz) != (zj > pz)) &&
          (px < (xj - xi) * (pz - zi) / (zj - zi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Converts degrees to radians.
  static double toRadians(double degrees) => degrees * math.pi / 180.0;
}
