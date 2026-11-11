import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../requests/data/supabase_requests_repository.dart'
    show mapRequestsException;
import '../../requests/domain/requests_domain.dart';
import '../domain/reviews_domain.dart';

/// Reviews: public reads of published ones (columns that identify people are
/// not selectable) and the database function that checks the job.
class SupabaseReviewsRepository implements ReviewsRepository {
  SupabaseReviewsRepository(this._client);
  final sb.SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw RequestsError(mapRequestsException(e));
    }
  }

  @override
  Future<List<Review>> forProfessional(
    String professionalId, {
    int offset = 0,
    int limit = reviewsPageSize,
  }) => _guard(() async {
    final rows = await _client
        .from('reviews')
        .select('id, rating, comment, reviewed_month')
        .eq('subject_id', professionalId)
        .eq('status', 'published')
        .order('seq', ascending: false)
        .range(offset, offset + limit - 1);
    return [
      for (final r in rows)
        Review(
          id: r['id'] as String,
          rating: (r['rating'] as num).toInt(),
          comment: r['comment'] as String?,
          month: DateTime.parse(r['reviewed_month'] as String),
        ),
    ];
  });

  @override
  Future<void> submit(String bookingId, int rating, String? comment) => _guard(
    () async {
      await _client.rpc(
        'submit_review',
        params: {
          'p_booking': bookingId,
          'p_rating': rating,
          'p_comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
        },
      );
    },
  );

  @override
  Future<Set<String>> myReviewedBookings() => _guard(() async {
    final rows = await _client.rpc('my_reviewed_bookings');
    return {for (final r in rows as List) r['booking_id'] as String};
  });
}
