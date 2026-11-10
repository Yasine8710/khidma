import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/storage/preferences_provider.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await _openStore();
  final auth = await _openAuth();
  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(auth),
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
  } catch (e, s) {
    debugPrint('Preferences unavailable, using in-memory settings: $e\n$s');
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
        );
        return SupabaseAuthRepository(Supabase.instance.client.auth);
      } catch (e, s) {
        debugPrint('Supabase initialize failed: $e\n$s');
        return const NotConfiguredAuthRepository();
      }
    case BackendInvalid(:final reason):
      debugPrint('Backend config rejected: $reason');
      return const NotConfiguredAuthRepository();
    case BackendMissing():
      return const NotConfiguredAuthRepository();
  }
}
