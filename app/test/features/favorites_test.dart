import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/core/storage/preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/favorites/application/favorites_providers.dart';
import 'package:khidma/features/favorites/data/local_favorites_repository.dart';
import 'package:khidma/features/favorites/data/supabase_favorites_repository.dart';
import 'package:khidma/features/favorites/domain/favorites_domain.dart';
import 'package:khidma/features/marketplace/data/supabase_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

/// An account-bound favorites store (like the backend one) with failure hooks.
class _FakeFavorites implements FavoritesRepository {
  final saved = <String>[];
  MarketplaceFailure? failNext;

  /// Ids whose next add/remove fails.
  final failIds = <String>{};

  /// Log of server calls in the order they finished: 'add:x' / 'remove:x'.
  final log = <String>[];

  /// Delay for add calls (to make a later remove overtake it if unserialized).
  Duration addDelay = Duration.zero;
  int adds = 0;
  int removes = 0;

  @override
  bool get isLocal => false;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw MarketplaceError(f);
    }
  }

  /// Delay before the list answers (to observe the loading state).
  Duration idsDelay = Duration.zero;

  @override
  Future<List<String>> ids() async {
    await Future<void>.delayed(idsDelay);
    return [...saved];
  }

  @override
  Future<void> add(String id) async {
    adds++;
    await Future<void>.delayed(addDelay);
    _maybeFail();
    if (failIds.remove(id)) {
      throw const MarketplaceError(MarketplaceFailure.network);
    }
    log.add('add:$id');
    saved.insert(0, id);
  }

  @override
  Future<void> remove(String id) async {
    removes++;
    _maybeFail();
    log.add('remove:$id');
    saved.remove(id);
  }
}

Future<void> _openProfile(WidgetTester tester, dynamic c, String id) async {
  c.read(routerProvider).push(AppRoutes.professionalPath(id));
  await tester.pumpAndSettle();
}

class _BadStore implements KeyValueStore {
  @override
  String? getString(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  bool? getBool(String key) => null;
  @override
  Future<bool> setBool(String key, bool value) async => false;
}

void main() {
  setUpAll(loadAppFonts);

  group('local favorites (no backend)', () {
    testWidgets('save from a profile, see it listed, survive a restart', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      await _openProfile(tester, c, 'demo-01');
      await tester.tap(
        find.byTooltip('Ajouter Plomberie Ben Salah aux favoris'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Retirer Plomberie Ben Salah des favoris'),
        findsOneWidget,
      );
      expect(c.read(favoriteIdsProvider).value, ['demo-01']);

      c.read(routerProvider).push(AppRoutes.favorites);
      await tester.pumpAndSettle();
      expect(find.text('Mes favoris'), findsOneWidget);
      expect(find.text('Plomberie Ben Salah'), findsOneWidget);

      // A fresh app start reads the same saved list.
      final persisted = c.read(keyValueStoreProvider).getString('favorites');
      expect(persisted, '["demo-01"]');
      final c2 = await pumpApp(tester, prefs: {'favorites': persisted!});
      expect(c2.read(favoriteIdsProvider).value, ['demo-01']);
    });

    testWidgets('removing from the list drops it at once; empty state shows', (
      tester,
    ) async {
      final c = await pumpApp(tester, prefs: {'favorites': '["demo-01"]'});
      c.read(routerProvider).push(AppRoutes.favorites);
      await tester.pumpAndSettle();
      expect(find.text('Plomberie Ben Salah'), findsOneWidget);
      await tester.tap(
        find.byTooltip('Retirer Plomberie Ben Salah des favoris'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aucun favori'), findsOneWidget);
      expect(c.read(keyValueStoreProvider).getString('favorites'), '[]');
    });

    testWidgets('the Profile tab links to favorites', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes favoris'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun favori'), findsOneWidget);
    });

    test('garbage or foreign data in storage is ignored', () async {
      for (final raw in ['nope', '{"a":1}', '[1,null,"x",""]']) {
        final store = MemoryStore()..setString('favorites', raw);
        final ids = await LocalFavoritesRepository(store).ids();
        expect(ids, raw == '[1,null,"x",""]' ? ['x'] : isEmpty, reason: raw);
      }
    });

    test('newest first, no duplicates, capped at $maxFavorites', () async {
      final repo = LocalFavoritesRepository(MemoryStore());
      await repo.add('a');
      await repo.add('b');
      await repo.add('a');
      expect(await repo.ids(), ['b', 'a']);
      for (var i = 0; i < maxFavorites - 2; i++) {
        await repo.add('p$i');
      }
      await expectLater(
        repo.add('one-too-many'),
        throwsA(
          isA<MarketplaceError>().having(
            (e) => e.failure,
            'failure',
            MarketplaceFailure.limitReached,
          ),
        ),
      );
      await repo.remove('b');
      expect((await repo.ids()).length, maxFavorites - 1);
    });

    test('a failed write is an error, never a silent success', () async {
      final repo = LocalFavoritesRepository(_BadStore());
      await expectLater(repo.add('a'), throwsA(isA<MarketplaceError>()));
    });
  });

