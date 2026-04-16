import 'package:vector_math/vector_math_64.dart';

/// Represents a single placed solar panel in AR world space.
class PanelModel {
  const PanelModel({
    required this.id,
    required this.position,
    required this.widthM,
    required this.heightM,
  });

  /// Unique identifier (index-based for deterministic layouts).
  final int id;

  /// Centre position in AR world space (metres).
  final Vector3 position;

  /// Panel width in metres (default 1.0 m).
  final double widthM;

  /// Panel height in metres (default 2.0 m).
  final double heightM;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'panel_id': id,
        'x': double.parse(position.x.toStringAsFixed(4)),
        'y': double.parse(position.y.toStringAsFixed(4)),
        'z': double.parse(position.z.toStringAsFixed(4)),
        'width_m': widthM,
        'height_m': heightM,
      };
}
