// lib/services/pvgis_service.dart
//
// Calls the PVGIS v5.2 REST API directly from the device.
// No backend proxy required.
//
// Endpoint: GET https://re.jrc.ec.europa.eu/api/v5_2/PVcalc
// On any failure → returns fallback 4.5 PSH (India average).

import 'dart:convert';
import 'package:http/http.dart' as http;

class IrradianceResult {
  final double peakSunHours;    // daily average
  final double annualKwhPerKw;  // annual yield per installed kWp
  final bool isFallback;

  const IrradianceResult({
    required this.peakSunHours,
    required this.annualKwhPerKw,
    required this.isFallback,
  });
}

const _kFallbackPsh = 4.5;

/// Documented system performance ratio (78%) used only for the offline
/// regional fallback. The live PVGIS `E_y` value already incorporates system
/// losses (requested with `loss=14`), so it is NOT re-applied there.
const double _kPerformanceRatio = 0.78;

/// Per-state peak-sun-hours fallback (regionalised India estimates) used when
/// PVGIS is unreachable. Keyed by the same snake_case state keys as
/// `state_subsidies.json`. Anything unmapped falls back to [_kFallbackPsh].
const Map<String, double> _kStateFallbackPsh = {
  'maharashtra': 4.6,
  'gujarat': 5.0,
  'rajasthan': 5.3,
  'karnataka': 4.7,
  'tamil_nadu': 4.8,
  'uttar_pradesh': 4.6,
  'delhi': 4.9,
  'telangana': 4.9,
  'andhra_pradesh': 4.8,
  'kerala': 4.3,
  'west_bengal': 4.4,
  'madhya_pradesh': 4.9,
  'punjab': 4.8,
  'haryana': 4.9,
};

class PvgisService {
  static const _timeout = Duration(seconds: 20);

  Future<IrradianceResult> fetchIrradiance(
    double lat,
    double lon, [
    String? stateKey,
  ]) async {
    try {
      final uri = Uri.parse(
        'https://re.jrc.ec.europa.eu/api/v5_2/PVcalc'
        '?lat=$lat&lon=$lon&peakpower=1&loss=14&outputformat=json&browser=0&optimalangles=1',
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return _fallback(stateKey);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final outputs = body['outputs'] as Map<String, dynamic>?;
      final totals = (outputs?['totals'] as Map<String, dynamic>?)?['fixed']
          as Map<String, dynamic>?;

      if (totals == null) return _fallback(stateKey);

      final annualKwh = (totals['E_y'] as num?)?.toDouble();
      if (annualKwh == null || annualKwh <= 0) return _fallback(stateKey);

      final psh = annualKwh / 365;

      return IrradianceResult(
        peakSunHours: double.parse(psh.toStringAsFixed(2)),
        annualKwhPerKw: double.parse(annualKwh.toStringAsFixed(1)),
        isFallback: false,
      );
    } catch (_) {
      return _fallback(stateKey);
    }
  }

  IrradianceResult _fallback(String? stateKey) {
    final psh = stateKey == null
        ? _kFallbackPsh
        : _kStateFallbackPsh[stateKey.toLowerCase().trim()] ?? _kFallbackPsh;
    final annual = psh * 365 * _kPerformanceRatio;
    return IrradianceResult(
      peakSunHours: double.parse(psh.toStringAsFixed(2)),
      annualKwhPerKw: double.parse(annual.toStringAsFixed(1)),
      isFallback: true,
    );
  }
}
