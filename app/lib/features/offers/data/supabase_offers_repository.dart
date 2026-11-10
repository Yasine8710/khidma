import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../requests/data/supabase_requests_repository.dart'
    show mapRequestsException;
import '../../requests/domain/requests_domain.dart';
import '../domain/offers_domain.dart';

OfferStatus _offerStatus(Object? v) => switch (v) {
  'accepted' => OfferStatus.accepted,
  'declined' => OfferStatus.declined,
  'withdrawn' => OfferStatus.withdrawn,
  _ => OfferStatus.pending,
};

BookingStatus _bookingStatus(Object? v) => switch (v) {
  'in_progress' => BookingStatus.inProgress,
  'pending_confirmation' => BookingStatus.pendingConfirmation,
  'completed' => BookingStatus.completed,
  'cancelled' => BookingStatus.cancelled,
  _ => BookingStatus.scheduled,
};

/// Open requests, offers and jobs of the signed-in professional, through
/// database functions and RLS-narrowed reads.
class SupabaseOffersRepository implements OffersRepository {
  SupabaseOffersRepository(this._client, {String? Function()? userId})
    : _userId = userId ?? (() => _client.auth.currentUser?.id);
  final sb.SupabaseClient _client;
  final String? Function() _userId;

  /// The tables also show a person the offers and bookings they have as a
  /// customer, so professional lists always filter by the caller's own id.
  String _uid() {
    final id = _userId();
    if (id == null) throw const RequestsError(RequestsFailure.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw RequestsError(mapRequestsException(e));
    }
  }

  OpenRequest _open(Map<String, dynamic> r) => OpenRequest(
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
    createdAt: DateTime.parse(r['created_at'] as String),
    expiresAt: DateTime.parse(r['expires_at'] as String),
    offersCount: (r['offers_count'] as num?)?.toInt() ?? 0,
    myOfferStatus: r['my_offer_status'] == null
        ? null
        : _offerStatus(r['my_offer_status']),
  );

  @override
  Future<List<OpenRequest>> openRequests({
    int? categoryId,
    int? governorateId,
    int offset = 0,
  }) => _guard(() async {
    final rows = await _client.rpc(
      'list_open_requests',
      params: {
        'p_category': categoryId,
        'p_governorate': governorateId,
        'p_limit': openRequestsPageSize,
        'p_offset': offset,
      },
    );
    return [for (final r in rows as List) _open(r as Map<String, dynamic>)];
  });

  @override
  Future<OpenRequest?> openRequest(String id) => _guard(() async {
    final rows = await _client.rpc(
      'get_open_request',
      params: {'p_request': id},
    );
    final list = rows as List;
    return list.isEmpty ? null : _open(list.first as Map<String, dynamic>);
  });

  @override
  Future<String> submitOffer(String requestId, OfferInput offer) =>
      _guard(() async {
        final id = await _client.rpc(
          'submit_offer',
          params: {
            'p_request': requestId,
            'p_price': offer.priceTnd,
            'p_message': offer.message?.trim().isEmpty ?? true
                ? null
                : offer.message!.trim(),
            'p_days': offer.estimatedDays,
          },
        );
        if (id is! String || id.isEmpty) {
          throw const RequestsError(RequestsFailure.unknown);
        }
        return id;
      });

  @override
  Future<void> withdrawOffer(String offerId) => _guard(() async {
    await _client.rpc('withdraw_offer', params: {'p_offer': offerId});
  });

  static const _offerCols =
      'id, request_id, price_tnd, message, estimated_days, status, created_at, '
      'quote_requests(title)';

  MyOffer _myOffer(Map<String, dynamic> r) => MyOffer(
    id: r['id'] as String,
    requestId: r['request_id'] as String,
    requestTitle: _title(r['quote_requests']),
    priceTnd: (r['price_tnd'] as num).toDouble(),
    status: _offerStatus(r['status']),
    createdAt: DateTime.parse(r['created_at'] as String),
    message: r['message'] as String?,
    estimatedDays: (r['estimated_days'] as num?)?.toInt(),
  );

  /// Pending offers first (at most 50 exist), then the 50 most recent others:
  /// an actionable offer is never cut off by history.
  @override
  Future<List<MyOffer>> myOffers() => _guard(() async {
    final uid = _uid();
    final pending = await _client
        .from('quote_offers')
        .select(_offerCols)
        .eq('professional_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final others = await _client
        .from('quote_offers')
        .select(_offerCols)
        .eq('professional_id', uid)
        .neq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final r in [...pending, ...others]) _myOffer(r),
    ];
  });

  @override
  Future<MyOffer?> myOfferFor(String requestId) => _guard(() async {
    final row = await _client
        .from('quote_offers')
        .select(_offerCols)
        .eq('professional_id', _uid())
        .eq('request_id', requestId)
        .maybeSingle();
    return row == null ? null : _myOffer(row);
  });

  static const _activeJobs = [
    'scheduled',
    'in_progress',
    'pending_confirmation',
  ];

  /// Jobs that need action first (all of them), then the 50 most recent
  /// finished ones.
  @override
  Future<List<Job>> myJobs() => _guard(() async {
    final uid = _uid();
    const cols =
        'id, request_id, price_tnd, status, created_at, quote_requests(title)';
    final active = await _client
        .from('bookings')
        .select(cols)
        .eq('professional_id', uid)
        .inFilter('status', _activeJobs)
        .order('created_at', ascending: false);
    final closed = await _client
        .from('bookings')
        .select(cols)
        .eq('professional_id', uid)
        .inFilter('status', ['completed', 'cancelled'])
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final r in [...active, ...closed])
        Job(
          id: r['id'] as String,
          requestId: r['request_id'] as String,
          requestTitle: _title(r['quote_requests']),
          priceTnd: (r['price_tnd'] as num).toDouble(),
          status: _bookingStatus(r['status']),
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  });

  static String _title(Object? embedded) {
    if (embedded is Map && embedded['title'] is String) {
      return embedded['title'] as String;
    }
    return '';
  }

  Future<void> _step(String fn, String id) => _guard(() async {
    await _client.rpc(fn, params: {'p_booking': id});
  });

  @override
  Future<void> startJob(String id) => _step('start_booking', id);
  @override
  Future<void> markJobDone(String id) => _step('mark_booking_done', id);
  @override
  Future<void> cancelJob(String id) => _step('cancel_booking', id);
}
