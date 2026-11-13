import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_provider.dart';

/// Centre of Tunis, used when there is neither a position nor a pin.
const tunisCenter = LatLng(36.8065, 10.1815);

/// The Google Maps implementation of [MapProvider]. The key itself lives in
/// the native projects (Android manifest placeholder, iOS Info.plist); the
/// compile-time [apiKey] only decides whether the map is offered at all, so a
/// build without a key never shows a grey, broken map.
class GoogleMapProvider implements MapProvider {
  const GoogleMapProvider({required this.apiKey});

  final String apiKey;

  @override
  bool get isAvailable => apiKey.trim().isNotEmpty;

  @override
  Widget build(BuildContext context, MapRequest request) =>
      _PinMap(request: request);
}

/// Camera start: the searcher's position, else the first pin, else Tunis.
LatLng initialTarget(MapRequest request) {
  final c = request.center;
  if (c != null) return LatLng(c.latitude, c.longitude);
  if (request.markers.isNotEmpty) {
    final m = request.markers.first;
    return LatLng(m.latitude, m.longitude);
  }
  return tunisCenter;
}

/// The bounds that hold every pin, or null for fewer than two distinct points
/// (a zero-size box makes the camera zoom to the maximum).
LatLngBounds? pinBounds(List<MapMarker> markers) {
  if (markers.length < 2) return null;
  var south = markers.first.latitude, north = south;
  var west = markers.first.longitude, east = west;
  for (final m in markers) {
    if (m.latitude < south) south = m.latitude;
    if (m.latitude > north) north = m.latitude;
    if (m.longitude < west) west = m.longitude;
    if (m.longitude > east) east = m.longitude;
  }
  if (south == north && west == east) return null;
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}

class _PinMap extends StatelessWidget {
  const _PinMap({required this.request});
  final MapRequest request;

  @override
  Widget build(BuildContext context) {
    final bounds = pinBounds(request.markers);
    return GoogleMap(
      key: ValueKey(
        [
          request.center?.latitude,
          request.center?.longitude,
          for (final m in request.markers)
            '${m.id}@${m.latitude},${m.longitude}',
        ].join('|'),
      ),
      initialCameraPosition: CameraPosition(
        target: initialTarget(request),
        zoom: 11,
      ),
      onMapCreated: (controller) {
        if (bounds != null) {
          controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 64));
        }
      },
      markers: {
        for (final m in request.markers)
          Marker(
            markerId: MarkerId(m.id),
            position: LatLng(m.latitude, m.longitude),
            infoWindow: InfoWindow(
              title: m.title,
              onTap: () => request.onSelect(m.id),
            ),
          ),
      },
      // The position is only approximate (about 1 km): no blue dot, and no
      // permission prompt coming from the map itself.
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
