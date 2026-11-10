import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/marketplace/application/home_providers.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/requests/application/requests_providers.dart';
import 'package:khidma/features/requests/data/supabase_requests_repository.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_portfolio.dart';
import '../support/fake_requests.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

PreparedPhoto _photo([int n = 50]) =>
    PreparedPhoto(bytes: Uint8List(n), width: 10, height: 10);

Future<dynamic> _open(
  WidgetTester tester,
  FakeRequestsRepository repo, {
  FakePhotoPicker? picker,
  String route = '/requests',
  Map<String, Object> prefs = const {},
  bool signedIn = true,
}) async {
  final c = await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: signedIn ? _ali : null),
    prefs: prefs,
    overrides: [
      requestsRepositoryProvider.overrideWithValue(repo),
      photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      photoPreparerProvider.overrideWithValue((b) async => _photo(b.length)),
    ],
  );
  if (route == '/requests') {
    c.read(routerProvider).go(AppRoutes.requests);
  } else {
    c.read(routerProvider).push(route);
  }
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

Future<void> _pickGovernorate(WidgetTester tester, String name) async {
  final dd = find.byType(DropdownButtonFormField<int>);
  await _reveal(tester, dd);
  await tester.tap(dd);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _fillRequired(WidgetTester tester) async {
  await _tap(tester, 'Plomberie');
  await _enter(tester, 'Titre', '  Fuite sous évier ');
  await _enter(
    tester,
    'Décrivez le problème',
    'Une fuite sous le lavabo de la cuisine.',
  );
  await _pickGovernorate(tester, 'Tunis');
}

void main() {
  setUpAll(loadAppFonts);

  group('request rules', () {
    test('limits mirror the database', () {
      expect(RequestRules.titleOk('abc'), isTrue);
      expect(RequestRules.titleOk('ab'), isFalse);
      expect(RequestRules.titleOk('  ab  '), isFalse, reason: 'trimmed');
      expect(RequestRules.titleOk('a' * 120), isTrue);
      expect(RequestRules.titleOk('a' * 121), isFalse);
      expect(RequestRules.descriptionOk('a' * 10), isTrue);
      expect(RequestRules.descriptionOk('a' * 9), isFalse);
      expect(RequestRules.descriptionOk('a' * 2001), isFalse);
      expect(RequestRules.budgetOk(null), isTrue);
      expect(RequestRules.budgetOk(0), isTrue);
      expect(RequestRules.budgetOk(1000000), isTrue);
      expect(RequestRules.budgetOk(1000001), isFalse);
      expect(RequestRules.budgetOk(-1), isFalse);
    });
  });

  group('my requests', () {
    testWidgets('signed out: an invitation, nothing loaded', (tester) async {
      await _open(tester, FakeRequestsRepository(), signedIn: false);
      expect(
        find.text('Connectez-vous pour voir vos demandes'),
        findsOneWidget,
      );
      expect(find.text('Nouvelle demande'), findsNothing);
    });

    testWidgets('empty: says so and offers to ask for a quote', (tester) async {
      await _open(tester, FakeRequestsRepository());
      expect(find.text("Aucune demande pour l'instant"), findsOneWidget);
      await tester.tap(find.text('Demander un devis'));
      await tester.pumpAndSettle();
      expect(find.text('Décrivez le problème'), findsOneWidget);
    });

    testWidgets('statuses, offer counts and a tap to the detail', (
      tester,
    ) async {
      final repo = FakeRequestsRepository([
        sampleRequest(id: 'a', title: 'Fuite sous évier', offers: 3),
        sampleRequest(
          id: 'b',
          title: 'Prise cassée',
          status: RequestStatus.awarded,
          offers: 1,
        ),
        sampleRequest(
          id: 'c',
          title: 'Peinture salon',
          status: RequestStatus.cancelled,
        ),
        sampleRequest(id: 'd', title: 'Clim', status: RequestStatus.expired),
      ]);
      await _open(tester, repo);
      expect(find.text('Ouverte'), findsOneWidget);
      expect(find.text('Attribuée'), findsOneWidget);
      expect(find.text('Annulée'), findsOneWidget);
      expect(find.text('Expirée'), findsOneWidget);
      expect(find.text('3 offres'), findsOneWidget);
      expect(find.text('1 offre'), findsOneWidget);
      expect(find.text('Aucune offre'), findsNWidgets(2));
      await tester.tap(find.text('Fuite sous évier'));
      await tester.pumpAndSettle();
      expect(find.text('Demande'), findsOneWidget);
      expect(find.text('Annuler la demande'), findsOneWidget);
    });
  });

  group('new request', () {
    testWidgets(
      'sends exactly what was typed, trimmed, and opens the request',
      (tester) async {
        final repo = FakeRequestsRepository();
        await _open(tester, repo, route: AppRoutes.newRequest);
        await _fillRequired(tester);
        await _enter(tester, 'Budget indicatif en TND (facultatif)', '150,5');
        await _tap(tester, 'Envoyer la demande');
        final (req, photos) = repo.created.single;
        expect(
          req.title.trim(),
          'Fuite sous évier',
          reason: 'the repository trims',
        );
        expect(req.categoryId, 1);
        expect(req.budgetTnd, 150.5);
        expect(req.cityId, isNull);
        expect(photos, isEmpty);
        expect(find.text('Demande'), findsOneWidget, reason: 'detail screen');
        expect(find.text('Fuite sous évier'), findsWidgets);
      },
    );

    testWidgets('each required field is checked before anything is sent', (
      tester,
    ) async {
      final repo = FakeRequestsRepository();
      await _open(tester, repo, route: AppRoutes.newRequest);
      await _tap(tester, 'Envoyer la demande');
      expect(find.text('Choisissez un type de service.'), findsOneWidget);
      expect(find.text('Entre 3 et 120 caractères.'), findsOneWidget);
      expect(find.text('Entre 10 et 2000 caractères.'), findsOneWidget);
      expect(find.text('Choisissez un gouvernorat.'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('an invalid budget is refused', (tester) async {
      final repo = FakeRequestsRepository();
      await _open(tester, repo, route: AppRoutes.newRequest);
      await _fillRequired(tester);
      await _enter(tester, 'Budget indicatif en TND (facultatif)', '2000000');
      await _tap(tester, 'Envoyer la demande');
      expect(find.text('Montant invalide (0 à 1 000 000).'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    for (final bad in ['1..2', '1.2.3', '.,']) {
      testWidgets('budget "$bad" is refused, not silently dropped', (
        tester,
      ) async {
        final repo = FakeRequestsRepository();
        await _open(tester, repo, route: AppRoutes.newRequest);
        await _fillRequired(tester);
        await _enter(tester, 'Budget indicatif en TND (facultatif)', bad);
        await _tap(tester, 'Envoyer la demande');
        expect(repo.created, isEmpty);
      });
    }

    testWidgets('the area chosen on Home is the starting point', (
      tester,
    ) async {
      final repo = FakeRequestsRepository();
      final c = await _open(
        tester,
        repo,
        prefs: {'place': '{"gov":11,"city":null}'},
      );
      expect(c.read(selectedPlaceProvider)?.governorateId, 11);
      c.read(routerProvider).push(AppRoutes.newRequest);
      await tester.pumpAndSettle();
      await _tap(tester, 'Plomberie');
      await _enter(tester, 'Titre', 'Fuite');
      await _enter(tester, 'Décrivez le problème', 'Une fuite sous le lavabo.');
      await _tap(tester, 'Envoyer la demande');
      expect(
        repo.created.single.$1.governorateId,
        11,
        reason: 'no need to pick again',
      );
    });

    testWidgets('a failed send keeps everything typed and explains why', (
      tester,
    ) async {
      final cases = {
        RequestsFailure.network:
            'Connexion impossible. Votre saisie est conservée, réessayez.',
        RequestsFailure.rateLimited:
            'Trop de demandes en peu de temps. Réessayez dans une heure.',
        RequestsFailure.limitReached: 'Vous avez déjà 10 demandes ouvertes. Annulez-en une avant d’en créer une autre.',
        RequestsFailure.invalidInput:
            'Certaines informations sont refusées. Vérifiez-les.',
      };
      final repo = FakeRequestsRepository();
      await _open(tester, repo, route: AppRoutes.newRequest);
      await _fillRequired(tester);
      for (final e in cases.entries) {
        repo.failNext = e.key;
        await _tap(tester, 'Envoyer la demande');
        await _reveal(tester, find.text(e.value));
        expect(find.text(e.value), findsOneWidget, reason: '${e.key}');
        expect(
          find.text('  Fuite sous évier '),
          findsOneWidget,
          reason: 'title kept',
        );
      }
      await _tap(tester, 'Envoyer la demande');
      expect(find.text('Demande'), findsOneWidget);
    });

    testWidgets('a double tap sends once', (tester) async {
      final repo = FakeRequestsRepository();
      await _open(tester, repo, route: AppRoutes.newRequest);
      await _fillRequired(tester);
      final gate = repo.gate = Completer<void>();
      final send = find.text('Envoyer la demande');
      await _reveal(tester, send);
      await tester.tap(send);
      await tester.pump();
      await tester.tap(send, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.created.length, 1);
    });

    testWidgets(
      'photos: added, removed, capped at 5, passed to the repository',
      (tester) async {
        final repo = FakeRequestsRepository();
        final picker = FakePhotoPicker(Uint8List.fromList([1, 2, 3]));
        await _open(tester, repo, picker: picker, route: AppRoutes.newRequest);
        await _fillRequired(tester);
        for (var i = 0; i < 5; i++) {
          await _tap(tester, 'Ajouter une photo');
        }
        expect(find.text('5 sur 5 photos'), findsOneWidget);
        final add = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Ajouter une photo'),
            matching: find.bySubtype<OutlinedButton>(),
          ),
        );
        expect(add.onPressed, isNull, reason: 'cap reached');
        await _tap(
          tester,
          'Retirer la photo 2'.isEmpty ? '' : 'Envoyer la demande',
        );
        expect(repo.created.single.$2.length, 5);
      },
    );

    testWidgets('removing a photo before sending', (tester) async {
      final repo = FakeRequestsRepository();
      final picker = FakePhotoPicker(Uint8List.fromList([1, 2, 3]));
      await _open(tester, repo, picker: picker, route: AppRoutes.newRequest);
      await _fillRequired(tester);
      await _tap(tester, 'Ajouter une photo');
      await _tap(tester, 'Ajouter une photo');
      expect(find.text('2 sur 5 photos'), findsOneWidget);
      final remove = find.byTooltip('Retirer la photo 1');
      await _reveal(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('1 sur 5 photos'), findsOneWidget);
      await _tap(tester, 'Envoyer la demande');
      expect(repo.created.single.$2.length, 1);
    });

    testWidgets(
      'some photos failing does not undo the request; the person is told',
      (tester) async {
        final repo = FakeRequestsRepository()..failedPhotos = 1;
        final picker = FakePhotoPicker(Uint8List.fromList([1]));
        await _open(tester, repo, picker: picker, route: AppRoutes.newRequest);
        await _fillRequired(tester);
        await _tap(tester, 'Ajouter une photo');
        await _tap(tester, 'Envoyer la demande');
        expect(
          find.text(
            'Demande envoyée, mais certaines photos n’ont pas pu être ajoutées.',
          ),
          findsOneWidget,
        );
        expect(repo.requests.length, 1);
      },
    );

    testWidgets('a photo that cannot be used is explained, nothing added', (
      tester,
    ) async {
      final repo = FakeRequestsRepository();
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          requestsRepositoryProvider.overrideWithValue(repo),
          photoPickerProvider.overrideWithValue(
            FakePhotoPicker(Uint8List.fromList([1])),
          ),
          photoPreparerProvider.overrideWithValue(
            (_) async =>
                throw const PortfolioError(PortfolioFailure.notAnImage),
          ),
        ],
      );
      c.read(routerProvider).push(AppRoutes.newRequest);
      await tester.pumpAndSettle();
      await _tap(tester, 'Ajouter une photo');
      expect(
        find.text(
          'Ce fichier n’est pas une photo lisible (JPEG, PNG ou WebP).',
        ),
        findsOneWidget,
      );
      expect(find.text('0 sur 5 photos'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
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
        final repo = FakeRequestsRepository([sampleRequest(offers: 2)]);
        await _open(tester, repo, prefs: {'locale': lang});
        expect(tester.takeException(), isNull, reason: '$lang list');
        final c = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        );
        c.read(routerProvider).push(AppRoutes.newRequest);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang form');
        c
            .read(routerProvider)
            .pushReplacement(AppRoutes.requestPath('r-sample'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang detail');
      });
    }
  });

  group('request detail', () {
    testWidgets('an open request can be cancelled after confirming', (
      tester,
    ) async {
      final repo = FakeRequestsRepository([
        sampleRequest(budget: 200, neededBy: DateTime(2026, 12, 1)),
      ]);
      await _open(tester, repo, route: AppRoutes.requestPath('r-sample'));
      expect(find.textContaining('Budget indicatif'), findsOneWidget);
      await _tap(tester, 'Annuler la demande');
      expect(find.text('Annuler cette demande ?'), findsOneWidget);
      await tester.tap(find.text('Garder la demande'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isEmpty);
      await _tap(tester, 'Annuler la demande');
      await tester.tap(find.widgetWithText(TextButton, 'Annuler la demande'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, ['r-sample']);
      expect(find.text('Demande annulée.'), findsOneWidget);
      expect(find.text('Annulée'), findsOneWidget);
      expect(
        find.text('Annuler la demande'),
        findsNothing,
        reason: 'no cancel once cancelled',
      );
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    for (final status in [
      RequestStatus.awarded,
      RequestStatus.cancelled,
      RequestStatus.expired,
    ]) {
      testWidgets('a $status request offers no cancel', (tester) async {
        final repo = FakeRequestsRepository([sampleRequest(status: status)]);
        await _open(tester, repo, route: AppRoutes.requestPath('r-sample'));
        expect(find.text('Annuler la demande'), findsNothing);
      });
    }

    testWidgets('cancelling a request that just closed says so', (
      tester,
    ) async {
      final repo = FakeRequestsRepository([sampleRequest()])
        ..failCancel = RequestsFailure.notOpen;
      await _open(tester, repo, route: AppRoutes.requestPath('r-sample'));
      await _tap(tester, 'Annuler la demande');
      await tester.tap(find.widgetWithText(TextButton, 'Annuler la demande'));
      await tester.pumpAndSettle();
      expect(find.text('Cette demande n’est plus ouverte.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('photos are shown with accessible labels', (tester) async {
      final repo = FakeRequestsRepository([sampleRequest()]);
      repo.photosByRequest['r-sample'] = const [
        RequestPhoto(
          id: 'p1',
          path: 'u/1.jpg',
          url: 'https://example.invalid/1.jpg',
        ),
        RequestPhoto(
          id: 'p2',
          path: 'u/2.jpg',
          url: 'https://example.invalid/2.jpg',
        ),
      ];
      await _open(tester, repo, route: AppRoutes.requestPath('r-sample'));
      expect(find.bySemanticsLabel('Photo 1 sur 2'), findsWidgets);
    });

    testWidgets('photos that fail to load say so and can be retried', (
      tester,
    ) async {
      final repo = FakeRequestsRepository([sampleRequest()])..failPhotos = true;
      repo.photosByRequest['r-sample'] = const [
        RequestPhoto(
          id: 'p1',
          path: 'u/1.jpg',
          url: 'https://example.invalid/1.jpg',
        ),
      ];
      await _open(tester, repo, route: AppRoutes.requestPath('r-sample'));
      expect(find.text('Impossible de charger les photos.'), findsOneWidget);
      repo.failPhotos = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger les photos.'), findsNothing);
      expect(find.bySemanticsLabel('Photo 1 sur 1'), findsWidgets);
    });

    testWidgets(
      'signing out clears an open request detail (no leftovers for the next account)',
      (tester) async {
        final auth = FakeAuthRepository(signedIn: _ali);
        final repo = FakeRequestsRepository([sampleRequest()]);
        repo.photosByRequest['r-sample'] = const [
          RequestPhoto(
            id: 'p1',
            path: 'u/1.jpg',
            url: 'https://example.invalid/1.jpg',
          ),
        ];
        final c = await pumpApp(
          tester,
          auth: auth,
          overrides: [requestsRepositoryProvider.overrideWithValue(repo)],
        );
        c.read(routerProvider).push(AppRoutes.requestPath('r-sample'));
        await tester.pumpAndSettle();
        expect(find.text('Fuite sous évier'), findsWidgets);
        auth.emit(null);
        await tester.pumpAndSettle();
        expect(find.text('Demande introuvable.'), findsOneWidget);
        expect(find.text('Fuite sous évier'), findsNothing);
      },
    );

    testWidgets('an unknown request says so', (tester) async {
      await _open(
        tester,
        FakeRequestsRepository(),
        route: AppRoutes.requestPath('nope'),
      );
      expect(find.text('Demande introuvable.'), findsOneWidget);
    });
  });

  group('wire format', () {
    late List<http.BaseRequest> requests;
    SupabaseRequestsRepository build({
      String? uid = 'u1',
      Object Function(http.BaseRequest)? answer,
    }) {
      requests = [];
      return SupabaseRequestsRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, body) async {
            requests.add(request);
            await body.drain<void>();
            final r = (answer ?? (_) => <Object>[])(request);
            if (r is http.StreamedResponse) return r;
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(r))),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
        userId: () => uid,
      );
    }

    final input = NewRequest(
      title: '  Fuite  ',
      description: '  Une fuite sous le lavabo.  ',
      categoryId: 1,
      governorateId: 11,
      budgetTnd: 99.5,
      neededBy: DateTime(2026, 12, 5),
    );

    test(
      'create calls the function with trimmed text and an ISO date',
      () async {
        final repo = build(answer: (r) => 'new-id');
        final created = await repo.create(input, const []);
        expect(created.id, 'new-id');
        expect(created.failedPhotos, 0);
        final r = requests.single as http.Request;
        expect(r.url.path, '/rest/v1/rpc/create_quote_request');
        expect(jsonDecode(r.body), {
          'p_title': 'Fuite',
          'p_description': 'Une fuite sous le lavabo.',
          'p_category': 1,
          'p_governorate': 11,
          'p_city': null,
          'p_budget': 99.5,
          'p_needed_by': '2026-12-05',
        });
      },
    );

    test('photos are uploaded to the private bucket in the own folder, then attached', () async {
      final repo = build(
        answer: (r) => r.url.path.endsWith('create_quote_request')
            ? 'new-id'
            : r.url.path.startsWith('/storage')
            ? {'Key': 'request-photos/x'}
            : <Object>[],
      );
      final created = await repo.create(input, [_photo(), _photo()]);
      expect(created.failedPhotos, 0);
      final uploads = requests.whereType<http.MultipartRequest>().toList();
      expect(uploads.length, 2);
      expect(
        uploads.first.url.path,
        startsWith('/storage/v1/object/request-photos/u1/'),
      );
      final attach = requests.where(
        (r) => r.url.path == '/rest/v1/request_photos' && r.method == 'POST',
      );
      expect(attach.length, 2);
      expect(
        (attach.first as http.Request).body,
        contains('"request_id":"new-id"'),
      );
    });

    test('a photo that fails is counted, the request still stands', () async {
      final repo = build(
        answer: (r) {
          if (r.url.path.endsWith('create_quote_request')) return 'new-id';
          if (r.url.path.startsWith('/storage/v1/object/request-photos') &&
              r.method == 'POST') {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"message":"x"}')),
              413,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }
          return <Object>[];
        },
      );
      final created = await repo.create(input, [_photo(), _photo()]);
      expect(created.id, 'new-id');
      expect(created.failedPhotos, 2);
    });

    test('more than five photos: only five are sent', () async {
      final repo = build(
        answer: (r) => r.url.path.endsWith('create_quote_request')
            ? 'new-id'
            : r.url.path.startsWith('/storage')
            ? {'Key': 'request-photos/x'}
            : <Object>[],
      );
      await repo.create(input, [for (var i = 0; i < 8; i++) _photo()]);
      expect(requests.whereType<http.MultipartRequest>().length, 5);
    });

    test(
      'mine and get use the owner-only functions (never the table)',
      () async {
        final row = {
          'id': 'a',
          'title': 'T',
          'description': 'D',
          'category_id': 1,
          'governorate_id': 11,
          'city_id': null,
          'budget_tnd': 12.5,
          'needed_by': '2026-12-05',
          'status': 'awarded',
          'expires_at': '2026-11-24T00:00:00Z',
          'created_at': '2026-11-10T00:00:00Z',
          'offers_count': 3,
        };
        final repo = build(answer: (r) => [row]);
        final list = await repo.mine();
        expect(requests.single.url.path, '/rest/v1/rpc/my_quote_requests');
        expect(list.single.offerCount, 3);
        expect(list.single.status, RequestStatus.awarded);
        expect(list.single.budgetTnd, 12.5);
        expect(list.single.neededBy, DateTime(2026, 12, 5));

        final one = await build(answer: (r) => [row]).get('a');
        expect(one?.id, 'a');
        expect(jsonDecode((requests.single as http.Request).body), {
          'p_request': 'a',
        });
        expect(requests.single.url.path, '/rest/v1/rpc/get_my_quote_request');
        expect(await build(answer: (r) => <Object>[]).get('zzz'), isNull);
      },
    );

    test('photos come as signed links (private bucket)', () async {
      final repo = build(
        answer: (r) {
          if (r.url.path == '/rest/v1/request_photos') {
            return [
              {'id': 'p1', 'path': 'u1/a.jpg'},
              {'id': 'p2', 'path': 'u1/b.jpg'},
            ];
          }
          return [
            {
              'path': 'u1/a.jpg',
              'signedURL': '/object/sign/request-photos/u1/a.jpg?token=t1',
              'error': null,
            },
            {
              'path': 'u1/b.jpg',
              'signedURL': null,
              'error': 'Object not found',
            },
          ];
        },
      );
      final photos = await repo.photos('r1');
      expect(
        photos.length,
        1,
        reason: 'a path that could not be signed is left out',
      );
      expect(photos.single.url, contains('token=t1'));
      expect(requests.last.url.path, contains('/object/sign/request-photos'));
    });

    test('cancel calls the function', () async {
      final repo = build();
      await repo.cancel('r1');
      expect(requests.single.url.path, '/rest/v1/rpc/cancel_quote_request');
      expect(jsonDecode((requests.single as http.Request).body), {
        'p_request': 'r1',
      });
    });

    test('database tags map to categories without leaking messages', () {
      RequestsFailure f(String code, String message) => mapRequestsException(
        sb.PostgrestException(message: message, code: code),
      );
      expect(f('P0001', 'rate_limited'), RequestsFailure.rateLimited);
      expect(f('P0001', 'limit_reached'), RequestsFailure.limitReached);
      expect(f('P0001', 'photo_limit'), RequestsFailure.limitReached);
      expect(f('P0001', 'not_open'), RequestsFailure.notOpen);
      expect(f('P0001', 'expired'), RequestsFailure.notOpen);
      expect(f('P0001', 'invalid_input'), RequestsFailure.invalidInput);
      expect(f('P0001', 'whatever'), RequestsFailure.unknown);
      expect(f('P0002', 'not found'), RequestsFailure.notFound);
      expect(f('42501', 'x'), RequestsFailure.forbidden);
      expect(f('23514', 'x'), RequestsFailure.invalidInput);
      expect(f('PGRST301', 'x'), RequestsFailure.notSignedIn);
    });
  });
}
