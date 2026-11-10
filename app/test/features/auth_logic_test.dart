import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/features/auth/data/supabase_auth_repository.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/auth/domain/auth_validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  group('validators', () {
    test('email', () {
      expect(validateEmail(null), FieldProblem.required);
      expect(validateEmail('   '), FieldProblem.required);
      for (final bad in [
        'abc',
        'a@b',
        'a@b.',
        '@b.co',
        'a b@c.com',
        'a@@b.com',
        'a@b.c',
      ]) {
        expect(validateEmail(bad), FieldProblem.invalidEmail, reason: bad);
      }
      for (final ok in [
        'a@b.co',
        ' karim@example.tn ',
        'k.ben-salah+x@mail.example.com',
      ]) {
        expect(validateEmail(ok), isNull, reason: ok);
      }
      expect(
        validateEmail('${'a' * 250}@b.co'),
        FieldProblem.invalidEmail,
        reason: 'over 254',
      );
    });

    test('new password: 8..72, not trimmed', () {
      expect(validateNewPassword(''), FieldProblem.required);
      expect(validateNewPassword('1234567'), FieldProblem.passwordTooShort);
      expect(validateNewPassword('12345678'), isNull);
      expect(validateNewPassword('a' * 72), isNull);
      expect(validateNewPassword('a' * 73), FieldProblem.passwordTooLong);
      expect(
        validateNewPassword('       x'),
        isNull,
        reason: 'spaces count: 8 chars',
      );
    });

    test('existing password only needs to be present', () {
      expect(validateExistingPassword(''), FieldProblem.required);
      expect(validateExistingPassword(null), FieldProblem.required);
      expect(validateExistingPassword('x'), isNull);
    });

    test('name', () {
      expect(validateName('  '), FieldProblem.required);
      expect(validateName('Karim'), isNull);
      expect(validateName('خالد'), isNull);
    });
  });

  group('mapAuthException', () {
    AuthFailure code(String c, {String? status, String msg = 'x'}) =>
        mapAuthException(sb.AuthApiException(msg, statusCode: status, code: c));

    test('known server codes', () {
      expect(
        code('invalid_credentials', status: '400'),
        AuthFailure.invalidCredentials,
      );
      expect(
        code('email_not_confirmed', status: '400'),
        AuthFailure.emailNotConfirmed,
      );
      expect(code('weak_password', status: '422'), AuthFailure.weakPassword);
      expect(
        code('signup_disabled', status: '422'),
        AuthFailure.signUpDisabled,
      );
      expect(code('email_provider_disabled'), AuthFailure.signUpDisabled);
      expect(
        code('over_request_rate_limit', status: '429'),
        AuthFailure.rateLimited,
      );
      expect(
        code('over_email_send_rate_limit', status: '429'),
        AuthFailure.rateLimited,
      );
    });

    test('weak-password exception class and network wrappers', () {
      expect(
        mapAuthException(
          sb.AuthWeakPasswordException(
            message: 'm',
            statusCode: '422',
            reasons: const ['length'],
          ),
        ),
        AuthFailure.weakPassword,
      );
      expect(
        mapAuthException(sb.AuthRetryableFetchException()),
        AuthFailure.network,
      );
      expect(mapAuthException(TimeoutException('slow')), AuthFailure.network);
    });

    test('status-only fallbacks', () {
      expect(
        mapAuthException(const sb.AuthException('Too many', statusCode: '429')),
        AuthFailure.rateLimited,
      );
      expect(
        mapAuthException(
          const sb.AuthException(
            'Invalid login credentials',
            statusCode: '400',
          ),
        ),
        AuthFailure.invalidCredentials,
        reason: 'older servers sent no code',
      );
    });

    test('everything else is unknown, and messages are never forwarded', () {
      expect(code('some_new_code', status: '500'), AuthFailure.unknown);
      expect(mapAuthException(StateError('boom')), AuthFailure.unknown);
      expect(mapAuthException('a string'), AuthFailure.unknown);
      expect(
        const AuthError(AuthFailure.network).toString(),
        'AuthError(AuthFailure.network)',
      );
    });
  });

  group('SupabaseAuthRepository with the real client', () {
    // flutter_test replaces all HTTP with a stub that answers 400, so a real
    // "connection refused" cannot be reproduced here (that mapping is covered
    // by the mapAuthException tests above). What we can prove with the real
    // GoTrue client: a failing server never leaks a raw exception, only an
    // AuthError, and nothing about the request ends up in it.
    late sb.GoTrueClient client;
    late SupabaseAuthRepository repo;
    setUp(() {
      client = sb.GoTrueClient(
        url: 'http://127.0.0.1:1/auth/v1',
        headers: const {'apikey': 'x'},
      );
      repo = SupabaseAuthRepository(client);
    });
    tearDown(() => client.dispose());

    test('starts signed out and available', () {
      expect(repo.isAvailable, isTrue);
      expect(repo.currentUser, isNull);
    });

    test(
      'every failing call surfaces as AuthError, never a raw exception',
      () async {
        Matcher authError() => throwsA(
          isA<AuthError>().having(
            (e) => e.toString(),
            'toString',
            isNot(contains('password1')),
          ),
        );
        await expectLater(
          () => repo.signIn(email: 'a@b.co', password: 'password1'),
          authError(),
        );
        await expectLater(
          () => repo.signUp(
            email: 'a@b.co',
            password: 'password1',
            fullName: 'A',
            language: 'fr',
          ),
          authError(),
        );
        await expectLater(() => repo.sendPasswordReset('a@b.co'), authError());
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('NotConfiguredAuthRepository', () {
    const repo = NotConfiguredAuthRepository();

    test(
      'is unavailable, signed out, and every action says "not configured"',
      () async {
        expect(repo.isAvailable, isFalse);
        expect(repo.currentUser, isNull);
        Matcher notConfigured() => throwsA(
          isA<AuthError>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.notConfigured,
          ),
        );
        await expectLater(
          repo.signIn(email: 'a@b.co', password: 'x'),
          notConfigured(),
        );
        await expectLater(
          repo.signUp(
            email: 'a@b.co',
            password: 'x',
            fullName: 'n',
            language: 'fr',
          ),
          notConfigured(),
        );
        await expectLater(repo.sendPasswordReset('a@b.co'), notConfigured());
        await repo.signOut(); // signing out of nothing is harmless
      },
    );
  });
}
