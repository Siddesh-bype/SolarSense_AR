// lib/services/api_service.dart
//
// Centralized API service for all SolarMitra backend calls.
// Swap _baseUrl to your ngrok URL for demo.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/enriched_scan_response.dart';

class ApiService {
  // ── Change this to your ngrok URL for physical device / demo ───────────────
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator default
  // For physical device: 'http://<your-local-ip>:8000'
  // For ngrok:           'https://<id>.ngrok.io'

  static const Duration _timeout = Duration(seconds: 45);

  // ── GET /irradiance ─────────────────────────────────────────────────────────

  Future<IrradianceData> fetchIrradiance(double lat, double lon) async {
    final uri = Uri.parse('$_baseUrl/irradiance').replace(
      queryParameters: {'lat': lat.toString(), 'lon': lon.toString()},
    );

    final response = await http.get(uri).timeout(_timeout);
    _assertOk(response, '/irradiance');

    return IrradianceData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── POST /subsidy-calc ──────────────────────────────────────────────────────

  Future<SubsidyBreakdown> calculateSubsidy({
    required double systemKw,
    required String state, // must match StateKey enum values e.g. 'maharashtra'
    required double systemCostInr,
    double? annualUnitsKwh,
    double? electricityTariff,
  }) async {
    final body = <String, dynamic>{
      'system_kw': systemKw,
      'state': state,
      'system_cost_inr': systemCostInr,
      if (annualUnitsKwh != null) 'annual_units_kwh': annualUnitsKwh,
      if (electricityTariff != null)
        'electricity_tariff_inr_per_unit': electricityTariff,
    };

    final response = await http
        .post(
          Uri.parse('$_baseUrl/subsidy-calc'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    _assertOk(response, '/subsidy-calc');

    return SubsidyBreakdown.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── POST /detect-obstacles ──────────────────────────────────────────────────

  Future<List<ObstacleDetection>> detectObstacles(Uint8List imageBytes) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/detect-obstacles'),
    )..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'frame.jpg',
      ));

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    _assertOk(response, '/detect-obstacles');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final detections = data['detections'] as List;
    return detections
        .map((e) => ObstacleDetection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── POST /enrich-scan (main demo endpoint) ──────────────────────────────────

  Future<EnrichedScanResponse> enrichScan({
    required double totalArea,
    required double usableArea,
    required int panelCount,
    required double systemSizeKw,
    required double latitude,
    required double longitude,
    required String state,
    required double systemCostInr,
    String priceSensitivity = 'medium', // 'low' | 'medium' | 'high'
    double? electricityTariff,
  }) async {
    final body = <String, dynamic>{
      'total_area': totalArea,
      'usable_area': usableArea,
      'panel_count': panelCount,
      'system_size_kw': systemSizeKw,
      'latitude': latitude,
      'longitude': longitude,
      'state': state,
      'system_cost_inr': systemCostInr,
      'price_sensitivity': priceSensitivity,
      if (electricityTariff != null)
        'electricity_tariff_inr_per_unit': electricityTariff,
    };

    final response = await http
        .post(
          Uri.parse('$_baseUrl/enrich-scan'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    _assertOk(response, '/enrich-scan');

    return EnrichedScanResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Helper ──────────────────────────────────────────────────────────────────

  void _assertOk(http.Response response, String endpoint) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        endpoint: endpoint,
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }
}

// ── Obstacle model needed by detectObstacles() ─────────────────────────────
// Minimal Dart mirror of ObstacleDetection schema

class ObstacleDetection {
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double w;
  final double h;
  final String? cocoClass;

  const ObstacleDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.cocoClass,
  });

  factory ObstacleDetection.fromJson(Map<String, dynamic> j) =>
      ObstacleDetection(
        label: j['label'] as String,
        confidence: (j['confidence'] as num).toDouble(),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        cocoClass: j['coco_class'] as String?,
      );
}

// ── Exception type ──────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String endpoint;
  final int statusCode;
  final String body;

  const ApiException({
    required this.endpoint,
    required this.statusCode,
    required this.body,
  });

  @override
  String toString() =>
      'ApiException[$statusCode] on $endpoint: $body';
}
