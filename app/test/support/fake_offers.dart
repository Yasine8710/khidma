import 'dart:async';

import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';

/// In-memory professional side of requests, with call recording and failures.
class FakeOffersRepository implements OffersRepository {
  FakeOffersRepository({
    List<OpenRequest>? open,
    List<MyOffer>? offers,
    List<Job>? jobs,
  }) : open = [...?open],
       offers = [...?offers],
       jobs = [...?jobs];

  final List<OpenRequest> open;
  final List<MyOffer> offers;
  final List<Job> jobs;

  final queries = <({int? categoryId, int? governorateId, int offset})>[];
  final submitted = <(String, OfferInput)>[];
  final withdrawn = <String>[];
  final steps = <String>[];
  RequestsFailure? failNext;
  Completer<void>? gate;

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
  }

  @override
  Future<List<OpenRequest>> openRequests({
    int? categoryId,
    int? governorateId,
    int offset = 0,
  }) async {
    queries.add((
      categoryId: categoryId,
      governorateId: governorateId,
      offset: offset,
    ));
    return [
      for (final r in open)
        if ((categoryId == null || r.categoryId == categoryId) &&
            (governorateId == null || r.governorateId == governorateId))
          r,
    ].skip(offset).take(openRequestsPageSize).toList();
  }

  @override
  Future<OpenRequest?> openRequest(String id) async =>
      open.where((r) => r.id == id).firstOrNull;

  @override
  Future<String> submitOffer(String requestId, OfferInput offer) async {
    submitted.add((requestId, offer));
    await _pre();
    final id = 'o${submitted.length}';
    offers.removeWhere((o) => o.requestId == requestId);
    final req = open.firstWhere((r) => r.id == requestId);
    offers.insert(
      0,
      MyOffer(
        id: id,
        requestId: requestId,
        requestTitle: req.title,
        priceTnd: offer.priceTnd,
        status: OfferStatus.pending,
        createdAt: DateTime(2026, 11, 10),
        message: offer.message?.trim().isEmpty ?? true ? null : offer.message,
        estimatedDays: offer.estimatedDays,
      ),
    );
    _setMine(requestId, OfferStatus.pending);
    return id;
  }

  void _setMine(String requestId, OfferStatus? status) {
    final i = open.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    final r = open[i];
    open[i] = OpenRequest(
      id: r.id,
      title: r.title,
      description: r.description,
      categoryId: r.categoryId,
      governorateId: r.governorateId,
      cityId: r.cityId,
      budgetTnd: r.budgetTnd,
      neededBy: r.neededBy,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
      offersCount: r.offersCount,
      myOfferStatus: status,
    );
  }

  @override
  Future<void> withdrawOffer(String offerId) async {
    withdrawn.add(offerId);
    await _pre();
    final o = offers.firstWhere((x) => x.id == offerId);
    offers.remove(o);
    _setMine(o.requestId, OfferStatus.withdrawn);
  }

  /// Delay before offers answer (to observe the loading state).
  Duration offersDelay = Duration.zero;

  @override
  Future<List<MyOffer>> myOffers() async => [...offers];

  @override
  Future<MyOffer?> myOfferFor(String requestId) async {
    await Future<void>.delayed(offersDelay);
    return offers.where((o) => o.requestId == requestId).firstOrNull;
  }

  @override
  Future<List<Job>> myJobs() async => [...jobs];

  Future<void> _job(String id, String step, BookingStatus to) async {
    steps.add('$step:$id');
    await _pre();
    final i = jobs.indexWhere((j) => j.id == id);
    final j = jobs[i];
    jobs[i] = Job(
      id: j.id,
      requestId: j.requestId,
      requestTitle: j.requestTitle,
      priceTnd: j.priceTnd,
      status: to,
      createdAt: j.createdAt,
    );
  }

  @override
  Future<void> startJob(String id) =>
      _job(id, 'start', BookingStatus.inProgress);
  @override
  Future<void> markJobDone(String id) =>
      _job(id, 'done', BookingStatus.pendingConfirmation);
  @override
  Future<void> cancelJob(String id) =>
      _job(id, 'cancel', BookingStatus.cancelled);
}

OpenRequest sampleOpen({
  String id = 'o-req',
  String title = 'Fuite sous évier',
  int categoryId = 1,
  int governorateId = 11,
  int offers = 0,
  OfferStatus? mine,
  double? budget,
}) => OpenRequest(
  id: id,
  title: title,
  description: 'Une fuite sous le lavabo de la cuisine.',
  categoryId: categoryId,
  governorateId: governorateId,
  createdAt: DateTime(2026, 11, 9),
  expiresAt: DateTime(2026, 11, 23),
  offersCount: offers,
  myOfferStatus: mine,
  budgetTnd: budget,
);

Job sampleJob({
  String id = 'j1',
  BookingStatus status = BookingStatus.scheduled,
  String title = 'Chauffe-eau en panne',
}) => Job(
  id: id,
  requestId: 'r-$id',
  requestTitle: title,
  priceTnd: 130,
  status: status,
  createdAt: DateTime(2026, 11, 9),
);