  group('account favorites (backend)', () {
    testWidgets('signed out: the heart opens sign-in, nothing is saved', (
      tester,
    ) async {
      final repo = _FakeFavorites();
      final c = await pumpApp(
        tester,
        overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
      );
      await _openProfile(tester, c, 'demo-01');
      await tester.tap(
        find.byTooltip('Ajouter Plomberie Ben Salah aux favoris'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Se connecter'), findsWidgets);
      expect(repo.adds, 0);
      c.read(routerProvider).go(AppRoutes.favorites);
      await tester.pumpAndSettle();
      expect(find.text('Retrouvez vos favoris'), findsOneWidget);
    });

    testWidgets('signed in: save and remove reach the repository', (
      tester,
    ) async {
      final repo = _FakeFavorites();
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
      );
      await _openProfile(tester, c, 'demo-01');
      await tester.tap(
        find.byTooltip('Ajouter Plomberie Ben Salah aux favoris'),
      );
      await tester.pumpAndSettle();
      expect(repo.saved, ['demo-01']);
      await tester.tap(
        find.byTooltip('Retirer Plomberie Ben Salah des favoris'),
      );
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect((repo.adds, repo.removes), (1, 1));
    });

    testWidgets(
      'a failed save goes back and says so; the limit has its own words',
      (tester) async {
        final repo = _FakeFavorites()..failNext = MarketplaceFailure.network;
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
        );
        await _openProfile(tester, c, 'demo-01');
        await tester.tap(
          find.byTooltip('Ajouter Plomberie Ben Salah aux favoris'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text('Impossible de modifier vos favoris. Réessayez.'),
          findsOneWidget,
        );
        await tester.pumpAndSettle(const Duration(seconds: 6));
        expect(
          find.byTooltip('Ajouter Plomberie Ben Salah aux favoris'),
          findsOneWidget,
          reason: 'rolled back',
        );

        repo.failNext = MarketplaceFailure.limitReached;
        await tester.tap(
          find.byTooltip('Ajouter Plomberie Ben Salah aux favoris'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text('Vous avez atteint la limite de 200 favoris.'),
          findsOneWidget,
        );
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    test('quick add then remove reach the server in that order', () async {
      final repo = _FakeFavorites()
        ..addDelay = const Duration(milliseconds: 50);
      final c = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: _ali),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(currentUserProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await c.read(favoriteIdsProvider.future);
      final n = c.read(favoriteIdsProvider.notifier);
      final a = n.toggle('x');
      final b = n.toggle('x');
      expect(await a, isNull);
      expect(await b, isNull);
      expect(repo.log, ['add:x', 'remove:x']);
      expect(repo.saved, isEmpty);
      expect(c.read(favoriteIdsProvider).value, isEmpty);
    });

    test('a failed save undoes only that professional', () async {
      final repo = _FakeFavorites()
        ..addDelay = const Duration(milliseconds: 20)
        ..failIds.add('a');
      final c = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: _ali),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(currentUserProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await c.read(favoriteIdsProvider.future);
      final n = c.read(favoriteIdsProvider.notifier);
      final a = n.toggle('a');
      final b = n.toggle('b');
      expect(await b, isNull);
      expect(await a, MarketplaceFailure.network);
      expect(c.read(favoriteIdsProvider).value, ['b']);
      expect(repo.saved, ['b']);
    });

    test(
      'while another account loads, nothing is saved or shown as saved',
      () async {
        final auth = FakeAuthRepository(signedIn: _ali);
        final repo = _FakeFavorites()..saved.add('x');
        final c = ProviderContainer(
          overrides: [
            favoritesRepositoryProvider.overrideWithValue(repo),
            authRepositoryProvider.overrideWithValue(auth),
          ],
        );
        addTearDown(c.dispose);
        c.listen(currentUserProvider, (_, _) {});
        c.listen(favoriteIdsProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);
        await c.read(favoriteIdsProvider.future);
        expect(c.read(isFavoriteProvider('x')), isTrue);
        repo.idsDelay = const Duration(milliseconds: 50);
        auth.emit(const AuthUser(id: 'u2', email: 'b@example.tn'));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(c.read(favoriteIdsProvider).isLoading, isTrue);
        expect(c.read(isFavoriteProvider('x')), isFalse);
        expect(
          await c.read(favoriteIdsProvider.notifier).toggle('y'),
          isNotNull,
        );
        expect(repo.adds, 0);
      },
    );

    testWidgets('another account does not inherit the previous favorites', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedIn: _ali);
      final repo = _FakeFavorites()..saved.add('demo-01');
      final c = await pumpApp(
        tester,
        auth: auth,
        overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
      );
      // Something must be watching the ids, as hearts on screen would.
      final sub = c.listen(favoriteIdsProvider, (_, _) {});
      addTearDown(sub.close);
      expect(c.read(favoriteIdsProvider).value, ['demo-01']);
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(c.read(favoriteIdsProvider).value, isEmpty);
      expect(c.read(isFavoriteProvider('demo-01')), isFalse);
    });
  });

  group('wire format', () {
    late List<http.Request> requests;
    http.Client client(Object body) => MockClient((r) async {
      requests.add(r);
      return http.Response(
        jsonEncode(body),
        200,
        request: r,
        headers: {'content-type': 'application/json'},
      );
    });
    sb.SupabaseClient supabase(Object body) {
      requests = [];
      return sb.SupabaseClient(
        'https://abc.supabase.co',
        'sb_publishable_testkey',
        httpClient: client(body),
      );
    }

    test('ids: own favorites, newest first, capped', () async {
      final repo = SupabaseFavoritesRepository(
        supabase([
          {'professional_id': 'p2'},
          {'professional_id': 'p1'},
        ]),
      );
      expect(await repo.ids(), ['p2', 'p1']);
      final r = requests.single;
      expect(r.url.path, '/rest/v1/favorites');
      expect(r.url.queryParameters['select'], 'professional_id');
      expect(r.url.queryParameters['order'], startsWith('created_at.desc'));
      expect(r.url.queryParameters['limit'], '$maxFavorites');
    });

    test('add upserts ignoring duplicates for the signed-in user', () async {
      final repo = SupabaseFavoritesRepository(
        supabase(<Object>[]),
        userId: () => 'u1',
      );
      await repo.add('p1');
      final r = requests.single;
      expect(r.method, 'POST');
      expect(jsonDecode(r.body), {'user_id': 'u1', 'professional_id': 'p1'});
      expect(r.url.queryParameters['on_conflict'], 'user_id,professional_id');
      expect(r.headers['Prefer'], contains('resolution=ignore-duplicates'));
    });

    test('remove deletes only that pair', () async {
      final repo = SupabaseFavoritesRepository(
        supabase(<Object>[]),
        userId: () => 'u1',
      );
      await repo.remove('p1');
      final r = requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.queryParameters['user_id'], 'eq.u1');
      expect(r.url.queryParameters['professional_id'], 'eq.p1');
    });

    test('without a session nothing is sent', () async {
      final repo = SupabaseFavoritesRepository(
        supabase(<Object>[]),
        userId: () => null,
      );
      await expectLater(
        repo.add('p1'),
        throwsA(
          isA<MarketplaceError>().having(
            (e) => e.failure,
            'failure',
            MarketplaceFailure.notSignedIn,
          ),
        ),
      );
      expect(requests, isEmpty);
    });

    test('the server cap maps to limitReached', () {
      expect(
        mapMarketplaceException(
          const sb.PostgrestException(
            message: 'favorites_limit',
            code: 'P0001',
          ),
        ),
        MarketplaceFailure.limitReached,
      );
    });

    test(
      'professionals(ids): published only, in the order asked, chunked',
      () async {
        Map<String, dynamic> row(String id) => {
          'user_id': id,
          'business_name': 'N $id',
          'primary_category_id': 1,
          'description': 'd',
          'years_experience': null,
          'governorate_id': 11,
          'city_id': null,
          'neighborhood_id': null,
          'latitude': null,
          'longitude': null,
          'availability': 'available',
          'verification_status': 'unverified',
          'rating_avg': 0,
          'review_count': 0,
        };
        // The server answers with every id it was asked about except "gone".
        requests = [];
        final repo = SupabaseMarketplaceRepository(
          sb.SupabaseClient(
            'https://abc.supabase.co',
            'sb_publishable_testkey',
            httpClient: MockClient((r) async {
              requests.add(r);
              final f = r.url.queryParameters['user_id']!;
              final ids = f
                  .substring(4, f.length - 1)
                  .split(',')
                  .map((x) => x.replaceAll('"', ''))
                  .toList();
              return http.Response(
                jsonEncode([
                  for (final i in ids)
                    if (i != 'gone') row(i),
                ]),
                200,
                request: r,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );
        final asked = ['c', 'gone', 'a', 'b', 'a'];
        final r = await repo.professionals(asked);
        expect(r.map((p) => p.id), ['c', 'a', 'b', 'a']);
        expect(requests.single.url.queryParameters['is_published'], 'eq.true');

        final many = [for (var i = 0; i < 120; i++) 'p$i'];
        requests.clear();
        final big = await repo.professionals(many);
        expect(requests.length, 3, reason: '50 + 50 + 20');
        expect(big.map((p) => p.id), many);
        expect(await repo.professionals(const []), isEmpty);
      },
    );
  });
}
