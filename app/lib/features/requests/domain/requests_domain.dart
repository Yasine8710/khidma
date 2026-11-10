import '../../portfolio/domain/portfolio_domain.dart';

/// Photos per request (also enforced by the database).
const maxRequestPhotos = 5;

enum RequestStatus { open, awarded, cancelled, expired }

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.governorateId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.cityId,
    this.budgetTnd,
    this.neededBy,
    this.offerCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final int categoryId;
  final int governorateId;
  final int? cityId;
  final double? budgetTnd;
  final DateTime? neededBy;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Offers received so far (the customer sees all offers on their request).
  final int offerCount;

  bool get isOpen => status == RequestStatus.open;
}

/// What the customer fills in. Limits mirror the database.
class NewRequest {
  const NewRequest({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.governorateId,
    this.cityId,
    this.budgetTnd,
    this.neededBy,
  });

  final String title;
  final String description;
  final int categoryId;
  final int governorateId;
  final int? cityId;
  final double? budgetTnd;
  final DateTime? neededBy;
}

abstract final class RequestRules {
  static const titleMin = 3;
  static const titleMax = 120;
  static const descriptionMin = 10;
  static const descriptionMax = 2000;
  static const budgetMax = 1000000.0;

  static bool titleOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= titleMin && n <= titleMax;
  }

  static bool descriptionOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= descriptionMin && n <= descriptionMax;
  }

  static bool budgetOk(double? v) => v == null || (v >= 0 && v <= budgetMax);
}

class RequestPhoto {
  const RequestPhoto({required this.id, required this.path, required this.url});
  final String id;
  final String path;

  /// A temporary signed address (the bucket is private).
  final String url;
}

class CreatedRequest {
  const CreatedRequest({required this.id, this.failedPhotos = 0});
  final String id;

  /// Photos that could not be attached; the request itself was sent.
  final int failedPhotos;
}

enum RequestsFailure {
  network,
  notSignedIn,
  forbidden,
  rateLimited,
  limitReached,
  invalidInput,

  /// The request is no longer open (answered, cancelled or expired).
  notOpen,

  /// You cannot offer on your own request.
  ownRequest,

  /// The offer was declined or already accepted: it can no longer change.
  offerClosed,

  /// That step is not possible from the current status.
  invalidTransition,
  notFound,
  notConfigured,
  unknown,
}

class RequestsError implements Exception {
  const RequestsError(this.failure);
  final RequestsFailure failure;
  @override
  String toString() => 'RequestsError($failure)';
}

/// The customer's side of requests.
abstract interface class RequestsRepository {
  /// Sends the request, then attaches [photos] one by one. A photo that fails
  /// does not undo the request; it is counted in `failedPhotos`.
  Future<CreatedRequest> create(NewRequest request, List<PreparedPhoto> photos);

  /// The signed-in customer's requests, newest first.
  Future<List<QuoteRequest>> mine();

  Future<QuoteRequest?> get(String id);
  Future<List<RequestPhoto>> photos(String requestId);
  Future<void> cancel(String id);
}

class NotConfiguredRequestsRepository implements RequestsRepository {
  const NotConfiguredRequestsRepository();
  Never _fail() => throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<CreatedRequest> create(
    NewRequest request,
    List<PreparedPhoto> photos,
  ) async => _fail();
  @override
  Future<List<QuoteRequest>> mine() async => _fail();
  @override
  Future<QuoteRequest?> get(String id) async => _fail();
  @override
  Future<List<RequestPhoto>> photos(String requestId) async => _fail();
  @override
  Future<void> cancel(String id) async => _fail();
}
