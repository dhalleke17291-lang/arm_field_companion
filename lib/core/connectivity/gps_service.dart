import 'package:geolocator/geolocator.dart';

/// Lightweight GPS helper. Returns null on any failure — never blocks.
class GpsService {
  /// Get current position. Returns null if permissions denied,
  /// service disabled, or timeout.
  static Future<({double latitude, double longitude})?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);
      return (latitude: pos.latitude, longitude: pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
