import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geolocator_location_service.dart';
import '../domain/location_domain.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// The position used for "near me", or null. Memory only: a restart forgets
/// it, and the person has to ask again.
final devicePositionProvider = NotifierProvider<DevicePosition, LocationFix?>(
  DevicePosition.new,
);

/// How long a position is reused. After this the person has moved on, or
/// revoked permission, and has to ask again.
const positionLifetime = Duration(minutes: 10);

class DevicePosition extends Notifier<LocationFix?> {
  bool _busy = false;
  Timer? _expiry;

  @override
  LocationFix? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  /// Reads the position. Returns the reason when it fails (null = success).
  Future<LocationFailure?> locate() async {
    if (_busy) return null;
    _busy = true;
    try {
      final fix = await ref.read(locationServiceProvider).current();
      if (ref.mounted) {
        state = fix;
        _expiry?.cancel();
        _expiry = Timer(positionLifetime, clear);
      }
      return null;
    } on LocationException catch (e) {
      return e.failure;
    } catch (_) {
      return LocationFailure.unavailable;
    } finally {
      _busy = false;
    }
  }

  void clear() {
    _expiry?.cancel();
    state = null;
  }
}
