import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/format/search_text.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/marketplace/data/supabase_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The same vectors the database tests run (backend/tests/vectors).
List<List<String>> _vectors() {
  final raw = jsonDecode(
    File('../backend/tests/vectors/search_normalize.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final v in raw['vectors'] as List)
      [for (final s in v as List) s as String],
  ];
}

void main() {
  group('normalizeSearch agrees with the database on the shared vectors', () {
    final vectors = _vectors();
    test(
      'there are vectors for French, Arabic variants and Persian letters',
      () {
        expect(vectors.length, greaterThanOrEqualTo(12));
      },
    );
    for (final v in vectors) {
      test(jsonEncode(v[0]), () => expect(normalizeSearch(v[0]), v[1]));
    }
  });

  group('prepareSearchText', () {
    test('collapses any whitespace, trims, normalizes', () {
      expect(
        prepareSearchText('  Électricité \t\n  À   côté '),
        'electricite a cote',
      );
      expect(prepareSearchText('\t \n '), '');
      expect(prepareSearchText(null), '');
    });
    test('caps the length like the database (100 characters)', () {
      expect(prepareSearchText('a' * 5000).length, maxSearchTextLength);
      expect(
        prepareSearchText('${'a' * 99} bcd'),
        'a' * 99,
        reason: 'cut at 100, then trimmed',
      );
    });
  });

  group(
    'demo repository applies the same place and text rules as the database',
    () {
      final repo = DemoMarketplaceRepository();
      Future<List<String>> names(SearchQuery q) async => [
        for (final p in await repo.search(q)) p.name,
      ];

      test(
        'a city must belong to the governorate it is combined with',
        () async {
          // Raoued (city 8) is in Ariana (12), not Tunis (11).
          expect(
            await names(
              const SearchQuery(governorateId: 11, cityId: 8, limit: 50),
            ),
            isEmpty,
          );
          final ok = await repo.search(
            const SearchQuery(governorateId: 12, cityId: 8, limit: 50),
          );
          expect(ok.every((p) => p.cityId == 8), isTrue);
          expect(ok, isNotEmpty);
        },
      );

      test('a city request is about that city, a governorate request about the governorate', () async {
        final city = await repo.search(const SearchQuery(cityId: 2, limit: 50));
        expect(city.every((p) => p.cityId == 2), isTrue);
        final gov = await repo.search(
          const SearchQuery(governorateId: 11, limit: 50),
        );
        expect(gov.every((p) => p.governorateId == 11), isTrue);
        expect(gov.length, greaterThan(city.length));
      });

      test('text never matches across the boundary of two fields', () async {
        // "Plomberie Ben Salah" + description "Fuites, ..." : a query joining the end of
        // the name and the start of the description must not match.
        expect(await names(const SearchQuery(text: 'salah fuites')), isEmpty);
        expect(
          await names(const SearchQuery(text: 'ben salah')),
          contains('Plomberie Ben Salah'),
        );
      });

      test(
        'whitespace-only text is no filter; very long text is harmless',
        () async {
          expect(
            (await repo.search(const SearchQuery(text: '\t \n', limit: 50)))
                .length,
            24,
          );
          expect(
            await repo.search(SearchQuery(text: 'a' * 100000)),
            isA<List<ProfessionalSummary>>(),
          );
        },
      );

      test('deep offsets are capped and return nothing', () async {
        expect(await names(const SearchQuery(offset: 1000000000)), isEmpty);
      });

      test('there is no "recent" sort until a real activity signal exists', () {
        expect(ProfessionalSort.values.map((s) => s.name), [
          'rating',
          'reviews',
          'nearest',
        ]);
      });

      test(
        'searches are consistent over repeated calls and pages (no duplicates)',
        () async {
          final a = await names(const SearchQuery(limit: 50));
          final b = await names(const SearchQuery(limit: 50));
          expect(a, b);
          expect(a.toSet().length, a.length);
        },
      );
    },
  );

  test(
    'permission errors are "forbidden", expired sessions are "not signed in"',
    () async {
      Future<MarketplaceFailure> failure(int status, String code) async {
        final client = MockClient(
          (r) async => http.Response(
            jsonEncode({'code': code, 'message': 'x'}),
            status,
            request: r,
            headers: {'content-type': 'application/json'},
          ),
        );
        final repo = SupabaseMarketplaceRepository(
          sb.SupabaseClient('https://abc.supabase.co', 'k', httpClient: client),
        );
        try {
          await repo.search(const SearchQuery());
        } on MarketplaceError catch (e) {
          return e.failure;
        }
        fail('expected a failure');
      }

      expect(
        await failure(403, '42501'),
        MarketplaceFailure.forbidden,
        reason: 'broken grants must not look like a signed-out user',
      );
      expect(await failure(401, 'PGRST301'), MarketplaceFailure.notSignedIn);
    },
  );
}
