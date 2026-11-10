import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_marketplace_repository.dart';
import '../domain/marketplace_domain.dart';

/// Demo data exists only in debug builds, or when explicitly built with
/// `--dart-define=DEMO_DATA=true`. A release build without a backend shows
/// honest empty states instead.
const bool kDemoDataAllowed = kDebugMode || bool.fromEnvironment('DEMO_DATA');

/// Overridden in `main()` with the Supabase repository when a backend is
/// configured. Otherwise: demo data in development, empty in release.
final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => kDemoDataAllowed
      ? DemoMarketplaceRepository()
      : const EmptyMarketplaceRepository(),
);

/// Whether what is on screen is made up (the UI shows a notice).
final isDemoDataProvider = Provider<bool>(
  (ref) => ref.watch(marketplaceRepositoryProvider).isDemo,
);

/// Categories rarely change: loaded once per session, no silent retry loop.
final categoriesProvider = FutureProvider<List<ServiceCategory>>(
  retry: (n, e) => null,
  (ref) => ref.watch(marketplaceRepositoryProvider).categories(),
);

final governoratesProvider = FutureProvider<List<Governorate>>(
  retry: (n, e) => null,
  (ref) => ref.watch(marketplaceRepositoryProvider).governorates(),
);

/// Cities of one governorate (null = all).
final citiesProvider = FutureProvider.family<List<City>, int?>(
  retry: (n, e) => null,
  (ref, governorateId) => ref
      .watch(marketplaceRepositoryProvider)
      .cities(governorateId: governorateId),
);
