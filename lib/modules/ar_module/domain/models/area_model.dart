import '../../../../core/constants/app_constants.dart';
import '../../../../core/converters/unit_converter.dart';

/// Immutable snapshot of the detected rooftop area at a point in time.
class AreaModel {
  const AreaModel({
    required this.totalAreaM2,
    required this.usableAreaM2,
    required this.panelCount,
  });

  final double totalAreaM2;
  final double usableAreaM2;
  final int panelCount;

  // ── Derived getters ────────────────────────────────────────────────────────

  double get totalAreaFt2 => UnitConverter.sqMetersToSqFeet(totalAreaM2);
  double get usableAreaFt2 => UnitConverter.sqMetersToSqFeet(usableAreaM2);

  /// Estimated system capacity in kW (panelCount × wattage per panel).
  double get systemSizeKw => panelCount * AppConstants.panelWattageKw;

  /// Estimated daily energy output assuming 4.5 peak sun hours.
  double get dailyEnergyKwh => systemSizeKw * 4.5;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'total_area': double.parse(totalAreaM2.toStringAsFixed(2)),
        'usable_area': double.parse(usableAreaM2.toStringAsFixed(2)),
        'panel_count': panelCount,
        'system_size_kw': double.parse(systemSizeKw.toStringAsFixed(2)),
      };

  // ── Zero state ─────────────────────────────────────────────────────────────

  static const AreaModel zero = AreaModel(
    totalAreaM2: 0,
    usableAreaM2: 0,
    panelCount: 0,
  );

  AreaModel copyWith({
    double? totalAreaM2,
    double? usableAreaM2,
    int? panelCount,
  }) =>
      AreaModel(
        totalAreaM2: totalAreaM2 ?? this.totalAreaM2,
        usableAreaM2: usableAreaM2 ?? this.usableAreaM2,
        panelCount: panelCount ?? this.panelCount,
      );
}
