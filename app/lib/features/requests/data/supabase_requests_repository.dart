import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../portfolio/data/supabase_portfolio_repository.dart'
    show randomFileId;
import '../../portfolio/domain/portfolio_domain.dart';
import '../domain/requests_domain.dart';

const requestPhotoBucket = 'request-photos';

/// Maps Supabase errors to a [RequestsFailure]. The function tags raised by
/// the database (`rate_limited`, `not_open`, ...) become categories; no
/// database message is ever shown.
RequestsFailure mapRequestsException(Object error) {
  if (error is RequestsError) return error.failure;
  if (error is TimeoutException) return RequestsFailure.network;
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '28000':
      case 'PGRST301':
      case 'PGRST302':
        return RequestsFailure.notSignedIn;
      case '42501':
        return RequestsFailure.forbidden;
      case 'P0002':
        return RequestsFailure.notFound;
      case '23514':
      case '23503':
        return RequestsFailure.invalidInput;
      case 'P0001':
        final m = error.message;
        if (m.contains('rate_limited')) return RequestsFailure.rateLimited;
        if (m.contains('limit_reached') ||
            m.contains('photo_limit') ||
            m.contains('review_limit')) {
          return RequestsFailure.limitReached;
        }
        if (m.contains('not_open') || m.contains('expired')) {
          return RequestsFailure.notOpen;
        }
        if (m.contains('invalid_input')) return RequestsFailure.invalidInput;
        if (m.contains('own_request')) return RequestsFailure.ownRequest;
        if (m.contains('not_completed')) return RequestsFailure.notCompleted;
        if (m.contains('already_reviewed')) {
          return RequestsFailure.alreadyReviewed;
        }
        if (m.contains('already_reported')) {
          return RequestsFailure.alreadyReported;
        }
        if (m.contains('already_pending')) {
          return RequestsFailure.alreadyPending;
        }
        if (m.contains('already_verified')) {
          return RequestsFailure.alreadyVerified;
        }
        if (m.contains('offer_closed')) return RequestsFailure.offerClosed;
        if (m.contains('invalid_transition')) {
          return RequestsFailure.invalidTransition;
        }
        return RequestsFailure.unknown;
    }
    return RequestsFailure.unknown;
  }
  if (error is sb.StorageException) {
    return switch (error.statusCode) {
      '401' => RequestsFailure.notSignedIn,
      '403' => RequestsFailure.forbidden,
      '413' || '400' || '415' => RequestsFailure.invalidInput,
      _ => RequestsFailure.unknown,
    };
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return RequestsFailure.network;
  }
  return RequestsFailure.unknown;
}

/// Requests through PostgREST and Storage. Reads are narrowed by Row Level
/// Security; every change goes through a database function.
class SupabaseRequestsRepository implements RequestsRepository {
  SupabaseRequestsRepository(
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
      throw RequestsError(mapRequestsException(e));
    }
  }

  QuoteRequest _request(Map<String, dynamic> r) {
    final count = (r['offers_count'] as num?)?.toInt() ?? 0;
    return QuoteRequest(
      id: r['id'] as String,
      title: r['title'] as String,
      description: r['description'] as String,
      categoryId: (r['category_id'] as num).toInt(),
      governorateId: (r['governorate_id'] as num).toInt(),
      cityId: (r['city_id'] as num?)?.toInt(),
      budgetTnd: (r['budget_tnd'] as num?)?.toDouble(),
      neededBy: r['needed_by'] == null
          ? null
          : DateTime.parse(r['needed_by'] as String),
      status: switch (r['status']) {
        'awarded' => RequestStatus.awarded,
        'cancelled' => RequestStatus.cancelled,
        'expired' => RequestStatus.expired,
        _ => RequestStatus.open,
      },
      createdAt: DateTime.parse(r['created_at'] as String),
      expiresAt: DateTime.parse(r['expires_at'] as String),
      offerCount: count,
    );
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<CreatedRequest> create(
    NewRequest request,
    List<PreparedPhoto> photos,
  ) async {
    final id = await _guard(() async {
      final row = await _client.rpc(
        'create_quote_request',
        params: {
          'p_title': request.title.trim(),
          'p_description': request.description.trim(),
          'p_category': request.categoryId,
          'p_governorate': request.governorateId,
          'p_city': request.cityId,
          'p_budget': request.budgetTnd,
          'p_needed_by': request.neededBy == null
              ? null
              : _date(request.neededBy!),
        },
      );
      if (row is! String || row.isEmpty) {
        throw const RequestsError(RequestsFailure.unknown);
      }
      return row;
    });
    var failed = 0;
    for (final photo in photos.take(maxRequestPhotos)) {
      try {
        await _attach(id, photo);
      } catch (_) {
        failed++;
      }
    }
    return CreatedRequest(id: id, failedPhotos: failed);
  }

  Future<void> _attach(String requestId, PreparedPhoto photo) async {
    final uid = _userId();
    if (uid == null) throw const RequestsError(RequestsFailure.notSignedIn);
    if (photo.bytes.length > maxUploadBytes) {
      throw const RequestsError(RequestsFailure.invalidInput);
    }
    final path = '$uid/${randomFileId(_random)}.jpg';
    final bucket = _client.storage.from(requestPhotoBucket);
    await bucket.uploadBinary(
      path,
      photo.bytes,
      fileOptions: const sb.FileOptions(
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );
    try {
      await _client.from('request_photos').insert({
        'request_id': requestId,
        'path': path,
      });
    } catch (_) {
      try {
        await bucket.remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  // Owner-only functions: the table also shows requests a professional offered
  // on, and its `customer_id` column is not selectable.
  @override
  Future<List<QuoteRequest>> mine() => _guard(() async {
    final rows = await _client.rpc('my_quote_requests');
    return [for (final r in rows as List) _request(r as Map<String, dynamic>)];
  });

  @override
  Future<QuoteRequest?> get(String id) => _guard(() async {
    final rows = await _client.rpc(
      'get_my_quote_request',
      params: {'p_request': id},
    );
    final list = rows as List;
    return list.isEmpty ? null : _request(list.first as Map<String, dynamic>);
  });

  @override
  Future<List<RequestPhoto>> photos(String requestId) => _guard(() async {
    final rows = await _client
        .from('request_photos')
        .select('id, path')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    if (rows.isEmpty) return const <RequestPhoto>[];
    final paths = [for (final r in rows) r['path'] as String];
    // The bucket is private: each photo is read through a short-lived link.
    final signed = await _client.storage
        .from(requestPhotoBucket)
        .createSignedUrlsResult(paths, 3600);
    final urlByPath = {
      for (final s in signed.whereType<sb.SignedUrlSuccess>())
        s.path: s.signedUrl,
    };
    return [
      for (final r in rows)
        if (urlByPath[r['path']] != null)
          RequestPhoto(
            id: r['id'] as String,
            path: r['path'] as String,
            url: urlByPath[r['path']]!,
          ),
    ];
  });

  @override
  Future<void> cancel(String id) => _guard(() async {
    await _client.rpc('cancel_quote_request', params: {'p_request': id});
  });
}
