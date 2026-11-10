import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../data/local_favorites_repository.dart';
import '../domain/favorites_domain.dart';

/// Overridden in `main()` with the Supabase repository when a backend is
/// configured; otherwise favorites stay on this device.
final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => LocalFavoritesRepository(ref.watch(keyValueStoreProvider)),
);

/// Whether saving needs a signed-in account right now.
final favoritesNeedSignInProvider = Provider<bool>(
  (ref) =>
      !ref.watch(favoritesRepositoryProvider).isLocal &&
      ref.watch(currentUserProvider) == null,
);

/// Saved ids, newest first. Starts again for each account.
final favoriteIdsProvider = AsyncNotifierProvider<FavoriteIds, List<String>>(
  FavoriteIds.new,
  retry: (n, e) => null,
);

class FavoriteIds extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id));
    if (ref.watch(favoritesNeedSignInProvider)) return const [];
    return ref.watch(favoritesRepositoryProvider).ids();
  }

  // Changes to one professional run one after the other, so a quick
  // add-then-remove reaches the server in that order.
  final _chains = <String, Future<void>>{};

  /// Saves or removes [id]. The heart changes at once; if the change fails,
  /// only that professional goes back. The failure is returned (null = ok).
  Future<MarketplaceFailure?> toggle(String id) async {
    // Not ready (loading, or reloading for another account): do not guess.
    if (state.isLoading ||
        state.value == null ||
        ref.read(favoritesNeedSignInProvider)) {
      return MarketplaceFailure.unknown;
    }
    final saving = !state.requireValue.contains(id);
    final account = ref.read(currentUserProvider)?.id;
    _set(id, saving);

    final previous = _chains[id] ?? Future<void>.value();
    final run = previous.then((_) async {
      final repo = ref.read(favoritesRepositoryProvider);
      saving ? await repo.add(id) : await repo.remove(id);
    });
    final guarded = run.catchError((_) {});
    _chains[id] = guarded;
    try {
      await run;
      return null;
    } on MarketplaceError catch (e) {
      _undo(account, id, saving);
      return e.failure;
    } catch (_) {
      _undo(account, id, saving);
      return MarketplaceFailure.unknown;
    } finally {
      if (identical(_chains[id], guarded)) _chains.remove(id);
    }
  }

  void _set(String id, bool saved) {
    final current = state.value ?? const <String>[];
    state = AsyncData(
      saved
          ? [id, ...current.where((x) => x != id)]
          : [
              for (final x in current)
                if (x != id) x,
            ],
    );
  }

  /// Puts back just [id]'s previous membership.
  void _undo(String? account, String id, bool wasSaving) {
    if (ref.mounted && ref.read(currentUserProvider)?.id == account) {
      _set(id, !wasSaving);
    }
  }
}

/// Whether one professional is saved (false while loading or signed out).
final isFavoriteProvider = Provider.family<bool, String>((ref, id) {
  final ids = ref.watch(favoriteIdsProvider);
  // While another account's list is loading, nothing is shown as saved.
  return !ids.isLoading && (ids.value?.contains(id) ?? false);
});

/// The saved professionals that still exist, newest saved first.
final favoriteProfessionalsProvider =
    FutureProvider.autoDispose<List<ProfessionalSummary>>(
      retry: (n, e) => null,
      (ref) async {
        final ids = await ref.watch(favoriteIdsProvider.future);
        if (ids.isEmpty) return const [];
        return ref.watch(marketplaceRepositoryProvider).professionals(ids);
      },
    );
