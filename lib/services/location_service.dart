// lib/services/location_service.dart
//
// Returns device GPS coordinates.
// Uses permission_handler to request permission, geolocator to get position.
// Falls back to Pune (18.5204, 73.8567) on any failure or denial.
// Timeout: 5 seconds, then fallback.

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

// Fallback: Pune, Maharashtra (central India solar belt)
const LatLon _kPune = LatLon(18.5204, 73.8567);
const Duration _kTimeout = Duration(seconds: 5);

class LocationService {
  Future<LatLon> getCurrentLatLon() async {
    try {
      // 1. Request permission via permission_handler first
      final status = await Permission.location.request();
      if (!status.isGranted) return _kPune;

      // 2. Check geolocator service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _kPune;

      // 3. Get position with 5-second timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(_kTimeout, onTimeout: () => throw Exception('GPS timeout'));

      return LatLon(position.latitude, position.longitude);
    } catch (_) {
      return _kPune;
    }
  }
}
