// lib/services/location_service.dart
//
// Wraps geolocator with permission handling.
// Falls back to Pune (18.5, 73.8) if permission is denied or GPS unavailable.

import 'package:geolocator/geolocator.dart';

class LatLon {
  final double lat;
  final double lon;

  const LatLon(this.lat, this.lon);
}

// Default fallback — Pune, Maharashtra
const LatLon _kDefaultLocation = LatLon(18.5204, 73.8567);

class LocationService {
  /// Returns the device's current GPS coordinates.
  /// Falls back to Pune if:
  ///   - Location services are disabled
  ///   - Permission is denied / denied forever
  ///   - Any other error occurs
  Future<LatLon> getCurrentLatLon() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _kDefaultLocation;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _kDefaultLocation;
      }
      if (permission == LocationPermission.deniedForever) {
        return _kDefaultLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      return LatLon(position.latitude, position.longitude);
    } catch (_) {
      return _kDefaultLocation;
    }
  }
}
