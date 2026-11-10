import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../marketplace/data/supabase_marketplace_repository.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../domain/favorites_domain.dart';

/// Favorites of the signed-in account, in the `favorites` table. Row Level
/// Security keeps them private; the server also caps them and refuses
/// unpublished professionals.
class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this._client, {String? Function()? userId})
    : _userId = userId ?? (() => _client.auth.currentUser?.id);
  final sb.SupabaseClient _client;
  final String? Function() _userId;

  @override
  bool get isLocal => false;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw MarketplaceError(mapMarketplaceException(e));
    }
  }

  String _uid() {
    final id = _userId();
    if (id == null) {
      throw const MarketplaceError(MarketplaceFailure.notSignedIn);
    }
    return id;
  }

  @override
  Future<List<String>> ids() => _guard(() async {
    final rows = await _client
        .from('favorites')
        .select('professional_id')
        .order('created_at', ascending: false)
        .limit(maxFavorites);
    return [for (final r in rows) r['professional_id'] as String];
  });

  @override
  Future<void> add(String id) => _guard(() async {
    await _client
        .from('favorites')
        .upsert(
          {'user_id': _uid(), 'professional_id': id},
          onConflict: 'user_id,professional_id',
          ignoreDuplicates: true,
        );
  });

  @override
  Future<void> remove(String id) => _guard(() async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', _uid())
        .eq('professional_id', id);
  });
}
