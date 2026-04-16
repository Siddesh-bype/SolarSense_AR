import '../constants/app_constants.dart';

/// Stateless unit conversion helpers.
class UnitConverter {
  UnitConverter._();

  /// Converts square metres to square feet.
  static double sqMetersToSqFeet(double m2) => m2 * AppConstants.sqMToSqFt;

  /// Converts kilowatts to watts.
  static double kwToWatts(double kw) => kw * 1000.0;

  /// Formats a double to 2 decimal places as a string.
  static String format2dp(double value) => value.toStringAsFixed(2);
}
