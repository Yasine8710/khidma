/// Saved professionals, newest first. Only ids are stored; the professional
/// data always comes from the marketplace, so a removed or unpublished
/// professional simply stops showing.
abstract interface class FavoritesRepository {
  /// Whether favorites live only on this device (no backend): then no account
  /// is needed. With a backend they belong to the signed-in account.
  bool get isLocal;

  /// Saved ids, newest first. Throws `MarketplaceError`.
  Future<List<String>> ids();

  Future<void> add(String id);
  Future<void> remove(String id);
}

/// Most favorites one person can keep (also enforced by the database).
const maxFavorites = 200;
