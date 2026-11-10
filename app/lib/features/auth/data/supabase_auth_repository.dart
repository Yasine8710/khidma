import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/auth_domain.dart';
import 'apple_sign_in.dart';

/// Maps whatever the Supabase client throws to an [AuthFailure]. Pure, so it
/// can be tested without a network. Messages are never forwarded: they can be
/// technical, and "invalid credentials" deliberately does not say whether the
/// email or the password was wrong.
AuthFailure mapAuthException(Object error) {
  if (isAppleCancellation(error)) return AuthFailure.cancelled;
  if (error is sb.AuthWeakPasswordException) return AuthFailure.weakPassword;
  // The client wraps connection failures in AuthRetryableFetchException.
  if (error is sb.AuthRetryableFetchException || error is TimeoutException) {
    return AuthFailure.network;
  }
  if (error is sb.AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return AuthFailure.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailure.emailNotConfirmed;
      case 'weak_password':
        return AuthFailure.weakPassword;
      case 'signup_disabled':
      case 'email_provider_disabled':
        return AuthFailure.signUpDisabled;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return AuthFailure.rateLimited;
    }
    if (error.statusCode == '429') return AuthFailure.rateLimited;
    // Older servers answered 400 "Invalid login credentials" without a code.
    if (error.statusCode == '400' &&
        error.message.toLowerCase().contains('invalid login credentials')) {
      return AuthFailure.invalidCredentials;
    }
  }
  return AuthFailure.unknown;
}

/// Where password-reset (and other email) links bring the user back to the
/// app on a phone. The exact value must be listed under "Additional Redirect
/// URLs" in the Supabase dashboard, and registered natively (Android intent
/// filter, iOS URL type). On web the project's Site URL is used instead.
const authRedirectUrl = 'tn.khidma.app://auth-callback';

/// Supabase Auth behind the app's [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._auth, {
    AppleCredentialProvider appleCredential = platformAppleCredential,
    // ignore: prefer_initializing_formals
  }) : _appleCredential = appleCredential;
  final sb.GoTrueClient _auth;
  final AppleCredentialProvider _appleCredential;

  @override
  bool get isAvailable => true;

  AuthUser? _map(sb.User? u) => u == null
      ? null
      : AuthUser(
          id: u.id,
          email: u.email ?? '',
          fullName: (u.userMetadata?['full_name'] as String?),
        );

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.onAuthStateChange.map((s) => _map(s.session?.user));

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthError {
      rethrow;
    } catch (e) {
      throw AuthError(mapAuthException(e));
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String language,
  }) => _guard(() async {
    final r = await _auth.signUp(
      email: email.trim(),
      password: password,
      // Display name and UI language only; roles are never sent (the database
      // ignores sign-up metadata for anything that matters).
      data: {'full_name': fullName.trim(), 'preferred_language': language},
    );
    return r.session != null
        ? SignUpOutcome.signedIn
        : SignUpOutcome.confirmationRequired;
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  @override
  Future<String?> signInWithApple() => _guard(() async {
    // Apple gets the hash; Supabase gets the original and verifies the pair.
    final rawNonce = generateNonce();
    final credential = await _appleCredential(hashedNonce: sha256Hex(rawNonce));
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthError(AuthFailure.unknown);
    }
    await _auth.signInWithIdToken(
      provider: sb.OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    // Apple shares the name only the first time; keep it if we got it.
    final name = credential.fullName;
    if (name != null &&
        (_auth.currentUser?.userMetadata?['full_name'] ?? '') == '') {
      try {
        await _auth.updateUser(sb.UserAttributes(data: {'full_name': name}));
      } catch (_) {
        // The name is a convenience; signing in already succeeded.
      }
    }
    return name;
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : authRedirectUrl,
    ),
  );

  @override
  Stream<void> get passwordRecoveryRequests => _auth.onAuthStateChange
      .where((s) => s.event == sb.AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(sb.UserAttributes(password: newPassword)));
}
