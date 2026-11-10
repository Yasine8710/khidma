import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/marketplace/application/marketplace_providers.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/marketplace/presentation/filters_sheet.dart';

import '../test_helpers.dart';

/// 45 professionals, rating descending; page 2 (offset 20) fails once on
/// request. Records every query it receives.
class _ManyRepository extends DemoMarketplaceRepository {
  final queries = <SearchQuery>[];
  bool failOffset20Once = false;

  @override
  Future<List<ProfessionalSummary>> search(SearchQuery query) async {
    queries.add(query);
    if (failOffset20Once && query.offset == 20) {
      failOffset20Once = false;
      throw const MarketplaceError(MarketplaceFailure.network);
    }
    final all = [
      for (var i = 0; i < 45; i++)
        ProfessionalSummary(
          id: 'p$i',
          name: 'Pro ${i.toString().padLeft(2, '0')}',
          categoryId: 1,
          rating: 5 - i * 0.01,
          reviewCount: 3,
        ),
    ];
    return all.skip(query.offset).take(query.limit).toList();
  }
}

/// Drags the open list (or sheet) up until [f] is built, then brings it in.
Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  final list = find.byType(ListView).last;
  for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -400));
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  test('SearchQuery has value equality (provider cache keys rely on it)', () {
    const a = SearchQuery(text: 'x', categoryId: 1, offset: 20);
    const b = SearchQuery(text: 'x', categoryId: 1, offset: 20);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == a.copyWith(offset: 40), isFalse);
    expect(a == a.copyWith(minRating: 4), isFalse);
    expect(a == a.copyWith(availableOnly: true), isFalse);
    expect(a == a.copyWith(sort: ProfessionalSort.reviews), isFalse);
  });

  test('SearchFilters counts filters, not sorting', () {
    expect(const SearchFilters().activeCount, 0);
    expect(
      const SearchFilters(
        categoryId: 1,
        minRating: 4,
        availableOnly: true,
        sort: ProfessionalSort.reviews,
      ).activeCount,
      3,
    );
    expect(const SearchFilters(sort: ProfessionalSort.reviews).activeCount, 0);
  });

  group('search screen', () {
    testWidgets('pages load on demand and each page can retry alone', (
      tester,
    ) async {
      final repo = _ManyRepository()..failOffset20Once = true;
      final c = await pumpApp(
        tester,
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      c.read(routerProvider).push(AppRoutes.searchPath(categoryId: 1));
      await tester.pumpAndSettle();
      expect(find.text('Pro 00'), findsOneWidget);
      await _scrollTo(tester, find.text('Voir plus'));
      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();
      // Page 2 failed: its own retry, page 1 still there.
      await _scrollTo(tester, find.text('Réessayer'));
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Pro 39'));
      expect(find.text('Pro 39'), findsOneWidget);
      expect(find.text('Voir plus'), findsOneWidget);
      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Pro 44'));
      expect(find.text('Voir plus'), findsNothing, reason: 'short last page');
      final searched = repo.queries.where((q) => q.categoryId == 1);
      final offsets = searched.map((q) => q.offset).toSet();
      expect(offsets, {0, 20, 40});
      expect(searched.every((q) => q.limit == 20), isTrue);
    });

    testWidgets('filters reach the repository; reset clears them', (
      tester,
    ) async {
      final repo = _ManyRepository();
      final c = await pumpApp(
        tester,
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      c.read(routerProvider).push(AppRoutes.searchPath(categoryId: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Filtrer'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('4.5+'));
      await tester.tap(find.text('4.5+'));
      await _scrollTo(tester, find.text('Plus d’avis'));
      await tester.tap(find.text('Plus d’avis'));
      await _scrollTo(tester, find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      final q = repo.queries.last;
      expect(q.minRating, 4.5);
      expect(q.availableOnly, isTrue);
      expect(q.sort, ProfessionalSort.reviews);
      expect(q.categoryId, 1);
      expect(q.offset, 0, reason: 'a new filter starts from page one');
      expect(find.textContaining('(3)'), findsWidgets);

      await tester.tap(find.textContaining('Filtrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      // Nothing asked any more: the start prompt, not a stale result.
      expect(find.text('Que cherchez-vous ?'), findsOneWidget);
    });

    testWidgets('changing the category in the route refreshes results', (
      tester,
    ) async {
      final repo = _ManyRepository();
      final c = await pumpApp(
        tester,
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      final router = c.read(routerProvider);
      router.push(AppRoutes.searchPath(categoryId: 1));
      await tester.pumpAndSettle();
      router.pushReplacement(AppRoutes.searchPath(categoryId: 2));
      await tester.pumpAndSettle();
      expect(repo.queries.last.categoryId, 2);
      expect(repo.queries.last.offset, 0);
    });

    testWidgets('the demo data respects rating and availability filters', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).push(AppRoutes.search);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Filtrer'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('4.5+'));
      await tester.tap(find.text('4.5+'));
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      final expected = (await DemoMarketplaceRepository().search(
        const SearchQuery(minRating: 4.5),
      )).first;
      expect(find.text(expected.name), findsOneWidget);
      expect(find.text('Filtrer (1)'), findsOneWidget);
    });

    testWidgets('filters sheet fits a small phone at 1.5x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      for (final lang in ['fr', 'ar', 'en']) {
        final c = await pumpApp(tester, prefs: {'locale': lang});
        c.read(routerProvider).push(AppRoutes.search);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: lang);
      }
    });
  });
}
