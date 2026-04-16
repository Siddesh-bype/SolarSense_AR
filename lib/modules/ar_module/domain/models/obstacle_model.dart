/// Represents a user-defined obstacle zone on the detected surface.
/// Bounds are in AR world-space metres on the XZ plane.
class ObstacleModel {
  const ObstacleModel({
    required this.id,
    required this.centerX,
    required this.centerZ,
    required this.widthM,
    required this.depthM,
  });

  final String id;

  /// Centre of the obstacle on the AR plane (X axis).
  final double centerX;

  /// Centre of the obstacle on the AR plane (Z axis).
  final double centerZ;

  /// Width of obstacle bounding rect in metres (X direction).
  final double widthM;

  /// Depth of obstacle bounding rect in metres (Z direction).
  final double depthM;

  // ── Derived ────────────────────────────────────────────────────────────────

  double get areaM2 => widthM * depthM;

  double get minX => centerX - widthM / 2;
  double get maxX => centerX + widthM / 2;
  double get minZ => centerZ - depthM / 2;
  double get maxZ => centerZ + depthM / 2;

  /// Returns true if the point (px, pz) falls inside this obstacle.
  bool containsPoint(double px, double pz) =>
      px >= minX && px <= maxX && pz >= minZ && pz <= maxZ;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'area_m2': double.parse(areaM2.toStringAsFixed(2)),
        'bounds': {
          'center_x': double.parse(centerX.toStringAsFixed(4)),
          'center_z': double.parse(centerZ.toStringAsFixed(4)),
          'width_m': widthM,
          'depth_m': depthM,
        },
      };

  ObstacleModel copyWith({
    double? centerX,
    double? centerZ,
    double? widthM,
    double? depthM,
  }) =>
      ObstacleModel(
        id: id,
        centerX: centerX ?? this.centerX,
        centerZ: centerZ ?? this.centerZ,
        widthM: widthM ?? this.widthM,
        depthM: depthM ?? this.depthM,
      );
}
