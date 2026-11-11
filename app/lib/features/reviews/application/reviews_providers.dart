import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../requests/domain/requests_domain.dart';
import '../domain/reviews_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => const NotConfiguredReviewsRepository(),
);

/// One page of a professional's published reviews.
typedef ReviewsPageQuery = ({String professionalId, int page});

final reviewsPageProvider = FutureProvider.autoDispose
    .family<List<Review>, ReviewsPageQuery>(
      retry: (n, e) => null,
      (ref, q) => ref
          .watch(reviewsRepositoryProvider)
          .forProfessional(q.professionalId, offset: q.page * reviewsPageSize),
    );

/// Jobs I already reviewed (so the "leave a review" button goes away).
final reviewedBookingsProvider = FutureProvider.autoDispose<Set<String>>(
  retry: (n, e) => null,
  (ref) {
    if (ref.watch(currentUserProvider.select((u) => u?.id)) == null) {
      return Future.value(const <String>{});
    }
    return ref.watch(reviewsRepositoryProvider).myReviewedBookings();
  },
);

/// Sends a review. [busy] is true while it runs (a double tap sends once).
final reviewActionsProvider = NotifierProvider<ReviewActions, bool>(
  ReviewActions.new,
);

class ReviewActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Returns the failure, or null on success.
  Future<RequestsFailure?> submit(
    String bookingId,
    int rating,
    String? comment,
  ) async {
    if (state) return RequestsFailure.unknown;
    state = true;
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .submit(bookingId, rating, comment);
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) {
        state = false;
        // Whatever happened, the "already reviewed" list may have changed.
        ref.invalidate(reviewedBookingsProvider);
        ref.invalidate(reviewsPageProvider);
      }
    }
  }
}
