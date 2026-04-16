import 'package:vector_math/vector_math_64.dart';

// ── Plane service ─────────────────────────────────────────────────────────────

/// Pure utility for validating and measuring ARCore plane polygons.
///
/// Kept stateless so it can be `const`-constructed and easily tested.
class PlaneService {
  const PlaneService();

  // ── Plane area estimation ──────────────────────────────────────────────────

  /// Computes the area of a convex/concave polygon given in the XZ plane
  /// (Y is height in ARCore world space) using the Shoelace formula.
  ///
  /// Returns 0.0 for fewer than 3 vertices.
  double computePolygonAreaXZ(List<Vector3> polygon) {
    final n = polygon.length;
    if (n < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += polygon[i].x * polygon[j].z;
      area -= polygon[j].x * polygon[i].z;
    }
    return area.abs() / 2.0;
  }

  /// Returns `true` if [areaM2] meets the minimum threshold for stable
  /// plane detection in typical indoor/outdoor AR scenarios.
  bool isQualifyingPlane(double areaM2, {required double minAreaM2}) =>
      areaM2 >= minAreaM2;

  // ── Plane hit validation ───────────────────────────────────────────────────

  /// Validates a plane hit result before allowing anchor placement.
  ///
  /// Checks:
  ///   1. [polygonAreaM2] meets [minAreaM2].
  ///   2. The hit point is within reasonable distance from the camera
  ///      (avoids degenerate far-field planes).
  ///
  /// Returns a [PlaneValidationResult] with pass/fail and reason.
  PlaneValidationResult validateHit({
    required double polygonAreaM2,
    required Vector3 hitWorldPos,
    required Vector3 cameraWorldPos,
    required double minAreaM2,
    double maxHitDistanceM = 8.0,
  }) {
    if (polygonAreaM2 < minAreaM2) {
      return PlaneValidationResult.fail(
        'Plane too small (${polygonAreaM2.toStringAsFixed(2)} m² < ${minAreaM2.toStringAsFixed(2)} m²)',
      );
    }

    final dist = (hitWorldPos - cameraWorldPos).length;
    if (dist > maxHitDistanceM) {
      return PlaneValidationResult.fail(
        'Hit point too far from camera (${dist.toStringAsFixed(1)} m)',
      );
    }

    return PlaneValidationResult.pass();
  }
}

// ── Validation result ──────────────────────────────────────────────────────────

class PlaneValidationResult {
  const PlaneValidationResult._({required this.isValid, this.reason});

  factory PlaneValidationResult.pass() =>
      const PlaneValidationResult._(isValid: true);

  factory PlaneValidationResult.fail(String reason) =>
      PlaneValidationResult._(isValid: false, reason: reason);

  /// Whether the plane hit passes all validation checks.
  final bool isValid;

  /// Human-readable reason for failure (null when [isValid] is true).
  final String? reason;
}
