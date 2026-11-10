import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/data/supabase_auth_repository.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/profile/application/profile_providers.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

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

void main() {
  setUpAll(loadAppFonts);

  group('email links return to the app', () {
    late List<http.Request> requests;
    late SupabaseAuthRepository repo;

    setUp(() {
      requests = [];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode({}),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      });
      repo = SupabaseAuthRepository(
        sb.GoTrueClient(
          url: 'https://abc.supabase.co/auth/v1',
          headers: const {'apikey': 'k'},
          httpClient: client,
          asyncStorage: _MemoryPkce(),
        ),
      );
    });

    test(
      'the sign-up confirmation link uses the registered native callback',
      () async {
        await repo.signUp(
          email: 'a@b.co',
          password: 'password-1',
          fullName: 'A',
          language: 'ar',
        );
        final r = requests.firstWhere((r) => r.url.path.endsWith('/signup'));
        expect(r.url.queryParameters['redirect_to'], authRedirectUrl);
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['data'], {
          'full_name': 'A',
          'preferred_language': 'ar',
        }, reason: 'no role or admin data is ever sent');
      },
    );

    test('the password-reset link uses the same callback', () async {
      await repo.sendPasswordReset('a@b.co');
      final r = requests.firstWhere((r) => r.url.path.endsWith('/recover'));
      expect(r.url.queryParameters['redirect_to'], authRedirectUrl);
    });
  });

  group('Apple name adoption is bound to the account that signed in', () {
    testWidgets(
      'a switch to another account mid-way never copies the first account\'s data',
      (tester) async {
        final auth = FakeAuthRepository(
          signedIn: const AuthUser(id: 'a', email: 'a@example.tn'),
        );
        final profiles = FakeProfileRepository(
          profile: const AppProfile(
            id: 'a',
            phone: '+21620123456',
            preferredLanguage: 'ar',
          ),
        )..gate = Completer<void>();
        final c = await pumpApp(tester, auth: auth, profiles: profiles);
        final pending = c
            .read(profileActionsProvider.notifier)
            .adoptSharedName('Karim');
        await tester.pump();
        // Someone else signs in while account A's profile is still loading.
        auth.emit(const AuthUser(id: 'b', email: 'b@example.tn'));
        await tester.pump();
        profiles.gate!.complete();
        await pending;
        await tester.pumpAndSettle();
        expect(profiles.updates, isEmpty);
      },
    );

    testWidgets('the normal case still fills an empty profile name', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        signedIn: const AuthUser(id: 'a', email: 'a@example.tn'),
      );
      final profiles = FakeProfileRepository(
        profile: const AppProfile(
          id: 'a',
          phone: '+21620123456',
          preferredLanguage: 'ar',
        ),
      );
      final c = await pumpApp(tester, auth: auth, profiles: profiles);
      await c
          .read(profileActionsProvider.notifier)
          .adoptSharedName('  Karim  ');
      final u = profiles.updates.single;
      expect(u.fullName, 'Karim');
      expect(u.phone, '+21620123456');
      expect(u.language, 'ar');
    });

    testWidgets('signed out: nothing is attempted', (tester) async {
      final profiles = FakeProfileRepository(
        profile: const AppProfile(id: 'a'),
      );
      final c = await pumpApp(tester, profiles: profiles);
      await c.read(profileActionsProvider.notifier).adoptSharedName('Karim');
      expect(profiles.fetchCalls, 0);
      expect(profiles.updates, isEmpty);
      expect(c.read(currentUserProvider), isNull);
    });
  });
}
