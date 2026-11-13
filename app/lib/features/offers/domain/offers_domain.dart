import '../../requests/domain/requests_domain.dart';

enum OfferStatus { pending, accepted, declined, withdrawn }

enum BookingStatus {
  scheduled,
  inProgress,
  pendingConfirmation,
  completed,
  cancelled,
}

/// A request a professional can answer. It never says who asked.
class OpenRequest {
  const OpenRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.governorateId,
    required this.createdAt,
    required this.expiresAt,
    this.cityId,
    this.budgetTnd,
    this.neededBy,
    this.offersCount = 0,
    this.myOfferStatus,
  });

  final String id;
  final String title;
  final String description;
  final int categoryId;
  final int governorateId;
  final int? cityId;
  final double? budgetTnd;
  final DateTime? neededBy;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// How many offers there are, not whose.
  final int offersCount;

  /// The caller's own offer on it, if any.
  final OfferStatus? myOfferStatus;
}

/// The caller's own offer, with the title of the request it answers.
class MyOffer {
  const MyOffer({
    required this.id,
    required this.requestId,
    required this.requestTitle,
    required this.priceTnd,
    required this.status,
    required this.createdAt,
    this.message,
    this.estimatedDays,
    this.remote = false,
  });

  final String id;
  final String requestId;
  final String requestTitle;
  final double priceTnd;
  final OfferStatus status;
  final DateTime createdAt;
  final String? message;
  final int? estimatedDays;

  /// On a remote project (opens the project screen, not the local request).
  final bool remote;
}

/// A job: an accepted offer.
class Job {
  const Job({
    required this.id,
    required this.requestId,
    required this.requestTitle,
    required this.priceTnd,
    required this.status,
    required this.createdAt,
    this.remote = false,
  });

  final String id;
  final String requestId;
  final String requestTitle;
  final double priceTnd;
  final BookingStatus status;
  final DateTime createdAt;

  /// A remote project job (handed in through deliveries).
  final bool remote;

  bool get canStart => status == BookingStatus.scheduled;
  bool get canMarkDone => status == BookingStatus.inProgress;
  bool get canCancel =>
      status == BookingStatus.scheduled || status == BookingStatus.inProgress;
}

/// What the professional types in an offer. Limits mirror the database.
class OfferInput {
  const OfferInput({required this.priceTnd, this.message, this.estimatedDays});
  final double priceTnd;
  final String? message;
  final int? estimatedDays;
}

abstract final class OfferRules {
  static const priceMin = 1.0;
  static const priceMax = 1000000.0;
  static const messageMax = 1000;
  static const daysMax = 365;

  static bool priceOk(double? v) => v != null && v >= priceMin && v <= priceMax;
  static bool messageOk(String? v) => (v?.trim().length ?? 0) <= messageMax;
  static bool daysOk(int? v) => v == null || (v >= 1 && v <= daysMax);
}

/// The professional's side of requests, offers and jobs.
abstract interface class OffersRepository {
  /// Open requests (no identity), newest first, 20 per page.
  Future<List<OpenRequest>> openRequests({
    int? categoryId,
    int? governorateId,
    int offset = 0,
  });

  Future<OpenRequest?> openRequest(String id);

  /// Creates or updates the caller's pending offer. Returns its id.
  Future<String> submitOffer(String requestId, OfferInput offer);
  Future<void> withdrawOffer(String offerId);

  Future<List<MyOffer>> myOffers();

  /// The caller's offer on one request, fetched directly (not from a list).
  Future<MyOffer?> myOfferFor(String requestId);
  Future<List<Job>> myJobs();

  Future<void> startJob(String id);
  Future<void> markJobDone(String id);
  Future<void> cancelJob(String id);
}

const openRequestsPageSize = 20;

class NotConfiguredOffersRepository implements OffersRepository {
  const NotConfiguredOffersRepository();
  Never _fail() => throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<List<OpenRequest>> openRequests({
    int? categoryId,
    int? governorateId,
    int offset = 0,
  }) async => _fail();
  @override
  Future<OpenRequest?> openRequest(String id) async => _fail();
  @override
  Future<String> submitOffer(String requestId, OfferInput offer) async =>
      _fail();
  @override
  Future<void> withdrawOffer(String offerId) async => _fail();
  @override
  Future<List<MyOffer>> myOffers() async => _fail();
  @override
  Future<MyOffer?> myOfferFor(String requestId) async => _fail();
  @override
  Future<List<Job>> myJobs() async => _fail();
  @override
  Future<void> startJob(String id) async => _fail();
  @override
  Future<void> markJobDone(String id) async => _fail();
  @override
  Future<void> cancelJob(String id) async => _fail();
}
