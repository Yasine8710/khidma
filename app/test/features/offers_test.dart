import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/offers/application/offers_providers.dart';
import 'package:khidma/features/offers/data/supabase_offers_repository.dart';
import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/professional/application/professional_providers.dart';
import 'package:khidma/features/professional/domain/professional_domain.dart';
import 'package:khidma/features/requests/application/requests_providers.dart';
import 'package:khidma/features/requests/data/supabase_requests_repository.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_offers.dart';
import '../support/fake_professional_repository.dart';
import '../support/fake_requests.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

const _published = ProfessionalDraft(
  businessName: 'Plomberie Ben Salah',
  categoryId: 1,
  description: 'Fuites, chauffe-eau et sanitaires. Intervention rapide.',
  governorateId: 11,
  phone: '+21620123456',
  isPublished: true,
);

Future<dynamic> _open(
  WidgetTester tester,
  FakeOffersRepository repo,
  String route, {
  ProfessionalDraft draft = _published,
  Map<String, Object> prefs = const {},
  FakeAuthRepository? auth,
}) async {
  final c = await pumpApp(
    tester,
    auth: auth ?? FakeAuthRepository(signedIn: _ali),
    prefs: prefs,
    overrides: [
      offersRepositoryProvider.overrideWithValue(repo),
      professionalRepositoryProvider.overrideWithValue(
        FakeProfessionalRepository(draft: draft),
      ),
      requestsRepositoryProvider.overrideWithValue(FakeRequestsRepository()),
    ],
  );
  c.read(routerProvider).push(route);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await _reveal(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );
  await _reveal(tester, field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  test('offer limits mirror the database', () {
    expect(OfferRules.priceOk(1), isTrue);
    expect(OfferRules.priceOk(0.99), isFalse);
    expect(OfferRules.priceOk(1000000), isTrue);
    expect(OfferRules.priceOk(1000001), isFalse);
    expect(OfferRules.priceOk(null), isFalse);
    expect(OfferRules.messageOk('a' * 1000), isTrue);
    expect(OfferRules.messageOk('a' * 1001), isFalse);
    expect(OfferRules.daysOk(null), isTrue);
    expect(OfferRules.daysOk(0), isFalse);
    expect(OfferRules.daysOk(365), isTrue);
    expect(OfferRules.daysOk(366), isFalse);
  });

  group('inbox', () {
    testWidgets(
      'lists open requests with my offer status; filters reach the repository',
      (tester) async {
        final repo = FakeOffersRepository(
          open: [
            sampleOpen(
              id: 'a',
              title: 'Fuite sous évier',
              offers: 2,
              budget: 150,
            ),
            sampleOpen(
              id: 'b',
              title: 'Prise cassée',
              categoryId: 2,
              mine: OfferStatus.pending,
            ),
            sampleOpen(id: 'c', title: 'Peinture', governorateId: 12),
          ],
        );
        await _open(tester, repo, AppRoutes.proInbox);
        // Starts in the professional's own governorate (11): the Ariana one is out.
        expect(find.text('Fuite sous évier'), findsOneWidget);
        expect(find.text('Prise cassée'), findsOneWidget);
        expect(find.text('Peinture'), findsNothing);
        expect(find.text('Votre offre : En attente'), findsOneWidget);
        expect(find.text('2 offres'), findsOneWidget);
        expect(repo.queries.last.governorateId, 11);

        await tester.tap(find.text('Dans mon gouvernorat'));
        await tester.pumpAndSettle();
        expect(find.text('Peinture'), findsOneWidget);
        expect(repo.queries.last.governorateId, isNull);

        await tester.tap(find.text('Électricité'));
        await tester.pumpAndSettle();
        expect(find.text('Prise cassée'), findsOneWidget);
        expect(find.text('Fuite sous évier'), findsNothing);
        expect(repo.queries.last.categoryId, 2);
      },
    );

    testWidgets('nothing shown says who asked', (tester) async {
      await _open(
        tester,
        FakeOffersRepository(open: [sampleOpen()]),
        AppRoutes.proInbox,
      );
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('empty state', (tester) async {
      await _open(tester, FakeOffersRepository(), AppRoutes.proInbox);
      expect(find.text('Aucune demande pour le moment'), findsOneWidget);
    });

    testWidgets(
      'an unpublished professional is asked to publish first, nothing is loaded',
      (tester) async {
        final repo = FakeOffersRepository(open: [sampleOpen()]);
        await _open(
          tester,
          repo,
          AppRoutes.proInbox,
          draft: const ProfessionalDraft(businessName: 'X'),
        );
        expect(
          find.text(
            'Publiez votre profil pour voir les demandes et envoyer des offres.',
          ),
          findsOneWidget,
        );
        expect(repo.queries, isEmpty);
      },
    );

    testWidgets('pages load on demand', (tester) async {
      final repo = FakeOffersRepository(
        open: [
          for (var i = 0; i < 25; i++)
            sampleOpen(
              id: 'r$i',
              title: 'Demande ${i.toString().padLeft(2, '0')}',
            ),
        ],
      );
      await _open(tester, repo, AppRoutes.proInbox);
      await tester.scrollUntilVisible(
        find.text('Voir plus'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();
      expect(repo.queries.map((q) => q.offset).toSet(), {0, 20});
      await tester.scrollUntilVisible(
        find.text('Demande 24'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Voir plus'), findsNothing);
    });
  });

  group('offer on a request', () {
    testWidgets('sends the typed price, message and days', (tester) async {
      final repo = FakeOffersRepository(open: [sampleOpen(offers: 1)]);
      await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
      expect(find.text('1 offre déjà reçue'), findsOneWidget);
      await _enter(tester, 'Prix en TND', '120,5');
      await _enter(
        tester,
        'Message au client (facultatif)',
        '  Je passe demain  ',
      );
      await _enter(tester, 'Délai estimé en jours (facultatif)', '3');
      await _tap(tester, 'Envoyer l’offre');
      final (id, offer) = repo.submitted.single;
      expect(id, 'o-req');
      expect(offer.priceTnd, 120.5);
      expect(offer.estimatedDays, 3);
      expect(offer.message?.trim(), 'Je passe demain');
      expect(find.text('Offre envoyée.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('invalid price, message and days are refused before sending', (
      tester,
    ) async {
      final repo = FakeOffersRepository(open: [sampleOpen()]);
      await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
      await _tap(tester, 'Envoyer l’offre');
      expect(find.text('Entre 1 et 1 000 000 TND.'), findsOneWidget);
      await _enter(tester, 'Prix en TND', '0,5');
      await _tap(tester, 'Envoyer l’offre');
      expect(find.text('Entre 1 et 1 000 000 TND.'), findsOneWidget);
      await _enter(tester, 'Prix en TND', '100');
      await _enter(tester, 'Délai estimé en jours (facultatif)', '400');
      await _tap(tester, 'Envoyer l’offre');
      expect(find.text('Entre 1 et 365 jours.'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    testWidgets('a pending offer is prefilled, can be updated and withdrawn', (
      tester,
    ) async {
      final repo = FakeOffersRepository(
        open: [sampleOpen(offers: 2, mine: OfferStatus.pending)],
        offers: [
          MyOffer(
            id: 'o9',
            requestId: 'o-req',
            requestTitle: 'Fuite sous évier',
            priceTnd: 100,
            status: OfferStatus.pending,
            createdAt: DateTime(2026, 11, 9),
            message: 'Premier prix',
            estimatedDays: 2,
          ),
        ],
      );
      await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
      expect(find.text('Votre offre : En attente'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Premier prix'), findsOneWidget);
      expect(
        find.text('1 offre déjà reçue'),
        findsOneWidget,
        reason: 'mine is not counted as "other"',
      );
      await _enter(tester, 'Prix en TND', '90');
      await _tap(tester, 'Mettre à jour l’offre');
      expect(repo.submitted.single.$2.priceTnd, 90);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tap(tester, 'Retirer mon offre');
      expect(repo.withdrawn.length, 1);
      expect(find.text('Offre retirée.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets(
      'a declined offer cannot be changed; an accepted one points to the job',
      (tester) async {
        final declined = FakeOffersRepository(
          open: [sampleOpen(mine: OfferStatus.declined)],
        );
        await _open(tester, declined, AppRoutes.proRequestPath('o-req'));
        expect(
          find.text('Le client n’a pas retenu votre offre.'),
          findsOneWidget,
        );
        expect(find.text('Envoyer l’offre'), findsNothing);
      },
    );

    testWidgets('an accepted offer is not editable', (tester) async {
      final repo = FakeOffersRepository(
        open: [sampleOpen(mine: OfferStatus.accepted)],
      );
      await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
      expect(
        find.text(
          'Votre offre est acceptée : suivez le chantier dans Mes chantiers.',
        ),
        findsOneWidget,
      );
      expect(find.text('Envoyer l’offre'), findsNothing);
    });

    testWidgets('failures are explained and the form keeps its values', (
      tester,
    ) async {
      final repo = FakeOffersRepository(open: [sampleOpen()]);
      await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
      await _enter(tester, 'Prix en TND', '100');
      final cases = {
        RequestsFailure.notOpen: 'Cette demande n’est plus ouverte.',
        RequestsFailure.ownRequest:
            'Vous ne pouvez pas répondre à votre propre demande.',
        RequestsFailure.offerClosed: 'Cette offre ne peut plus être modifiée.',
        RequestsFailure.limitReached: 'Vous avez 50 offres en attente. Retirez-en une avant d’en envoyer une autre.',
        RequestsFailure.network:
            'Connexion impossible. Votre saisie est conservée, réessayez.',
      };
      for (final e in cases.entries) {
        repo.failNext = e.key;
        await _tap(tester, 'Envoyer l’offre');
        await _reveal(tester, find.text(e.value));
        expect(find.text(e.value), findsOneWidget, reason: '${e.key}');
        expect(find.text('100'), findsOneWidget);
      }
    });

    testWidgets(
      'the offer limit says to withdraw an offer, not to cancel requests',
      (tester) async {
        final repo = FakeOffersRepository(open: [sampleOpen()]);
        await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
        await _enter(tester, 'Prix en TND', '100');
        repo.failNext = RequestsFailure.limitReached;
        await _tap(tester, 'Envoyer l’offre');
        await _reveal(
          tester,
          find.text(
            'Vous avez 50 offres en attente. Retirez-en une avant d’en envoyer une autre.',
          ),
        );
        expect(find.textContaining('demandes ouvertes'), findsNothing);
      },
    );

    testWidgets(
      'the form waits for the existing offer, so nothing typed is overwritten later',
      (tester) async {
        final repo = FakeOffersRepository(
          open: [sampleOpen(mine: OfferStatus.pending)],
          offers: [
            MyOffer(
              id: 'o9',
              requestId: 'o-req',
              requestTitle: 'Fuite',
              priceTnd: 100,
              status: OfferStatus.pending,
              createdAt: DateTime(2026, 11, 9),
              message: 'Avant',
            ),
          ],
        )..offersDelay = const Duration(seconds: 1);
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [
            offersRepositoryProvider.overrideWithValue(repo),
            professionalRepositoryProvider.overrideWithValue(
              FakeProfessionalRepository(draft: _published),
            ),
          ],
        );
        c.read(routerProvider).push(AppRoutes.proRequestPath('o-req'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text('Prix en TND'),
          findsNothing,
          reason: 'no editable form while the offer loads',
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Prix en TND'), findsOneWidget);
        expect(find.text('Avant'), findsOneWidget);
      },
    );

    testWidgets('a double tap sends once', (tester) async {
      final repo = FakeOffersRepository(open: [sampleOpen()]);
      await _open(tester, repo, AppRoutes.proRequestPath('o-req'));
      await _enter(tester, 'Prix en TND', '100');
      final gate = repo.gate = Completer<void>();
      final send = find.text('Envoyer l’offre');
      await _reveal(tester, send);
      await tester.tap(send);
      await tester.pump();
      await tester.tap(send, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.submitted.length, 1);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('a request that is gone says so', (tester) async {
      await _open(
        tester,
        FakeOffersRepository(),
        AppRoutes.proRequestPath('nope'),
      );
      expect(find.text('Demande introuvable.'), findsOneWidget);
    });
  });

  group('my offers and jobs', () {
    testWidgets('my offers: status, price, tap opens the request', (
      tester,
    ) async {
      final repo = FakeOffersRepository(
        open: [sampleOpen(id: 'r1', mine: OfferStatus.accepted)],
        offers: [
          MyOffer(
            id: 'o1',
            requestId: 'r1',
            requestTitle: 'Fuite sous évier',
            priceTnd: 130,
            status: OfferStatus.accepted,
            createdAt: DateTime(2026, 11, 9),
          ),
          MyOffer(
            id: 'o2',
            requestId: 'r2',
            requestTitle: 'Peinture salon',
            priceTnd: 800,
            status: OfferStatus.declined,
            createdAt: DateTime(2026, 11, 8),
          ),
        ],
      );
      await _open(tester, repo, AppRoutes.proOffers);
      expect(find.text('Acceptée'), findsOneWidget);
      expect(find.text('Refusée'), findsOneWidget);
      expect(find.textContaining('130'), findsOneWidget);
      await tester.tap(find.text('Fuite sous évier'));
      await tester.pumpAndSettle();
      expect(find.text('Demande'), findsOneWidget);
    });

    testWidgets('my offers: empty state', (tester) async {
      await _open(tester, FakeOffersRepository(), AppRoutes.proOffers);
      expect(
        find.text('Vous n’avez pas encore envoyé d’offre.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a job moves scheduled -> in progress -> waiting for the customer; no completion by the pro',
      (tester) async {
        final repo = FakeOffersRepository(jobs: [sampleJob()]);
        await _open(tester, repo, AppRoutes.proJobs);
        expect(find.text('Planifié'), findsOneWidget);
        expect(find.text('Marquer comme terminé'), findsNothing);
        await tester.tap(find.text('Démarrer'));
        await tester.pumpAndSettle();
        expect(find.text('En cours'), findsOneWidget);
        await tester.tap(find.text('Marquer comme terminé'));
        await tester.pumpAndSettle();
        expect(
          find.text('En attente de confirmation du client'),
          findsOneWidget,
        );
        expect(repo.steps, ['start:j1', 'done:j1']);
        expect(find.text('Démarrer'), findsNothing);
        expect(
          find.text('Annuler le chantier'),
          findsNothing,
          reason: 'no cancel once waiting for confirmation',
        );
      },
    );

    testWidgets('cancelling a job asks first', (tester) async {
      final repo = FakeOffersRepository(jobs: [sampleJob()]);
      await _open(tester, repo, AppRoutes.proJobs);
      await tester.tap(find.text('Annuler le chantier'));
      await tester.pumpAndSettle();
      expect(find.text('Annuler ce chantier ?'), findsOneWidget);
      await tester.tap(find.text('Garder le chantier'));
      await tester.pumpAndSettle();
      expect(repo.steps, isEmpty);
      await tester.tap(find.text('Annuler le chantier'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Annuler le chantier'));
      await tester.pumpAndSettle();
      expect(repo.steps, ['cancel:j1']);
      expect(find.text('Annulé'), findsOneWidget);
    });

    testWidgets('a step refused by the server is explained', (tester) async {
      final repo = FakeOffersRepository(jobs: [sampleJob()]);
      await _open(tester, repo, AppRoutes.proJobs);
      repo.failNext = RequestsFailure.invalidTransition;
      await tester.tap(find.text('Démarrer'));
      await tester.pumpAndSettle();
      expect(find.text('Cette étape n’est plus possible.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('finished and cancelled jobs have no actions', (tester) async {
      final repo = FakeOffersRepository(
        jobs: [
          sampleJob(id: 'a', status: BookingStatus.completed),
          sampleJob(id: 'b', status: BookingStatus.cancelled),
        ],
      );
      await _open(tester, repo, AppRoutes.proJobs);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('Annulé'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Démarrer'), findsNothing);
    });

    testWidgets(
      'signing out clears the lists (no leftovers for the next account)',
      (tester) async {
        final auth = FakeAuthRepository(signedIn: _ali);
        final repo = FakeOffersRepository(jobs: [sampleJob()]);
        await _open(tester, repo, AppRoutes.proJobs, auth: auth);
        expect(find.text('Chauffe-eau en panne'), findsOneWidget);
        auth.emit(null);
        await tester.pumpAndSettle();
        expect(find.text('Chauffe-eau en panne'), findsNothing);
      },
    );

    testWidgets('the dashboard links to all three', (tester) async {
      final c = await _open(
        tester,
        FakeOffersRepository(),
        AppRoutes.proDashboard,
      );
      expect(find.text('Demandes ouvertes'), findsOneWidget);
      expect(find.text('Mes offres'), findsOneWidget);
      expect(find.text('Mes chantiers'), findsOneWidget);
      expect(c, isNotNull);
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
        final repo = FakeOffersRepository(
          open: [sampleOpen(mine: OfferStatus.pending, offers: 3, budget: 150)],
          jobs: [sampleJob()],
          offers: [
            MyOffer(
              id: 'o1',
              requestId: 'o-req',
              requestTitle: 'Fuite sous évier',
              priceTnd: 130,
              status: OfferStatus.pending,
              createdAt: DateTime(2026, 11, 9),
            ),
          ],
        );
        final c = await _open(
          tester,
          repo,
          AppRoutes.proInbox,
          prefs: {'locale': lang},
        );
        expect(tester.takeException(), isNull, reason: '$lang inbox');
        for (final r in [
          AppRoutes.proRequestPath('o-req'),
          AppRoutes.proOffers,
          AppRoutes.proJobs,
        ]) {
          c.read(routerProvider).pushReplacement(r);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$lang $r');
        }
      });
    }
  });

  group('wire format', () {
    late List<http.Request> requests;
    SupabaseOffersRepository build({
      String? uid = 'u1',
      Object Function(http.Request)? answer,
    }) {
      requests = [];
      return SupabaseOffersRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode((answer ?? (_) => <Object>[])(r)),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        userId: () => uid,
      );
    }

    final openRow = {
      'id': 'a',
      'title': 'T',
      'description': 'D',
      'category_id': 1,
      'governorate_id': 11,
      'city_id': null,
      'budget_tnd': 99.5,
      'needed_by': null,
      'created_at': '2026-11-09T00:00:00Z',
      'expires_at': '2026-11-23T00:00:00Z',
      'offers_count': 4,
      'my_offer_status': 'pending',
    };

    test('open requests: the function with filters and a page size', () async {
      final repo = build(answer: (_) => [openRow]);
      final list = await repo.openRequests(
        categoryId: 1,
        governorateId: 11,
        offset: 20,
      );
      expect(requests.single.url.path, '/rest/v1/rpc/list_open_requests');
      expect(jsonDecode(requests.single.body), {
        'p_category': 1,
        'p_governorate': 11,
        'p_limit': 20,
        'p_offset': 20,
      });
      expect(list.single.offersCount, 4);
      expect(list.single.myOfferStatus, OfferStatus.pending);
      expect(list.single.budgetTnd, 99.5);
    });

    test('one open request: found and not found', () async {
      expect((await build(answer: (_) => [openRow]).openRequest('a'))?.id, 'a');
      expect(await build().openRequest('zzz'), isNull);
    });

    test('submit sends the offer trimmed; blank message means none', () async {
      final repo = build(answer: (_) => 'offer-1');
      expect(
        await repo.submitOffer(
          'r1',
          const OfferInput(
            priceTnd: 80,
            message: '  hello  ',
            estimatedDays: 2,
          ),
        ),
        'offer-1',
      );
      expect(jsonDecode(requests.single.body), {
        'p_request': 'r1',
        'p_price': 80.0,
        'p_message': 'hello',
        'p_days': 2,
      });
      await repo.submitOffer(
        'r1',
        const OfferInput(priceTnd: 80, message: '   '),
      );
      expect(jsonDecode(requests.last.body)['p_message'], isNull);
    });

    test('withdraw and the job steps call the right functions', () async {
      final repo = build();
      await repo.withdrawOffer('o1');
      await repo.startJob('b1');
      await repo.markJobDone('b1');
      await repo.cancelJob('b1');
      expect(requests.map((r) => r.url.path.split('/').last), [
        'withdraw_offer',
        'start_booking',
        'mark_booking_done',
        'cancel_booking',
      ]);
      expect(jsonDecode(requests.first.body), {'p_offer': 'o1'});
      expect(jsonDecode(requests[1].body), {'p_booking': 'b1'});
    });

    test('my offers and jobs are filtered to the caller and never cut off actionable records', () async {
      final offerRow = {
        'id': 'o1',
        'request_id': 'r1',
        'price_tnd': 10,
        'message': null,
        'estimated_days': null,
        'status': 'declined',
        'created_at': '2026-11-09T00:00:00Z',
        'quote_requests': {'title': 'Titre'},
      };
      final jobRow = {
        'id': 'b1',
        'request_id': 'r1',
        'price_tnd': 20,
        'status': 'in_progress',
        'created_at': '2026-11-09T00:00:00Z',
        'quote_requests': {'title': 'Titre'},
      };
      final repo = build(
        answer: (r) =>
            r.url.path.endsWith('quote_offers') ? [offerRow] : [jobRow],
      );
      final offers = await repo.myOffers();
      final jobs = await repo.myJobs();
      expect(
        requests.every(
          (r) => r.url.queryParameters['professional_id'] == 'eq.u1',
        ),
        isTrue,
      );
      // pending ones are fetched on their own, then the recent others
      expect(requests[0].url.queryParameters['status'], 'eq.pending');
      expect(requests[1].url.queryParameters['status'], 'neq.pending');
      expect(requests[2].url.queryParameters['status'], contains('scheduled'));
      expect(requests[3].url.queryParameters['status'], contains('completed'));
      expect(
        requests[2].url.queryParameters.containsKey('limit'),
        isFalse,
        reason: 'active jobs are never limited',
      );
      expect(offers.length, 2);
      expect(offers.first.requestTitle, 'Titre');
      expect(jobs.first.status, BookingStatus.inProgress);
      expect(
        requests[0].url.queryParameters['select'],
        isNot(contains('customer_id')),
      );
    });

    test('one offer is fetched directly by request', () async {
      final repo = build(
        answer: (_) => {
          'id': 'o1',
          'request_id': 'r1',
          'price_tnd': 10,
          'message': 'x',
          'estimated_days': 2,
          'status': 'pending',
          'created_at': '2026-11-09T00:00:00Z',
          'quote_requests': {'title': 'T'},
        },
      );
      final o = await repo.myOfferFor('r1');
      expect(o?.status, OfferStatus.pending);
      expect(requests.single.url.queryParameters['request_id'], 'eq.r1');
      expect(requests.single.url.queryParameters['professional_id'], 'eq.u1');
    });

    test('no session: nothing is sent for the filtered lists', () async {
      final repo = build(uid: null);
      await expectLater(repo.myOffers(), throwsA(isA<RequestsError>()));
      await expectLater(repo.myJobs(), throwsA(isA<RequestsError>()));
      expect(requests, isEmpty);
    });

    test('database tags map to categories', () {
      RequestsFailure f(String m) => mapRequestsException(
        sb.PostgrestException(message: m, code: 'P0001'),
      );
      expect(f('own_request'), RequestsFailure.ownRequest);
      expect(f('offer_closed'), RequestsFailure.offerClosed);
      expect(f('invalid_transition'), RequestsFailure.invalidTransition);
    });
  });

  test(
    'providers: a container reading offers for a signed-out user gets nothing',
    () async {
      final c = ProviderContainer(
        overrides: [
          offersRepositoryProvider.overrideWithValue(
            FakeOffersRepository(jobs: [sampleJob()]),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(myJobsProvider, (_, _) {});
      expect(await c.read(myJobsProvider.future), isEmpty);
    },
  );
}
