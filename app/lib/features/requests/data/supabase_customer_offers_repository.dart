import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../offers/domain/offers_domain.dart';
import '../domain/customer_offers_domain.dart';
import '../domain/requests_domain.dart';
import 'supabase_requests_repository.dart' show mapRequestsException;

/// Offers on the signed-in customer's request, through RLS-narrowed reads
/// (the customer sees every offer on their own request, nobody else's) and the
/// database functions that guard each step.
class SupabaseCustomerOffersRepository implements CustomerOffersRepository {
  SupabaseCustomerOffersRepository(this._client);
  final sb.SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw RequestsError(mapRequestsException(e));
    }
  }

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

  /// Every offer on the request, read page by page: a comparison must never
  /// miss an older, cheaper offer.
  @override
  Future<List<ReceivedOffer>> offers(String requestId) => _guard(() async {
    const page = 100;
    final all = <ReceivedOffer>[];
    for (var from = 0; from < 1000; from += page) {
      final rows = await _client
          .from('quote_offers')
          .select(
            'id, professional_id, price_tnd, message, estimated_days, revisions, status, created_at',
          )
          .eq('request_id', requestId)
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .range(from, from + page - 1);
      for (final r in rows) {
        all.add(
          ReceivedOffer(
            id: r['id'] as String,
            professionalId: r['professional_id'] as String,
            priceTnd: (r['price_tnd'] as num).toDouble(),
            status: _offerStatus(r['status']),
            createdAt: DateTime.parse(r['created_at'] as String),
            message: r['message'] as String?,
            estimatedDays: (r['estimated_days'] as num?)?.toInt(),
            revisions: (r['revisions'] as num?)?.toInt(),
          ),
        );
      }
      if (rows.length < page) break;
    }
    return all;
  });

  @override
  Future<String> accept(String offerId) => _guard(() async {
    final id = await _client.rpc('accept_offer', params: {'p_offer': offerId});
    if (id is! String || id.isEmpty) {
      throw const RequestsError(RequestsFailure.unknown);
    }
    return id;
  });

  @override
  Future<void> decline(String offerId) => _guard(() async {
    await _client.rpc('decline_offer', params: {'p_offer': offerId});
  });

  @override
  Future<CustomerBooking?> booking(String requestId) => _guard(() async {
    final row = await _client
        .from('bookings')
        .select('id, professional_id, price_tnd, status')
        .eq('request_id', requestId)
        .maybeSingle();
    if (row == null) return null;
    return CustomerBooking(
      id: row['id'] as String,
      professionalId: row['professional_id'] as String,
      priceTnd: (row['price_tnd'] as num).toDouble(),
      status: _bookingStatus(row['status']),
    );
  });

  @override
  Future<void> confirmCompleted(String bookingId) => _guard(() async {
    await _client.rpc(
      'confirm_booking_completed',
      params: {'p_booking': bookingId},
    );
  });

  @override
  Future<void> cancelBooking(String bookingId) => _guard(() async {
    await _client.rpc('cancel_booking', params: {'p_booking': bookingId});
  });
}
