import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/profile/application/profile_providers.dart';
import 'package:khidma/features/profile/data/supabase_profile_repository.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:khidma/features/profile/presentation/account_type_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn', fullName: 'Ali');
const _aliProfile = AppProfile(
  id: 'u1',
  fullName: 'Ali Ben Salah',
  phone: '+21620123456',
);

/// A stored pending choice, as the app writes it.
String _pending(String email, {Duration age = Duration.zero}) => jsonEncode({
  'type': 'professional',
  'email': email,
  'at': DateTime.now().subtract(age).millisecondsSinceEpoch,
});

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

Future<void> _tapButton(WidgetTester tester, String label) async {
  final b = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(b);
  await tester.pumpAndSettle();
  await tester.tap(b);
}

/// The register form is longer than the test screen: scroll to the option.
Future<void> _choose(WidgetTester tester, String option) async {
  await tester.ensureVisible(find.text(option));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pump();
}

Future<void> _openRegister(WidgetTester tester) async {
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Créer un compte').first);
  await tester.pumpAndSettle();
}

Future<void> _fillRegister(WidgetTester tester) async {
  await tester.enterText(_field('Nom complet'), 'Ali');
  await tester.enterText(_field('Adresse e-mail'), 'ali@example.tn');
  await tester.enterText(_field('Mot de passe'), 'long-enough-1');
}

