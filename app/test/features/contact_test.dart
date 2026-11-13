import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/marketplace/application/contact_providers.dart';
import 'package:khidma/features/marketplace/application/marketplace_providers.dart';
import 'package:khidma/features/marketplace/data/demo_marketplace_repository.dart';
import 'package:khidma/features/marketplace/data/supabase_marketplace_repository.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

/// Demo professionals with a real-looking (non-demo) repository personality
/// and a scripted contact reveal.
class _Repo extends DemoMarketplaceRepository {
  _Repo({this.phone = '+21620123456'});
  String phone;
  final failures = <MarketplaceFailure>[];
  int reveals = 0;

  @override
  bool get isDemo => false;

  @override
  Future<ProfessionalDetails> details(String id) async =>
      const ProfessionalDetails(
        serviceCategoryIds: [1, 2],
        areas: [
          ServiceArea(governorateId: 11),
          ServiceArea(governorateId: 11, cityId: 2),
        ],
      );

  @override
  Future<String> revealContact(String id) async {
    reveals++;
    if (failures.isNotEmpty) throw MarketplaceError(failures.removeAt(0));
    return phone;
  }
}

Future<List<Uri>> _open(
  WidgetTester tester,
  _Repo repo, {
  bool signedIn = true,
  bool launches = true,
}) async {
  final opened = <Uri>[];
  final c = await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: signedIn ? _ali : null),
    overrides: [
      marketplaceRepositoryProvider.overrideWithValue(repo),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return launches;
      }),
    ],
  );
  c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _scrollDown(WidgetTester tester, Finder f) async {
  final list = find.byType(ListView).last;
  for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('contact on the profile', () {
    testWidgets('the Contact button at the top jumps to the contact section', (
      tester,
    ) async {
      await _open(tester, _Repo());
      await tester.tap(find.widgetWithText(OutlinedButton, 'Contact'));
      await tester.pumpAndSettle();
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final box = tester.getRect(find.text('Afficher le contact'));
      expect(box.bottom, lessThanOrEqualTo(screen.height));
      expect(box.top, greaterThanOrEqualTo(0));
    });

    testWidgets('signed out: asked to sign in, no number requested', (
      tester,
    ) async {
      final repo = _Repo();
      await _open(tester, repo, signedIn: false);
      await _scrollDown(
        tester,
        find.text('Connectez-vous pour voir le contact'),
      );
      expect(find.text('Afficher le contact'), findsNothing);
      expect(repo.reveals, 0);
    });

    testWidgets(
      'signed in: reveals, then call and WhatsApp open the right links',
      (tester) async {
        final repo = _Repo();
        final opened = await _open(tester, repo);
        await _scrollDown(tester, find.text('Afficher le contact'));
        expect(
          find.textContaining('+216'),
          findsNothing,
          reason: 'hidden first',
        );
        expect(repo.reveals, 0);
        await tester.tap(find.text('Afficher le contact'));
        await tester.pumpAndSettle();
        await _scrollDown(tester, find.text('Appeler'));
        expect(find.text('+216 20 123 456'), findsOneWidget);
        await tester.tap(find.text('Appeler'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('WhatsApp'));
        await tester.pumpAndSettle();
        expect(opened.map((u) => u.toString()), [
          'tel:+21620123456',
          'https://wa.me/21620123456',
        ]);
        expect(repo.reveals, 1);
      },
    );

    testWidgets('a link that cannot open says so', (tester) async {
      await _open(tester, _Repo(), launches: false);
      await _scrollDown(tester, find.text('Afficher le contact'));
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      await _scrollDown(tester, find.text('Appeler'));
      await tester.tap(find.text('Appeler'));
      await tester.pump();
      expect(find.text('Impossible d’ouvrir l’application.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('rate limited: explained, no retry button', (tester) async {
      final repo = _Repo()..failures.add(MarketplaceFailure.rateLimited);
      await _open(tester, repo);
      await _scrollDown(tester, find.text('Afficher le contact'));
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      await _scrollDown(tester, find.textContaining('Trop de numéros'));
      expect(find.text('Réessayer'), findsNothing);
    });

    testWidgets('a network failure offers a retry that works', (tester) async {
      final repo = _Repo()..failures.add(MarketplaceFailure.network);
      await _open(tester, repo);
      await _scrollDown(tester, find.text('Afficher le contact'));
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      await _scrollDown(tester, find.text('Réessayer'));
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      await _scrollDown(tester, find.text('+216 20 123 456'));
      expect(repo.reveals, 2);
    });

    testWidgets('signing out clears a revealed number; no stale state', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedIn: _ali);
      final repo = _Repo();
      final c = await pumpApp(
        tester,
        auth: auth,
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
      await tester.pumpAndSettle();
      await _scrollDown(tester, find.text('Afficher le contact'));
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      expect(c.read(contactProvider('demo-01')), isA<ContactRevealed>());
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(c.read(contactProvider('demo-01')), isA<ContactHidden>());
      auth.emit(const AuthUser(id: 'u2', email: 'b@example.tn'));
      await tester.pumpAndSettle();
      expect(c.read(contactProvider('demo-01')), isA<ContactHidden>());
      expect(find.text('+216 20 123 456'), findsNothing);
    });

    testWidgets('a number that is not Tunisian is never made dialable', (
      tester,
    ) async {
      final opened = await _open(tester, _Repo(phone: '+33612345678'));
      await _scrollDown(tester, find.text('Afficher le contact'));
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      await _scrollDown(
        tester,
        find.text('Impossible de charger le contact. Réessayez.'),
      );
      expect(find.text('Appeler'), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('demo data: honest note, no reveal', (tester) async {
      final c = await pumpApp(tester, auth: FakeAuthRepository(signedIn: _ali));
      c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
      await tester.pumpAndSettle();
      await _scrollDown(
        tester,
        find.text(
          'Le contact n’est pas disponible avec les données de démonstration.',
        ),
      );
      expect(find.text('Afficher le contact'), findsNothing);
    });

    testWidgets('services and areas are listed', (tester) async {
      await _open(tester, _Repo());
      await _scrollDown(tester, find.text('Zones d’intervention'));
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Tunis (tout le gouvernorat)'), findsOneWidget);
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('revealed contact fits a small phone at 1.5x ($lang)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final c = await pumpApp(
          tester,
          prefs: {'locale': lang},
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [marketplaceRepositoryProvider.overrideWithValue(_Repo())],
        );
        c.read(routerProvider).push(AppRoutes.professionalPath('demo-01'));
        await tester.pumpAndSettle();
        final show = find.byType(ElevatedButton);
        // The reveal button is the first AppButton after the description.
        final label = {
          'fr': 'Afficher le contact',
          'ar': 'إظهار رقم التواصل',
          'en': 'Show contact',
        }[lang]!;
        await _scrollDown(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(show, isNotNull);
        expect(tester.takeException(), isNull, reason: lang);
      });
    }
  });

  group('wire format', () {
    late List<http.Request> requests;
    SupabaseMarketplaceRepository build(Object body, {int status = 200}) {
      requests = [];
      return SupabaseMarketplaceRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(body),
              status,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    }

    test(
      'reveal calls the RPC with the id only and returns the number',
      () async {
        final repo = build('+21620123456');
        expect(await repo.revealContact('u1'), '+21620123456');
        expect(
          requests.single.url.path,
          '/rest/v1/rpc/reveal_professional_contact',
        );
        expect(jsonDecode(requests.single.body), {'p_professional': 'u1'});
      },
    );

    test('reveal failures map to categories', () async {
      Future<MarketplaceFailure> failure(String code, String message) async {
        final repo = build({'code': code, 'message': message}, status: 400);
        try {
          await repo.revealContact('u1');
        } on MarketplaceError catch (e) {
          return e.failure;
        }
        fail('no error');
      }

      expect(
        await failure('P0001', 'rate_limited'),
        MarketplaceFailure.rateLimited,
      );
      expect(
        await failure('P0001', 'something else'),
        MarketplaceFailure.unknown,
      );
      expect(await failure('P0002', 'not found'), MarketplaceFailure.notFound);
      expect(
        await failure('28000', 'not authenticated'),
        MarketplaceFailure.notSignedIn,
      );
    });

    test('an empty answer is not a number', () async {
      final repo = build('');
      await expectLater(
        repo.revealContact('u1'),
        throwsA(
          isA<MarketplaceError>().having(
            (e) => e.failure,
            'failure',
            MarketplaceFailure.notFound,
          ),
        ),
      );
    });

    test('details reads services and areas of that professional', () async {
      final repo = build([
        {'category_id': 3, 'governorate_id': 11, 'city_id': null},
      ]);
      final d = await repo.details('u1');
      expect(requests.map((r) => r.url.path).toSet(), {
        '/rest/v1/professional_services',
        '/rest/v1/service_areas',
      });
      expect(
        requests.every(
          (r) => r.url.queryParameters['professional_id'] == 'eq.u1',
        ),
        isTrue,
      );
      expect(d.serviceCategoryIds, [3]);
      expect(d.areas.single.governorateId, 11);
      expect(d.areas.single.cityId, isNull);
    });
  });
}
