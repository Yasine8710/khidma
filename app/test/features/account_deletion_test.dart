import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/profile/application/profile_providers.dart';
import 'package:khidma/features/profile/data/supabase_profile_repository.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');
const _aliProfile = AppProfile(id: 'u1', fullName: 'Ali');

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  await scrollProfileTo(tester, find.text('Supprimer mon compte'));
  await tester.tap(find.text('Supprimer mon compte'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('delete account: the dialog', () {
    testWidgets('explains the consequences and needs the confirmation word', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await _openDialog(tester);
      expect(find.text('Supprimer votre compte ?'), findsOneWidget);
      expect(find.textContaining('irréversible'), findsOneWidget);
      expect(find.text('Saisissez SUPPRIMER pour confirmer'), findsOneWidget);
      FilledButton confirm() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Supprimer mon compte'),
      );
      expect(
        confirm().onPressed,
        isNull,
        reason: 'disabled until the word is typed',
      );
      await tester.enterText(find.byType(TextField), 'supprim');
      await tester.pump();
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byType(TextField), ' supprimer ');
      await tester.pump();
      expect(
        confirm().onPressed,
        isNotNull,
        reason: 'case and spaces are forgiven',
      );
      expect(
        profiles.deleteCalls,
        0,
        reason: 'nothing happens until the button is pressed',
      );
    });

    testWidgets('cancel leaves everything as it was', (tester) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await _openDialog(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer votre compte ?'), findsNothing);
      expect(profiles.deleteCalls, 0);
      expect(
        find.textContaining('ali@example.tn'),
        findsOneWidget,
        reason: 'still signed in',
      );
    });

    testWidgets('the confirmation word is localized (Arabic and English)', (
      tester,
    ) async {
      for (final (lang, word, signedOutText) in [
        ('ar', 'حذف', 'سجّل الدخول أو أنشئ حسابًا'),
        ('en', 'DELETE', 'Sign in or create an account'),
      ]) {
        final profiles = FakeProfileRepository(profile: _aliProfile);
        final auth = FakeAuthRepository(signedIn: _ali);
        await pumpApp(
          tester,
          auth: auth,
          profiles: profiles,
          prefs: {'locale': lang},
        );
        await tester.tap(find.text(lang == 'ar' ? 'حسابي' : 'Profile'));
        await tester.pumpAndSettle();
        final label = lang == 'ar' ? 'حذف حسابي' : 'Delete my account';
        await scrollProfileTo(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), word);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, label));
        await tester.pumpAndSettle();
        expect(profiles.deleteCalls, 1, reason: lang);
        await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(find.text(signedOutText), findsOneWidget, reason: lang);
      }
    });
  });

  group('delete account: the effect', () {
    testWidgets(
      'deletes on the server, signs out, forgets the pending choice, confirms',
      (tester) async {
        final profiles = FakeProfileRepository(profile: _aliProfile);
        final auth = FakeAuthRepository(signedIn: _ali);
        final c = await pumpApp(tester, auth: auth, profiles: profiles);
        await c
            .read(pendingAccountChoiceProvider.notifier)
            .remember(AccountType.professional, 'someone@example.tn');
        await _openDialog(tester);
        await tester.enterText(find.byType(TextField), 'SUPPRIMER');
        await tester.pump();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Supprimer mon compte'),
        );
        await tester.pumpAndSettle();
        expect(profiles.deleteCalls, 1);
        expect(auth.signOutCalls, 1);
        expect(find.text('Votre compte a été supprimé.'), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(find.text('Connectez-vous ou créez un compte'), findsOneWidget);
        expect(c.read(pendingAccountChoiceProvider), isNull);
      },
    );

    testWidgets(
      'if the server refuses, the person stays signed in and is told',
      (tester) async {
        final profiles = FakeProfileRepository(profile: _aliProfile)
          ..failNext = ProfileFailure.network;
        final auth = FakeAuthRepository(signedIn: _ali);
        // The profile screen loads first; let that succeed, then fail the delete.
        await pumpApp(tester, auth: auth, profiles: profiles);
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        profiles.failNext = ProfileFailure.network;
        await scrollProfileTo(tester, find.text('Supprimer mon compte'));
        await tester.tap(find.text('Supprimer mon compte'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'SUPPRIMER');
        await tester.pump();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Supprimer mon compte'),
        );
        await tester.pumpAndSettle();
        expect(profiles.deleteCalls, 1);
        expect(
          auth.signOutCalls,
          0,
          reason: 'nothing was deleted, so nothing is signed out',
        );
        expect(
          find.text('Connexion impossible. Vérifiez votre réseau.'),
          findsOneWidget,
        );
        expect(find.textContaining('ali@example.tn'), findsOneWidget);
      },
    );

    testWidgets('the delete button is not offered when signed out', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte'), findsNothing);
    });

    testWidgets('a double confirmation sends one request', (tester) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      final first = c.read(profileActionsProvider.notifier).deleteAccount();
      final second = await c
          .read(profileActionsProvider.notifier)
          .deleteAccount();
      expect(
        second.isOk,
        isFalse,
        reason: 'refused while the first is running',
      );
      expect((await first).isOk, isTrue);
      expect(profiles.deleteCalls, 1);
    });
  });

  group('delete account: what goes over the wire', () {
    test('a single argument-less RPC; no user id is ever sent', () async {
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response(
          'null',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = SupabaseProfileRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: client,
        ),
        userId: () => 'u1',
      );
      await repo.deleteMyAccount();
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/rest/v1/rpc/delete_my_account');
      expect(['', '{}', 'null'], contains(r.body));
      expect(jsonEncode(r.url.queryParameters), isNot(contains('u1')));
    });

    test('server failures map to categories and never leak details', () async {
      for (final (status, code, expected) in [
        (401, 'PGRST301', ProfileFailure.notSignedIn),
        (403, '42501', ProfileFailure.notSignedIn),
        (500, 'XX000', ProfileFailure.unknown),
      ]) {
        final client = MockClient(
          (r) async => http.Response(
            jsonEncode({'code': code, 'message': 'secret internal detail'}),
            status,
            request: r,
            headers: {'content-type': 'application/json'},
          ),
        );
        final repo = SupabaseProfileRepository(
          sb.SupabaseClient(
            'https://abc.supabase.co',
            'sb_publishable_testkey',
            httpClient: client,
          ),
          userId: () => 'u1',
        );
        await expectLater(
          repo.deleteMyAccount(),
          throwsA(
            isA<ProfileError>()
                .having((e) => e.failure, 'failure', expected)
                .having(
                  (e) => e.toString(),
                  'toString',
                  isNot(contains('secret')),
                ),
          ),
        );
      }
    });
  });

  testWidgets('the dialog fits a small phone at 1.5x text in Arabic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final profiles = FakeProfileRepository(profile: _aliProfile);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedIn: _ali),
      profiles: profiles,
      prefs: {'locale': 'ar'},
    );
    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await scrollProfileTo(tester, find.text('حذف حسابي'));
    await tester.ensureVisible(find.text('حذف حسابي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف حسابي'));
    await tester.pumpAndSettle();
    expect(find.text('حذف حسابك؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
