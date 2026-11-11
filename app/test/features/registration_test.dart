import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/professional/application/professional_providers.dart';
import 'package:khidma/features/professional/data/supabase_professional_repository.dart';
import 'package:khidma/features/professional/domain/professional_domain.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_professional_repository.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');
const _aliPro = AppProfile(
  id: 'u1',
  fullName: 'Ali',
  isCustomer: true,
  isProfessional: true,
);

const _name = 'Plomberie Ben Salah';
const _about = 'Fuites, chauffe-eau et sanitaires. Intervention rapide.';

Future<ProviderContainerLike> _open(
  WidgetTester tester,
  FakeProfessionalRepository repo, {
  Map<String, Object> prefs = const {},
}) async {
  final c = await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: _ali),
    profiles: FakeProfileRepository(profile: _aliPro),
    prefs: prefs,
    overrides: [professionalRepositoryProvider.overrideWithValue(repo)],
  );
  c.read(routerProvider).push(AppRoutes.proRegistration);
  await tester.pumpAndSettle();
  return c;
}

typedef ProviderContainerLike = dynamic;

/// Brings [f] into view (the steps are plain scroll views, fully built).
Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.text(label);
  await _reveal(tester, f.first);
  await tester.tap(f.first);
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

Future<void> _fillBusiness(WidgetTester tester) async {
  await _enter(tester, 'Nom affiché (entreprise ou personne)', _name);
  await _tap(tester, 'Plomberie');
  await _enter(tester, 'Description de vos services', _about);
  await _enter(tester, 'Années d’expérience (facultatif)', '12');
}

