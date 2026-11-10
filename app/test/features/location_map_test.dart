import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/location/application/location_providers.dart';
import 'package:khidma/features/location/domain/location_domain.dart';
import 'package:khidma/features/marketplace/application/marketplace_providers.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/marketplace/presentation/map_provider.dart';

import '../test_helpers.dart';

class _FakeLocation implements LocationService {
  LocationFailure? fail;
  int calls = 0;
  int settingsOpened = 0;
  Duration delay = Duration.zero;

  @override
  Future<LocationFix> current() async {
    calls++;
    await Future<void>.delayed(delay);
    if (fail != null) throw LocationException(fail!);
    return LocationFix.approximate(36.8065, 10.1815);
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// A stand-in "map": one tappable row per pin.
class _ListMap implements MapProvider {
  MapRequest? last;
  @override
  bool get isAvailable => true;
  @override
  Widget build(BuildContext context, MapRequest request) {
    last = request;
    return ListView(
      children: [
        for (final m in request.markers)
          ListTile(
            title: Text('PIN ${m.title}'),
            onTap: () => request.onSelect(m.id),
          ),
      ],
    );
  }
}

/// Repository that records the queries and has one professional without a
/// position.
class _Repo extends DemoMarketplaceRepository {
  final queries = <SearchQuery>[];
  @override
  Future<List<ProfessionalSummary>> search(SearchQuery q) async {
    queries.add(q);
    return const [
      ProfessionalSummary(
        id: 'a',
        name: 'Avec position',
        categoryId: 1,
        latitude: 36.8,
        longitude: 10.2,
        distanceKm: 1.2,
      ),
      ProfessionalSummary(id: 'b', name: 'Sans position', categoryId: 1),
    ];
  }
}

Future<ProviderContainer> _openSearch(
  WidgetTester tester, {
  _FakeLocation? location,
  _Repo? repo,
  MapProvider? map,
}) async {
  final c = await pumpApp(
    tester,
    overrides: [
      locationServiceProvider.overrideWithValue(location ?? _FakeLocation()),
      if (repo != null) marketplaceRepositoryProvider.overrideWithValue(repo),
      if (map != null) mapProviderProvider.overrideWithValue(map),
    ],
  );
  c.read(routerProvider).push(AppRoutes.searchPath(categoryId: 1));
  await tester.pumpAndSettle();
  return c;
}

Future<void> _openSheetAndScrollTo(WidgetTester tester, Finder f) async {
  final list = find.byType(ListView).last;
  for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('approximate position', () {
    test('is rounded to about 1 km, both hemispheres', () {
      final a = LocationFix.approximate(36.80649, 10.18151);
      expect((a.latitude, a.longitude), (36.81, 10.18));
      final b = LocationFix.approximate(-33.8688, -151.2093);
      expect((b.latitude, b.longitude), (-33.87, -151.21));
      expect(
        LocationFix.approximate(36.806, 10.181),
        LocationFix.approximate(36.8099, 10.1849),
        reason: 'two nearby points are indistinguishable',
      );
    });

    test('locate: success keeps it, failures say why, clear forgets', () async {
      final svc = _FakeLocation();
      final c = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(c.dispose);
      c.listen(devicePositionProvider, (_, _) {});
      final n = c.read(devicePositionProvider.notifier);
      expect(await n.locate(), isNull);
      expect(c.read(devicePositionProvider)?.latitude, 36.81);
      n.clear();
      expect(c.read(devicePositionProvider), isNull);
      for (final f in LocationFailure.values) {
        svc.fail = f;
        expect(await n.locate(), f);
        expect(c.read(devicePositionProvider), isNull);
      }
    });

    test('a second request while one is running does not ask twice', () async {
      final svc = _FakeLocation()..delay = const Duration(milliseconds: 30);
      final c = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(c.dispose);
      c.listen(devicePositionProvider, (_, _) {});
      final n = c.read(devicePositionProvider.notifier);
      await Future.wait([n.locate(), n.locate()]);
      expect(svc.calls, 1);
    });
  });

  testWidgets('a position expires; the person has to ask again', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(_FakeLocation())],
    );
    addTearDown(c.dispose);
    c.listen(devicePositionProvider, (_, _) {});
    final done = c.read(devicePositionProvider.notifier).locate();
    await tester.pump(const Duration(milliseconds: 1));
    await done;
    expect(c.read(devicePositionProvider), isNotNull);
    await tester.pump(positionLifetime - const Duration(seconds: 1));
    expect(c.read(devicePositionProvider), isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(c.read(devicePositionProvider), isNull);
  });

