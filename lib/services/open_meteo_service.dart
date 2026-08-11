// lib/services/open_meteo_service.dart
//
// Free, keyless live solar-radiation API (Open-Meteo). Used on the Home
// dashboard to show real "Live Irradiance (W/m²)" for the user's coordinates.
//
// Endpoint: https://api.open-meteo.com/v1/forecast?current=shortwave_radiation

import 'dart:convert';
import 'package:http/http.dart' as http;

class LiveSolarResult {
  /// Shortwave radiation in W/m² (null when the API didn't return a value).
  final double? shortwaveRadiation;
  final bool isDay;
  final int? weatherCode;
  const LiveSolarResult({
    this.shortwaveRadiation,
    this.weatherCode,
    this.isDay = true,
  });
}

class OpenMeteoService {
  static const _timeout = Duration(seconds: 10);

  Future<LiveSolarResult> fetchCurrentSolar(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=shortwave_radiation,is_day,weather_code'
        '&timezone=auto',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return const LiveSolarResult();

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final current = body['current'] as Map<String, dynamic>?;
      if (current == null) return const LiveSolarResult();

      final wm2 = (current['shortwave_radiation'] as num?)?.toDouble();
      final isDay = (current['is_day'] as num?)?.toDouble() == 1;
      final code = (current['weather_code'] as num?)?.toInt();
      return LiveSolarResult(
        shortwaveRadiation: wm2,
        isDay: isDay,
        weatherCode: code,
      );
    } catch (_) {
      return const LiveSolarResult();
    }
  }
}
