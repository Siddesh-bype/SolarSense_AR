// lib/models/obstacle_detection.dart
//
// Represents a single bounding-box detection from the on-device YOLOv8n model.
// All coordinates are normalized to [0.0, 1.0] relative to image dimensions.

import 'dart:convert';

class ObstacleDetection {
  final String label;
  final double confidence;
  final double x; // centre x (image fraction)
  final double y; // centre y (image fraction)
  final double w; // width (image fraction)
  final double h; // height (image fraction)

  const ObstacleDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// Approximate ground footprint (m²) reserved around this obstacle on the
  /// roof. Drives the usable-area subtraction in the analysis pipeline.
  double get footprintM2 => ObstacleFootprint.kind(this.label);

  /// Fraction of generation lost because this obstacle sits in/near the
  /// panel array (shading + setback). Bounded by [ObstacleSummary.maxLoss].
  double get shadingLossPct => ObstacleFootprint.shading(this.label);

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  factory ObstacleDetection.fromJson(Map<String, dynamic> json) =>
      ObstacleDetection(
        label: json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        w: (json['w'] as num).toDouble(),
        h: (json['h'] as num).toDouble(),
      );

  /// Decode a list of detections from JSON (used by the demo-mode fallback).
  static List<ObstacleDetection> listFromJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) ObstacleDetection.fromJson(item),
    ];
  }
}

/// Rooftop obstacle physical properties used by the solar analysis pipeline.
///
/// These are engineering estimates tuned for Indian residential rooftops
/// (ac_units, water tanks, chimneys, etc.) mapped from COCO proxy classes.
class ObstacleFootprint {
  // Ground footprint in m² reserved around each obstacle.
  static const Map<String, double> _footprint = {
    'ac_unit': 1.0,
    'water_tank': 1.4,
    'chimney': 0.6,
    'furniture': 0.8,
    'rooftop_equipment': 1.0,
    'person': 0.4,
    'other': 0.6,
  };

  // Generation loss fraction attributed to shading/setback for each class.
  static const Map<String, double> _shading = {
    'ac_unit': 0.02,
    'water_tank': 0.06,
    'chimney': 0.08,
    'furniture': 0.025,
    'rooftop_equipment': 0.04,
    'person': 0.01,
    'other': 0.03,
  };

  static double kind(String label) => _footprint[label] ?? _footprint['other']!;
  static double shading(String label) => _shading[label] ?? _shading['other']!;
}
