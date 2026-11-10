import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// A random single-use value that ties an Apple sign-in to the request that
/// started it (replay protection). Apple receives its SHA-256, Supabase the
/// original, and Supabase checks they match.
String generateNonce([Random? random, int length = 32]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
  final r = random ?? Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

/// What the app needs from Apple's credential.
class AppleCredential {
  const AppleCredential({this.identityToken, this.givenName, this.familyName});
  final String? identityToken;

  /// Apple sends the name only on a person's very first sign-in with the app.
  final String? givenName;
  final String? familyName;

  String? get fullName {
    final parts = [
      givenName,
      familyName,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// Asks Apple for a credential. Injectable so everything around it can be
/// tested without an Apple account or a device.
typedef AppleCredentialProvider = Future<AppleCredential> Function({
  required String hashedNonce,
});

Future<AppleCredential> platformAppleCredential({
  required String hashedNonce,
}) async {
  final c = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: hashedNonce,
  );
  return AppleCredential(
    identityToken: c.identityToken,
    givenName: c.givenName,
    familyName: c.familyName,
  );
}

/// True when the person closed Apple's sheet: not an error worth showing.
bool isAppleCancellation(Object error) =>
    error is SignInWithAppleAuthorizationException &&
    error.code == AuthorizationErrorCode.canceled;