void main() {
  setUpAll(loadAppFonts);

  group('mapProfileException', () {
    ProfileFailure code(String c) =>
        mapProfileException(sb.PostgrestException(message: 'm', code: c));
    test('database errors map to categories', () {
      expect(code('23514'), ProfileFailure.invalidData);
      expect(code('22001'), ProfileFailure.invalidData);
      expect(code('42501'), ProfileFailure.notSignedIn);
      expect(code('28000'), ProfileFailure.notSignedIn);
      expect(code('PGRST301'), ProfileFailure.notSignedIn);
      expect(code('XX000'), ProfileFailure.unknown);
    });
    test('other failures', () {
      expect(
        mapProfileException(const ProfileError(ProfileFailure.network)),
        ProfileFailure.network,
      );
      expect(
        mapProfileException(const sb.AuthException('x')),
        ProfileFailure.notSignedIn,
      );
      expect(mapProfileException(StateError('x')), ProfileFailure.unknown);
    });
  });

  test('there is no way to choose admin: only two account types exist', () {
    expect(AccountType.values.map((e) => e.name), ['customer', 'professional']);
  });

  group('account type at sign-up', () {
    testWidgets(
      'customer is the default and both options are exclusive and labelled',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester);
        await _openRegister(tester);
        expect(find.byType(AccountTypeSelector), findsOneWidget);
        expect(find.text('Trouver un professionnel'), findsOneWidget);
        expect(find.text('Proposer mes services'), findsOneWidget);
        final customer = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Trouver un professionnel')),
        );
        expect(
          customer,
          isSemantics(
            isButton: true,
            isChecked: true,
            hasCheckedState: true,
            hasTapAction: true,
          ),
        );
        final pro = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Proposer mes services')),
        );
        expect(
          pro,
          isSemantics(
            isButton: true,
            isChecked: false,
            hasCheckedState: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'professional + email confirmation: applied on the first session, then forgotten',
      (tester) async {
        final auth = FakeAuthRepository();
        final profiles = FakeProfileRepository(profile: _aliProfile);
        final c = await pumpApp(tester, auth: auth, profiles: profiles);
        await _openRegister(tester);
        await _fillRegister(tester);
        await _choose(tester, 'Proposer mes services');
        await _tapButton(tester, 'Créer un compte');
        await tester.pumpAndSettle();
        expect(find.text('Confirmez votre adresse e-mail'), findsOneWidget);
        expect(profiles.becomeProfessionalCalls, 0, reason: 'no session yet');
        expect(c.read(pendingAccountChoiceProvider)?.email, 'ali@example.tn');

        // The user opens the confirmation link: a session appears.
        auth.emit(_ali);
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 1);
        expect(c.read(pendingAccountChoiceProvider), isNull);
        auth.emit(null);
        auth.emit(_ali);
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 1, reason: 'only once');
      },
    );

    testWidgets(
      'professional without email confirmation is set up immediately',
      (tester) async {
        final auth = FakeAuthRepository()
          ..signUpOutcome = SignUpOutcome.signedIn;
        final profiles = FakeProfileRepository(profile: _aliProfile);
        await pumpApp(tester, auth: auth, profiles: profiles);
        await _openRegister(tester);
        await _fillRegister(tester);
        await _choose(tester, 'Proposer mes services');
        await _tapButton(tester, 'Créer un compte');
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 1);
      },
    );

    testWidgets('customer sign-up never makes anyone a professional', (
      tester,
    ) async {
      final auth = FakeAuthRepository()..signUpOutcome = SignUpOutcome.signedIn;
      final profiles = FakeProfileRepository(profile: _aliProfile);
      final c = await pumpApp(tester, auth: auth, profiles: profiles);
      await _openRegister(tester);
      await _fillRegister(tester);
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(profiles.becomeProfessionalCalls, 0);
      expect(c.read(pendingAccountChoiceProvider), isNull);
    });

    testWidgets('a failed sign-up forgets the choice', (tester) async {
      final auth = FakeAuthRepository()..failNext = AuthFailure.weakPassword;
      final c = await pumpApp(tester, auth: auth);
      await _openRegister(tester);
      await _fillRegister(tester);
      await _choose(tester, 'Proposer mes services');
      await _tapButton(tester, 'Créer un compte');
      await tester.pumpAndSettle();
      expect(c.read(pendingAccountChoiceProvider), isNull);
    });

    testWidgets(
      'a stored choice survives a restart; garbage and expired ones do not',
      (tester) async {
        final c = await pumpApp(
          tester,
          prefs: {'pendingAccountChoice': _pending('ali@example.tn')},
        );
        expect(c.read(pendingAccountChoiceProvider)?.email, 'ali@example.tn');
        final garbage = await pumpApp(
          tester,
          prefs: {'pendingAccountChoice': 'garbage'},
        );
        expect(garbage.read(pendingAccountChoiceProvider), isNull);
        final old = await pumpApp(
          tester,
          prefs: {
            'pendingAccountChoice': _pending(
              'ali@example.tn',
              age: const Duration(days: 8),
            ),
          },
        );
        expect(
          old.read(pendingAccountChoiceProvider),
          isNull,
          reason: 'expired after 7 days',
        );
      },
    );

    testWidgets('an expired choice is never applied', (tester) async {
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: auth,
        profiles: profiles,
        prefs: {
          'pendingAccountChoice': _pending(
            'ali@example.tn',
            age: const Duration(days: 30),
          ),
        },
      );
      auth.emit(_ali);
      await tester.pumpAndSettle();
      expect(profiles.becomeProfessionalCalls, 0);
    });

    testWidgets(
      'only the account that made the choice can act on it (case-insensitive email)',
      (tester) async {
        final auth = FakeAuthRepository();
        final profiles = FakeProfileRepository(
          profile: const AppProfile(id: 'u2'),
        );
        final c = await pumpApp(
          tester,
          auth: auth,
          profiles: profiles,
          prefs: {'pendingAccountChoice': _pending('ali@example.tn')},
        );
        // A different person signs in on this device first.
        auth.emit(const AuthUser(id: 'u2', email: 'sami@example.tn'));
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 0, reason: 'not their choice');
        expect(
          c.read(pendingAccountChoiceProvider)?.email,
          'ali@example.tn',
          reason: 'left untouched',
        );
        // Then the right person (different letter case) signs in.
        profiles.profile = _aliProfile;
        auth.emit(const AuthUser(id: 'u1', email: 'ALI@Example.TN'));
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 1);
        expect(c.read(pendingAccountChoiceProvider), isNull);
      },
    );

    testWidgets(
      'if setup fails (offline), the choice stays pending for that account',
      (tester) async {
        final auth = FakeAuthRepository();
        final profiles = FakeProfileRepository(profile: _aliProfile)
          ..failNext = ProfileFailure.network;
        final c = await pumpApp(
          tester,
          auth: auth,
          profiles: profiles,
          prefs: {'pendingAccountChoice': _pending('ali@example.tn')},
        );
        auth.emit(_ali);
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 1);
        expect(c.read(pendingAccountChoiceProvider)?.email, 'ali@example.tn');
      },
    );

    testWidgets(
      'a persistence failure does not lose the choice for this session',
      (tester) async {
        final c = await pumpApp(tester);
        await c
            .read(pendingAccountChoiceProvider.notifier)
            .remember(AccountType.professional, ' Ali@Example.tn ');
        expect(
          c.read(pendingAccountChoiceProvider)?.email,
          'ali@example.tn',
          reason: 'trimmed and lower-cased',
        );
        await c
            .read(pendingAccountChoiceProvider.notifier)
            .remember(AccountType.customer, 'ali@example.tn');
        expect(
          c.read(pendingAccountChoiceProvider),
          isNull,
          reason: 'picking customer forgets it',
        );
      },
    );
  });

  group('PendingAccountChoice parsing', () {
    test('accepts only well-formed professional choices', () {
      expect(
        PendingAccountChoice.tryParse(_pending('a@b.co'))?.email,
        'a@b.co',
      );
      for (final bad in [
        null,
        '',
        'not json',
        '[]',
        '{"type":"admin","email":"a@b.co","at":1}',
        '{"type":"professional","email":"","at":1}',
        '{"type":"professional","email":"a@b.co"}',
        '{"type":"professional","email":3,"at":1}',
        '{"type":"professional","email":"a@b.co","at":"x"}',
      ]) {
        expect(PendingAccountChoice.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('isFor ignores case and whitespace but not the address', () {
      final c = PendingAccountChoice(
        email: 'ali@example.tn',
        createdAt: DateTime.now(),
      );
      expect(c.isFor(' ALI@example.TN '), isTrue);
      expect(c.isFor('sami@example.tn'), isFalse);
      expect(c.isFor(null), isFalse);
    });
  });

  group('profile screen', () {
    testWidgets(
      'a customer sees the invitation; tapping it makes them a professional',
      (tester) async {
        final profiles = FakeProfileRepository(profile: _aliProfile);
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          profiles: profiles,
        );
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(find.text('Proposez vos services'), findsOneWidget);
        expect(find.text('Professionnel'), findsNothing);
        await tester.ensureVisible(find.text('Devenir professionnel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Devenir professionnel'));
        await tester.pumpAndSettle();
        expect(profiles.becomeProfessionalCalls, 1);
        expect(find.text('Professionnel'), findsOneWidget);
        expect(find.text('Devenir professionnel'), findsNothing);
      },
    );

    testWidgets('a professional sees the badge, not the invitation', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(
        profile: _aliProfile.copyWith(isProfessional: true),
      );
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Professionnel'), findsOneWidget);
      expect(find.text('Devenir professionnel'), findsNothing);
    });

    testWidgets('a failing "become professional" explains itself', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      profiles.failNext = ProfileFailure.network;
      await tester.ensureVisible(find.text('Devenir professionnel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devenir professionnel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );
    });

    testWidgets('signed out: no professional section, no profile request', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(tester, profiles: profiles);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Proposez vos services'), findsNothing);
      expect(profiles.fetchCalls, 0);
    });

    testWidgets("switching accounts never shows the previous person's profile", (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedIn: _ali);
      final profiles = FakeProfileRepository(
        profile: _aliProfile.copyWith(isProfessional: true),
      );
      final c = await pumpApp(tester, auth: auth, profiles: profiles);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Professionnel'), findsOneWidget);
      // Someone else signs in on the same device; their profile is a customer.
      profiles.profile = const AppProfile(id: 'u2', fullName: 'Sami');
      auth.emit(const AuthUser(id: 'u2', email: 'sami@example.tn'));
      await tester.pumpAndSettle();
      expect(find.text('Professionnel'), findsNothing);
      expect(find.text('Devenir professionnel'), findsOneWidget);
      expect(c.read(myProfileProvider).value?.id, 'u2');
    });

    testWidgets(
      "while the next account's profile loads, nothing of the previous one shows",
      (tester) async {
        final auth = FakeAuthRepository(signedIn: _ali);
        final profiles = FakeProfileRepository(
          profile: _aliProfile.copyWith(isProfessional: true),
        );
        await pumpApp(tester, auth: auth, profiles: profiles);
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(find.text('Professionnel'), findsOneWidget);
        // Account B signs in; B's profile is slow, and then fails.
        profiles.gate = Completer<void>();
        auth.emit(const AuthUser(id: 'u2', email: 'sami@example.tn'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.text('Professionnel'),
          findsNothing,
          reason: 'loading: no stale badge',
        );
        expect(find.text('Devenir professionnel'), findsNothing);
        profiles.failNext = ProfileFailure.network;
        profiles.gate!.complete();
        await tester.pumpAndSettle();
        expect(
          find.text('Professionnel'),
          findsNothing,
          reason: 'failed: still no stale badge',
        );
        expect(
          find.text('Connecté en tant que sami@example.tn'),
          findsOneWidget,
        );
      },
    );

    testWidgets('signing out clears the profile immediately', (tester) async {
      final auth = FakeAuthRepository(signedIn: _ali);
      final profiles = FakeProfileRepository(
        profile: _aliProfile.copyWith(isProfessional: true),
      );
      final c = await pumpApp(tester, auth: auth, profiles: profiles);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.text('Professionnel'), findsNothing);
      expect(c.read(visibleProfileProvider), isNull);
    });

    testWidgets('after saving, the header shows the saved name', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Ben Salah'), findsOneWidget);
      await tester.tap(find.text('Modifier le profil'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nom complet'), 'Nouveau Nom');
      await _tapButton(tester, 'Enregistrer');
      await tester.pumpAndSettle();
      expect(find.text('Nouveau Nom'), findsOneWidget);
      expect(find.text('Ali Ben Salah'), findsNothing);
    });

    testWidgets('a profile that belongs to someone else is rejected', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(
        profile: const AppProfile(id: 'someone-else', isProfessional: true),
      );
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(c.read(myProfileProvider), isA<AsyncError<AppProfile?>>());
      expect(find.text('Professionnel'), findsNothing);
    });
  });

  group('edit profile', () {
    Future<void> openEdit(WidgetTester tester) async {
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier le profil'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows current values (phone in national format)', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await openEdit(tester);
      expect(
        tester.widget<TextField>(_field('Nom complet')).controller!.text,
        'Ali Ben Salah',
      );
      expect(
        tester.widget<TextField>(_field('Téléphone')).controller!.text,
        '+216 20 123 456',
      );
    });

    testWidgets(
      'saves a trimmed name, an E.164 phone and the current language, then returns',
      (tester) async {
        final profiles = FakeProfileRepository(profile: _aliProfile);
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          profiles: profiles,
        );
        await openEdit(tester);
        await tester.enterText(_field('Nom complet'), '  Ali B.  ');
        await tester.enterText(_field('Téléphone'), '71 123 456');
        await _tapButton(tester, 'Enregistrer');
        await tester.pumpAndSettle();
        final u = profiles.updates.single;
        expect(
          u.fullName,
          '  Ali B.  ',
          reason: 'trimming happens in the repository',
        );
        expect(u.phone, '+21671123456');
        expect(u.language, 'fr');
        expect(find.text('Profil enregistré.'), findsOneWidget);
        expect(
          find.text('Modifier le profil'),
          findsWidgets,
          reason: 'back on the Profile screen',
        );
      },
    );

    testWidgets(
      'an empty phone clears it; an invalid one is refused before any request',
      (tester) async {
        final profiles = FakeProfileRepository(profile: _aliProfile);
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          profiles: profiles,
        );
        await openEdit(tester);
        await tester.enterText(_field('Téléphone'), '12345');
        await _tapButton(tester, 'Enregistrer');
        await tester.pumpAndSettle();
        expect(find.textContaining('Numéro tunisien invalide'), findsOneWidget);
        expect(profiles.updates, isEmpty);
        await tester.enterText(_field('Téléphone'), '');
        await _tapButton(tester, 'Enregistrer');
        await tester.pumpAndSettle();
        expect(profiles.updates.single.phone, isNull);
      },
    );

    testWidgets('a name is required', (tester) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await openEdit(tester);
      await tester.enterText(_field('Nom complet'), '   ');
      await _tapButton(tester, 'Enregistrer');
      await tester.pumpAndSettle();
      expect(find.text('Saisissez votre nom.'), findsOneWidget);
      expect(profiles.updates, isEmpty);
    });

    testWidgets('server refusal shows a message and keeps the form', (
      tester,
    ) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await openEdit(tester);
      await tester.enterText(_field('Nom complet'), 'Nouveau');
      profiles.failNext = ProfileFailure.invalidData;
      await _tapButton(tester, 'Enregistrer');
      await tester.pumpAndSettle();
      expect(
        find.text('Certaines informations sont invalides.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(_field('Nom complet')).controller!.text,
        'Nouveau',
      );
    });

    testWidgets('a load failure offers a retry that works', (tester) async {
      final profiles = FakeProfileRepository(profile: _aliProfile)
        ..failNext = ProfileFailure.network;
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier le profil'));
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger votre profil.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Nom complet'), findsOneWidget);
    });

    testWidgets('a double tap on Save sends one request', (tester) async {
      final profiles = FakeProfileRepository(profile: _aliProfile);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: profiles,
      );
      await openEdit(tester);
      profiles.gate = Completer<void>();
      await _tapButton(tester, 'Enregistrer');
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(profiles.updates.length, 1);
      profiles.gate!.complete();
      await tester.pumpAndSettle();
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('edit and register fit a small phone at 1.5x text ($lang)', (
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
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          profiles: profiles,
          prefs: {'locale': lang},
        );
        c.read(routerProvider).push(AppRoutes.editProfile);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang edit');
        expect(c.read(localeProvider).languageCode, lang);
      });
    }
  });
}
