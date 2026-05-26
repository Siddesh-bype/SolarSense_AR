// lib/services/location_service.dart
//
// Accurate device-GPS coordinates via geolocator + OpenStreetMap Nominatim
// for free reverse-geocoding (no API key). Falls back to Pune on any failure.
//
// Nominatim usage policy: one request/sec max, identifying User-Agent required.
// We only call it once per GPS lock (not on every frame) so we stay well within
// the public rate limit.

import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

/// Reverse-geocoded human-readable placemark.
class Placemark {
  final String? city;       // "Pune"
  final String? stateName;  // "Maharashtra"
  final String? stateKey;   // "maharashtra" (matches state_subsidies.json keys)
  final String? countryCode;// "IN"
  const Placemark({this.city, this.stateName, this.stateKey, this.countryCode});
}

// Fallback: Pune, Maharashtra — central India solar belt
const LatLon _kPune = LatLon(18.5204, 73.8567);
const Duration _kTimeout = Duration(seconds: 8);
const Duration _kGeoTimeout = Duration(seconds: 6);

// Must match the keys in assets/data/state_subsidies.json
const Map<String, String> _kStateNameToKey = {
  'maharashtra': 'maharashtra',
  'gujarat': 'gujarat',
  'karnataka': 'karnataka',
  'rajasthan': 'rajasthan',
  'tamil nadu': 'tamil_nadu',
  'tamilnadu': 'tamil_nadu',
  'uttar pradesh': 'uttar_pradesh',
};

class LocationService {
  Future<LatLon> getCurrentLatLon() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _kPune;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _kPune;
      }
      if (permission == LocationPermission.deniedForever) return _kPune;

      // High accuracy — the solar-irradiance (PVGIS) API and tilt optimum
      // are sensitive to latitude to ~0.01°, so a ±10m fix is worth the
      // extra second of acquisition time vs. LocationAccuracy.medium.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(_kTimeout);

      return LatLon(position.latitude, position.longitude);
    } catch (_) {
      return _kPune;
    }
  }

  /// Reverse-geocodes `lat,lon` via OpenStreetMap Nominatim (free, no key).
  /// Returns `null` on any failure — caller is expected to leave the city
  /// field untouched in that case.
  Future<Placemark?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$lat&lon=$lon&zoom=10&addressdetails=1',
      );
      final res = await http.get(
        uri,
        headers: {
          // Nominatim requires an identifying UA — rejects bare defaults.
          'User-Agent': 'SolarMitra/1.0 (contact: support@solarmitra.app)',
          'Accept': 'application/json',
        },
      ).timeout(_kGeoTimeout);

      if (res.statusCode != 200) return null;
      final body = json.decode(res.body);
      if (body is! Map) return null;
      final addr = body['address'];
      if (addr is! Map) return null;

      // Pick the most specific locality name available.
      final city = (addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['municipality'] ??
              addr['suburb'] ??
              addr['county']) as String?;

      final stateName = addr['state'] as String?;
      final stateKey = stateName == null
          ? null
          : _kStateNameToKey[stateName.toLowerCase().trim()];
      final countryCode = (addr['country_code'] as String?)?.toUpperCase();

      return Placemark(
        city: city,
        stateName: stateName,
        stateKey: stateKey,
        countryCode: countryCode,
      );
    } catch (_) {
      return null;
    }
  }
}
