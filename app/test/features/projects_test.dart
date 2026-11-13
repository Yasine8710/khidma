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
import 'package:khidma/features/freelance/application/freelance_providers.dart';
import 'package:khidma/features/offers/application/offers_providers.dart';
import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/projects/application/projects_providers.dart';
import 'package:khidma/features/projects/data/supabase_projects_repository.dart';
import 'package:khidma/features/projects/domain/projects_domain.dart';
import 'package:khidma/features/requests/application/customer_offers_providers.dart';
import 'package:khidma/features/requests/domain/customer_offers_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:khidma/shared/widgets/app_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_customer_offers.dart';
import '../support/fake_freelance.dart';
import '../support/fake_offers.dart';
import '../support/fake_portfolio.dart';
import '../support/fake_projects.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

/// The text input of the app field labelled [label].
Finder _field(String label) => find.descendant(
  of: find.widgetWithText(AppTextField, label),
  matching: find.byType(TextField),
);

void main() {
  setUpAll(loadAppFonts);

  test('links: https only, no spaces, 300 characters at most', () {
    expect(isProjectLink('https://behance.net/sami'), isTrue);
    for (final bad in [
      'http://x.tn',
      'javascript:alert(1)',
      'https://x.tn/a b',
      'ftp://x.tn',
      'https://${'a' * 300}.tn',
    ]) {
      expect(isProjectLink(bad), isFalse, reason: bad);
    }
  });

  group('over a recorded HTTP layer', () {
    late List<http.BaseRequest> requests;
    late List<String> bodies;
    var rpcStatus = 200;

    SupabaseProjectsRepository build() {
      requests = [];
      bodies = [];
      return SupabaseProjectsRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, stream) async {
            requests.add(request);
            bodies.add(
              utf8.decode(await stream.toBytes(), allowMalformed: true),
            );
            final storage = request.url.path.startsWith('/storage/');
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(storage ? jsonEncode({'Key': 'x'}) : '"id1"'),
              ),
              storage ? 200 : rpcStatus,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
      );
    }

    setUp(() => rpcStatus = 200);

    test(
      'creating sends the project with trimmed links and a plain date',
      () async {
        final repo = build();
        final id = await repo.create(
          NewProject(
            title: ' Logo ',
            description: 'Un logo pour ma boutique.',
            categoryId: 3,
            deliverables: 'PNG',
            budgetMin: 100,
            budgetMax: 300,
            neededBy: DateTime(2026, 12, 5),
            links: const [' https://pinterest.com/x ', ''],
          ),
        );
        expect(id, 'id1');
        expect(requests.single.url.path, '/rest/v1/rpc/create_remote_request');
        final body = jsonDecode(bodies.single) as Map<String, dynamic>;
        expect(body['p_title'], 'Logo');
        expect(body['p_digital_category'], 3);
        expect(body['p_needed_by'], '2026-12-05');
        expect(body['p_links'], ['https://pinterest.com/x']);
      },
    );

    test('bad links never reach the network', () async {
      final repo = build();
      await expectLater(
        repo.create(
          const NewProject(
            title: 'Logo',
            description: 'Un logo pour ma boutique.',
            categoryId: 3,
            deliverables: 'PNG',
            links: ['javascript:alert(1)'],
          ),
        ),
        throwsA(isA<RequestsError>()),
      );
      expect(requests, isEmpty);
    });

    test(
      'delivering uploads into the booking folder, then hands in the paths',
      () async {
        final repo = build();
        await repo.deliver(
          'b1',
          note: ' Voici ',
          link: 'https://figma.com/f',
          photos: [PreparedPhoto(bytes: Uint8List(4), width: 1, height: 1)],
        );
        expect(
          requests.first.url.path,
          startsWith('/storage/v1/object/deliveries/b1/'),
        );
        expect(requests.last.url.path, '/rest/v1/rpc/deliver_booking');
        final body = jsonDecode(bodies.last) as Map<String, dynamic>;
        expect(body['p_note'], 'Voici');
        expect((body['p_paths'] as List).single, startsWith('b1/'));
      },
    );

    test('a refused hand-in removes the uploaded files', () async {
      final repo = build();
      rpcStatus = 400;
      await expectLater(
        repo.deliver(
          'b1',
          photos: [PreparedPhoto(bytes: Uint8List(4), width: 1, height: 1)],
        ),
        throwsA(isA<RequestsError>()),
      );
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/storage/v1/object/deliveries');
    });
  });

  group('screens', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      String route, {
      required FakeProjectsRepository projects,
      FakeCustomerOffersRepository? offers,
      FakeOffersRepository? proOffers,
      Uint8List? photo,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          projectsRepositoryProvider.overrideWithValue(projects),
          freelanceRepositoryProvider.overrideWithValue(
            FakeFreelanceRepository(),
          ),
          customerOffersRepositoryProvider.overrideWithValue(
            offers ?? FakeCustomerOffersRepository(),
          ),
          if (proOffers != null)
            offersRepositoryProvider.overrideWithValue(proOffers),
          photoPickerProvider.overrideWithValue(FakePhotoPicker(photo)),
          photoPreparerProvider.overrideWithValue(
            (b) async => PreparedPhoto(bytes: b, width: 10, height: 10),
          ),
        ],
      );
      c.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets(
      'posting a project checks fields, links and budget, then opens it',
      (tester) async {
        final projects = FakeProjectsRepository();
        await open(tester, AppRoutes.newProject, projects: projects);
        await tester.tap(find.text('Publier le projet'));
        await tester.pumpAndSettle();
        expect(projects.created, isEmpty);
        expect(find.text('Choisissez un type de travail.'), findsOneWidget);

        await tester.enterText(_field('Titre du projet'), 'Logo boutique');
        await tester.enterText(
          _field('Brief : décrivez le besoin'),
          'Un logo pour ma boutique de miel.',
        );
        await tester.enterText(_field('Livrables attendus'), 'PNG et SVG');
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownMenuItem<int>).last);
        await tester.pumpAndSettle();
        await tester.enterText(
          _field('Lien de référence (https)'),
          'http://pas-sur.tn',
        );
        await tester.tap(find.text('Publier le projet'));
        await tester.pumpAndSettle();
        expect(
          find.text('Seuls les liens https:// sont acceptés.'),
          findsOneWidget,
        );
        expect(projects.created, isEmpty);

        await tester.enterText(
          _field('Lien de référence (https)'),
          'https://pinterest.com/miel',
        );
        await tester.enterText(_field('Budget min (TND)'), '300');
        await tester.enterText(_field('Budget max (TND)'), '100');
        await tester.tap(find.text('Publier le projet'));
        await tester.pumpAndSettle();
        expect(
          find.text('Le budget max doit être supérieur ou égal au min.'),
          findsOneWidget,
        );

        await tester.enterText(_field('Budget max (TND)'), '500');
        await tester.tap(find.text('Publier le projet'));
        await tester.pumpAndSettle();
        expect(projects.created.single.links, ['https://pinterest.com/miel']);
        expect(projects.created.single.budgetMax, 500);
        expect(
          find.text('Logo pour ma boutique'),
          findsWidgets,
          reason: 'the new project opens',
        );
      },
    );

    testWidgets(
      'accepting a freelancer offer shows that Khidma holds no money',
      (tester) async {
        final offers = FakeCustomerOffersRepository(
          offers: [sampleOffer(days: 5)],
        );
        await open(
          tester,
          AppRoutes.projectPath('p1'),
          projects: FakeProjectsRepository(projects: [sampleProject()]),
          offers: offers,
        );
        expect(find.text('À distance'), findsOneWidget);
        expect(find.text('PNG et SVG'), findsOneWidget);
        await tester.tap(find.text('Accepter').first);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Khidma ne détient pas l’argent'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a freelancer sends an offer with days and revisions', (
      tester,
    ) async {
      final projects = FakeProjectsRepository(projects: [sampleProject()]);
      await open(
        tester,
        AppRoutes.proProjectPath('p1'),
        projects: projects,
        proOffers: FakeOffersRepository(),
      );
      await tester.enterText(_field('Prix (TND)'), '250');
      await tester.enterText(_field('Révisions incluses'), '25');
      await tester.tap(find.text('Envoyer l’offre'));
      await tester.pumpAndSettle();
      expect(
        find.text('Prix ≥ 1, délai de 1 à 365 jours, 0 à 20 révisions.'),
        findsOneWidget,
      );
      expect(projects.offers, isEmpty);
      await tester.enterText(_field('Révisions incluses'), '3');
      await tester.tap(find.text('Envoyer l’offre'));
      await tester.pumpAndSettle();
      expect(projects.offers.single, ('p1', 250.0, 7, 3, ''));
      expect(find.text('Offre envoyée.'), findsOneWidget);
    });

    testWidgets('the freelancer hands in work with a note and an image', (
      tester,
    ) async {
      final projects = FakeProjectsRepository(
        projects: [
          sampleProject(
            status: RequestStatus.awarded,
            myOfferStatus: 'accepted',
          ),
        ],
      );
      final proOffers = FakeOffersRepository(
        jobs: [
          sampleJob(
            id: 'b1',
            requestId: 'p1',
            status: BookingStatus.inProgress,
            remote: true,
          ),
        ],
      );
      await open(
        tester,
        AppRoutes.proProjectPath('p1'),
        projects: projects,
        proOffers: proOffers,
        photo: Uint8List(8),
      );
      expect(find.text('Rien n’a encore été livré.'), findsOneWidget);
      await tester.tap(find.text('Livrer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ajoutez un message, un lien ou une image.'),
        findsOneWidget,
      );
      await tester.enterText(
        _field('Message de livraison'),
        'Première version',
      );
      await tester.tap(find.text('Ajouter une image'));
      await tester.pumpAndSettle();
      expect(find.text('1 image(s) jointe(s)'), findsOneWidget);
      await tester.tap(find.text('Livrer'));
      await tester.pumpAndSettle();
      expect(projects.deliveries_.single, ('b1', 'Première version', '', 1));
      expect(
        find.text('Travail livré. Le client va vérifier.'),
        findsOneWidget,
      );
    });

    testWidgets('the customer opens a delivered file and asks for a revision', (
      tester,
    ) async {
      final projects = FakeProjectsRepository(
        projects: [sampleProject(status: RequestStatus.awarded)],
        delivered: Deliveries(
          items: [
            Delivery(
              id: 'd1',
              createdAt: DateTime(2026, 11, 14),
              note: 'V1',
              paths: const ['b1/a.jpg'],
            ),
          ],
          revisionsIncluded: 2,
        ),
      );
      final offers = FakeCustomerOffersRepository(
        offers: [sampleOffer(status: OfferStatus.accepted)],
        bookingValue: const CustomerBooking(
          id: 'b1',
          professionalId: 'demo-01',
          priceTnd: 250,
          status: BookingStatus.pendingConfirmation,
        ),
      );
      await open(
        tester,
        AppRoutes.projectPath('p1'),
        projects: projects,
        offers: offers,
      );
      expect(find.text('2 révision(s) restante(s)'), findsOneWidget);
      await tester.tap(find.text('Fichier 1'));
      await tester.pumpAndSettle();
      expect(projects.opened, ['b1/a.jpg']);
      await tester.enterText(
        _field('Ce qu’il faut changer'),
        'Couleurs plus chaudes',
      );
      await tester.tap(find.text('Demander une révision'));
      await tester.pumpAndSettle();
      expect(projects.revisions.single, ('b1', 'Couleurs plus chaudes'));
    });
  });
}
