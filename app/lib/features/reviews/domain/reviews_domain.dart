import '../../requests/domain/requests_domain.dart';

/// Most characters in a comment (also enforced by the database).
const maxReviewComment = 1000;

/// A published review as the public sees it: no author, no job.
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.month,
    this.comment,
  });

  final String id;
  final int rating;

  /// Only the month is public (the exact time would let someone match a
  /// review to a job they know about).
  final DateTime month;
  final String? comment;
}

abstract final class ReviewRules {
  static bool ratingOk(int? r) => r != null && r >= 1 && r <= 5;
  static bool commentOk(String? c) =>
      (c?.trim().length ?? 0) <= maxReviewComment;
}

abstract interface class ReviewsRepository {
  /// Published reviews about a professional, newest first.
  Future<List<Review>> forProfessional(
    String professionalId, {
    int offset = 0,
    int limit = reviewsPageSize,
  });

  /// Leaves the one review the signed-in person may write about a completed
  /// job. Throws `RequestsError` (not completed, already reviewed, ...).
  Future<void> submit(String bookingId, int rating, String? comment);

  /// Jobs the signed-in person has already reviewed.
  Future<Set<String>> myReviewedBookings();
}

const reviewsPageSize = 10;

class NotConfiguredReviewsRepository implements ReviewsRepository {
  const NotConfiguredReviewsRepository();
  @override
  Future<List<Review>> forProfessional(
    String professionalId, {
    int offset = 0,
    int limit = reviewsPageSize,
  }) async => const [];
  @override
  Future<void> submit(String bookingId, int rating, String? comment) async {
    throw const RequestsError(RequestsFailure.notConfigured);
  }

  @override
  Future<Set<String>> myReviewedBookings() async => const {};
}
