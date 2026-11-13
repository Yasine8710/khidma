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
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/messages/application/messages_providers.dart';
import 'package:khidma/features/messages/domain/messages_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:khidma/features/trust/application/trust_providers.dart';
import 'package:khidma/features/trust/data/supabase_trust_repository.dart';
import 'package:khidma/features/trust/domain/trust_domain.dart';
import 'package:khidma/features/trust/presentation/suspension_card.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_messages.dart';
import '../support/fake_trust.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

void main() {
  setUpAll(loadAppFonts);

  group('over a recorded HTTP layer', () {
    late List<http.BaseRequest> requests;
    late List<String> bodies;
    var status = 200;
    var body = 'null';

    SupabaseTrustRepository build() {
      requests = [];
      bodies = [];
      return SupabaseTrustRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, stream) async {
            requests.add(request);
            bodies.add(utf8.decode(await stream.toBytes()));
            return http.StreamedResponse(
              Stream.value(utf8.encode(body)),
              status,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
        userId: () => 'u1',
      );
    }

    setUp(() {
      status = 200;
      body = 'null';
    });

    test(
      'a message report goes to report_message with the numeric id',
      () async {
        final repo = build();
        await repo.report(
          ReportTarget.message,
          '42',
          ReportReason.payOutside,
          null,
        );
        expect(requests.single.url.path, '/rest/v1/rpc/report_message');
        expect(jsonDecode(bodies.single), {
          'p_message': 42,
          'p_reason': 'pay_outside',
          'p_details': null,
        });
        await expectLater(
          repo.report(ReportTarget.message, 'x', ReportReason.other, null),
          throwsA(
            isA<RequestsError>().having(
              (e) => e.failure,
              'failure',
              RequestsFailure.invalidInput,
            ),
          ),
        );
        expect(requests, hasLength(1), reason: 'a bad id is never sent');
      },
    );

    test('an offer report and the new reasons use database names', () async {
      final repo = build();
      await repo.report(ReportTarget.offer, 'o1', ReportReason.noShow, ' x ');
      expect(requests.single.url.path, '/rest/v1/rpc/report_content');
      expect(jsonDecode(bodies.single), {
        'p_type': 'offer',
        'p_target': 'o1',
        'p_reason': 'no_show',
        'p_details': 'x',
      });
    });

    test('account status is read from my_account_status', () async {
      final repo = build();
      body = jsonEncode({
        'suspended': true,
        'suspended_until': '2026-12-01T10:00:00+00:00',
        'reason': 'Paiement hors application',
        'appeal_status': 'rejected',
        'appeal_note': null,
      });
      final s = await repo.myAccountStatus();
      expect(requests.single.url.path, '/rest/v1/rpc/my_account_status');
      expect(s.suspended, isTrue);
      expect(s.suspendedUntil!.toUtc(), DateTime.utc(2026, 12, 1, 10));
      expect(s.reason, 'Paiement hors application');
      expect(s.appeal, AppealStatus.rejected);
    });

    test('appeals are trimmed and length-checked before sending', () async {
      final repo = build();
      await expectLater(
        repo.submitAppeal('  court  '),
        throwsA(isA<RequestsError>()),
      );
      expect(requests, isEmpty);
      await repo.submitAppeal('  Je n ai jamais demande d avance.  ');
      expect(requests.single.url.path, '/rest/v1/rpc/submit_appeal');
      expect(jsonDecode(bodies.single), {
        'p_message': 'Je n ai jamais demande d avance.',
      });
    });

    test('suspended and not_suspended tags map apart', () async {
      final repo = build();
      for (final (tag, failure) in [
        ('suspended', RequestsFailure.suspended),
        ('not_suspended', RequestsFailure.invalidInput),
      ]) {
        status = 400;
        body = jsonEncode({'code': 'P0001', 'message': tag});
        await expectLater(
          repo.submitAppeal('Une explication assez longue.'),
          throwsA(
            isA<RequestsError>().having((e) => e.failure, 'failure', failure),
          ),
          reason: tag,
        );
      }
    });
  });

  group('badge validity', () {
    final now = DateTime.utc(2026, 11, 13, 12);

    test('verified until today or later stays verified', () {
      expect(
        parseVerification('verified', '2026-11-13', now: now),
        Verification.verified,
      );
      expect(
        parseVerification('verified', '2027-11-13', now: now),
        Verification.verified,
      );
    });

    test('a past date, revoked or unknown values read as unverified', () {
      expect(
        parseVerification('verified', '2026-11-12', now: now),
        Verification.unverified,
      );
      expect(
        parseVerification('revoked', null, now: now),
        Verification.unverified,
      );
      expect(
        parseVerification('pending', '2020-01-01', now: now),
        Verification.pending,
      );
    });

    test('the day turns at midnight in Tunis (UTC+1), not UTC', () {
      // 23:30 UTC on the 12th is already the 13th in Tunis.
      final late = DateTime.utc(2026, 11, 12, 23, 30);
      expect(tunisToday(late), DateTime.utc(2026, 11, 13));
      expect(
        parseVerification('verified', '2026-11-12', now: late),
        Verification.unverified,
      );
    });

    test('search rows without a date keep the server status', () {
      expect(parseVerification('verified', null), Verification.verified);
    });
  });

  group('suspension card', () {
    Future<FakeTrustRepository> host(
      WidgetTester tester,
      AccountStatus status,
    ) async {
      final repo = FakeTrustRepository()..account = status;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: _ali),
          ),
          trustRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: SuspensionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('nothing in good standing', (tester) async {
      await host(tester, AccountStatus.none);
      expect(find.text('Compte suspendu'), findsNothing);
    });

    testWidgets('shows until when and why, then sends an appeal', (
      tester,
    ) async {
      final repo = await host(
        tester,
        AccountStatus(
          suspended: true,
          suspendedUntil: DateTime(2026, 12, 1),
          reason: 'Paiement hors application',
        ),
      );
      expect(find.text('Compte suspendu'), findsOneWidget);
      expect(
        find.textContaining('Votre profil est masqué jusqu’au'),
        findsOneWidget,
      );
      expect(find.text('Motif : Paiement hors application'), findsOneWidget);

      await tester.tap(find.text('Faire un recours'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'court');
      await tester.tap(find.text('Envoyer le recours'));
      await tester.pumpAndSettle();
      expect(find.text('Écrivez au moins 10 caractères.'), findsOneWidget);
      expect(repo.appeals, isEmpty);

      await tester.enterText(
        find.byType(TextField),
        'Je n ai jamais demande de paiement.',
      );
      await tester.tap(find.text('Envoyer le recours'));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(repo.appeals.single, 'Je n ai jamais demande de paiement.');
      expect(find.text('Votre recours est en cours d’examen.'), findsOneWidget);
      expect(find.text('Faire un recours'), findsNothing);
    });

    testWidgets('a rejection a week ago is explained; a fresh one says wait', (
      tester,
    ) async {
      final repo = await host(
        tester,
        const AccountStatus(suspended: true, appeal: AppealStatus.rejected),
      );
      expect(find.text('Votre dernier recours a été refusé.'), findsOneWidget);
      expect(find.textContaining('jusqu’à la décision'), findsOneWidget);
      repo.failNext = RequestsFailure.rateLimited;
      await tester.tap(find.text('Faire un recours'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Une nouvelle explication.',
      );
      await tester.tap(find.text('Envoyer le recours'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Attendez une semaine après un refus avant un nouveau recours.',
        ),
        findsOneWidget,
      );
    });
  });

  group('chat safety', () {
    Future<FakeTrustRepository> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messages = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      messages.byConversation['c1'] = [
        ChatMessage(
          id: 7,
          fromCustomer: false,
          createdAt: DateTime(2026, 11, 13, 9),
          body: 'Envoyez 50 dinars d avance sur D17',
        ),
        ChatMessage(
          id: 8,
          fromCustomer: true,
          createdAt: DateTime(2026, 11, 13, 9, 5),
          body: 'Non merci',
        ),
      ];
      final trust = FakeTrustRepository();
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          messagesRepositoryProvider.overrideWithValue(messages),
          trustRepositoryProvider.overrideWithValue(trust),
        ],
      );
      c.read(routerProvider).go(AppRoutes.chatPath('c1'));
      await tester.pumpAndSettle();
      return trust;
    }

    testWidgets('the safety tip is always shown', (tester) async {
      await open(tester);
      expect(
        find.text('Ne payez jamais d’avance. Gardez vos accords dans Khidma.'),
        findsOneWidget,
      );
    });

    testWidgets('long-press on their message reports that one message', (
      tester,
    ) async {
      final trust = await open(tester);
      await tester.longPress(find.text('Non merci'));
      await tester.pumpAndSettle();
      expect(
        find.text('Signaler ce message'),
        findsNothing,
        reason: 'my own messages have no report entry',
      );
      await tester.longPress(find.text('Envoyez 50 dinars d avance sur D17'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler ce message'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Demande de paiement d’avance ou hors de l’app'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(trust.reports.single.$1, ReportTarget.message);
      expect(trust.reports.single.$2, '7');
      expect(trust.reports.single.$3, ReportReason.payOutside);
    });
  });

  testWidgets('every new string exists in Arabic and English', (tester) async {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.chatSafetyTip, isNotEmpty);
      expect(l10n.reportReasonPayOutside, isNotEmpty);
      expect(l10n.suspendedUntil('1'), contains('1'));
      expect(l10n.verifiedUntil('1'), contains('1'));
    }
  });
}