Future<void> _pickGovernorate(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('profile rules', () {
    test('what blocks publishing mirrors the database rule', () {
      expect(
        const ProfessionalDraft().gaps,
        ProfileGap.values,
        reason: 'an empty draft lacks everything',
      );
      const ok = ProfessionalDraft(
        businessName: 'Ab',
        categoryId: 1,
        description: 'xxxxxxxxxxxxxxxxxxxx',
        governorateId: 11,
        phone: '+21620123456',
      );
      expect(ok.isComplete, isTrue);
      expect(
        const ProfessionalDraft(
          businessName: ' A ',
          categoryId: 1,
          description: 'xxxxxxxxxxxxxxxxxxxx',
          governorateId: 11,
          phone: '+21620123456',
        ).gaps,
        [ProfileGap.name],
        reason: 'the name is trimmed before counting',
      );
      expect(
        const ProfessionalDraft(
          businessName: 'Ab',
          categoryId: 1,
          description: 'xxxxxxxxxxxxxxxxxxx',
          governorateId: 11,
          phone: '+2161234',
        ).gaps,
        [ProfileGap.description, ProfileGap.phone],
      );
    });

    test('limits', () {
      expect(ProfessionalRules.nameOk('a' * 120), isTrue);
      expect(ProfessionalRules.nameOk('a' * 121), isFalse);
      expect(ProfessionalRules.descriptionOk('a' * 2000), isTrue);
      expect(ProfessionalRules.descriptionOk('a' * 2001), isFalse);
      expect(ProfessionalRules.yearsOk(null), isTrue);
      expect(ProfessionalRules.yearsOk(60), isTrue);
      expect(ProfessionalRules.yearsOk(61), isFalse);
      expect(ProfessionalRules.yearsOk(-1), isFalse);
    });
  });

  group('registration steps', () {
    testWidgets('a full registration saves each step and publishes', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository();
      await _open(tester, repo);
      expect(find.text('Étape 1 sur 6'), findsOneWidget);

      await _fillBusiness(tester);
      await _tap(tester, 'Continuer');
      expect(repo.saved.single.businessName, _name);
      expect(repo.saved.single.categoryId, 1);
      expect(repo.saved.single.yearsExperience, 12);
      expect(find.text('Étape 2 sur 6'), findsOneWidget);

      await _pickGovernorate(tester, 'Ariana');
      await _tap(tester, 'Continuer');
      expect(repo.saved.last.governorateId, isNotNull);

      expect(find.text('Étape 3 sur 6'), findsOneWidget);
      await _tap(tester, 'Tunis');
      await _tap(tester, 'Continuer');
      expect(repo.areasSaved.single.map((a) => a.cityId), [null]);

      await _tap(tester, 'Électricité');
      await _tap(tester, 'Continuer');
      expect(repo.servicesSaved.single, {2});

      await _enter(tester, 'Téléphone de contact', '20 123 456');
      await _tap(tester, 'Continuer');
      expect(repo.draft.phone, '+21620123456');

      expect(find.text('Étape 6 sur 6'), findsOneWidget);
      expect(
        find.text('Brouillon : invisible pour les clients.'),
        findsOneWidget,
      );
      // The main action is in the footer, not inside the scrolling review.
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text('Publier mon profil'),
        ),
        findsNothing,
      );
      await _tap(tester, 'Publier mon profil');
      expect(repo.publishCalls, [true]);
      expect(find.text('Votre profil est publié.'), findsOneWidget);
      // Once published, the footer offers a way out.
      expect(find.widgetWithText(FilledButton, 'Terminer'), findsOneWidget);
      await _tap(tester, 'Retirer de la liste');
      expect(repo.publishCalls, [true, false]);
    });

    testWidgets(
      'an existing draft is prefilled and the wizard resumes from it',
      (tester) async {
        final repo = FakeProfessionalRepository(
          draft: const ProfessionalDraft(
            businessName: _name,
            categoryId: 1,
            description: _about,
            yearsExperience: 7,
            governorateId: 11,
            phone: '+21620123456',
          ),
        );
        await _open(tester, repo);
        expect(find.text(_name), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        await _tap(tester, 'Continuer');
        expect(repo.saved.single.businessName, _name, reason: 'kept as is');
        await _tap(tester, 'Continuer');
        expect(find.text('Zones d’intervention'), findsOneWidget);
      },
    );

    testWidgets('each step refuses what the database would refuse', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository();
      await _open(tester, repo);
      await _tap(tester, 'Continuer');
      expect(find.text('Entre 2 et 120 caractères.'), findsOneWidget);
      expect(find.text('Choisissez un métier.'), findsOneWidget);
      expect(find.text('Entre 20 et 2000 caractères.'), findsOneWidget);
      expect(repo.saved, isEmpty, reason: 'nothing sent');

      await _fillBusiness(tester);
      await _enter(tester, 'Années d’expérience (facultatif)', '61');
      await _tap(tester, 'Continuer');
      expect(find.text('Entre 0 et 60.'), findsOneWidget);
      await _enter(tester, 'Années d’expérience (facultatif)', '');
      await _tap(tester, 'Continuer');
      expect(find.text('Étape 2 sur 6'), findsOneWidget);

      await _tap(tester, 'Continuer');
      expect(find.text('Choisissez un gouvernorat.'), findsOneWidget);
      await _pickGovernorate(tester, 'Tunis');
      await _tap(tester, 'Continuer');
      await _tap(tester, 'Continuer');
      await _tap(tester, 'Continuer');
      expect(find.text('Étape 5 sur 6'), findsOneWidget);
      await _enter(tester, 'Téléphone de contact', '12345');
      await _tap(tester, 'Continuer');
      expect(
        find.text('Numéro tunisien invalide (8 chiffres).'),
        findsOneWidget,
      );
    });

    testWidgets('a failed save keeps the step and the answers; retry works', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository();
      await _open(tester, repo);
      repo.failNext = ProfessionalFailure.network;
      await _fillBusiness(tester);
      await _tap(tester, 'Continuer');
      await _reveal(
        tester,
        find.text(
          'Connexion impossible. Vos réponses sont conservées, réessayez.',
        ),
      );
      expect(find.text('Étape 1 sur 6'), findsOneWidget);
      expect(find.text(_name), findsOneWidget);
      await _tap(tester, 'Continuer');
      expect(find.text('Étape 2 sur 6'), findsOneWidget);
      expect(repo.saved.length, 2);
    });

    testWidgets('a double tap sends one request', (tester) async {
      final repo = FakeProfessionalRepository();
      await _open(tester, repo);
      await _fillBusiness(tester);
      final gate = repo.gate = Completer<void>();
      final next = find.text('Continuer');
      await _reveal(tester, next);
      await tester.tap(next);
      await tester.pump();
      await tester.tap(next, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.saved.length, 1);
    });

    testWidgets('Save and leave saves the first step, then leaves', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository();
      await _open(tester, repo);
      await _tap(tester, 'Enregistrer et quitter');
      expect(repo.saved, isEmpty, reason: 'invalid: nothing sent, stays');
      expect(find.text('Profil professionnel'), findsOneWidget);
      await _fillBusiness(tester);
      await _tap(tester, 'Enregistrer et quitter');
      expect(repo.saved.single.businessName, _name);
      expect(find.text('Profil professionnel'), findsNothing);
    });

    testWidgets('a failed save and a failed reload keep the typed answers', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository();
      await _open(tester, repo);
      await _fillBusiness(tester);
      repo.failNext = ProfessionalFailure.network;
      await _tap(tester, 'Continuer');
      expect(find.text('Étape 1 sur 6'), findsOneWidget);
      expect(find.text(_name), findsOneWidget);
    });

    testWidgets('a neighbourhood is kept while the city is unchanged', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository(
        draft: const ProfessionalDraft(
          businessName: _name,
          categoryId: 1,
          description: _about,
          governorateId: 11,
          cityId: 2,
          neighborhoodId: 9,
          phone: '+21620123456',
        ),
      );
      await _open(tester, repo);
      await _tap(tester, 'Continuer');
      await _tap(tester, 'Continuer');
      expect(repo.saved.last.neighborhoodId, 9);
    });

    testWidgets('Back returns to the previous step with answers kept', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository();
      final c = await _open(tester, repo);
      await _fillBusiness(tester);
      await _tap(tester, 'Continuer');
      await _tap(tester, 'Retour');
      expect(find.text('Étape 1 sur 6'), findsOneWidget);
      expect(find.text(_name), findsOneWidget);
      // The system back button behaves the same on later steps.
      await _tap(tester, 'Continuer');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 6'), findsOneWidget);
      expect(
        find.text('Profil professionnel'),
        findsOneWidget,
        reason: 'still open',
      );
      // On the first step, back leaves.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Profil professionnel'), findsNothing);
      expect(c, isNotNull);
    });

    testWidgets('review lists what is missing and disables Publish', (
      tester,
    ) async {
      // The server drops the phone (as if refused): the app must not claim
      // the profile is publishable.
      final repo = FakeProfessionalRepository(
        draft: const ProfessionalDraft(
          businessName: _name,
          categoryId: 1,
          description: _about,
          governorateId: 11,
          phone: '+21620123456',
        ),
      )..dropPhone = true;
      await _open(tester, repo);
      for (var i = 0; i < 5; i++) {
        await _tap(tester, 'Continuer');
      }
      expect(find.text('Étape 6 sur 6'), findsOneWidget);
      expect(
        find.text('Pour publier, il manque : le téléphone.'),
        findsOneWidget,
      );
      final publish = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publier mon profil'),
      );
      expect(publish.onPressed, isNull);
      expect(repo.publishCalls, isEmpty);
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('every step fits a small phone at 1.5x text ($lang)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final repo = FakeProfessionalRepository(
          draft: const ProfessionalDraft(
            businessName: _name,
            categoryId: 1,
            description: _about,
            governorateId: 11,
            phone: '+21620123456',
          ),
        );
        await _open(tester, repo, prefs: {'locale': lang});
        for (var i = 0; i < 5; i++) {
          expect(tester.takeException(), isNull, reason: '$lang step $i');
          await tester.tap(find.byType(FilledButton).last);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: '$lang review');
      });
    }
  });

  group('wire format', () {
    late List<http.Request> requests;
    Object Function(http.Request) responder = (_) => <Object>[];
    SupabaseProfessionalRepository build({String? uid = 'u1'}) {
      requests = [];
      return SupabaseProfessionalRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(responder(r)),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        userId: () => uid,
      );
    }

    test(
      'fetchMine reads own row, phone by function, services and areas',
      () async {
        responder = (r) {
          final p = r.url.path;
          if (p.endsWith('/professional_profiles')) {
            return {
              'business_name': 'N',
              'primary_category_id': 1,
              'description': 'd',
              'years_experience': 3,
              'governorate_id': 11,
              'city_id': null,
              'availability': 'busy',
              'is_published': true,
              'verification_status': 'pending',
            };
          }
          if (p.endsWith('get_my_professional_contact')) return '+21620123456';
          if (p.endsWith('/professional_services')) {
            return [
              {'category_id': 2},
            ];
          }
          return [
            {'governorate_id': 12, 'city_id': null},
          ];
        };
        final d = await build().fetchMine();
        expect(d.phone, '+21620123456');
        expect(d.serviceCategoryIds, {2});
        expect(d.areas.single.governorateId, 12);
        expect(d.availability, Availability.busy);
        expect(d.isPublished, isTrue);
        expect(d.verification, Verification.pending);
        final own = requests.first.url.queryParameters;
        expect(own['user_id'], 'eq.u1');
        expect(own['select'], isNot(contains('contact_phone')));
      },
    );

    test('saveProfile sends the phone as E.164 and never a city without a governorate', () async {
      responder = (r) => r.url.path.endsWith('/professional_profiles')
          ? {
              'business_name': 'N',
              'primary_category_id': null,
              'description': null,
              'years_experience': null,
              'governorate_id': null,
              'city_id': null,
              'availability': 'available',
              'is_published': false,
              'verification_status': 'unverified',
            }
          : <Object>[];
      await build().saveProfile(
        const ProfessionalProfileInput(
          businessName: '  Nom  ',
          categoryId: 1,
          description: '   ',
          cityId: 5,
          phone: '20 123 456',
        ),
      );
      final patch = requests.firstWhere((r) => r.method == 'PATCH');
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body['contact_phone'], '+21620123456');
      expect(body['business_name'], 'Nom');
      expect(body['description'], isNull, reason: 'blank means none');
      expect(body['city_id'], isNull);
      expect(patch.url.queryParameters['user_id'], 'eq.u1');
      expect(body.keys, isNot(contains('is_published')));
      expect(body.keys, isNot(contains('verification_status')));
    });

    test('a neighbourhood is cleared whenever the city is', () async {
      responder = (r) => r.url.path.endsWith('/professional_profiles')
          ? {
              'business_name': 'N',
              'primary_category_id': null,
              'description': null,
              'years_experience': null,
              'governorate_id': null,
              'city_id': null,
              'neighborhood_id': null,
              'availability': 'available',
              'is_published': false,
              'verification_status': 'unverified',
            }
          : <Object>[];
      Future<Map<String, dynamic>> sent(ProfessionalProfileInput i) async {
        final repo = build();
        await repo.saveProfile(i);
        return jsonDecode(requests.firstWhere((r) => r.method == 'PATCH').body)
            as Map<String, dynamic>;
      }

      expect(
        (await sent(
          const ProfessionalProfileInput(
            governorateId: 11,
            cityId: 2,
            neighborhoodId: 9,
          ),
        ))['neighborhood_id'],
        9,
      );
      expect(
        (await sent(
          const ProfessionalProfileInput(governorateId: 11, neighborhoodId: 9),
        ))['neighborhood_id'],
        isNull,
      );
    });

    test('an invalid phone is refused before anything is sent', () async {
      final repo = build();
      await expectLater(
        repo.saveProfile(const ProfessionalProfileInput(phone: '123')),
        throwsA(
          isA<ProfessionalError>().having(
            (e) => e.failure,
            'failure',
            ProfessionalFailure.invalid,
          ),
        ),
      );
      expect(requests, isEmpty);
    });

    test('setServices adds first, then removes only what changed', () async {
      responder = (r) => r.method == 'GET'
          ? [
              {'category_id': 1},
              {'category_id': 2},
            ]
          : <Object>[];
      await build().setServices({2, 3});
      final writes = requests.where((r) => r.method != 'GET').toList();
      expect(writes.map((r) => r.method), ['POST', 'DELETE']);
      expect(jsonDecode(writes[0].body), [
        {'professional_id': 'u1', 'category_id': 3},
      ]);
      expect(writes[1].url.queryParameters['category_id'], 'in.(1)');
      expect(writes[1].url.queryParameters['professional_id'], 'eq.u1');
    });

    test('setServices with no change writes nothing', () async {
      responder = (r) => [
        {'category_id': 2},
      ];
      await build().setServices({2});
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    });

    test('setAreas diffs governorate-wide and city areas separately', () async {
      responder = (r) => r.method == 'GET'
          ? [
              {'id': 7, 'governorate_id': 11, 'city_id': null},
              {'id': 8, 'governorate_id': 12, 'city_id': 40},
            ]
          : <Object>[];
      await build().setAreas([
        const ServiceArea(governorateId: 11),
        const ServiceArea(governorateId: 12),
        const ServiceArea(governorateId: 12),
      ]);
      final writes = requests.where((r) => r.method != 'GET').toList();
      expect(writes.map((r) => r.method), ['POST', 'DELETE']);
      expect(jsonDecode(writes[0].body), [
        {'professional_id': 'u1', 'governorate_id': 12, 'city_id': null},
      ]);
      expect(writes[1].url.queryParameters['id'], 'in.(8)');
    });

    test('setPublished writes only that flag', () async {
      await build().setPublished(true);
      final r = requests.single;
      expect(r.method, 'PATCH');
      expect(jsonDecode(r.body), {'is_published': true});
      expect(r.url.queryParameters['user_id'], 'eq.u1');
    });

    test('no session: nothing is sent', () async {
      final repo = build(uid: null);
      await expectLater(repo.fetchMine(), throwsA(isA<ProfessionalError>()));
      await expectLater(
        repo.setPublished(true),
        throwsA(isA<ProfessionalError>()),
      );
      expect(requests, isEmpty);
    });

    test('server errors map to categories without leaking messages', () {
      ProfessionalFailure f(String code) => mapProfessionalException(
        sb.PostgrestException(message: 'secret detail', code: code),
      );
      expect(f('23514'), ProfessionalFailure.invalid);
      expect(f('23503'), ProfessionalFailure.invalid);
      expect(f('42501'), ProfessionalFailure.forbidden);
      expect(f('PGRST301'), ProfessionalFailure.notSignedIn);
      expect(f('XX000'), ProfessionalFailure.unknown);
    });
  });
}
