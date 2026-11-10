import 'dart:async';

import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:khidma/features/reviews/domain/reviews_domain.dart';

/// In-memory reviews with call recording and failure hooks.
class FakeReviewsRepository implements ReviewsRepository {
  FakeReviewsRepository({List<Review>? reviews, Set<String>? reviewed})
    : all = [...?reviews],
      reviewedSet = {...?reviewed};

  final List<Review> all;
  final Set<String> reviewedSet;
  final submitted = <(String, int, String?)>[];
  final pagesAsked = <int>[];
  RequestsFailure? failNext;
  bool failList = false;
  Completer<void>? gate;

  @override
  Future<List<Review>> forProfessional(
    String professionalId, {
    int offset = 0,
    int limit = reviewsPageSize,
  }) async {
    pagesAsked.add(offset ~/ limit);
    if (failList) throw const RequestsError(RequestsFailure.network);
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<void> submit(String bookingId, int rating, String? comment) async {
    submitted.add((bookingId, rating, comment));
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
    reviewedSet.add(bookingId);
  }

  @override
  Future<Set<String>> myReviewedBookings() async => {...reviewedSet};
}

Review sampleReview({
  String id = 'rv1',
  int rating = 5,
  String? comment = 'Très bon travail',
}) =>
    Review(id: id, rating: rating, comment: comment, month: DateTime(2026, 11));
