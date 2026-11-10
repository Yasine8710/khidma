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

const _complete = ProfessionalDraft(
  businessName: 'Plomberie Ben Salah',
  categoryId: 1,
  description: 'Fuites, chauffe-eau et sanitaires. Intervention rapide.',
  governorateId: 11,
  phone: '+21620123456',
);

Future<dynamic> _open(
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
  c.read(routerProvider).push(AppRoutes.proDashboard);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUpAll(loadAppFonts);

  group('dashboard', () {
    testWidgets('a draft shows what is missing and leads to the steps', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository(
        draft: const ProfessionalDraft(businessName: 'Ali Pro'),
      );
      await _open(tester, repo);
      expect(find.text('Profil non publié'), findsOneWidget);
      expect(
        find.text(
          'Pour publier, il manque : le métier, la description, le gouvernorat, le téléphone.',
        ),
        findsOneWidget,
      );
      expect(find.text('Voir mon profil public'), findsNothing);
      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 6'), findsOneWidget);
    });

    testWidgets(
      'a published profile can be viewed; verified only when verified',
      (tester) async {
        final repo = FakeProfessionalRepository(
          draft: const ProfessionalDraft(
            businessName: 'Plomberie Ben Salah',
            categoryId: 1,
            description:
                'Fuites, chauffe-eau et sanitaires. Intervention rapide.',
            governorateId: 11,
            phone: '+21620123456',
            isPublished: true,
            verification: Verification.pending,
          ),
        );
        await _open(tester, repo);
        expect(find.text('Profil publié'), findsOneWidget);
        expect(
          find.text('Vérifié'),
          findsNothing,
          reason: 'pending is not verified',
        );
        expect(find.text('Modifier mon profil professionnel'), findsOneWidget);
        expect(find.text('Voir mon profil public'), findsOneWidget);
      },
    );

    testWidgets('verified shows the badge', (tester) async {
      final repo = FakeProfessionalRepository(
        draft: const ProfessionalDraft(
          businessName: 'Plomberie Ben Salah',
          categoryId: 1,
          description:
              'Fuites, chauffe-eau et sanitaires. Intervention rapide.',
          governorateId: 11,
          phone: '+21620123456',
          isPublished: true,
          verification: Verification.verified,
        ),
      );
      await _open(tester, repo);
      expect(find.text('Vérifié'), findsOneWidget);
    });

    testWidgets('availability changes reach the server and the screen', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository(draft: _complete);
      await _open(tester, repo);
      await tester.tap(find.text('Occupé'));
      await tester.pumpAndSettle();
      expect(repo.availabilityCalls, [Availability.busy]);
      final segmented = tester.widget<SegmentedButton<Availability>>(
        find.byType(SegmentedButton<Availability>),
      );
      expect(segmented.selected, {Availability.busy});
    });

    testWidgets(
      'a failed availability change says so and keeps the old value',
      (tester) async {
        final repo = FakeProfessionalRepository(draft: _complete);
        await _open(tester, repo);
        repo.failNext = ProfessionalFailure.network;
        await tester.tap(find.text('Hors ligne'));
        await tester.pumpAndSettle();
        expect(
          find.text('Modification impossible. Réessayez.'),
          findsOneWidget,
        );
        final segmented = tester.widget<SegmentedButton<Availability>>(
          find.byType(SegmentedButton<Availability>),
        );
        expect(segmented.selected, {Availability.available});
        await tester.pumpAndSettle(const Duration(seconds: 6));
      },
    );

    testWidgets('a saved availability stays shown even if the reload fails', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository(draft: _complete)
        ..reloadFails = true;
      await _open(tester, repo);
      await tester.tap(find.text('Occupé'));
      await tester.pumpAndSettle();
      expect(repo.availabilityCalls, [Availability.busy]);
      final segmented = tester.widget<SegmentedButton<Availability>>(
        find.byType(SegmentedButton<Availability>),
      );
      expect(segmented.selected, {Availability.busy});
      expect(
        find.text(
          'Impossible d’actualiser. Les chiffres affichés peuvent être anciens.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('activity numbers are shown, anonymous', (tester) async {
      final repo = FakeProfessionalRepository(draft: _complete)
        ..activity = const ProfessionalActivity(
          contactViews30d: 4,
          contactViewsTotal: 19,
          favorites: 7,
        );
      await _open(tester, repo);
      await tester.scrollUntilVisible(
        find.text('Enregistrés en favoris'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Chiffres anonymes'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('Chiffres anonymes'), findsOneWidget);
    });

    testWidgets('activity failing does not break the rest; retry works', (
      tester,
    ) async {
      final repo = FakeProfessionalRepository(draft: _complete)
        ..failActivity = true
        ..activity = const ProfessionalActivity(contactViewsTotal: 5);
      await _open(tester, repo);
      expect(find.text('Profil non publié'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Activité indisponible pour le moment.'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      repo.failActivity = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('the Profile tab opens it', (tester) async {
      final repo = FakeProfessionalRepository(draft: _complete);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: FakeProfileRepository(profile: _aliPro),
        overrides: [professionalRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mon espace pro'));
      await tester.tap(find.text('Mon espace pro'));
      await tester.pumpAndSettle();
      expect(find.text('Disponibilité'), findsOneWidget);
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
        final repo = FakeProfessionalRepository(
          draft: const ProfessionalDraft(
            businessName: 'Plomberie Ben Salah',
            isPublished: true,
          ),
        );
        await _open(tester, repo, prefs: {'locale': lang});
        expect(tester.takeException(), isNull, reason: lang);
      });
    }
  });

  group('wire format', () {
    late List<http.Request> requests;
    SupabaseProfessionalRepository build(Object body) {
      requests = [];
      return SupabaseProfessionalRepository(
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
        userId: () => 'u1',
      );
    }

    test('setAvailability writes only that column, for me', () async {
      await build(<Object>[]).setAvailability(Availability.offline);
      final r = requests.single;
      expect(r.method, 'PATCH');
      expect(jsonDecode(r.body), {'availability': 'offline'});
      expect(r.url.queryParameters['user_id'], 'eq.u1');
    });

    test(
      'activity reads the owner-only function (rows or a single object)',
      () async {
        final row = {
          'reveals_30d': 3,
          'reveals_total': 10,
          'favorites_count': 2,
        };
        for (final body in [
          [row],
          row,
        ]) {
          final a = await build(body).fetchActivity();
          expect(
            (a.contactViews30d, a.contactViewsTotal, a.favorites),
            (3, 10, 2),
          );
          expect(requests.single.url.path, '/rest/v1/rpc/get_my_activity');
        }
        final none = await build(<Object>[]).fetchActivity();
        expect(none.contactViewsTotal, 0);
      },
    );
  });
}
