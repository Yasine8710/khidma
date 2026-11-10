import 'dart:convert';

import '../../../core/storage/preferences_provider.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../domain/favorites_domain.dart';

/// Favorites kept on this device. Used when there is no backend (development,
/// demo). A failed write is an error, so the heart never lies about it.
class LocalFavoritesRepository implements FavoritesRepository {
  LocalFavoritesRepository(this._store);
  final KeyValueStore _store;

  static const _key = 'favorites';

  @override
  bool get isLocal => true;

  List<String> _read() {
    final raw = _store.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final v in list)
          if (v is String && v.isNotEmpty) v,
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<String> ids) async {
    try {
      final ok = await _store.setString(_key, jsonEncode(ids));
      if (!ok) throw const MarketplaceError(MarketplaceFailure.unknown);
    } catch (e) {
      if (e is MarketplaceError) rethrow;
      throw const MarketplaceError(MarketplaceFailure.unknown);
    }
  }

  @override
  Future<List<String>> ids() async => _read();

  @override
  Future<void> add(String id) async {
    final ids = _read();
    if (ids.contains(id)) return;
    if (ids.length >= maxFavorites) {
      throw const MarketplaceError(MarketplaceFailure.limitReached);
    }
    await _write([id, ...ids]);
  }

  @override
  Future<void> remove(String id) async => _write([
    for (final x in _read())
      if (x != id) x,
  ]);
}
