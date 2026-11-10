import 'dart:async';

import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';

/// In-memory customer requests with call recording and failure hooks.
class FakeRequestsRepository implements RequestsRepository {
  FakeRequestsRepository([List<QuoteRequest>? requests])
    : requests = [...?requests];

  final List<QuoteRequest> requests;
  final photosByRequest = <String, List<RequestPhoto>>{};

  final created = <(NewRequest, List<PreparedPhoto>)>[];
  final cancelled = <String>[];
  RequestsFailure? failNext;
  RequestsFailure? failCancel;
  bool failPhotos = false;
  int failedPhotos = 0;
  Completer<void>? gate;
  int _n = 0;

  @override
  Future<CreatedRequest> create(
    NewRequest request,
    List<PreparedPhoto> photos,
  ) async {
    created.add((request, photos));
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
    final id = 'r${_n++}';
    requests.insert(
      0,
      QuoteRequest(
        id: id,
        title: request.title.trim(),
        description: request.description.trim(),
        categoryId: request.categoryId,
        governorateId: request.governorateId,
        cityId: request.cityId,
        budgetTnd: request.budgetTnd,
        neededBy: request.neededBy,
        status: RequestStatus.open,
        createdAt: DateTime(2026, 11, 10),
        expiresAt: DateTime(2026, 11, 24),
      ),
    );
    return CreatedRequest(id: id, failedPhotos: failedPhotos);
  }

  @override
  Future<List<QuoteRequest>> mine() async => [...requests];

  @override
  Future<QuoteRequest?> get(String id) async =>
      requests.where((r) => r.id == id).firstOrNull;

  @override
  Future<List<RequestPhoto>> photos(String requestId) async {
    if (failPhotos) throw const RequestsError(RequestsFailure.network);
    return photosByRequest[requestId] ?? const [];
  }

  @override
  Future<void> cancel(String id) async {
    final f = failCancel;
    if (f != null) {
      failCancel = null;
      throw RequestsError(f);
    }
    cancelled.add(id);
    final i = requests.indexWhere((r) => r.id == id);
    if (i >= 0) {
      final r = requests[i];
      requests[i] = QuoteRequest(
        id: r.id,
        title: r.title,
        description: r.description,
        categoryId: r.categoryId,
        governorateId: r.governorateId,
        cityId: r.cityId,
        budgetTnd: r.budgetTnd,
        neededBy: r.neededBy,
        status: RequestStatus.cancelled,
        createdAt: r.createdAt,
        expiresAt: r.expiresAt,
        offerCount: r.offerCount,
      );
    }
  }
}

QuoteRequest sampleRequest({
  String id = 'r-sample',
  String title = 'Fuite sous évier',
  RequestStatus status = RequestStatus.open,
  int offers = 0,
  double? budget,
  DateTime? neededBy,
}) => QuoteRequest(
  id: id,
  title: title,
  description: 'Une fuite sous le lavabo de la cuisine.',
  categoryId: 1,
  governorateId: 11,
  status: status,
  createdAt: DateTime(2026, 11, 9),
  expiresAt: DateTime(2026, 11, 23),
  offerCount: offers,
  budgetTnd: budget,
  neededBy: neededBy,
);
