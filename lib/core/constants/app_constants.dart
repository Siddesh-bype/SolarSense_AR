/// Central configuration constants for the SolarSense AR module.
/// Adjust panel dimensions and wattage here without touching business logic.
class AppConstants {
  AppConstants._();

  // ── Panel Physical Dimensions ──────────────────────────────────────────────
  /// Standard residential solar panel width in metres.
  static const double panelWidthM = 1.0;

  /// Standard residential solar panel height in metres.
  static const double panelHeightM = 2.0;

  /// Minimum spacing between panels in metres (gap / grout line).
  static const double panelGapM = 0.05;

  /// Rated peak power per panel in kilowatts (400 W standard module).
  static const double panelWattageKw = 0.4;

  // ── AR Configuration ───────────────────────────────────────────────────────
  /// Minimum plane area (m²) before we attempt panel placement.
  static const double minDetectableAreaM2 = 2.0;

  /// Maximum number of 3D ARNode panels to place simultaneously.
  /// Capped to avoid overwhelming the ARCore platform channel.
  static const int maxPanelNodes = 20;

  /// Tolerance for point-in-polygon edge checks (avoid float precision issues).
  static const double pipTolerance = 1e-9;

  // ── Unit Conversion ────────────────────────────────────────────────────────
  static const double sqMToSqFt = 10.7639;

  // ── UI ─────────────────────────────────────────────────────────────────────
  static const String appName = 'SolarSense AR';
}