  group('near me', () {
    testWidgets('sends the approximate position and enables nearest + radius', (
      tester,
    ) async {
      final repo = _Repo();
      final svc = _FakeLocation();
      final c = await _openSearch(tester, repo: repo, location: svc);
      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.latitude, 36.81);
      expect(repo.queries.last.longitude, 10.18);
      expect(repo.queries.last.sort, ProfessionalSort.rating);

      await tester.tap(find.textContaining('Filtrer'));
      await tester.pumpAndSettle();
      await _openSheetAndScrollTo(tester, find.text('Plus proches'));
      await tester.tap(find.text('Plus proches'));
      await _openSheetAndScrollTo(tester, find.text('25 km'));
      await tester.tap(find.text('25 km'));
      await _openSheetAndScrollTo(tester, find.text('Appliquer'));
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.sort, ProfessionalSort.nearest);
      expect(repo.queries.last.radiusKm, 25);
      // The position expires on a timer: end the test without one pending.
      c.read(devicePositionProvider.notifier).clear();
    });

    testWidgets(
      'without a position the sheet offers neither nearest nor radius',
      (tester) async {
        await _openSearch(tester, repo: _Repo());
        await tester.tap(find.textContaining('Filtrer'));
        await tester.pumpAndSettle();
        await _openSheetAndScrollTo(tester, find.text('Appliquer'));
        expect(find.text('Plus proches'), findsNothing);
        expect(find.text('Distance maximale'), findsNothing);
      },
    );

