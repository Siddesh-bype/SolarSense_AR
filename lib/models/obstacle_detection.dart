// lib/models/obstacle_detection.dart
//
// Represents a single bounding-box detection from the on-device YOLOv8n model.
// All coordinates are normalized to [0.0, 1.0] relative to image dimensions.

class ObstacleDetection {
  final String label;
  final double confidence;
  final double x; // centre x
  final double y; // centre y
  final double w; // width
  final double h; // height

  const ObstacleDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}
