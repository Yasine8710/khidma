import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/location_domain.dart';

/// Reads the device position with the `geolocator` plugin. Only coarse
/// accuracy is requested, and the result is rounded to about 1 km.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(LocationFailure.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          throw const LocationException(LocationFailure.denied);
        case LocationPermission.deniedForever:
          throw const LocationException(LocationFailure.deniedForever);
        case LocationPermission.unableToDetermine:
          throw const LocationException(LocationFailure.unavailable);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationFix.approximate(p.latitude, p.longitude);
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}
