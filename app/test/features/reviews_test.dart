import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/requests/application/customer_offers_providers.dart';
import 'package:khidma/features/requests/application/requests_providers.dart';
import 'package:khidma/features/requests/data/supabase_requests_repository.dart'
    show mapRequestsException;
import 'package:khidma/features/requests/domain/customer_offers_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:khidma/features/reviews/application/reviews_providers.dart';
import 'package:khidma/features/reviews/data/supabase_reviews_repository.dart';
import 'package:khidma/features/reviews/domain/reviews_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_customer_offers.dart';
import '../support/fake_requests.dart';
import '../support/fake_reviews.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

Future<dynamic> _openJob(
  WidgetTester tester,
  FakeReviewsRepository reviews, {
  Map<String, Object> prefs = const {},
}) async {
  final c = await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: _ali),
    prefs: prefs,
    overrides: [
      reviewsRepositoryProvider.overrideWithValue(reviews),
      requestsRepositoryProvider.overrideWithValue(
        FakeRequestsRepository([
          sampleRequest(status: RequestStatus.awarded, offers: 1),
        ]),
      ),
      customerOffersRepositoryProvider.overrideWithValue(
        FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'a', status: OfferStatus.accepted)],
          bookingValue: const CustomerBooking(
            id: 'b1',
            professionalId: 'demo-01',
            priceTnd: 150,
            status: BookingStatus.completed,
          ),
        ),
      ),
    ],
  );
  c.read(routerProvider).push(AppRoutes.requestPath('r-sample'));
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  test('rules', () {
    expect(ReviewRules.ratingOk(1), isTrue);
    expect(ReviewRules.ratingOk(5), isTrue);
    expect(ReviewRules.ratingOk(0), isFalse);
    expect(ReviewRules.ratingOk(6), isFalse);
    expect(ReviewRules.ratingOk(null), isFalse);
    expect(ReviewRules.commentOk('a' * 1000), isTrue);
    expect(ReviewRules.commentOk('a' * 1001), isFalse);
  });

  group('leaving a review', () {
    testWidgets(
      'a completed job offers it; stars and comment are sent; then it says it is done',
      (tester) async {
        final repo = FakeReviewsRepository();
        await _openJob(tester, repo);
        await _tap(tester, 'Laisser un avis');
        expect(
          find.text('Votre avis sera public, sans votre nom.'),
          findsOneWidget,
        );
        await tester.tap(find.bySemanticsLabel('4 étoiles'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          '  Ponctuel et propre  ',
        );
        await tester.tap(find.text('Publier mon avis'));
        await tester.pumpAndSettle();
        expect(repo.submitted.single.$1, 'b1');
        expect(repo.submitted.single.$2, 4);
        expect(repo.submitted.single.$3?.trim(), 'Ponctuel et propre');
        expect(find.text('Merci pour votre avis.'), findsOneWidget);
        expect(find.text('Laisser un avis'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Avis donné'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets('assistive tech can pick a star (the semantic tap works)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = FakeReviewsRepository();
      await _openJob(tester, repo);
      await _tap(tester, 'Laisser un avis');
      tester.semantics.tap(find.semantics.byLabel('4 étoiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publier mon avis'));
      await tester.pumpAndSettle();
      expect(repo.submitted.single.$2, 4);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      handle.dispose();
    });

    testWidgets('too many reviews for one professional is explained', (
      tester,
    ) async {
      final repo = FakeReviewsRepository();
      await _openJob(tester, repo);
      await _tap(tester, 'Laisser un avis');
      await tester.tap(find.bySemanticsLabel('5 étoiles'));
      await tester.pumpAndSettle();
      repo.failNext = RequestsFailure.limitReached;
      await tester.tap(find.text('Publier mon avis'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vous avez déjà donné trop d’avis sur ce professionnel.'),
        findsOneWidget,
      );
    });

    testWidgets('a rating is required; nothing is sent without one', (
      tester,
    ) async {
      final repo = FakeReviewsRepository();
      await _openJob(tester, repo);
      await _tap(tester, 'Laisser un avis');
      await tester.tap(find.text('Publier mon avis'));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez une note de 1 à 5.'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    testWidgets('already reviewed: no button, a done badge', (tester) async {
      await _openJob(tester, FakeReviewsRepository(reviewed: {'b1'}));
      await tester.scrollUntilVisible(
        find.text('Avis donné'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Laisser un avis'), findsNothing);
    });

    testWidgets(
      'a failure keeps the sheet and the typed comment; an "already reviewed" answer closes it',
      (tester) async {
        final repo = FakeReviewsRepository();
        await _openJob(tester, repo);
        await _tap(tester, 'Laisser un avis');
        await tester.tap(find.bySemanticsLabel('5 étoiles'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'à garder');
        repo.failNext = RequestsFailure.network;
        await tester.tap(find.text('Publier mon avis'));
        await tester.pumpAndSettle();
        expect(
          find.text('Impossible d’envoyer l’avis. Réessayez.'),
          findsOneWidget,
        );
        expect(find.text('à garder'), findsOneWidget);
        repo.failNext = RequestsFailure.notCompleted;
        await tester.tap(find.text('Publier mon avis'));
        await tester.pumpAndSettle();
        expect(
          find.text('Le chantier doit être terminé pour laisser un avis.'),
          findsOneWidget,
        );
        repo.failNext = RequestsFailure.alreadyReviewed;
        await tester.tap(find.text('Publier mon avis'));
        await tester.pumpAndSettle();
        expect(
          find.text('Publier mon avis'),
          findsNothing,
          reason: 'sheet closed',
        );
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets('a double tap sends once', (tester) async {
      final repo = FakeReviewsRepository();
      await _openJob(tester, repo);
      await _tap(tester, 'Laisser un avis');
      await tester.tap(find.bySemanticsLabel('5 étoiles'));
      await tester.pumpAndSettle();
      final gate = repo.gate = Completer<void>();
      await tester.tap(find.text('Publier mon avis'));
      await tester.pump();
      await tester.tap(find.text('Publier mon avis'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.submitted.length, 1);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets(
      'stars are buttons with their own labels, the chosen one is selected',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openJob(tester, FakeReviewsRepository());
        await _tap(tester, 'Laisser un avis');
        await tester.tap(find.bySemanticsLabel('3 étoiles'));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.bySemanticsLabel('3 étoiles'));
        expect(node.getSemanticsData().flagsCollection.isSelected, isNotNull);
        expect(find.bySemanticsLabel('1 étoile'), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('public list', () {
    Future<dynamic> openProfile(
      WidgetTester tester,
      FakeReviewsRepository repo, {
      Map<String, Object> prefs = const {},
    }) async {
      final c = await pumpApp(
        tester,
        prefs: prefs,
        overrides: [reviewsRepositoryProvider.overrideWithValue(repo)],
      );
      c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('shows rating, comment and date, never an author name', (
      tester,
    ) async {
      final repo = FakeReviewsRepository(
        reviews: [
          sampleReview(comment: 'Très bon travail'),
          sampleReview(id: 'b', rating: 3, comment: null),
        ],
      );
      await openProfile(tester, repo);
      await tester.scrollUntilVisible(
        find.text('Très bon travail'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Très bon travail'), findsOneWidget);
      expect(
        find.textContaining('Client · novembre 2026'),
        findsNWidgets(2),
        reason: 'month only, never the exact day',
      );
      expect(
        find.bySemanticsLabel(RegExp('^3 étoiles, novembre 2026')),
        findsOneWidget,
      );
    });

    testWidgets('no reviews, or a failing list: no heading at all', (
      tester,
    ) async {
      await openProfile(tester, FakeReviewsRepository());
      expect(find.text('Avis'), findsNothing);
    });

    testWidgets('paging: more reviews on demand', (tester) async {
      final repo = FakeReviewsRepository(
        reviews: [
          for (var i = 0; i < 12; i++)
            sampleReview(id: 'r$i', comment: 'Avis numéro $i'),
        ],
      );
      await openProfile(tester, repo);
      Future<void> down(Finder f) => tester.scrollUntilVisible(
        f,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await down(find.text('Voir plus d’avis'));
      expect(find.text('Avis numéro 11'), findsNothing);
      await tester.ensureVisible(find.text('Voir plus d’avis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir plus d’avis'));
      await tester.pumpAndSettle();
      expect(find.text('Avis numéro 11', skipOffstage: false), findsOneWidget);
      expect(repo.pagesAsked.toSet(), {0, 1});
      expect(find.text('Voir plus d’avis'), findsNothing);
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
        await openProfile(
          tester,
          FakeReviewsRepository(
            reviews: [
              sampleReview(
                comment: 'Un commentaire assez long pour passer à la ligne sur un petit téléphone.',
              ),
            ],
          ),
          prefs: {'locale': lang},
        );
        expect(tester.takeException(), isNull, reason: lang);
      });
    }
  });

  group('wire format', () {
    late List<http.Request> requests;
    SupabaseReviewsRepository build(Object body) {
      requests = [];
      return SupabaseReviewsRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(body),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    }

    test('public reads select only public columns, published, newest first, ranged', () async {
      final repo = build([
        {
          'id': 'r1',
          'rating': 4,
          'comment': 'ok',
          'reviewed_month': '2026-11-01',
        },
      ]);
      final list = await repo.forProfessional('p1', offset: 10);
      final q = requests.single.url.queryParameters;
      expect(requests.single.url.path, '/rest/v1/reviews');
      expect(q['select'], 'id,rating,comment,reviewed_month');
      expect(q['subject_id'], 'eq.p1');
      expect(q['status'], 'eq.published');
      expect(q['order'], startsWith('seq.desc'));
      expect(q['offset'], '10');
      expect(q['limit'], '10');
      expect(list.single.rating, 4);
    });

    test('submit calls the function; a blank comment is none', () async {
      final repo = build('rev-1');
      await repo.submit('b1', 5, '  Super  ');
      await repo.submit('b1', 5, '   ');
      expect(jsonDecode(requests[0].body), {
        'p_booking': 'b1',
        'p_rating': 5,
        'p_comment': 'Super',
      });
      expect(jsonDecode(requests[1].body)['p_comment'], isNull);
      expect(requests[0].url.path, '/rest/v1/rpc/submit_review');
    });

    test('my reviewed bookings', () async {
      final ids = await build([
        {'booking_id': 'b1'},
        {'booking_id': 'b2'},
      ]).myReviewedBookings();
      expect(ids, {'b1', 'b2'});
    });

    test('database tags map to categories', () {
      RequestsFailure f(String m) => mapRequestsException(
        sb.PostgrestException(message: m, code: 'P0001'),
      );
      expect(f('not_completed'), RequestsFailure.notCompleted);
      expect(f('already_reviewed'), RequestsFailure.alreadyReviewed);
      expect(f('invalid_input'), RequestsFailure.invalidInput);
    });
  });
}
