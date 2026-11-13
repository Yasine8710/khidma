import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/monitoring/error_reporting.dart';
import 'core/storage/preferences_provider.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/secure_auth_storage.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_domain.dart';
import 'features/favorites/application/favorites_providers.dart';
import 'features/favorites/data/supabase_favorites_repository.dart';
import 'features/freelance/application/freelance_providers.dart';
import 'features/freelance/data/supabase_freelance_repository.dart';
import 'features/marketplace/application/marketplace_providers.dart';
import 'features/marketplace/data/supabase_marketplace_repository.dart';
import 'features/messages/application/messages_providers.dart';
import 'features/messages/data/supabase_messages_repository.dart';
import 'features/notifications/application/notifications_providers.dart';
import 'features/notifications/data/supabase_notifications_repository.dart';
import 'features/offers/application/offers_providers.dart';
import 'features/offers/data/supabase_offers_repository.dart';
import 'features/portfolio/application/portfolio_providers.dart';
import 'features/requests/application/customer_offers_providers.dart';
import 'features/reviews/application/reviews_providers.dart';
import 'features/reviews/data/supabase_reviews_repository.dart';
import 'features/trust/application/trust_providers.dart';
import 'features/trust/data/supabase_trust_repository.dart';
import 'features/requests/application/requests_providers.dart';
import 'features/requests/data/supabase_customer_offers_repository.dart';
import 'features/requests/data/supabase_requests_repository.dart';
import 'features/portfolio/data/supabase_portfolio_repository.dart';
import 'features/billing/application/billing_providers.dart';
import 'features/billing/data/supabase_billing_repository.dart';
import 'features/professional/application/professional_providers.dart';
import 'features/professional/data/supabase_professional_repository.dart';
import 'features/profile/application/profile_providers.dart';
import 'features/profile/data/supabase_profile_repository.dart';
import 'features/profile/domain/profile_domain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only when built with SENTRY_DSN; otherwise a no-op.
  await initErrorReporting();
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
        if (auth.isAvailable)
          offersRepositoryProvider.overrideWithValue(
            SupabaseOffersRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          customerOffersRepositoryProvider.overrideWithValue(
            SupabaseCustomerOffersRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          messagesRepositoryProvider.overrideWithValue(
            SupabaseMessagesRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          notificationsRepositoryProvider.overrideWithValue(
            SupabaseNotificationsRepository(Supabase.instance.client),
          ),
        // Stop pushes for this account on this device before signing out.
        beforeSignOutProvider.overrideWith(
          (ref) => [() => ref.read(pushLifecycleProvider).unregister()],
        ),
        if (auth.isAvailable)
          reviewsRepositoryProvider.overrideWithValue(
            SupabaseReviewsRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          trustRepositoryProvider.overrideWithValue(
            SupabaseTrustRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          requestsRepositoryProvider.overrideWithValue(
            SupabaseRequestsRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          portfolioRepositoryProvider.overrideWithValue(
            SupabasePortfolioRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          professionalRepositoryProvider.overrideWithValue(
            SupabaseProfessionalRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          billingRepositoryProvider.overrideWithValue(
            SupabaseBillingRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          favoritesRepositoryProvider.overrideWithValue(
            SupabaseFavoritesRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          marketplaceRepositoryProvider.overrideWithValue(
            SupabaseMarketplaceRepository(Supabase.instance.client),
          ),
        if (auth.isAvailable)
          freelanceRepositoryProvider.overrideWithValue(
            SupabaseFreelanceRepository(Supabase.instance.client),
          ),
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
