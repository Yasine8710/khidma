import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/storage/preferences_provider.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/secure_auth_storage.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_domain.dart';
import 'features/profile/application/profile_providers.dart';
import 'features/profile/data/supabase_profile_repository.dart';
import 'features/profile/domain/profile_domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await _openStore();
  final auth = await _openAuth();
  final ProfileRepository profiles = auth.isAvailable
      ? SupabaseProfileRepository(Supabase.instance.client)
      : const NotConfiguredProfileRepository();
  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: const KhidmaApp(),
    ),
  );
}

/// Device storage can fail to open (corrupt file, full disk). The app must
/// still start, so fall back to an in-memory store.
Future<KeyValueStore> _openStore() async {
  try {
    return PrefsStore(await SharedPreferences.getInstance());
  } catch (e) {
    _log('Preferences unavailable, using in-memory settings', e);
    return MemoryStore();
  }
}

/// Connects to Supabase only when a valid public config was provided at build
/// time. Anything else (nothing configured, invalid, a failing initialize)
/// leaves accounts honestly unavailable; the rest of the app still works.
Future<AuthRepository> _openAuth() async {
  final config = parseBackendConfig(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  switch (config) {
    case BackendReady():
      try {
        await Supabase.initialize(
          url: config.url.toString(),
          // Accepts the new publishable key or a legacy anon key.
          publishableKey: config.anonKey,
          // The SDK's own logger prints raw error messages; our `_log` is the
          // only sanctioned diagnostic output.
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: SecureSessionStorage(),
            pkceAsyncStorage: SecurePkceStorage(),
          ),
        );
        return SupabaseAuthRepository(Supabase.instance.client.auth);
      } catch (e) {
        _log('Supabase initialize failed', e);
        return const NotConfiguredAuthRepository();
      }
    case BackendInvalid(:final reason):
      _log('Backend config rejected', reason);
      return const NotConfiguredAuthRepository();
    case BackendMissing():
      return const NotConfiguredAuthRepository();
  }
}

/// Diagnostics for developers only. Release builds log nothing, and even debug
/// builds print just the kind of error, never its message (which could echo
/// request details).
void _log(String what, Object detail) {
  if (kDebugMode) {
    debugPrint('$what: ${detail is String ? detail : detail.runtimeType}');
  }
}
