import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session (access + refresh tokens) in the platform's
/// secure storage (Keychain on iOS, encrypted storage on Android) instead of
/// the plain shared preferences the SDK uses by default.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() =>
      _storage.containsKey(key: supabasePersistSessionKey);

  @override
  Future<String?> accessToken() =>
      _storage.read(key: supabasePersistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) => _storage.write(
    key: supabasePersistSessionKey,
    value: persistSessionString,
  );

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: supabasePersistSessionKey);
}

/// The PKCE code verifier is a short-lived secret that proves the app that
/// started a sign-in or reset is the one finishing it; it gets the same care.
class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) => _storage.read(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> removeItem({required String key}) => _storage.delete(key: key);
}
