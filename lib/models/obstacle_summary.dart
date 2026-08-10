// lib/models/obstacle_summary.dart
//
// Aggregated result of on-device obstacle detection: the total roof area
// reserved for obstacles and the combined shading/setback generation loss
// applied by the analysis pipeline.

class ObstacleSummary {
  /// Total ground area (m²) to reserve for detected obstacles — subtracted
  /// from usable roof area before panel-count estimation.
  final double obstacleAreaM2;

  /// Combined generation loss fraction (0.0–1.0) from shading + setback.
  /// Never exceeds [maxLoss].
  final double shadingLossPct;

  /// Raw per-detection breakdown, kept for the report PDF.
  final List<ObstacleDetectionLite> items;

  const ObstacleSummary({
    required this.obstacleAreaM2,
    required this.shadingLossPct,
    this.items = const [],
  });

  static const double maxLoss = 0.30;

  ObstacleSummary copyWith({
    double? obstacleAreaM2,
    double? shadingLossPct,
    List<ObstacleDetectionLite>? items,
  }) =>
      ObstacleSummary(
        obstacleAreaM2: obstacleAreaM2 ?? this.obstacleAreaM2,
        shadingLossPct: shadingLossPct ?? this.shadingLossPct,
        items: items ?? this.items,
      );
}

/// Lightweight obstacle entry for the report (label + footprint + loss).
class ObstacleDetectionLite {
  final String label;
  final double footprintM2;
  final double shadingLossPct;

  const ObstacleDetectionLite({
    required this.label,
    required this.footprintM2,
    required this.shadingLossPct,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'footprintM2': footprintM2,
        'shadingLossPct': shadingLossPct,
      };
}
