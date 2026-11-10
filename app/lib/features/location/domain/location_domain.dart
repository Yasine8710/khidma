/// An approximate position of the device (rounded to 2 decimals, about 1 km,
/// before it is ever used). It lives in memory only: never stored, never sent
/// anywhere except as search parameters.
class LocationFix {
  const LocationFix({required this.latitude, required this.longitude});

  /// Rounds to roughly 1 km, so the exact whereabouts never leave the device.
  factory LocationFix.approximate(double latitude, double longitude) =>
      LocationFix(
        latitude: (latitude * 100).round() / 100,
        longitude: (longitude * 100).round() / 100,
      );

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LocationFix &&
      other.latitude == latitude &&
      other.longitude == longitude;
  @override
  int get hashCode => Object.hash(latitude, longitude);
}

enum LocationFailure {
  /// The person said no (this time; asking again is allowed).
  denied,

  /// The person said no for good: only the system settings can change it.
  deniedForever,

  /// Location services are switched off on the device.
  serviceOff,

  /// No position could be read in time.
  unavailable,
}

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
  @override
  String toString() => 'LocationException($failure)';
}

abstract interface class LocationService {
  /// Asks for permission if needed and returns the approximate position.
  /// Throws [LocationException].
  Future<LocationFix> current();

  /// Opens the system settings page of this app (after `deniedForever`).
  Future<void> openSettings();
}
