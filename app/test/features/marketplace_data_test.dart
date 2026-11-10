import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/format/search_text.dart';
import 'package:khidma/features/marketplace/data/demo_data.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/marketplace/data/supabase_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Pulls the quoted string values out of one SQL `values (...)` row.
List<String> _quoted(String row) => [
  for (final m in RegExp(r"'((?:[^']|'')*)'").allMatches(row))
    m[1]!.replaceAll("''", "'"),
];

String get _seedSql => File(
  '../backend/supabase/migrations/20261110000200_seed_reference_data.sql',
).readAsStringSync();

void main() {
  group('normalizeSearch (must match the database search_normalize)', () {
    // The same vectors the backend tests use.
    test('French accents, case', () {
      expect(normalizeSearch('Électricité À Côté'), 'electricite a cote');
      expect(normalizeSearch('Œuvre'), 'ouvre');
      expect(normalizeSearch(null), '');
    });
    test('Arabic: diacritics, alef forms, ya, taa marbuta', () {
      expect(normalizeSearch('مَدْرَسَة'), 'مدرسه');
      expect(normalizeSearch('أحمد إبراهيم آمنة'), 'احمد ابراهيم امنه');
      expect(normalizeSearch('كتابى'), 'كتابي');
      expect(normalizeSearch('مـــدرسة'), 'مدرسه', reason: 'tatweel removed');
    });
    test('is idempotent', () {
      for (final s in ['Électricité', 'أريانة', 'abc 123']) {
        expect(normalizeSearch(normalizeSearch(s)), normalizeSearch(s));
      }
    });
  });

  test(
    'distanceKm matches the database formula (Tunis to Sfax is about 236 km)',
    () {
      final d = distanceKm(36.8065, 10.1815, 34.7406, 10.7603);
      expect(d, inInclusiveRange(225, 245));
      expect(distanceKm(36.8, 10.18, 36.8, 10.18), 0);
      expect(
        distanceKm(36.8, 10.18, 34.7, 10.7),
        closeTo(distanceKm(34.7, 10.7, 36.8, 10.18), 1e-9),
      );
    },
  );

  group('demo reference data stays identical to the database seed', () {
    test('governorates: ids, codes and all three names', () {
      final rows = RegExp(r"\((\d+), 'TN-\d+',[^)]*\)")
          .allMatches(_seedSql)
          .map((m) => m[0]!)
          .toList();
      expect(rows.length, 24);
      for (final row in rows) {
        final id = int.parse(RegExp(r'\((\d+),').firstMatch(row)![1]!);
        final q = _quoted(row); // code, fr, ar, en
        final g = demoGovernorates.firstWhere((g) => g.id == id);
        expect(
          [g.code, g.nameFr, g.nameAr, g.nameEn],
          q,
          reason: 'governorate $id',
        );
      }
      expect(demoGovernorates.length, 24);
    });

    test('categories: slug and names, in the same order', () {
      final block = _seedSql.substring(
        _seedSql.indexOf('insert into public.service_categories'),
      );
      final rows = RegExp(
        r"\('([a-z-]+)', '((?:[^']|'')*)', '((?:[^']|'')*)', '((?:[^']|'')*)'",
      ).allMatches(block).toList();
      expect(rows.length, 12);
      for (var i = 0; i < rows.length; i++) {
        final c = demoCategories[i];
        expect(c.id, i + 1);
        expect(c.slug, rows[i][1]);
        expect(c.nameFr, rows[i][2]!.replaceAll("''", "'"));
        expect(c.nameAr, rows[i][3]);
        expect(c.nameEn, rows[i][4]);
      }
    });

    test('cities: Greater Tunis, same order and names', () {
      final block = _seedSql.substring(
        _seedSql.indexOf('insert into public.cities'),
        _seedSql.indexOf('insert into public.neighborhoods'),
      );
      final rows = RegExp(
        r"\((1[1-4]),\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)'\)",
      ).allMatches(block).toList();
      expect(rows.length, demoCities.length);
      for (var i = 0; i < rows.length; i++) {
        final c = demoCities[i];
        expect(
          c.governorateId,
          int.parse(rows[i][1]!),
          reason: 'city ${i + 1}',
        );
        expect(c.nameFr, rows[i][2]!.replaceAll("''", "'"));
        expect(c.nameAr, rows[i][3]);
        expect(c.nameEn, rows[i][4]);
      }
    });
  });

  group('demo professionals', () {
    final all = buildDemoProfessionals();

    test('are plausible, unique, consistent with reference data, and never carry contact details', () {
      expect(all.length, greaterThanOrEqualTo(20));
      expect(all.map((p) => p.id).toSet().length, all.length);
      for (final p in all) {
        expect(p.name.trim(), isNotEmpty);
        expect(demoCategories.any((c) => c.id == p.categoryId), isTrue);
        final city = demoCities.firstWhere((c) => c.id == p.cityId);
        expect(city.governorateId, p.governorateId, reason: p.name);
        expect(p.rating, inInclusiveRange(0, 5));
        expect(
          p.hasReviews || p.rating == 0,
          isTrue,
          reason: 'no rating without reviews: ${p.name}',
        );
        expect(
          p.latitude!.toString().split('.').last.length <= 2,
          isTrue,
          reason: 'coordinates rounded to 2 decimals',
        );
      }
      expect(
        all.where((p) => p.isVerified).length,
        lessThan(all.length),
        reason: 'not everyone is verified',
      );
      expect(
        all.any((p) => !p.hasReviews),
        isTrue,
        reason: 'a newcomer with no reviews exists',
      );
    });
  });

  group('DemoMarketplaceRepository.search follows the database rules', () {
    final repo = DemoMarketplaceRepository();
    Future<List<String>> names(SearchQuery q) async => [
      for (final p in await repo.search(q)) p.name,
    ];

    test('is flagged as demo and has reference data', () async {
      expect(repo.isDemo, isTrue);
      expect((await repo.categories()).length, 12);
      expect((await repo.governorates()).length, 24);
      expect(
        (await repo.cities(governorateId: 12)).map((c) => c.nameFr),
        containsAll(['Ariana', 'Raoued']),
      );
      expect((await repo.cities()).length, 21);
    });

    test(
      'default order: rating then reviews; everything fits one big page',
      () async {
        final r = await repo.search(const SearchQuery(limit: 50));
        expect(r.length, 24);
        for (var i = 1; i < r.length; i++) {
          final a = r[i - 1];
          final b = r[i];
          expect(
            a.rating > b.rating ||
                (a.rating == b.rating && a.reviewCount >= b.reviewCount),
            isTrue,
            reason: '${a.name} before ${b.name}',
          );
        }
      },
    );

    test('text matches name, description, profession and place in any language, accents ignored', () async {
      expect(await names(const SearchQuery(text: 'trabelsi')), [
        'Atelier Trabelsi Électricité',
      ]);
      expect(
        await names(const SearchQuery(text: 'ELECTRICITE')),
        contains('Atelier Trabelsi Électricité'),
      );
      expect(
        await names(const SearchQuery(text: 'الكهرباء')),
        contains('Atelier Trabelsi Électricité'),
        reason: 'profession in Arabic',
      );
      expect(
        await names(const SearchQuery(text: 'climatiseurs')),
        contains('Clim Express Tunis'),
      );
      expect(
        await names(const SearchQuery(text: 'la marsa')),
        contains('Plomberie Ben Salah'),
      );
      expect(
        await names(const SearchQuery(text: 'المرسى')),
        contains('Plomberie Ben Salah'),
        reason: 'city in Arabic',
      );
      expect(
        await names(const SearchQuery(text: 'سباكه')),
        contains('سباكة النور'),
        reason: 'taa marbuta typed as haa',
      );
    });

    test('blank text means no filter; nonsense matches nothing', () async {
      expect(
        (await repo.search(const SearchQuery(text: '   ', limit: 50))).length,
        24,
      );
      expect(await names(const SearchQuery(text: 'zzzzzz')), isEmpty);
      expect(await names(const SearchQuery(text: '%')), isEmpty);
    });

    test(
      'category, governorate, city, rating, availability filters combine',
      () async {
        final plumbing = await repo.search(
          const SearchQuery(categoryId: 1, limit: 50),
        );
        expect(plumbing.every((p) => p.categoryId == 1), isTrue);
        final tunis = await repo.search(
          const SearchQuery(governorateId: 11, limit: 50),
        );
        expect(tunis.every((p) => p.governorateId == 11), isTrue);
        final hi = await repo.search(
          const SearchQuery(minRating: 4.7, limit: 50),
        );
        expect(hi.every((p) => p.rating >= 4.7), isTrue);
        final free = await repo.search(
          const SearchQuery(availableOnly: true, limit: 50),
        );
        expect(
          free.every((p) => p.availability == Availability.available),
          isTrue,
        );
        final combo = await repo.search(
          const SearchQuery(
            categoryId: 1,
            governorateId: 11,
            minRating: 4.5,
            availableOnly: true,
          ),
        );
        expect(combo.map((p) => p.name), ['Plomberie Ben Salah']);
      },
    );

    test('nearest: distances computed, ascending; radius filters; no position means no distance', () async {
      final tunis = demoCityCentre(1);
      final near = await repo.search(
        SearchQuery(
          sort: ProfessionalSort.nearest,
          latitude: tunis.lat,
          longitude: tunis.lng,
          limit: 50,
        ),
      );
      final d = near.map((p) => p.distanceKm!).toList();
      expect([...d]..sort(), d);
      final close = await repo.search(
        SearchQuery(
          sort: ProfessionalSort.nearest,
          latitude: tunis.lat,
          longitude: tunis.lng,
          radiusKm: 5,
          limit: 50,
        ),
      );
      expect(close.every((p) => p.distanceKm! <= 5), isTrue);
      expect(close.length, lessThan(near.length));
      final none = await repo.search(const SearchQuery(radiusKm: 5, limit: 50));
      expect(none.length, 24, reason: 'a radius without a position is ignored');
      expect(none.every((p) => p.distanceKm == null), isTrue);
    });

    test('most reviewed first', () async {
      final r = await repo.search(
        const SearchQuery(sort: ProfessionalSort.reviews, limit: 3),
      );
      expect(r.first.name, 'Atelier Trabelsi Électricité');
      expect(
        r.map((p) => p.reviewCount).toList(),
        [...r.map((p) => p.reviewCount)]..sort((a, b) => b.compareTo(a)),
      );
    });

    test('paging is stable and limits are clamped', () async {
      final all = await names(const SearchQuery(limit: 50));
      final paged = [
        ...await names(const SearchQuery(limit: 10, offset: 0)),
        ...await names(const SearchQuery(limit: 10, offset: 10)),
        ...await names(const SearchQuery(limit: 10, offset: 20)),
      ];
      expect(paged, all);
      expect((await repo.search(const SearchQuery(limit: 0))).length, 1);
      expect((await repo.search(const SearchQuery(limit: 10000))).length, 24);
      expect(
        (await repo.search(const SearchQuery(limit: 2, offset: -4))).length,
        2,
      );
      expect(await names(const SearchQuery(offset: 500)), isEmpty);
    });
  });

  group('domain', () {
    test('names fall back to French for unknown languages', () {
      final c = demoCategories.first;
      expect(c.nameFor(const Locale('fr')), 'Plomberie');
      expect(c.nameFor(const Locale('en')), 'Plumbing');
      expect(c.nameFor(const Locale('ar')), 'السباكة');
      expect(c.nameFor(const Locale('de')), 'Plomberie');
    });

    test('SearchQuery.copyWith sets and clears', () {
      const q = SearchQuery(
        text: 'a',
        categoryId: 1,
        minRating: 4,
        latitude: 1,
        longitude: 2,
        radiusKm: 5,
      );
      final c = q.copyWith(
        clearText: true,
        clearCategory: true,
        clearMinRating: true,
        clearPosition: true,
        clearRadius: true,
        sort: ProfessionalSort.reviews,
      );
      expect(c.text, isNull);
      expect(c.categoryId, isNull);
      expect(c.minRating, isNull);
      expect(c.hasPosition, isFalse);
      expect(c.radiusKm, isNull);
      expect(c.sort, ProfessionalSort.reviews);
      expect(
        q.copyWith(limit: 5).text,
        'a',
        reason: 'untouched values are kept',
      );
    });
  });

  group('SupabaseMarketplaceRepository over a recorded HTTP layer', () {
    late List<http.Request> requests;
    SupabaseMarketplaceRepository build(Object body, {int status = 200}) {
      requests = [];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode(body),
          status,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      });
      return SupabaseMarketplaceRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: client,
        ),
      );
    }

    test('categories read only public columns, ordered', () async {
      final repo = build([
        {
          'id': 1,
          'slug': 'plumbing',
          'name_fr': 'Plomberie',
          'name_ar': 'السباكة',
          'name_en': 'Plumbing',
          'description_fr': 'd',
          'description_ar': 'd',
          'description_en': 'd',
          'icon': 'plumbing',
          'sort_order': 10,
        },
      ]);
      final c = (await repo.categories()).single;
      expect(c.slug, 'plumbing');
      expect(c.nameEn, 'Plumbing');
      final r = requests.single;
      expect(r.url.path, '/rest/v1/service_categories');
      expect(r.url.queryParameters['order'], startsWith('sort_order.asc'));
      expect(r.url.queryParameters['select'], isNot(contains('*')));
    });

    test('cities filter by governorate on the server', () async {
      final repo = build([
        {
          'id': 7,
          'governorate_id': 12,
          'name_fr': 'Ariana',
          'name_ar': 'أريانة',
          'name_en': 'Ariana',
        },
      ]);
      final c = (await repo.cities(governorateId: 12)).single;
      expect(c.governorateId, 12);
      expect(requests.single.url.queryParameters['governorate_id'], 'eq.12');
      expect(
        requests.single.url.queryParameters['order'],
        startsWith('name_fr.asc'),
      );
    });

    test(
      'search sends only the filters that are set, as p_ parameters',
      () async {
        final repo = build(<Object>[]);
        await repo.search(
          const SearchQuery(
            text: '  plombier  ',
            categoryId: 1,
            availableOnly: true,
            sort: ProfessionalSort.rating,
            limit: 10,
            offset: 20,
          ),
        );
        final r = requests.single;
        expect(r.method, 'POST');
        expect(r.url.path, '/rest/v1/rpc/search_professionals');
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body, {
          'p_query': 'plombier',
          'p_category': 1,
          'p_available_only': true,
          'p_sort': 'rating',
          'p_limit': 10,
          'p_offset': 20,
        });
      },
    );

    test('position and radius travel together; a radius without a position is not sent', () async {
      final repo = build(<Object>[]);
      await repo.search(
        const SearchQuery(
          latitude: 36.8,
          longitude: 10.18,
          radiusKm: 15,
          sort: ProfessionalSort.nearest,
        ),
      );
      var body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_lat'], 36.8);
      expect(body['p_lng'], 10.18);
      expect(body['p_radius_km'], 15);
      expect(body['p_sort'], 'nearest');
      await repo.search(const SearchQuery(radiusKm: 15));
      body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body.containsKey('p_radius_km'), isFalse);
      expect(body.containsKey('p_lat'), isFalse);
    });

    test('rows become summaries (numbers as ints or doubles, unknown enums handled)', () async {
      final repo = build([
        {
          'user_id': 'u1',
          'business_name': 'Karim',
          'primary_category_id': 1,
          'description': 'd',
          'years_experience': 5,
          'governorate_id': 11,
          'city_id': 2,
          'neighborhood_id': null,
          'latitude': 36.88,
          'longitude': 10,
          'availability': 'busy',
          'verification_status': 'verified',
          'rating_avg': 4,
          'review_count': 3,
          'updated_at': '2026-11-10T10:00:00Z',
          'distance_km': 12.5,
        },
        {
          'user_id': 'u2',
          'business_name': null,
          'primary_category_id': 2,
          'description': null,
          'years_experience': null,
          'governorate_id': null,
          'city_id': null,
          'neighborhood_id': null,
          'latitude': null,
          'longitude': null,
          'availability': 'something-new',
          'verification_status': 'weird',
          'rating_avg': 0,
          'review_count': 0,
          'updated_at': '2026-11-10T10:00:00Z',
          'distance_km': null,
        },
      ]);
      final r = await repo.search(const SearchQuery());
      expect(r[0].id, 'u1');
      expect(r[0].rating, 4.0);
      expect(r[0].longitude, 10.0);
      expect(r[0].availability, Availability.busy);
      expect(r[0].isVerified, isTrue);
      expect(r[0].distanceKm, 12.5);
      expect(r[1].name, '');
      expect(
        r[1].availability,
        Availability.offline,
        reason: 'unknown value is treated cautiously',
      );
      expect(r[1].isVerified, isFalse);
      expect(r[1].distanceKm, isNull);
    });

    test('failures map to categories without leaking messages', () async {
      for (final (status, code, expected) in [
        (401, 'PGRST301', MarketplaceFailure.notSignedIn),
        (500, 'XX000', MarketplaceFailure.unknown),
      ]) {
        final repo = build({
          'code': code,
          'message': 'secret detail',
        }, status: status);
        await expectLater(
          repo.search(const SearchQuery()),
          throwsA(
            isA<MarketplaceError>()
                .having((e) => e.failure, 'failure', expected)
                .having(
                  (e) => e.toString(),
                  'toString',
                  isNot(contains('secret')),
                ),
          ),
        );
      }
      final dropped = SupabaseMarketplaceRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'k',
          httpClient: MockClient(
            (_) async => throw http.ClientException('Failed host lookup'),
          ),
        ),
      );
      await expectLater(
        dropped.search(const SearchQuery()),
        throwsA(
          isA<MarketplaceError>().having(
            (e) => e.failure,
            'failure',
            MarketplaceFailure.network,
          ),
        ),
      );
    });
  });

  test('EmptyMarketplaceRepository is honestly empty and not demo', () async {
    const repo = EmptyMarketplaceRepository();
    expect(repo.isDemo, isFalse);
    expect(await repo.search(const SearchQuery()), isEmpty);
    expect(await repo.categories(), isEmpty);
  });
}
