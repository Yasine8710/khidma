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
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:khidma/features/trust/application/trust_providers.dart';
import 'package:khidma/features/trust/data/supabase_trust_repository.dart';
import 'package:khidma/features/trust/domain/trust_domain.dart';
import 'package:khidma/features/trust/presentation/report_sheet.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_portfolio.dart';
import '../support/fake_trust.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

PreparedPhoto _photo([int n = 100]) =>
    PreparedPhoto(bytes: Uint8List(n), width: 10, height: 10);

void main() {
  setUpAll(loadAppFonts);

  group('over a recorded HTTP layer', () {
    late List<http.BaseRequest> requests;
    late List<String> bodies;
    int rpcStatus = 200;
    int uploadStatus = 200;
    String rpcBody = 'null';

    SupabaseTrustRepository build({String? uid = 'u1'}) {
      requests = [];
      bodies = [];
      return SupabaseTrustRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, bodyStream) async {
            requests.add(request);
            bodies.add(
              utf8.decode(await bodyStream.toBytes(), allowMalformed: true),
            );
            final path = request.url.path;
            if (path.startsWith('/storage/v1/object/verification-docs')) {
              if (request.method == 'POST') {
                return http.StreamedResponse(
                  Stream.value(utf8.encode(jsonEncode({'Key': 'x'}))),
                  uploadStatus,
                  headers: {'content-type': 'application/json'},
                  request: request,
                );
              }
              return http.StreamedResponse(
                Stream.value(utf8.encode('[]')),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            return http.StreamedResponse(
              Stream.value(utf8.encode(rpcBody)),
              rpcStatus,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
        userId: () => uid,
      );
    }

    setUp(() {
      rpcStatus = 200;
      uploadStatus = 200;
      rpcBody = 'null';
    });

    test('report sends the type, target, reason and trimmed details', () async {
      final repo = build();
      await repo.report(
        ReportTarget.review,
        'r1',
        ReportReason.fake,
        '  faux  ',
      );
      expect(requests.single.url.path, '/rest/v1/rpc/report_content');
      expect(jsonDecode(bodies.single), {
        'p_type': 'review',
        'p_target': 'r1',
        'p_reason': 'fake',
        'p_details': 'faux',
      });
      await repo.report(
        ReportTarget.professional,
        'p1',
        ReportReason.spam,
        '   ',
      );
      expect(jsonDecode(bodies.last)['p_details'], isNull);
    });

    test('database tags become categories', () async {
      final repo = build();
      for (final (tag, failure) in [
        ('already_reported', RequestsFailure.alreadyReported),
        ('rate_limited', RequestsFailure.rateLimited),
        ('already_pending', RequestsFailure.alreadyPending),
        ('already_verified', RequestsFailure.alreadyVerified),
      ]) {
        rpcStatus = 400;
        rpcBody = jsonEncode({'code': 'P0001', 'message': tag});
        await expectLater(
          repo.report(ReportTarget.professional, 'p', ReportReason.other, null),
          throwsA(
            isA<RequestsError>().having((e) => e.failure, 'failure', failure),
          ),
          reason: tag,
        );
      }
    });

    test(
      'myVerification: none when there is no request, else the latest',
      () async {
        final repo = build();
        rpcBody = '[]';
        expect((await repo.myVerification()).status, VerificationStatus.none);
        rpcBody = jsonEncode([
          {
            'status': 'rejected',
            'reject_reason': 'Illisible',
            'submitted_at': '2026-11-01T00:00:00Z',
          },
        ]);
        final info = await repo.myVerification();
        expect(info.status, VerificationStatus.rejected);
        expect(info.rejectReason, 'Illisible');
      },
    );

    test(
      'submit uploads each file to the private bucket, then sends the paths',
      () async {
        final repo = build();
        await repo.submitVerification([_photo(), _photo(200)]);
        final uploads = requests
            .where(
              (r) =>
                  r.method == 'POST' &&
                  r.url.path.startsWith(
                    '/storage/v1/object/verification-docs/u1/',
                  ),
            )
            .toList();
        expect(uploads, hasLength(2));
        expect(uploads.every((r) => r.url.path.endsWith('.jpg')), isTrue);
        final rpc = requests.last;
        expect(rpc.url.path, '/rest/v1/rpc/submit_verification');
        final paths = (jsonDecode(bodies.last)['p_paths'] as List)
            .cast<String>();
        expect(paths, hasLength(2));
        expect(
          paths.every((p) => p.startsWith('u1/') && p.endsWith('.jpg')),
          isTrue,
        );
        expect(paths.toSet(), hasLength(2));
      },
    );

    test(
      'if the request is refused, the uploaded files are removed again',
      () async {
        final repo = build();
        rpcStatus = 400;
        rpcBody = jsonEncode({'code': 'P0001', 'message': 'already_pending'});
        await expectLater(
          repo.submitVerification([_photo()]),
          throwsA(
            isA<RequestsError>().having(
              (e) => e.failure,
              'failure',
              RequestsFailure.alreadyPending,
            ),
          ),
        );
        expect(
          requests.any(
            (r) =>
                r.method == 'DELETE' &&
                r.url.path.startsWith('/storage/v1/object/verification-docs'),
          ),
          isTrue,
        );
      },
    );

    test('a failed upload removes every chosen name, even one whose answer was lost', () async {
      final repo = build();
      uploadStatus = 500;
      await expectLater(
        repo.submitVerification([_photo(), _photo()]),
        throwsA(isA<RequestsError>()),
      );
      expect(
        requests.any((r) => r.url.path.endsWith('/rpc/submit_verification')),
        isFalse,
      );
      final del = requests.firstWhere((r) => r.method == 'DELETE');
      final i = requests.indexOf(del);
      final removed = (jsonDecode(bodies[i])['prefixes'] as List)
          .cast<String>();
      expect(
        removed,
        hasLength(2),
        reason: 'both names, not only the saved ones',
      );
    });

    test('no session, no files or too many files: nothing is sent', () async {
      await expectLater(
        build(uid: null).submitVerification([_photo()]),
        throwsA(isA<RequestsError>()),
      );
      expect(requests, isEmpty);
      final repo = build();
      await expectLater(
        repo.submitVerification([]),
        throwsA(isA<RequestsError>()),
      );
      await expectLater(
        repo.submitVerification([
          for (var i = 0; i < maxVerificationDocuments + 1; i++) _photo(),
        ]),
        throwsA(isA<RequestsError>()),
      );
      expect(requests, isEmpty);
    });

    test('cancel calls the database function', () async {
      final repo = build();
      await repo.cancelVerification();
      expect(requests.single.url.path, '/rest/v1/rpc/cancel_verification');
    });
  });

  group('verification screen', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      FakeTrustRepository repo, {
      FakePhotoPicker? picker,
      Map<String, Object> prefs = const {},
    }) async {
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        prefs: prefs,
        overrides: [
          trustRepositoryProvider.overrideWithValue(repo),
          photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
          photoPreparerProvider.overrideWithValue(
            (b) async => _photo(b.length),
          ),
        ],
      );
      c.read(routerProvider).push(AppRoutes.proVerification);
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets(
      'not verified: pick up to 3 documents, send them, then it is pending',
      (tester) async {
        final repo = FakeTrustRepository();
        final picker = FakePhotoPicker(Uint8List.fromList([1, 2, 3]));
        await open(tester, repo, picker: picker);
        expect(find.text('Pas encore vérifié'), findsOneWidget);
        expect(find.text('0 sur 3 documents'), findsOneWidget);
        // sending needs at least one document
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Envoyer pour vérification'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Ajouter une photo'));
        await tester.pumpAndSettle();
        expect(find.text('1 sur 3 documents'), findsOneWidget);
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Ajouter une photo'));
          await tester.pumpAndSettle();
        }
        expect(find.text('3 sur 3 documents'), findsOneWidget);
        expect(picker.picks, 3);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Ajouter une photo'),
              )
              .onPressed,
          isNull,
          reason: 'limit reached',
        );
        await tester.tap(find.text('Envoyer pour vérification'));
        await tester.pumpAndSettle(const Duration(seconds: 6));
        expect(repo.submitted.single, hasLength(3));
        expect(find.text('En cours de vérification'), findsOneWidget);
        expect(find.text('Annuler la demande'), findsOneWidget);
      },
    );

    testWidgets('a failed send keeps the documents and says why', (
      tester,
    ) async {
      final repo = FakeTrustRepository()
        ..failNext = RequestsFailure.rateLimited;
      await open(
        tester,
        repo,
        picker: FakePhotoPicker(Uint8List.fromList([1])),
      );
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer pour vérification'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Trop de demandes ces 30 derniers jours. Réessayez plus tard.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 sur 3 documents'), findsOneWidget);
      // retry works
      await tester.tap(find.text('Envoyer pour vérification'));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(repo.submitted, hasLength(2));
      expect(find.text('En cours de vérification'), findsOneWidget);
    });

    testWidgets('cancelling a pending request goes back to a form', (
      tester,
    ) async {
      final repo = FakeTrustRepository(
        info: const VerificationInfo(status: VerificationStatus.pending),
      );
      await open(tester, repo);
      expect(
        find.text('Ajouter une photo'),
        findsNothing,
        reason: 'nothing to add while pending',
      );
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(repo.cancels, 1);
      expect(find.text('Demande annulée'), findsOneWidget);
      expect(find.text('Ajouter une photo'), findsOneWidget);
    });

    testWidgets('rejected: the reason is shown and a new request is possible', (
      tester,
    ) async {
      final repo = FakeTrustRepository(
        info: const VerificationInfo(
          status: VerificationStatus.rejected,
          rejectReason: 'Photo illisible',
        ),
      );
      await open(tester, repo);
      expect(find.text('Demande refusée'), findsOneWidget);
      expect(find.text('Motif : Photo illisible'), findsOneWidget);
      expect(find.text('Ajouter une photo'), findsOneWidget);
    });

    testWidgets('verified: nothing to send', (tester) async {
      await open(
        tester,
        FakeTrustRepository(
          info: const VerificationInfo(status: VerificationStatus.approved),
        ),
      );
      expect(find.text('Profil vérifié'), findsOneWidget);
      expect(find.text('Ajouter une photo'), findsNothing);
      expect(find.text('Envoyer pour vérification'), findsNothing);
    });

    testWidgets('a cancelled photo picker changes nothing', (tester) async {
      await open(tester, FakeTrustRepository(), picker: FakePhotoPicker());
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pumpAndSettle();
      expect(find.text('0 sur 3 documents'), findsOneWidget);
    });

    for (final (locale, title) in [
      ('ar', 'توثيق الحساب'),
      ('en', 'Profile verification'),
    ]) {
      testWidgets('$locale: renders on a small phone with large text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320 * 2, 568 * 2);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await open(tester, FakeTrustRepository(), prefs: {'locale': locale});
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('report sheet', () {
    Future<(ProviderContainer, FakeTrustRepository)> host(
      WidgetTester tester, {
      FakeTrustRepository? repo,
      String locale = 'fr',
    }) async {
      final r = repo ?? FakeTrustRepository();
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(
        overrides: [trustRepositoryProvider.overrideWithValue(r)],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(
                child: ReportButton(
                  target: ReportTarget.review,
                  targetId: 'rv1',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ReportButton));
      await tester.pumpAndSettle();
      return (c, r);
    }

    testWidgets('needs a reason, then sends it with the details and confirms', (
      tester,
    ) async {
      final (_, repo) = await host(tester);
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();
      expect(repo.reports, isEmpty, reason: 'no reason chosen');
      await tester.tap(find.text('Faux profil ou faux avis'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Je ne le connais pas');
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(repo.reports.single, (
        ReportTarget.review,
        'rv1',
        ReportReason.fake,
        'Je ne le connais pas',
      ));
      expect(
        find.text('Signaler un problème'),
        findsNothing,
        reason: 'sheet closed',
      );
    });

    testWidgets(
      'a duplicate is treated as done; other failures stay in the sheet',
      (tester) async {
        final repo = FakeTrustRepository()
          ..failNext = RequestsFailure.rateLimited;
        await host(tester, repo: repo);
        await tester.tap(find.text('Publicité ou spam'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Envoyer le signalement'));
        await tester.pumpAndSettle();
        expect(
          find.text('Trop de signalements aujourd’hui. Réessayez demain.'),
          findsOneWidget,
        );
        repo.failNext = RequestsFailure.alreadyReported;
        await tester.tap(find.text('Envoyer le signalement'));
        await tester.pumpAndSettle(const Duration(seconds: 6));
        expect(find.text('Signaler un problème'), findsNothing);
      },
    );

    testWidgets('a double tap sends once', (tester) async {
      final repo = FakeTrustRepository()..gate = Completer<void>();
      await host(tester, repo: repo);
      await tester.tap(find.text('Publicité ou spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pump();
      await tester.tap(
        find.text('Envoyer le signalement'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(repo.reports, hasLength(1));
      repo.gate!.complete();
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('arabic: renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await host(tester, locale: 'ar');
      expect(find.text('الإبلاغ عن مشكلة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
