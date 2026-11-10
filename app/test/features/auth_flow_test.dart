import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';

import '../support/fake_auth_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(
  id: 'u1',
  email: 'ali@example.tn',
  fullName: 'Ali Ben Salah',
);

Future<void> _openLogin(WidgetTester tester) async {
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Se connecter').first);
  await tester.pumpAndSettle();
}

/// Scrolls the (long) form to the submit button, then taps it.
Future<void> _tapButton(WidgetTester tester, String label) async {
  final b = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(b);
  await tester.pumpAndSettle();
  await tester.tap(b);
}

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

void main() {
  setUpAll(loadAppFonts);

  group('signed-out tabs', () {
    testWidgets('Requests, Messages and Profile invite the user to sign in', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Demandes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connectez-vous pour voir vos demandes'),
        findsOneWidget,
      );
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Connectez-vous pour discuter'), findsOneWidget);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Connectez-vous ou créez un compte'), findsOneWidget);
    });

    testWidgets('the prompt buttons open login and register', (tester) async {
      final c = await pumpApp(tester);
      await tester.tap(find.text('Demandes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Bon retour'), findsOneWidget);
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();
      expect(find.text('Créez votre compte'), findsOneWidget);
    });

    testWidgets('a restored session shows signed-in content immediately', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository(signedIn: _ali));
      await tester.tap(find.text('Demandes'));
      await tester.pumpAndSettle();
      expect(find.text("Aucune demande pour l'instant"), findsOneWidget);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Ben Salah'), findsOneWidget);
      expect(find.text('Connecté en tant que ali@example.tn'), findsOneWidget);
    });

    testWidgets('the session ending elsewhere signs the UI out', (
      tester,
    ) async {
      final fake = FakeAuthRepository(signedIn: _ali);
      await pumpApp(tester, auth: fake);
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun message'), findsOneWidget);
      fake.emit(null);
      await tester.pumpAndSettle();
      expect(find.text('Connectez-vous pour discuter'), findsOneWidget);
    });
  });

  group('sign in', () {
    testWidgets('empty and malformed input is rejected before any request', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      await pumpApp(tester, auth: fake);
      await _openLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
      expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
      await tester.enterText(_field('Adresse e-mail'), 'pas-un-email');
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
      expect(fake.signInCalls, isEmpty);
    });

    testWidgets('success returns to Profile, signed in', (tester) async {
      final fake = FakeAuthRepository()
        ..accounts['ali@example.tn'] = 'secret-pass';
      await pumpApp(tester, auth: fake);
      await _openLogin(tester);
      await tester.enterText(_field('Adresse e-mail'), '  ali@example.tn ');
      await tester.enterText(_field('Mot de passe'), 'secret-pass');
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(fake.signInCalls.single.password, 'secret-pass');
      expect(
        find.text('Bon retour'),
        findsNothing,
        reason: 'login screen closed',
      );
      expect(find.text('Connecté en tant que ali@example.tn'), findsOneWidget);
    });

    testWidgets(
      'wrong credentials: friendly message, nothing cleared, can retry',
      (tester) async {
        final fake = FakeAuthRepository()
          ..accounts['ali@example.tn'] = 'right-pass';
        await pumpApp(tester, auth: fake);
        await _openLogin(tester);
        await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
        await tester.enterText(_field('Mot de passe'), 'wrong-pass');
        await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
        await tester.pumpAndSettle();
        expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
        expect(
          find.text('Bon retour'),
          findsOneWidget,
          reason: 'still on the login screen',
        );
        await tester.enterText(_field('Mot de passe'), 'right-pass');
        await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
        await tester.pumpAndSettle();
        expect(find.text('E-mail ou mot de passe incorrect.'), findsNothing);
        expect(
          find.text('Connecté en tant que ali@example.tn'),
          findsOneWidget,
        );
      },
    );

    testWidgets('every failure kind has its own message', (tester) async {
      final fake = FakeAuthRepository();
      await pumpApp(tester, auth: fake);
      await _openLogin(tester);
      await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
      await tester.enterText(_field('Mot de passe'), 'x');
      final expected = {
        AuthFailure.emailNotConfirmed:
            "Confirmez d'abord votre adresse e-mail (lien reçu par e-mail).",
        AuthFailure.rateLimited:
            'Trop de tentatives. Réessayez dans quelques minutes.',
        AuthFailure.network: 'Connexion impossible. Vérifiez votre réseau.',
        AuthFailure.unknown: 'Une erreur est survenue. Réessayez.',
        AuthFailure.invalidCredentials: 'E-mail ou mot de passe incorrect.',
      };
      for (final e in expected.entries) {
        fake.failNext = e.key;
        await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
        await tester.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget, reason: '${e.key}');
      }
    });

    testWidgets(
      'while signing in: spinner, fields locked, a second tap does nothing',
      (tester) async {
        final fake = FakeAuthRepository()
          ..accounts['ali@example.tn'] = 'secret-pass'
          ..gate = Completer<void>();
        await pumpApp(tester, auth: fake);
        await _openLogin(tester);
        await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
        await tester.enterText(_field('Mot de passe'), 'secret-pass');
        await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester.widget<TextField>(_field('Adresse e-mail')).enabled,
          isFalse,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Se connecter'),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(fake.signInCalls.length, 1, reason: 'no double submit');
        fake.gate!.complete();
        await tester.pumpAndSettle();
        expect(
          find.text('Connecté en tant que ali@example.tn'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the password is not shown by default and can be revealed', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await _openLogin(tester);
      EditableText pw() => tester.widget<EditableText>(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Mot de passe'),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byType(EditableText),
        ),
      );
      expect(pw().obscureText, isTrue);
      expect(pw().autocorrect, isFalse);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(pw().obscureText, isFalse);
    });

    testWidgets('links lead to registration and to password reset', (
      tester,
    ) async {
      final c = await pumpApp(tester, auth: FakeAuthRepository());
      await _openLogin(tester);
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer un compte').last);
      await tester.pumpAndSettle();
      expect(find.text('Créez votre compte'), findsOneWidget);
    });
  });

  group('register', () {
    Future<void> openRegister(WidgetTester tester) async {
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer un compte').first);
      await tester.pumpAndSettle();
    }

    testWidgets('validates name, email and password length', (tester) async {
      final fake = FakeAuthRepository();
      await pumpApp(tester, auth: fake);
      await openRegister(tester);
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(find.text('Saisissez votre nom.'), findsOneWidget);
      expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
      await tester.enterText(_field('Nom complet'), 'Ali');
      await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
      await tester.enterText(_field('Mot de passe'), 'court');
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(find.text('8 caractères minimum.'), findsWidgets);
      expect(fake.signUpCalls, isEmpty);
    });

    testWidgets(
      'sends the cleaned details and the UI language, then asks to confirm the email',
      (tester) async {
        final fake = FakeAuthRepository();
        await pumpApp(tester, auth: fake);
        await openRegister(tester);
        await tester.enterText(_field('Nom complet'), '  Ali Ben Salah ');
        await tester.enterText(_field('Adresse e-mail'), ' ali@example.tn ');
        await tester.enterText(_field('Mot de passe'), ' mot de passe 1 ');
        await _tapButton(tester, 'Créer un compte');
        await tester.pumpAndSettle();
        final call = fake.signUpCalls.single;
        expect(call.email, 'ali@example.tn');
        expect(call.language, 'fr');
        expect(
          call.password,
          ' mot de passe 1 ',
          reason: 'passwords are never trimmed',
        );
        expect(find.text('Confirmez votre adresse e-mail'), findsOneWidget);
        expect(find.textContaining('ali@example.tn'), findsOneWidget);
      },
    );

    testWidgets('when no confirmation is needed the user is signed in', (
      tester,
    ) async {
      final fake = FakeAuthRepository()..signUpOutcome = SignUpOutcome.signedIn;
      await pumpApp(tester, auth: fake);
      await openRegister(tester);
      await tester.enterText(_field('Nom complet'), 'Ali');
      await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
      await tester.enterText(_field('Mot de passe'), 'long-enough-1');
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(find.text('Connecté en tant que ali@example.tn'), findsOneWidget);
    });

    testWidgets('weak password and closed sign-ups get specific messages', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      await pumpApp(tester, auth: fake);
      await openRegister(tester);
      await tester.enterText(_field('Nom complet'), 'Ali');
      await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
      await tester.enterText(_field('Mot de passe'), '12345678');
      fake.failNext = AuthFailure.weakPassword;
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(find.textContaining('Mot de passe trop faible'), findsOneWidget);
      fake.failNext = AuthFailure.signUpDisabled;
      // The error notice pushed the button down: scroll it into view.
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Créer un compte'),
      );
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(
        find.text('Les inscriptions sont fermées pour le moment.'),
        findsOneWidget,
      );
    });

    testWidgets('the language chosen in the app is what gets sent (Arabic)', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      await pumpApp(tester, auth: fake, prefs: {'locale': 'ar'});
      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء حساب').first);
      await tester.pumpAndSettle();
      await tester.enterText(_field('الاسم الكامل'), 'خالد');
      await tester.enterText(_field('البريد الإلكتروني'), 'k@example.tn');
      await tester.enterText(_field('كلمة المرور'), 'long-enough-1');
      await _tapButton(tester, 'إنشاء حساب');
      await tester.pumpAndSettle();
      expect(fake.signUpCalls.single.language, 'ar');
      expect(fake.signUpCalls.single.fullName, 'خالد');
    });
  });

  group('forgot password', () {
    testWidgets(
      'shows the same confirmation whether or not an account exists',
      (tester) async {
        final fake = FakeAuthRepository();
        await pumpApp(tester, auth: fake);
        await _openLogin(tester);
        await tester.tap(find.text('Mot de passe oublié ?'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le lien'));
        await tester.pumpAndSettle();
        expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
        await tester.enterText(_field('Adresse e-mail'), 'inconnu@example.tn');
        await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le lien'));
        await tester.pumpAndSettle();
        expect(fake.resetCalls, ['inconnu@example.tn']);
        expect(find.text('Vérifiez vos e-mails'), findsOneWidget);
        expect(find.textContaining('Si un compte existe'), findsOneWidget);
      },
    );

    testWidgets('rate limiting is reported', (tester) async {
      final fake = FakeAuthRepository()..failNext = AuthFailure.rateLimited;
      await pumpApp(tester, auth: fake);
      await _openLogin(tester);
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
      await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le lien'));
      await tester.pumpAndSettle();
      expect(
        find.text('Trop de tentatives. Réessayez dans quelques minutes.'),
        findsOneWidget,
      );
      expect(find.text('Vérifiez vos e-mails'), findsNothing);
    });
  });

  group('sign out', () {
    testWidgets('signs out and shows the invitation again', (tester) async {
      final fake = FakeAuthRepository(signedIn: _ali);
      await pumpApp(tester, auth: fake);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(fake.signOutCalls, 1);
      expect(find.text('Connectez-vous ou créez un compte'), findsOneWidget);
    });
  });

  group('no backend configured', () {
    testWidgets('screens explain it honestly and cannot be submitted', (
      tester,
    ) async {
      await pumpApp(tester, auth: const NotConfiguredAuthRepository());
      await _openLogin(tester);
      expect(
        find.text(
          "Les comptes ne sont pas disponibles dans cette version de l'application.",
        ),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Se connecter'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('layout', () {
    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets(
        'login, register and reset fit a small phone at 1.5x text ($lang)',
        (tester) async {
          tester.view.physicalSize = const Size(320 * 3, 568 * 3);
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final c = await pumpApp(
            tester,
            auth: FakeAuthRepository(),
            prefs: {'locale': lang},
          );
          for (final path in [
            AppRoutes.login,
            AppRoutes.register,
            AppRoutes.forgotPassword,
          ]) {
            c.read(routerProvider).push(path);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$lang $path');
            c.read(routerProvider).pop();
            await tester.pumpAndSettle();
          }
        },
      );
    }

    testWidgets(
      'Arabic login is RTL but email and password fields stay left-to-right',
      (tester) async {
        await pumpApp(
          tester,
          auth: FakeAuthRepository(),
          prefs: {'locale': 'ar'},
        );
        await tester.tap(find.text('حسابي'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تسجيل الدخول').first);
        await tester.pumpAndSettle();
        expect(find.text('مرحبًا بعودتك'), findsOneWidget);
        expect(screenDirection(tester), TextDirection.rtl);
        for (final label in ['البريد الإلكتروني', 'كلمة المرور']) {
          expect(
            tester.widget<TextField>(_field(label)).textDirection,
            TextDirection.ltr,
            reason: label,
          );
        }
      },
    );
  });

  testWidgets('auth providers: busy flag toggles around an action', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..gate = Completer<void>();
    final c = await pumpApp(tester, auth: fake);
    expect(c.read(authActionsProvider), isFalse);
    final future = c
        .read(authActionsProvider.notifier)
        .sendPasswordReset('a@b.co');
    await tester.pump();
    expect(c.read(authActionsProvider), isTrue);
    fake.gate!.complete();
    final r = await future;
    expect(r.isOk, isTrue);
    expect(c.read(authActionsProvider), isFalse);
    expect(c.read(currentUserProvider), isNull);
    // A second action while busy is refused.
    fake.gate = Completer<void>();
    final first = c
        .read(authActionsProvider.notifier)
        .sendPasswordReset('a@b.co');
    await tester.pump();
    final second = await c
        .read(authActionsProvider.notifier)
        .sendPasswordReset('c@d.co');
    expect(second.isOk, isFalse);
    expect(fake.resetCalls, ['a@b.co', 'a@b.co']);
    fake.gate!.complete();
    await first;
    // Silence an unused-variable lint for the provider import in this file.
    expect(ProviderScope, isNotNull);
  });
}
