import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/features/location/domain/location_domain.dart';
import 'package:khidma/features/marketplace/presentation/google_map_provider.dart';
import 'package:khidma/features/marketplace/presentation/map_provider.dart';

MapMarker _m(String id, double lat, double lng) =>
    MapMarker(id: id, title: id, latitude: lat, longitude: lng);

MapRequest _req(List<MapMarker> m, {LocationFix? center}) =>
    MapRequest(markers: m, onSelect: (_) {}, center: center);

void main() {
  group('GoogleMapProvider availability', () {
    test('no key, blank key: unavailable', () {
      expect(const GoogleMapProvider(apiKey: '').isAvailable, isFalse);
      expect(const GoogleMapProvider(apiKey: '  ').isAvailable, isFalse);
    });
    test('with a key: available', () {
      expect(const GoogleMapProvider(apiKey: 'AIza-x').isAvailable, isTrue);
    });
    test('a build without the define hides the map', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(mapProviderProvider).isAvailable, isFalse);
    });
  });

  group('initialTarget', () {
    test('prefers the searcher position', () {
      final t = initialTarget(
        _req([_m('a', 35, 10)], center: LocationFix.approximate(36.8, 10.18)),
      );
      expect((t.latitude, t.longitude), (36.8, 10.18));
    });
    test('then the first pin, then Tunis', () {
      final t = initialTarget(_req([_m('a', 35.5, 10.5)]));
      expect((t.latitude, t.longitude), (35.5, 10.5));
      expect(initialTarget(_req([])), tunisCenter);
    });
  });

  group('pinBounds', () {
    test('zero or one pin: none', () {
      expect(pinBounds([]), isNull);
      expect(pinBounds([_m('a', 36, 10)]), isNull);
    });
    test('two pins at the same spot: none (zero-size box)', () {
      expect(pinBounds([_m('a', 36, 10), _m('b', 36, 10)]), isNull);
    });
    test('covers every pin, in any order', () {
      final b = pinBounds([
        _m('a', 36.8, 10.1),
        _m('b', 34.7, 10.7),
        _m('c', 35.8, 10.6),
        _m('d', 35.0, 9.9),
      ])!;
      expect((b.southwest.latitude, b.southwest.longitude), (34.7, 9.9));
      expect((b.northeast.latitude, b.northeast.longitude), (36.8, 10.7));
    });
    test('two pins on one meridian still make a box', () {
      expect(pinBounds([_m('a', 36, 10), _m('b', 37, 10)]), isNotNull);
    });
  });
}
