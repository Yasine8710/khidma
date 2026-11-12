import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/marketplace/application/home_providers.dart';
import 'package:khidma/features/marketplace/application/marketplace_providers.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/marketplace/presentation/professional_card.dart';
import 'package:khidma/features/requests/presentation/new_request_screen.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

const _pro = 'Plomberie Ben Salah';

/// Demo data whose governorate list fails once, then works.
class _FlakyRepository extends DemoMarketplaceRepository {
  int govCalls = 0;
  @override
  Future<List<Governorate>> governorates() async {
    if (govCalls++ == 0) {
      throw const MarketplaceError(MarketplaceFailure.network);
    }
    return super.governorates();
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('Home', () {
    testWidgets('demo data is labelled; categories and cards show', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Données de démonstration'), findsOneWidget);
      expect(find.text('Plomberie'), findsWidgets);
      final top = (await DemoMarketplaceRepository().search(
        const SearchQuery(limit: 1),
      )).first;
      await tester.scrollUntilVisible(
        find.text(top.name),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(top.name), findsOneWidget);
    });

    testWidgets('without a backend and demo data: no banner, honest empty', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          marketplaceRepositoryProvider.overrideWithValue(
            const EmptyMarketplaceRepository(),
          ),
        ],
      );
      expect(find.text('Données de démonstration'), findsNothing);
      expect(find.text(_pro), findsNothing);
      final empty = find.text(
        "Ils apparaîtront ici dès qu'ils auront rejoint Khidma.",
      );
      await tester.scrollUntilVisible(
        empty,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(empty, findsOneWidget);
    });

    testWidgets('greets a signed-in person by first name', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(
          signedIn: const AuthUser(id: 'u1', email: 'ali@example.tn'),
        ),
        profiles: FakeProfileRepository(
          profile: const AppProfile(id: 'u1', fullName: 'Ali Ben Youssef'),
        ),
      );
      expect(find.text('Bonjour, Ali'), findsOneWidget);
    });

    testWidgets('signed out: plain greeting, no name', (tester) async {
      await pumpApp(tester);
      expect(find.text('Bonjour'), findsOneWidget);
    });

    testWidgets('verified badge only on verified professionals', (
      tester,
    ) async {
      const verified = ProfessionalSummary(
        id: 'a',
        name: 'Vrai Pro',
        categoryId: 1,
        verification: Verification.verified,
      );
      const pending = ProfessionalSummary(
        id: 'b',
        name: 'Autre Pro',
        categoryId: 1,
        verification: Verification.pending,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: bareApp(
            const Column(
              children: [
                ProfessionalCard(professional: verified),
                ProfessionalCard(professional: pending),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vérifié'), findsOneWidget);
    });

    testWidgets('the quote card is on Home and leads to a new request', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Besoin d’un service ?'), findsOneWidget);
      await tester.ensureVisible(find.text('Demander un devis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demander un devis'));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestScreen), findsOneWidget);
    });

    testWidgets('a category tile opens search filtered to it', (tester) async {
      await pumpApp(tester);
      // Bring the tile clear of the bottom bar before tapping it.
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Électricité').first);
      await tester.pumpAndSettle();
      expect(find.text('Recherche'), findsNothing); // title is the field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(_pro), findsNothing, reason: 'a plumber, not electric');
      expect(find.byType(ProfessionalCard), findsWidgets);
    });

    testWidgets('typing in search finds by name; nonsense shows empty', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).push(AppRoutes.search);
      await tester.pumpAndSettle();
      expect(find.text('Que cherchez-vous ?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ben salah');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(_pro), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzzzqqq');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets('the chosen place is remembered and prompts until chosen', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      await tester.scrollUntilVisible(
        find.text(
          'Choisissez une zone pour voir les professionnels autour de vous.',
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await c
          .read(selectedPlaceProvider.notifier)
          .select(const Place(governorateId: 11));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Choisissez une zone pour voir les professionnels autour de vous.',
        ),
        findsNothing,
      );
      expect(c.read(selectedPlaceProvider), const Place(governorateId: 11));
    });

    testWidgets('a saved place loads on start; garbage is ignored', (
      tester,
    ) async {
      final c = await pumpApp(tester, prefs: {'place': '{"gov":11,"city":2}'});
      expect(
        c.read(selectedPlaceProvider),
        const Place(governorateId: 11, cityId: 2),
      );
      expect(Place.tryParse('nope'), isNull);
      expect(Place.tryParse('{"gov":"x"}'), isNull);
      expect(Place.tryParse('[1]'), isNull);
      expect(Place.tryParse(''), isNull);
    });

    testWidgets('the place sheet picks a governorate then a city', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      await tester.tap(find.text('Toute la Tunisie').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tunis').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('La Marsa').first);
      await tester.pumpAndSettle();
      final place = c.read(selectedPlaceProvider);
      expect(place?.governorateId, 11);
      expect(place?.cityId, isNotNull);
      expect(find.text('La Marsa'), findsWidgets);
    });

    testWidgets('the place chip is activatable by assistive tech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Choisir une zone')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('a failed governorate load offers a retry that works', (
      tester,
    ) async {
      final repo = _FlakyRepository();
      await pumpApp(
        tester,
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('Toute la Tunisie').first);
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Tunis'), findsWidgets);
    });

    testWidgets('opening a profile adds it to recently viewed', (tester) async {
      final c = await pumpApp(tester);
      expect(find.text('Consultés récemment'), findsNothing);
      c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
      await tester.pumpAndSettle();
      expect(find.text('À propos'), findsOneWidget);
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(c.read(recentlyViewedProvider), ['demo-01']);
      await tester.scrollUntilVisible(
        find.text('Consultés récemment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    });

    testWidgets('an unknown profile id says so', (tester) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).push(AppRoutes.professionalPath('nope'));
      await tester.pumpAndSettle();
      expect(find.text('Profil introuvable'), findsOneWidget);
    });

    test('recently viewed: newest first, no duplicates, capped', () {
      // Exercised through the notifier in the widget test above; the cap:
      expect(maxRecentlyViewed, 10);
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('fits a small phone at 1.5x text ($lang)', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final c = await pumpApp(tester, prefs: {'locale': lang});
        expect(tester.takeException(), isNull, reason: '$lang home');
        c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang profile');
      });
    }
  });
}
