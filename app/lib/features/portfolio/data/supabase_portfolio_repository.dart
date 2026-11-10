import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/portfolio_domain.dart';

const portfolioBucket = 'portfolio';

/// Maps Supabase errors to a [PortfolioFailure]. Messages are never forwarded.
PortfolioFailure mapPortfolioException(Object error) {
  if (error is PortfolioError) return error.failure;
  if (error is TimeoutException) return PortfolioFailure.network;
  if (error is sb.StorageException) {
    switch (error.statusCode) {
      case '413':
        return PortfolioFailure.tooLarge;
      case '400':
      case '415':
        return PortfolioFailure.notAnImage;
      case '401':
        return PortfolioFailure.notSignedIn;
      case '403':
        return PortfolioFailure.forbidden;
    }
    return PortfolioFailure.unknown;
  }
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '28000':
      case 'PGRST301':
      case 'PGRST302':
        return PortfolioFailure.notSignedIn;
      case '42501':
        return PortfolioFailure.forbidden;
      case 'P0001':
        return error.message.contains('portfolio_limit')
            ? PortfolioFailure.limitReached
            : PortfolioFailure.unknown;
    }
    return PortfolioFailure.unknown;
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return PortfolioFailure.network;
  }
  return PortfolioFailure.unknown;
}

/// A random UUID (v4), used as the file name so names are unguessable and
/// never collide.
String randomFileId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${[for (var i = 0; i < 4; i++) h(i)].join()}-'
      '${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-'
      '${[for (var i = 10; i < 16; i++) h(i)].join()}';
}

/// Portfolio photos in Supabase Storage (public bucket) plus the
/// `portfolio_items` table that makes them part of a profile.
class SupabasePortfolioRepository implements PortfolioRepository {
  SupabasePortfolioRepository(
    this._client, {
    String? Function()? userId,
    this._random,
  }) : _userId = userId ?? (() => _client.auth.currentUser?.id);

  final sb.SupabaseClient _client;
  final String? Function() _userId;
  final Random? _random;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw PortfolioError(mapPortfolioException(e));
    }
  }

  PortfolioItem _item(Map<String, dynamic> r) {
    final path = r['path'] as String;
    return PortfolioItem(
      id: r['id'] as String,
      path: path,
      url: _client.storage.from(portfolioBucket).getPublicUrl(path),
    );
  }

  @override
  Future<List<PortfolioItem>> list(String professionalId) => _guard(() async {
    final rows = await _client
        .from('portfolio_items')
        .select('id, path')
        .eq('professional_id', professionalId)
        .order('created_at', ascending: true);
    return [for (final r in rows) _item(r)];
  });

  @override
  Future<PortfolioItem> add(PreparedPhoto photo) => _guard(() async {
    final uid = _userId();
    if (uid == null) {
      throw const PortfolioError(PortfolioFailure.notSignedIn);
    }
    if (photo.bytes.length > maxUploadBytes) {
      throw const PortfolioError(PortfolioFailure.tooLarge);
    }
    final path = '$uid/${randomFileId(_random)}.jpg';
    final bucket = _client.storage.from(portfolioBucket);
    await bucket.uploadBinary(
      path,
      photo.bytes,
      fileOptions: const sb.FileOptions(
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );
    try {
      final row = await _client
          .from('portfolio_items')
          .insert({'professional_id': uid, 'path': path})
          .select('id, path')
          .single();
      return _item(row);
    } catch (_) {
      // The answer may have been lost after the row was saved: if it exists,
      // the photo is part of the profile and the file must stay.
      try {
        final saved = await _client
            .from('portfolio_items')
            .select('id, path')
            .eq('path', path)
            .maybeSingle();
        if (saved != null) return _item(saved);
      } catch (_) {}
      // Otherwise it is not part of the profile: do not leave the file behind.
      try {
        await bucket.remove([path]);
      } catch (_) {}
      rethrow;
    }
  });

  @override
  Future<void> remove(PortfolioItem item) => _guard(() async {
    // The file first: if that fails the photo stays listed and the person can
    // try again (removing a missing file is harmless). Doing the row first
    // could leave a public file nobody can find to delete.
    await _client.storage.from(portfolioBucket).remove([item.path]);
    await _client.from('portfolio_items').delete().eq('id', item.id);
  });
}
