import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/profile_domain.dart';

/// Maps Supabase/PostgREST errors to a [ProfileFailure]. Pure and tested.
/// Database messages are never forwarded.
ProfileFailure mapProfileException(Object error) {
  if (error is ProfileError) return error.failure;
  if (error is TimeoutException) return ProfileFailure.network;
  if (error is sb.AuthException) return ProfileFailure.notSignedIn;
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '23514': // check constraint (bad phone, bad language, too long)
      case '22023':
      case '22001': // value too long
        return ProfileFailure.invalidData;
      case '28000': // not authenticated (become_professional)
      case '42501': // permission denied / refused by the database
      case 'PGRST301': // JWT expired / invalid
      case 'PGRST302':
        return ProfileFailure.notSignedIn;
    }
    // PostgREST reports connection trouble as 5xx without a SQL state.
    return ProfileFailure.unknown;
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return ProfileFailure.network;
  }
  return ProfileFailure.unknown;
}

/// `profiles` through PostgREST. Row Level Security limits every call to the
/// caller's own row; the code does not rely on that alone and filters by id.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final sb.SupabaseClient _client;

  static const _columns =
      'id, full_name, phone, preferred_language, is_customer, is_professional';

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const ProfileError(ProfileFailure.notSignedIn);
    return id;
  }

  AppProfile _row(Map<String, dynamic> r) => AppProfile(
    id: r['id'] as String,
    fullName: r['full_name'] as String?,
    phone: r['phone'] as String?,
    preferredLanguage: (r['preferred_language'] as String?) ?? 'fr',
    isCustomer: (r['is_customer'] as bool?) ?? true,
    isProfessional: (r['is_professional'] as bool?) ?? false,
  );

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ProfileError(mapProfileException(e));
    }
  }

  @override
  Future<AppProfile> fetchMine() => _guard(() async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', _uid)
        .single();
    return _row(row);
  });

  @override
  Future<AppProfile> updateMine({
    required String fullName,
    required String? phone,
    required String preferredLanguage,
  }) => _guard(() async {
    final row = await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'phone': phone,
          'preferred_language': preferredLanguage,
        })
        .eq('id', _uid)
        .select(_columns)
        .single();
    return _row(row);
  });

  @override
  Future<void> becomeProfessional() =>
      _guard(() => _client.rpc('become_professional'));
}
