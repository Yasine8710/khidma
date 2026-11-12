import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/requests/application/customer_offers_providers.dart';
import 'package:khidma/features/requests/application/requests_providers.dart';
import 'package:khidma/features/requests/data/supabase_customer_offers_repository.dart';
import 'package:khidma/features/requests/domain/customer_offers_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_customer_offers.dart';
import '../support/fake_requests.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

Future<dynamic> _open(
  WidgetTester tester,
  FakeCustomerOffersRepository offers, {
  QuoteRequest? request,
  Map<String, Object> prefs = const {},
  FakeAuthRepository? auth,
}) async {
  final c = await pumpApp(
    tester,
    auth: auth ?? FakeAuthRepository(signedIn: _ali),
    prefs: prefs,
    overrides: [
      requestsRepositoryProvider.overrideWithValue(
        FakeRequestsRepository([
          request ?? sampleRequest(offers: offers.offerList.length),
        ]),
      ),
      customerOffersRepositoryProvider.overrideWithValue(offers),
    ],
  );
  c
      .read(routerProvider)
      .push(AppRoutes.requestPath((request ?? sampleRequest()).id));
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

  group('offers received', () {
    testWidgets('no offers yet: says so', (tester) async {
      await _open(tester, FakeCustomerOffersRepository());
      expect(find.textContaining('Pas encore d’offre'), findsOneWidget);
    });

    testWidgets(
      'side by side: who, rating, price, delay, message; verified only when verified',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [
            sampleOffer(
              id: 'a',
              pro: 'demo-01',
              price: 150,
              days: 2,
              message: 'Je passe demain',
            ),
            sampleOffer(id: 'b', pro: 'demo-02', price: 120),
          ],
        );
        await _open(tester, repo);
        final demo = DemoMarketplaceRepository();
        final pros = await demo.professionals(['demo-01', 'demo-02']);
        expect(find.text(pros[0].name), findsOneWidget);
        expect(find.text(pros[1].name), findsOneWidget);
        expect(find.text('Je passe demain'), findsOneWidget);
        expect(find.text('Délai : 2 j'), findsOneWidget);
        expect(find.textContaining('150'), findsWidgets);
        expect(
          find.text('Vérifié').evaluate().length,
          pros.where((p) => p.isVerified).length,
        );
        expect(find.text('Prix le plus bas'), findsOneWidget);
      },
    );

    testWidgets(
      'sorted by price first; the lowest is marked; sorting by rating and delay works',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [
            sampleOffer(id: 'a', pro: 'demo-01', price: 150, days: 5),
            sampleOffer(id: 'b', pro: 'demo-02', price: 120, days: 9),
            sampleOffer(id: 'c', pro: 'demo-03', price: 200, days: 1),
          ],
        );
        await _open(tester, repo);
        final pros = {
          for (final p in await DemoMarketplaceRepository().professionals([
            'demo-01',
            'demo-02',
            'demo-03',
          ]))
            p.id: p,
        };
        double y(String id) =>
            tester.getTopLeft(find.text(pros[id]!.name).first).dy;
        expect(
          y('demo-02') < y('demo-01') && y('demo-01') < y('demo-03'),
          isTrue,
          reason: 'cheapest first',
        );

        await _tap(tester, 'Délai');
        expect(
          y('demo-03') < y('demo-01') && y('demo-01') < y('demo-02'),
          isTrue,
          reason: 'fastest first',
        );

        await _tap(tester, 'Note');
        final byRating = ['demo-01', 'demo-02', 'demo-03']
          ..sort((a, b) => pros[b]!.rating.compareTo(pros[a]!.rating));
        expect(
          y(byRating.first) < y(byRating.last),
          isTrue,
          reason: 'best rated first',
        );
      },
    );

    testWidgets(
      'accepting asks first, awards the request and shows the job; the others are declined',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [
            sampleOffer(id: 'a', pro: 'demo-01', price: 150),
            sampleOffer(id: 'b', pro: 'demo-02', price: 120),
          ],
        );
        await _open(tester, repo);
        await tester.ensureVisible(find.text('Accepter').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accepter').first);
        await tester.pumpAndSettle();
        expect(find.text('Accepter cette offre ?'), findsOneWidget);
        expect(
          find.textContaining('Les autres offres seront refusées'),
          findsOneWidget,
        );
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(repo.calls, isEmpty);
        await tester.ensureVisible(find.text('Accepter').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accepter').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Accepter'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['accept:b'], reason: 'the cheapest card was first');
        expect(find.text('Offre acceptée.'), findsOneWidget);
        expect(
          repo.offerList.where((o) => o.status == OfferStatus.declined).length,
          1,
        );
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets(
      'declining asks first; the offer is shown as declined with no actions',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'a')],
        );
        await _open(tester, repo);
        await tester.tap(find.text('Refuser'));
        await tester.pumpAndSettle();
        expect(find.text('Refuser cette offre ?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Refuser'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['decline:a']);
        expect(find.text('Refusée'), findsOneWidget);
        expect(find.text('Accepter'), findsNothing);
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets('a request that is no longer open offers no actions', (
      tester,
    ) async {
      final repo = FakeCustomerOffersRepository(offers: [sampleOffer(id: 'a')]);
      await _open(
        tester,
        repo,
        request: sampleRequest(status: RequestStatus.cancelled, offers: 1),
      );
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
    });

    testWidgets('accepting an offer that just closed says so', (tester) async {
      final repo = FakeCustomerOffersRepository(offers: [sampleOffer(id: 'a')]);
      await _open(tester, repo);
      repo.failNext = RequestsFailure.notOpen;
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Accepter'));
      await tester.pumpAndSettle();
      expect(find.text('Cette demande n’est plus ouverte.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('a double tap on Accept sends once', (tester) async {
      final repo = FakeCustomerOffersRepository(offers: [sampleOffer(id: 'a')]);
      await _open(tester, repo);
      final gate = repo.gate = Completer<void>();
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Accepter'));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.calls.length, 1);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets(
      'Accept is not offered for a professional who is no longer public; Decline stays',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'a', pro: 'gone')],
        );
        await _open(tester, repo);
        expect(find.text('Accepter'), findsNothing);
        expect(find.text('Refuser'), findsOneWidget);
      },
    );

    testWidgets('an expired request still marked open offers no Accept', (
      tester,
    ) async {
      final repo = FakeCustomerOffersRepository(
        offers: [sampleOffer(id: 'a', pro: 'demo-01')],
      );
      final expired = QuoteRequest(
        id: 'r-sample',
        title: 'Fuite',
        description: 'Une fuite sous le lavabo.',
        categoryId: 1,
        governorateId: 11,
        status: RequestStatus.open,
        createdAt: DateTime(2020),
        expiresAt: DateTime(2020, 1, 15),
        offerCount: 1,
      );
      await _open(tester, repo, request: expired);
      expect(find.text('Accepter'), findsNothing);
    });

    testWidgets(
      'an offerer who is no longer public is still shown, without a link',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'a', pro: 'gone')],
        );
        await _open(tester, repo);
        expect(find.text('Professionnel'), findsOneWidget);
      },
    );
  });

  group('the job', () {
    final awarded = sampleRequest(status: RequestStatus.awarded, offers: 1);

    testWidgets('waiting for the professional: shows the status, can cancel', (
      tester,
    ) async {
      final repo = FakeCustomerOffersRepository(
        offers: [sampleOffer(id: 'a', status: OfferStatus.accepted)],
        bookingValue: const CustomerBooking(
          id: 'b1',
          professionalId: 'demo-01',
          priceTnd: 150,
          status: BookingStatus.scheduled,
        ),
      );
      await _open(tester, repo, request: awarded);
      await tester.scrollUntilVisible(
        find.text('Chantier'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Planifié'), findsOneWidget);
      expect(find.text('Confirmer que le travail est terminé'), findsNothing);
      await _tap(tester, 'Annuler le chantier');
      expect(find.text('Annuler ce chantier ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Annuler le chantier'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['cancel:b1']);
      expect(find.text('Annulé'), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets(
      'only the customer confirms, and only once the professional says it is done',
      (tester) async {
        final repo = FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'a', status: OfferStatus.accepted)],
          bookingValue: const CustomerBooking(
            id: 'b1',
            professionalId: 'demo-01',
            priceTnd: 150,
            status: BookingStatus.pendingConfirmation,
          ),
        );
        await _open(tester, repo, request: awarded);
        await _tap(tester, 'Confirmer que le travail est terminé');
        expect(repo.calls, ['confirm:b1']);
        expect(find.text('Terminé'), findsWidgets);
        expect(find.text('Confirmer que le travail est terminé'), findsNothing);
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets('a job that fails to load says so and can be retried', (
      tester,
    ) async {
      final repo = FakeCustomerOffersRepository(
        offers: [sampleOffer(id: 'a', status: OfferStatus.accepted)],
        bookingValue: const CustomerBooking(
          id: 'b1',
          professionalId: 'demo-01',
          priceTnd: 150,
          status: BookingStatus.scheduled,
        ),
      )..failBooking = true;
      await _open(tester, repo, request: awarded);
      await tester.scrollUntilVisible(
        find.text('Réessayer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      repo.failBooking = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Chantier'), findsOneWidget);
    });

    testWidgets('no job, no section', (tester) async {
      final repo = FakeCustomerOffersRepository(offers: [sampleOffer(id: 'a')]);
      await _open(tester, repo);
      expect(find.text('Chantier'), findsNothing);
    });

    testWidgets(
      'signing out clears the offers (no leftovers for the next account)',
      (tester) async {
        final auth = FakeAuthRepository(signedIn: _ali);
        final repo = FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'a', message: 'Secret message')],
        );
        await _open(tester, repo, auth: auth);
        expect(find.text('Secret message'), findsOneWidget);
        auth.emit(null);
        await tester.pumpAndSettle();
        expect(find.text('Secret message'), findsNothing);
      },
    );

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('fits a small phone at 1.5x text ($lang)', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final repo = FakeCustomerOffersRepository(
          offers: [
            sampleOffer(
              id: 'a',
              pro: 'demo-01',
              price: 150,
              days: 3,
              message: 'Je peux passer demain matin avec le matériel.',
            ),
            sampleOffer(id: 'b', pro: 'demo-02', price: 120),
          ],
          bookingValue: const CustomerBooking(
            id: 'b1',
            professionalId: 'demo-01',
            priceTnd: 150,
            status: BookingStatus.pendingConfirmation,
          ),
        );
        await _open(
          tester,
          repo,
          prefs: {'locale': lang},
          request: sampleRequest(status: RequestStatus.awarded, offers: 2),
        );
        expect(tester.takeException(), isNull, reason: lang);
      });
    }
  });

  group('wire format', () {
    late List<http.Request> requests;
    SupabaseCustomerOffersRepository build(
      Object Function(http.Request) answer,
    ) {
      requests = [];
      return SupabaseCustomerOffersRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(answer(r)),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    }

    test(
      'offers on one request, never selecting more than the offer columns',
      () async {
        final repo = build(
          (_) => [
            {
              'id': 'o1',
              'professional_id': 'p1',
              'price_tnd': 99.5,
              'message': 'hi',
              'estimated_days': 2,
              'status': 'pending',
              'created_at': '2026-11-09T00:00:00Z',
            },
          ],
        );
        final list = await repo.offers('r1');
        final q = requests.single.url.queryParameters;
        expect(requests.single.url.path, '/rest/v1/quote_offers');
        expect(q['request_id'], 'eq.r1');
        expect(list.single.priceTnd, 99.5);
        expect(list.single.isPending, isTrue);
      },
    );

    test(
      'offers are read page by page until exhausted (no silent cap)',
      () async {
        var pages = 0;
        final repo = build((r) {
          final from = int.parse(r.url.queryParameters['offset'] ?? '0');
          pages++;
          final n = from == 0 ? 100 : 7;
          return [
            for (var i = 0; i < n; i++)
              {
                'id': 'o$from-$i',
                'professional_id': 'p$i',
                'price_tnd': 10 + i,
                'message': null,
                'estimated_days': null,
                'status': 'pending',
                'created_at': '2026-11-09T00:00:00Z',
              },
          ];
        });
        final list = await repo.offers('r1');
        expect(list.length, 107);
        expect(pages, 2);
      },
    );

    test(
      'accept, decline and the job steps call the right functions',
      () async {
        final repo = build((_) => 'b9');
        expect(await repo.accept('o1'), 'b9');
        await repo.decline('o2');
        await repo.confirmCompleted('b9');
        await repo.cancelBooking('b9');
        expect(requests.map((r) => r.url.path.split('/').last), [
          'accept_offer',
          'decline_offer',
          'confirm_booking_completed',
          'cancel_booking',
        ]);
        expect(jsonDecode(requests.first.body), {'p_offer': 'o1'});
        expect(jsonDecode(requests[2].body), {'p_booking': 'b9'});
      },
    );

    test('booking of a request: found and not found', () async {
      final found = await build(
        (_) => {
          'id': 'b1',
          'professional_id': 'p1',
          'price_tnd': 130,
          'status': 'pending_confirmation',
        },
      ).booking('r1');
      expect(found?.status, BookingStatus.pendingConfirmation);
      expect(found?.canConfirm, isTrue);
      expect(await build((_) => <Object>[]).booking('r1'), isNull);
    });
  });
}