    testWidgets('switching it off forgets the position and drops nearest', (
      tester,
    ) async {
      final repo = _Repo();
      final c = await _openSearch(tester, repo: repo);
      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Filtrer'));
      await tester.pumpAndSettle();
      await _openSheetAndScrollTo(tester, find.text('Plus proches'));
      await tester.tap(find.text('Plus proches'));
      await _openSheetAndScrollTo(tester, find.text('Appliquer'));
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.sort, ProfessionalSort.nearest);

      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();
      expect(c.read(devicePositionProvider), isNull);
      expect(repo.queries.last.latitude, isNull);
      expect(repo.queries.last.sort, ProfessionalSort.rating);
    });

    testWidgets('switching it off keeps unrelated sorting', (tester) async {
      final repo = _Repo();
      await _openSearch(tester, repo: repo);
      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Filtrer'));
      await tester.pumpAndSettle();
      await _openSheetAndScrollTo(tester, find.text('Plus d’avis'));
      await tester.tap(find.text('Plus d’avis'));
      await _openSheetAndScrollTo(tester, find.text('25 km'));
      await tester.tap(find.text('25 km'));
      await _openSheetAndScrollTo(tester, find.text('Appliquer'));
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.sort, ProfessionalSort.reviews);
      expect(repo.queries.last.radiusKm, isNull);
    });

    for (final f in LocationFailure.values) {
      testWidgets('refused: $f is explained', (tester) async {
        final svc = _FakeLocation()..fail = f;
        final c = await _openSearch(tester, repo: _Repo(), location: svc);
        await tester.tap(find.text('Près de moi'));
        await tester.pumpAndSettle();
        expect(c.read(devicePositionProvider), isNull);
        final text = switch (f) {
          LocationFailure.denied => 'Autorisez la localisation pour voir les professionnels près de vous.',
          LocationFailure.deniedForever =>
            'La localisation est bloquée. Autorisez-la dans les réglages.',
          LocationFailure.serviceOff =>
            'La localisation est désactivée sur cet appareil.',
          LocationFailure.unavailable => 'Position introuvable. Réessayez.',
        };
        expect(find.text(text), findsOneWidget);
        if (f == LocationFailure.deniedForever) {
          await tester.tap(find.text('Réglages'));
          await tester.pump();
          expect(svc.settingsOpened, 1);
        } else {
          expect(find.text('Réglages'), findsNothing);
        }
        await tester.pumpAndSettle(const Duration(seconds: 6));
      });
    }
  });

  group('map toggle', () {
    testWidgets('hidden while no map provider is configured', (tester) async {
      await _openSearch(tester, repo: _Repo());
      expect(find.byTooltip('Afficher la carte'), findsNothing);
    });

    testWidgets('shows only pinnable professionals; a pin opens the profile', (
      tester,
    ) async {
      final map = _ListMap();
      await _openSearch(tester, repo: _Repo(), map: map);
      await tester.tap(find.byTooltip('Afficher la carte'));
      await tester.pumpAndSettle();
      expect(find.text('PIN Avec position'), findsOneWidget);
      expect(find.text('PIN Sans position'), findsNothing);
      await tester.tap(find.text('PIN Avec position'));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
      // Back to the list.
      final router = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(routerProvider);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Afficher la liste'));
      await tester.pumpAndSettle();
      expect(find.text('Avec position'), findsOneWidget);
      expect(find.text('Sans position'), findsOneWidget);
    });

    testWidgets('map mode can load more pages; later pages may hold the pins', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        overrides: [
          mapProviderProvider.overrideWithValue(_ListMap()),
          marketplaceRepositoryProvider.overrideWithValue(_PagedRepo()),
        ],
      );
      c.read(routerProvider).push(AppRoutes.searchPath(categoryId: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Afficher la carte'));
      await tester.pumpAndSettle();
      expect(find.text('Rien à placer sur la carte'), findsOneWidget);
      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();
      expect(find.text('PIN Épinglé'), findsOneWidget);
      expect(find.text('Voir plus'), findsNothing);
    });

    testWidgets('no pinnable professional: an honest empty state', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        overrides: [
          mapProviderProvider.overrideWithValue(_ListMap()),
          marketplaceRepositoryProvider.overrideWithValue(_NoPositionRepo()),
        ],
      );
      c.read(routerProvider).push(AppRoutes.searchPath(categoryId: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Afficher la carte'));
      await tester.pumpAndSettle();
      expect(find.text('Rien à placer sur la carte'), findsOneWidget);
    });
  });

  group('platform declarations', () {
    test('CI builds iOS without the always-authorization code', () {
      final ci = File('../.github/workflows/ci.yml').readAsStringSync();
      expect(
        ci,
        contains('BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ios'),
      );
    });

    test('Android asks for approximate location only', () {
      final m = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(m, contains('ACCESS_COARSE_LOCATION'));
      expect(
        RegExp(r'ACCESS_FINE_LOCATION"\s+tools:node="remove"').hasMatch(m),
        isTrue,
        reason: 'the plugin adds the precise permission; it must be removed',
      );
      expect(m, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });

    test('iOS explains when-in-use location and never asks for always', () {
      final p = File('ios/Runner/Info.plist').readAsStringSync();
      expect(p, contains('NSLocationWhenInUseUsageDescription'));
      expect(p, isNot(contains('NSLocationAlways')));
      expect(p, contains('NSLocationDefaultAccuracyReduced'));
    });
  });
}

class _NoPositionRepo extends DemoMarketplaceRepository {
  @override
  Future<List<ProfessionalSummary>> search(SearchQuery q) async => const [
    ProfessionalSummary(id: 'b', name: 'Sans position', categoryId: 1),
  ];
}

/// Page 1: twenty professionals without a position; page 2: one with.
class _PagedRepo extends DemoMarketplaceRepository {
  @override
  Future<List<ProfessionalSummary>> search(SearchQuery q) async => q.offset == 0
      ? [
          for (var i = 0; i < 20; i++)
            ProfessionalSummary(
              id: 'n$i',
              name: 'Nulle part $i',
              categoryId: 1,
            ),
        ]
      : const [
          ProfessionalSummary(
            id: 'p',
            name: 'Épinglé',
            categoryId: 1,
            latitude: 36.8,
            longitude: 10.2,
          ),
        ];
}
