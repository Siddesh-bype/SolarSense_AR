// lib/services/location_service.dart
//
// Returns device GPS coordinates using geolocator.
// Requests permission via geolocator's own permission API.
// Falls back to Pune (18.5204, 73.8567) on any failure, denial or timeout.

import 'package:geolocator/geolocator.dart';

class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

// Fallback: Pune, Maharashtra — central India solar belt
const LatLon _kPune = LatLon(18.5204, 73.8567);
const Duration _kTimeout = Duration(seconds: 8);

class LocationService {
  Future<LatLon> getCurrentLatLon() async {
    try {
      // 1. Check if location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _kPune;

      // 2. Check / request permission via geolocator (no permission_handler needed)
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _kPune;
      }

      if (permission == LocationPermission.deniedForever) return _kPune;

      // 3. Get position — medium accuracy (fast), 8-second timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(_kTimeout);

      return LatLon(position.latitude, position.longitude);
    } catch (_) {
      return _kPune;
    }
  }
}
