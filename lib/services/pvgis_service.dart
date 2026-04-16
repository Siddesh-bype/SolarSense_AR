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
const _kFallbackAnnual = 1642.5; // 4.5 × 365

class PvgisService {
  static const _timeout = Duration(seconds: 20);

  Future<IrradianceResult> fetchIrradiance(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://re.jrc.ec.europa.eu/api/v5_2/PVcalc'
        '?lat=$lat&lon=$lon&peakpower=1&loss=14&outputformat=json&browser=0&optimalangles=1',
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return _fallback();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final outputs = body['outputs'] as Map<String, dynamic>?;
      final totals = (outputs?['totals'] as Map<String, dynamic>?)?['fixed']
          as Map<String, dynamic>?;

      if (totals == null) return _fallback();

      final annualKwh = (totals['E_y'] as num?)?.toDouble();
      if (annualKwh == null || annualKwh <= 0) return _fallback();

      final psh = annualKwh / 365;

      return IrradianceResult(
        peakSunHours: double.parse(psh.toStringAsFixed(2)),
        annualKwhPerKw: double.parse(annualKwh.toStringAsFixed(1)),
        isFallback: false,
      );
    } catch (_) {
      return _fallback();
    }
  }

  IrradianceResult _fallback() => const IrradianceResult(
        peakSunHours: _kFallbackPsh,
        annualKwhPerKw: _kFallbackAnnual,
        isFallback: true,
      );
}
