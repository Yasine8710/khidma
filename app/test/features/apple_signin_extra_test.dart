import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/data/apple_sign_in.dart';
import 'package:khidma/features/auth/data/supabase_auth_repository.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/auth/presentation/apple_sign_in_button.dart';
import 'package:khidma/features/auth/presentation/login_screen.dart';
import 'package:khidma/features/profile/application/profile_providers.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

String _b64(Object o) =>
    base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

String _jwt() =>
    '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
    '${_b64({'sub': 'u-apple', 'role': 'authenticated', 'aud': 'authenticated', 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})}.sig';

Map<String, Object?> _session({String? name}) => {
  'access_token': _jwt(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': 'u-apple',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'apple@privaterelay.appleid.com',
    'app_metadata': {'provider': 'apple'},
    'user_metadata': {'full_name': ?name},
    'created_at': DateTime.now().toIso8601String(),
  },
};

class _MemoryPkce extends sb.GotrueAsyncStorage {
  final _m = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _m[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _m[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _m.remove(key);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openLogin(WidgetTester tester) async {
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Se connecter').first);
  await tester.pumpAndSettle();
}

Future<void> _openRegister(WidgetTester tester) async {
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Créer un compte').first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group(
    'SupabaseAuthRepository.signInWithApple: name and token edge cases',
    () {
      SupabaseAuthRepository build(
        AppleCredentialProvider apple, {
        List<http.Request>? log,
        bool failUserUpdate = false,
      }) {
        final client = MockClient((r) async {
          log?.add(r);
          if (r.method == 'PUT' && failUserUpdate) {
            return http.Response(
              '{"msg":"nope"}',
              500,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = r.url.path.endsWith('/user')
              ? _session()['user']!
              : _session();
          return http.Response(
            jsonEncode(body),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        });
        final auth = sb.GoTrueClient(
          url: 'https://abc.supabase.co/auth/v1',
          headers: const {'apikey': 'k'},
          httpClient: client,
          asyncStorage: _MemoryPkce(),
        );
        return SupabaseAuthRepository(auth, appleCredential: apple);
      }

      test(
        'returns the name Apple shared, and null when it shares none',
        () async {
          final first = build(
            ({required hashedNonce}) async => const AppleCredential(
              identityToken: 't',
              givenName: 'Karim',
              familyName: 'Ben Salah',
            ),
          );
          expect(await first.signInWithApple(), 'Karim Ben Salah');
          final later = build(
            ({required hashedNonce}) async =>
                const AppleCredential(identityToken: 't'),
          );
          expect(await later.signInWithApple(), isNull);
        },
      );

      test(
        'an empty-string token is refused like a missing one, sending nothing',
        () async {
          final log = <http.Request>[];
          final repo = build(
            ({required hashedNonce}) async =>
                const AppleCredential(identityToken: ''),
            log: log,
          );
          await expectLater(repo.signInWithApple(), throwsA(isA<AuthError>()));
          expect(log, isEmpty);
        },
      );

      test('a failing metadata update does not fail the sign-in', () async {
        final repo = build(
          ({required hashedNonce}) async =>
              const AppleCredential(identityToken: 't', givenName: 'Karim'),
          failUserUpdate: true,
        );
        expect(await repo.signInWithApple(), 'Karim');
        expect(repo.currentUser?.id, 'u-apple');
      });
    },
  );

  group('after Apple sign-in', () {
    final iosOn = appleSignInAvailableProvider.overrideWithValue(true);

    testWidgets(
      'the shared name fills an empty profile but never overwrites a typed one',
      (tester) async {
        final empty = FakeProfileRepository(
          profile: const AppProfile(id: 'apple-user'),
        );
        await pumpApp(
          tester,
          auth: FakeAuthRepository()..appleSharedName = 'Karim Ben Salah',
          profiles: empty,
          overrides: [iosOn],
        );
        await _openLogin(tester);
        await _scrollTo(tester, find.text('Continuer avec Apple'));
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(empty.updates.single.fullName, 'Karim Ben Salah');

        final named = FakeProfileRepository(
          profile: const AppProfile(id: 'apple-user', fullName: 'Typed Name'),
        );
        await pumpApp(
          tester,
          auth: FakeAuthRepository()..appleSharedName = 'Someone Else',
          profiles: named,
          overrides: [iosOn],
        );
        await _openLogin(tester);
        await _scrollTo(tester, find.text('Continuer avec Apple'));
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(named.updates, isEmpty);
      },
    );

    testWidgets('an over-long shared name is ignored', (tester) async {
      final profiles = FakeProfileRepository(
        profile: const AppProfile(id: 'apple-user'),
      );
      await pumpApp(
        tester,
        auth: FakeAuthRepository()..appleSharedName = 'x' * 121,
        profiles: profiles,
        overrides: [iosOn],
      );
      await _openLogin(tester);
      await _scrollTo(tester, find.text('Continuer avec Apple'));
      await tester.tap(find.text('Continuer avec Apple'));
      await tester.pumpAndSettle();
      expect(profiles.updates, isEmpty);
    });

    testWidgets('a failing profile lookup does not block signing in', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(
        profile: const AppProfile(id: 'apple-user'),
      )..failNext = ProfileFailure.network;
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository()..appleSharedName = 'Karim',
        profiles: profiles,
        overrides: [iosOn],
      );
      await _openLogin(tester);
      await _scrollTo(tester, find.text('Continuer avec Apple'));
      await tester.tap(find.text('Continuer avec Apple'));
      await tester.pumpAndSettle();
      expect(c.read(currentUserProvider)?.id, 'apple-user');
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      'choosing customer clears a stale pending professional choice',
      (tester) async {
        final profiles = FakeProfileRepository(
          profile: const AppProfile(id: 'apple-user'),
        );
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(),
          profiles: profiles,
          overrides: [iosOn],
        );
        await c
            .read(pendingAccountChoiceProvider.notifier)
            .remember(AccountType.professional, 'apple@privaterelay.example');
        await _openRegister(tester);
        await _scrollTo(tester, find.text('Continuer avec Apple'));
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(c.read(pendingAccountChoiceProvider), isNull);
      },
    );

    testWidgets(
      'if "offer services" cannot be applied, the choice stays pending for that account',
      (tester) async {
        final profiles = FakeProfileRepository(
          profile: const AppProfile(id: 'apple-user'),
        )..failNext = ProfileFailure.network;
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(),
          profiles: profiles,
          overrides: [iosOn],
        );
        await _openRegister(tester);
        await _scrollTo(tester, find.text('Proposer mes services'));
        await tester.tap(find.text('Proposer mes services'));
        await tester.pump();
        await _scrollTo(tester, find.text('Continuer avec Apple'));
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(
          c.read(pendingAccountChoiceProvider)?.email,
          'apple@privaterelay.example',
        );
        expect(
          profiles.becomeProfessionalCalls,
          greaterThanOrEqualTo(1),
          reason: 'the first attempt failed (offline) and the choice was kept',
        );
        // The Profile screen's own "Become a professional" button remains the
        // manual way to finish (covered in the profile tests).
      },
    );
  });
}
