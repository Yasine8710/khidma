import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_provider.dart';
import '../domain/marketplace_domain.dart';
import 'marketplace_providers.dart';

/// The area the person is browsing: a governorate, optionally one city in it.
/// Null means all of Tunisia. Kept on this device only.
class Place {
  const Place({required this.governorateId, this.cityId});
  final int governorateId;
  final int? cityId;

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.governorateId == governorateId &&
      other.cityId == cityId;
  @override
  int get hashCode => Object.hash(governorateId, cityId);

  Map<String, Object?> toJson() => {'gov': governorateId, 'city': cityId};

  static Place? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final gov = m['gov'];
      final city = m['city'];
      if (gov is! int || (city != null && city is! int)) return null;
      return Place(governorateId: gov, cityId: city as int?);
    } catch (_) {
      return null;
    }
  }
}

const _placeKey = 'place';

final selectedPlaceProvider = NotifierProvider<SelectedPlace, Place?>(
  SelectedPlace.new,
);

class SelectedPlace extends Notifier<Place?> {
  @override
  Place? build() =>
      Place.tryParse(ref.read(keyValueStoreProvider).getString(_placeKey));

  /// Sets (or with null clears) the browsing area. The in-memory value wins; a
  /// failed write only means it may not survive a restart.
  Future<void> select(Place? place) async {
    state = place;
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(
            _placeKey,
            place == null ? '' : jsonEncode(place.toJson()),
          );
    } catch (_) {}
  }
}

/// How many professionals each Home section shows.
const homeSectionSize = 10;

/// The best-rated professionals anywhere.
final topRatedProvider = FutureProvider<List<ProfessionalSummary>>(
  retry: (n, e) => null,
  (ref) => ref
      .watch(marketplaceRepositoryProvider)
      .search(const SearchQuery(limit: homeSectionSize)),
);

/// Professionals in the selected area, best rated first. Empty list when no
/// area is chosen (the UI then asks the person to choose one).
final inYourAreaProvider = FutureProvider<List<ProfessionalSummary>>(
  retry: (n, e) => null,
  (ref) async {
    final place = ref.watch(selectedPlaceProvider);
    if (place == null) return const [];
    return ref
        .watch(marketplaceRepositoryProvider)
        .search(
          SearchQuery(
            governorateId: place.governorateId,
            cityId: place.cityId,
            limit: homeSectionSize,
          ),
        );
  },
);

const _recentKey = 'recentlyViewed';
const maxRecentlyViewed = 10;

/// Ids of recently opened profiles, newest first (this device only). Written
/// when a profile is opened; Home resolves them to cards.
final recentlyViewedProvider = NotifierProvider<RecentlyViewed, List<String>>(
  RecentlyViewed.new,
);

class RecentlyViewed extends Notifier<List<String>> {
  @override
  List<String> build() {
    final raw = ref.read(keyValueStoreProvider).getString(_recentKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final v in list)
          if (v is String && v.isNotEmpty) v,
      ].take(maxRecentlyViewed).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String id) async {
    state = [
      id,
      ...state.where((x) => x != id),
    ].take(maxRecentlyViewed).toList();
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(_recentKey, jsonEncode(state));
    } catch (_) {}
  }

  Future<void> clear() async {
    state = const [];
    try {
      await ref.read(keyValueStoreProvider).setString(_recentKey, '');
    } catch (_) {}
  }
}

/// The recently viewed professionals that still exist, in order. Deleted or
/// unpublished ones silently drop out.
final recentProfessionalsProvider = FutureProvider<List<ProfessionalSummary>>(
  retry: (n, e) => null,
  (ref) async {
    final ids = ref.watch(recentlyViewedProvider);
    if (ids.isEmpty) return const [];
    final repo = ref.watch(marketplaceRepositoryProvider);
    return repo.professionals(ids);
  },
);
