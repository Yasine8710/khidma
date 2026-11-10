import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' hide generateNonce;
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

/// The auth forms are lazy lists: scroll until the target has been built.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('nonce', () {
    test('is long, URL-safe, random and not reused', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final n = generateNonce();
        expect(n.length, 32);
        expect(RegExp(r'^[A-Za-z0-9\-._]+$').hasMatch(n), isTrue, reason: n);
        seen.add(n);
      }
      expect(seen.length, 200, reason: 'no collisions in 200 draws');
    });

    test('is deterministic only when given a seeded generator (tests)', () {
      expect(generateNonce(Random(1)), generateNonce(Random(1)));
      expect(generateNonce(Random(1)), isNot(generateNonce(Random(2))));
    });

    test('sha256 matches the standard test vectors', () {
      expect(
        sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
  });

  group('AppleCredential', () {
    test('joins the name parts that exist', () {
      expect(
        const AppleCredential(
          givenName: ' Karim ',
          familyName: 'Ben Salah',
        ).fullName,
        'Karim Ben Salah',
      );
      expect(const AppleCredential(givenName: 'Karim').fullName, 'Karim');
      expect(const AppleCredential(familyName: '  ').fullName, isNull);
      expect(const AppleCredential().fullName, isNull);
    });

    test('closing Apple\'s sheet is a cancellation; other errors are not', () {
      expect(
        isAppleCancellation(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'x',
          ),
        ),
        isTrue,
      );
      expect(
        isAppleCancellation(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'x',
          ),
        ),
        isFalse,
      );
      expect(isAppleCancellation(StateError('x')), isFalse);
      expect(
        mapAuthException(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'x',
          ),
        ),
        AuthFailure.cancelled,
      );
    });
  });

  group(
    'SupabaseAuthRepository.signInWithApple over a recorded HTTP layer',
    () {
      late List<http.Request> requests;
      late String? hashedNonceSeen;

      SupabaseAuthRepositoryForTest build(
        AppleCredentialProvider apple, {
        String? name,
      }) {
        requests = [];
        final client = MockClient((r) async {
          requests.add(r);
          Object body = <String, Object?>{};
          if (r.url.path.endsWith('/token')) {
            body = _session();
          } else if (r.url.path.endsWith('/user')) {
            body = _session(name: name)['user']!;
          }
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
        return SupabaseAuthRepositoryForTest(auth, apple);
      }

      test('sends Apple the HASH and Supabase the ORIGINAL nonce', () async {
        hashedNonceSeen = null;
        final t = build(({required hashedNonce}) async {
          hashedNonceSeen = hashedNonce;
          return const AppleCredential(identityToken: 'apple.id.token');
        });
        await t.repo.signInWithApple();
        final tokenReq = requests.firstWhere(
          (r) => r.url.path.endsWith('/token'),
        );
        expect(tokenReq.url.queryParameters['grant_type'], 'id_token');
        final body = jsonDecode(tokenReq.body) as Map<String, dynamic>;
        expect(body['provider'], 'apple');
        expect(body['id_token'], 'apple.id.token');
        final raw = body['nonce'] as String;
        expect(
          raw,
          isNot(hashedNonceSeen),
          reason: 'the original never goes to Apple',
        );
        expect(
          sha256Hex(raw),
          hashedNonceSeen,
          reason: 'Apple received SHA-256(original)',
        );
        expect(t.repo.currentUser?.id, 'u-apple');
      });

      test('each attempt uses a fresh nonce', () async {
        final seen = <String>[];
        final t = build(({required hashedNonce}) async {
          seen.add(hashedNonce);
          return const AppleCredential(identityToken: 't');
        });
        await t.repo.signInWithApple();
        await t.repo.signInWithApple();
        expect(seen.toSet().length, 2);
      });

      test('keeps the name Apple shares on first sign-in', () async {
        final t = build(
          ({required hashedNonce}) async => const AppleCredential(
            identityToken: 't',
            givenName: 'Karim',
            familyName: 'Ben Salah',
          ),
          name: 'Karim Ben Salah',
        );
        await t.repo.signInWithApple();
        final put = requests.where(
          (r) => r.method == 'PUT' && r.url.path.endsWith('/user'),
        );
        expect(put, isNotEmpty);
        expect(jsonDecode(put.first.body)['data'], {
          'full_name': 'Karim Ben Salah',
        });
      });

      test('does not touch the name when Apple shares none', () async {
        final t = build(
          ({required hashedNonce}) async =>
              const AppleCredential(identityToken: 't'),
        );
        await t.repo.signInWithApple();
        expect(requests.where((r) => r.method == 'PUT'), isEmpty);
      });

      test(
        'a missing identity token is a failure, and nothing is sent',
        () async {
          final t = build(
            ({required hashedNonce}) async => const AppleCredential(),
          );
          await expectLater(
            t.repo.signInWithApple(),
            throwsA(
              isA<AuthError>().having(
                (e) => e.failure,
                'failure',
                AuthFailure.unknown,
              ),
            ),
          );
          expect(requests, isEmpty);
        },
      );

      test(
        'closing Apple\'s sheet surfaces as "cancelled" and sends nothing',
        () async {
          final t = build(
            ({required hashedNonce}) async =>
                throw const SignInWithAppleAuthorizationException(
                  code: AuthorizationErrorCode.canceled,
                  message: 'x',
                ),
          );
          await expectLater(
            t.repo.signInWithApple(),
            throwsA(
              isA<AuthError>().having(
                (e) => e.failure,
                'failure',
                AuthFailure.cancelled,
              ),
            ),
          );
          expect(requests, isEmpty);
        },
      );
    },
  );

  group('button and screens', () {
    testWidgets(
      'hidden where Apple sign-in is not available (default in tests: not iOS)',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Se connecter').first);
        await tester.pumpAndSettle();
        expect(find.text('Continuer avec Apple'), findsNothing);
      },
    );

    testWidgets(
      'on iOS, tapping it signs in; cancelling shows nothing; failures are explained',
      (tester) async {
        final fake = FakeAuthRepository();
        final c = await pumpApp(
          tester,
          auth: fake,
          overrides: [appleSignInAvailableProvider.overrideWithValue(true)],
        );
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Se connecter').first);
        await tester.pumpAndSettle();
        expect(find.text('Continuer avec Apple'), findsOneWidget);
        expect(find.text('ou'), findsOneWidget);

        fake.failNext = AuthFailure.cancelled;
        await tester.ensureVisible(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(fake.appleCalls, 1);
        expect(
          find.byType(LoginScreen),
          findsOneWidget,
          reason: 'still on the sign-in screen',
        );
        expect(
          find.byIcon(Icons.error_outline_rounded),
          findsNothing,
          reason: 'cancelling is not an error',
        );

        fake.failNext = AuthFailure.network;
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(
          find.text('Connexion impossible. Vérifiez votre réseau.'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsNothing);
        expect(
          c.read(currentUserProvider)?.email,
          'apple@privaterelay.example',
        );
      },
    );

    testWidgets(
      'on the register screen, "offer services" is applied after Apple sign-in',
      (tester) async {
        final fake = FakeAuthRepository();
        final profiles = FakeProfileRepository(
          profile: const AppProfile(id: 'apple-user'),
        );
        await pumpApp(
          tester,
          auth: fake,
          profiles: profiles,
          overrides: [appleSignInAvailableProvider.overrideWithValue(true)],
        );
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Créer un compte').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Proposer mes services'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Proposer mes services'));
        await tester.pump();
        await tester.ensureVisible(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuer avec Apple'));
        await tester.pumpAndSettle();
        expect(fake.appleCalls, 1);
        expect(profiles.becomeProfessionalCalls, 1);
      },
    );

    testWidgets('a customer choice never makes the Apple user a professional', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      final profiles = FakeProfileRepository(
        profile: const AppProfile(id: 'apple-user'),
      );
      await pumpApp(
        tester,
        auth: fake,
        profiles: profiles,
        overrides: [appleSignInAvailableProvider.overrideWithValue(true)],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer un compte').first);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Continuer avec Apple'));
      await tester.tap(find.text('Continuer avec Apple'));
      await tester.pumpAndSettle();
      expect(fake.appleCalls, 1);
      expect(profiles.becomeProfessionalCalls, 0);
    });

    testWidgets('no backend: the button is hidden even on iOS', (tester) async {
      await pumpApp(
        tester,
        auth: const NotConfiguredAuthRepository(),
        overrides: [appleSignInAvailableProvider.overrideWithValue(true)],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter').first);
      await tester.pumpAndSettle();
      expect(find.text('Continuer avec Apple'), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets(
        'follows Apple\'s styling: black button in light mode, white in dark (dark=$dark)',
        (tester) async {
          await pumpApp(
            tester,
            auth: FakeAuthRepository(),
            prefs: {'themeMode': dark ? 'dark' : 'light'},
            overrides: [appleSignInAvailableProvider.overrideWithValue(true)],
          );
          await tester.tap(find.text('Profil'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Se connecter').first);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Continuer avec Apple'));
          await tester.pumpAndSettle();
          final material = tester.widget<Material>(
            find
                .ancestor(
                  of: find.text('Continuer avec Apple'),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(material.color, dark ? Colors.white : Colors.black);
        },
      );
    }

    testWidgets('fits a small phone in Arabic at 1.5x text', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        prefs: {'locale': 'ar'},
        overrides: [appleSignInAvailableProvider.overrideWithValue(true)],
      );
      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل الدخول').first);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('المتابعة عبر Apple'));
      expect(find.text('المتابعة عبر Apple'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('iOS project configuration', () {
    test('the Sign in with Apple entitlement file exists and is wired into the Runner target', () {
      final e = File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(e, contains('com.apple.developer.applesignin'));
      expect(e, contains('<string>Default</string>'));
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
            .allMatches(pbx)
            .length,
        3,
        reason: 'Debug, Release, Profile',
      );
    });
  });
}

/// A repository plus the credential provider it was built with.
class SupabaseAuthRepositoryForTest {
  SupabaseAuthRepositoryForTest(
    sb.GoTrueClient auth,
    AppleCredentialProvider apple,
  ) : repo = SupabaseAuthRepository(auth, appleCredential: apple);
  final SupabaseAuthRepository repo;
}

/// PKCE storage that stays in memory (nothing touches disk in tests).
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
