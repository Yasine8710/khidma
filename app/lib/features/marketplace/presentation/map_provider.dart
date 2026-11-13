import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/domain/location_domain.dart';
import 'google_map_provider.dart';

/// One pin: a professional with a known position.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
  });
  final String id;
  final String title;
  final double latitude;
  final double longitude;
}

class MapRequest {
  const MapRequest({
    required this.markers,
    required this.onSelect,
    this.center,
  });

  final List<MapMarker> markers;

  /// The searcher's approximate position, when they shared it.
  final LocationFix? center;

  /// Called with a professional id when its pin is chosen.
  final void Function(String id) onSelect;
}

/// The map behind the list/map toggle. The app depends on this interface, not
/// on a vendor: Google Maps, Apple Maps or MapLibre can be plugged in (see the
/// benchmark plan in docs/ARCHITECTURE.md). Until one is configured, the
/// default reports itself unavailable and the toggle is hidden.
abstract interface class MapProvider {
  bool get isAvailable;
  Widget build(BuildContext context, MapRequest request);
}

class UnavailableMapProvider implements MapProvider {
  const UnavailableMapProvider();
  @override
  bool get isAvailable => false;
  @override
  Widget build(BuildContext context, MapRequest request) =>
      const SizedBox.shrink();
}

/// Passed with `--dart-define=GOOGLE_MAPS_API_KEY=...` (the same value goes to
/// the native projects, see docs/MAPS.md). Empty: no map, toggle hidden.
const _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

final mapProviderProvider = Provider<MapProvider>(
  (ref) => _googleMapsApiKey.trim().isEmpty
      ? const UnavailableMapProvider()
      : const GoogleMapProvider(apiKey: _googleMapsApiKey),
);
