import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/data/secure_auth_storage.dart';
import 'package:khidma/features/auth/data/supabase_auth_repository.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/auth/domain/auth_validators.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show supabasePersistSessionKey;

import '../support/fake_auth_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

void main() {
  setUpAll(loadAppFonts);

  group(
    'password limits follow Supabase (code points min, UTF-8 bytes max)',
    () {
      test('Arabic letters are 2 bytes each', () {
        expect(
          validateNewPassword('ا' * 7),
          FieldProblem.passwordTooShort,
          reason: '7 characters',
        );
        expect(
          validateNewPassword('ا' * 8),
          isNull,
          reason: '8 characters, 16 bytes',
        );
        expect(validateNewPassword('ا' * 36), isNull, reason: '72 bytes');
        expect(
          validateNewPassword('ا' * 37),
          FieldProblem.passwordTooLong,
          reason: '74 bytes',
        );
      });

      test('emoji are 4 bytes and one character each', () {
        expect(validateNewPassword('😀' * 8), isNull);
        expect(validateNewPassword('😀' * 18), isNull, reason: '72 bytes');
        expect(validateNewPassword('😀' * 19), FieldProblem.passwordTooLong);
        expect(validateNewPassword('😀' * 7), FieldProblem.passwordTooShort);
      });

      test('ASCII boundaries', () {
        expect(validateNewPassword('a' * 72), isNull);
        expect(validateNewPassword('a' * 73), FieldProblem.passwordTooLong);
      });
    },
  );

  group('session storage is secure, not shared preferences', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('the session round-trips through secure storage', () async {
      final s = SecureSessionStorage();
      expect(await s.hasAccessToken(), isFalse);
      await s.persistSession('{"access_token":"abc","refresh_token":"def"}');
      expect(await s.hasAccessToken(), isTrue);
      expect(await s.accessToken(), contains('refresh_token'));
      await s.removePersistedSession();
      expect(await s.hasAccessToken(), isFalse);
      expect(await s.accessToken(), isNull);
    });

    test('tokens never reach shared preferences', () async {
      await SecureSessionStorage().persistSession('{"refresh_token":"secret"}');
      await SecurePkceStorage().setItem(key: 'verifier', value: 'v');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('the PKCE verifier is stored, read and removed securely', () async {
      final s = SecurePkceStorage();
      expect(await s.getItem(key: 'k'), isNull);
      await s.setItem(key: 'k', value: 'verifier-123');
      expect(await s.getItem(key: 'k'), 'verifier-123');
      await s.removeItem(key: 'k');
      expect(await s.getItem(key: 'k'), isNull);
    });

    test('uses the SDK session key so the SDK finds it again', () async {
      await SecureSessionStorage().persistSession('x');
      expect(
        await const FlutterSecureStorage().read(key: supabasePersistSessionKey),
        'x',
      );
    });
  });

  group('password reset completes inside the app', () {
    testWidgets('opening the link shows the new-password form; saving works', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      await pumpApp(tester, auth: fake);
      fake.openRecoveryLink(asUser: _ali);
      await tester.pumpAndSettle();
      expect(find.text('Nouveau mot de passe'), findsWidgets);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enregistrer le mot de passe'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      expect(fake.passwordUpdates, isEmpty);
      await tester.enterText(_field('Mot de passe'), 'court');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enregistrer le mot de passe'),
      );
      await tester.pumpAndSettle();
      expect(find.text('8 caractères minimum.'), findsWidgets);
      await tester.enterText(_field('Mot de passe'), 'nouveau-mot-de-passe');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enregistrer le mot de passe'),
      );
      await tester.pumpAndSettle();
      expect(fake.passwordUpdates, ['nouveau-mot-de-passe']);
      expect(find.text('Mot de passe mis à jour.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Accueil'));
      await tester.pumpAndSettle();
      expect(find.text('De quel service avez-vous besoin ?'), findsOneWidget);
    });

    testWidgets(
      'a rejected new password (weak/rate limited) is explained and retryable',
      (tester) async {
        final fake = FakeAuthRepository();
        await pumpApp(tester, auth: fake);
        fake.openRecoveryLink(asUser: _ali);
        await tester.pumpAndSettle();
        await tester.enterText(_field('Mot de passe'), '12345678');
        fake.failNext = AuthFailure.weakPassword;
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enregistrer le mot de passe'),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Mot de passe trop faible'), findsOneWidget);
        expect(find.text('Mot de passe mis à jour.'), findsNothing);
      },
    );

    testWidgets(
      'without a recovery session (expired or opened directly) it says so',
      (tester) async {
        final c = await pumpApp(tester, auth: FakeAuthRepository());
        c.read(routerProvider).go(AppRoutes.resetPassword);
        await tester.pumpAndSettle();
        expect(find.text('Lien expiré ou invalide'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Mot de passe oublié ?'),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Mot de passe oublié ?'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);
      },
    );

    testWidgets(
      'direct entry to /forgot-password: "back to sign in" does not crash',
      (tester) async {
        final c = await pumpApp(tester, auth: FakeAuthRepository());
        c.read(routerProvider).go(AppRoutes.forgotPassword);
        await tester.pumpAndSettle();
        await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
        await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le lien'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retour à la connexion'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Bon retour'), findsOneWidget);
      },
    );

    testWidgets(
      'the new-password screen works in Arabic and on a small phone',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final fake = FakeAuthRepository();
        await pumpApp(tester, auth: fake, prefs: {'locale': 'ar'});
        fake.openRecoveryLink(asUser: _ali);
        await tester.pumpAndSettle();
        expect(find.text('كلمة مرور جديدة'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('sign-out feedback', () {
    testWidgets('a failing sign-out tells the user instead of staying silent', (
      tester,
    ) async {
      final fake = FakeAuthRepository(signedIn: _ali)
        ..failNext = AuthFailure.network;
      await pumpApp(tester, auth: fake);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      // Sign-out is a settings row near the end of the Profile list.
      await scrollProfileTo(tester, find.text('Se déconnecter'));
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );
    });
  });

  group('native deep-link configuration matches the redirect URL', () {
    final uri = Uri.parse(authRedirectUrl);

    test('the redirect URL is a custom scheme with a host', () {
      expect(uri.scheme, 'tn.khidma.app');
      expect(uri.host, 'auth-callback');
      expect(
        authRedirectUrl.endsWith('/'),
        isFalse,
        reason: 'extra slashes break Supabase matching',
      );
    });

    test(
      'Android registers the scheme and stops Flutter double-handling the link',
      () {
        final m = File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync();
        expect(m, contains('android:scheme="${uri.scheme}"'));
        expect(m, contains('android:host="${uri.host}"'));
        expect(m, contains('android.intent.category.BROWSABLE'));
        expect(m, contains('flutter_deeplinking_enabled'));
        expect(
          RegExp(r'flutter_deeplinking_enabled"\s+android:value="false"')
              .hasMatch(m),
          isTrue,
        );
      },
    );

    test(
      'iOS registers the scheme and stops Flutter double-handling the link',
      () {
        final p = File('ios/Runner/Info.plist').readAsStringSync();
        expect(p, contains('<string>${uri.scheme}</string>'));
        expect(p, contains('CFBundleURLSchemes'));
        expect(
          RegExp(r'FlutterDeepLinkingEnabled</key>\s*<false/>').hasMatch(p),
          isTrue,
        );
      },
    );
  });
}
