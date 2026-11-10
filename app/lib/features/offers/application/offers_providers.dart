import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../requests/domain/requests_domain.dart';
import '../domain/offers_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => const NotConfiguredOffersRepository(),
);

/// Ask for [offset]-th page of open requests. A record keeps equality so
/// identical asks share a result; each page can fail and retry on its own.
typedef OpenRequestsQuery = ({int? categoryId, int? governorateId, int offset});

String? _uid(Ref ref) => ref.watch(currentUserProvider.select((u) => u?.id));

final openRequestsPageProvider = FutureProvider.autoDispose
    .family<List<OpenRequest>, OpenRequestsQuery>(retry: (n, e) => null, (
      ref,
      q,
    ) {
      if (_uid(ref) == null) return Future.value(const <OpenRequest>[]);
      return ref
          .watch(offersRepositoryProvider)
          .openRequests(
            categoryId: q.categoryId,
            governorateId: q.governorateId,
            offset: q.offset,
          );
    });

final openRequestProvider = FutureProvider.autoDispose
    .family<OpenRequest?, String>(retry: (n, e) => null, (ref, id) {
      if (_uid(ref) == null) return Future.value(null);
      return ref.watch(offersRepositoryProvider).openRequest(id);
    });

final myOffersProvider = FutureProvider.autoDispose<List<MyOffer>>(
  retry: (n, e) => null,
  (ref) {
    if (_uid(ref) == null) return Future.value(const <MyOffer>[]);
    return ref.watch(offersRepositoryProvider).myOffers();
  },
);

final myJobsProvider = FutureProvider.autoDispose<List<Job>>(
  retry: (n, e) => null,
  (ref) {
    if (_uid(ref) == null) return Future.value(const <Job>[]);
    return ref.watch(offersRepositoryProvider).myJobs();
  },
);

/// The signed-in professional's offer on one request, fetched directly.
final myOfferForProvider = FutureProvider.autoDispose.family<MyOffer?, String>(
  retry: (n, e) => null,
  (ref, requestId) {
    if (_uid(ref) == null) return Future.value(null);
    return ref.watch(offersRepositoryProvider).myOfferFor(requestId);
  },
);

/// Sends, withdraws and moves jobs. [busy] is true while one runs, so a double
/// tap cannot send two.
final offerActionsProvider = NotifierProvider<OfferActions, bool>(
  OfferActions.new,
);

class OfferActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Returns the failure, or null on success.
  Future<RequestsFailure?> _run(
    Future<void> Function(OffersRepository repo) action, {
    String? requestId,
  }) async {
    if (state) return RequestsFailure.unknown;
    state = true;
    final account = ref.read(currentUserProvider)?.id;
    try {
      await action(ref.read(offersRepositoryProvider));
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) {
        state = false;
        // Whatever the outcome, what is shown may be stale: reload it (only for
        // the account that acted).
        if (ref.read(currentUserProvider)?.id == account) {
          ref.invalidate(myOffersProvider);
          ref.invalidate(myJobsProvider);
          ref.invalidate(openRequestsPageProvider);
          if (requestId != null) {
            ref.invalidate(openRequestProvider(requestId));
            ref.invalidate(myOfferForProvider(requestId));
          }
        }
      }
    }
  }

  Future<RequestsFailure?> submit(String requestId, OfferInput offer) =>
      _run((r) => r.submitOffer(requestId, offer), requestId: requestId);

  Future<RequestsFailure?> withdraw(String offerId, String requestId) =>
      _run((r) => r.withdrawOffer(offerId), requestId: requestId);

  Future<RequestsFailure?> start(String jobId) =>
      _run((r) => r.startJob(jobId));
  Future<RequestsFailure?> markDone(String jobId) =>
      _run((r) => r.markJobDone(jobId));
  Future<RequestsFailure?> cancel(String jobId) =>
      _run((r) => r.cancelJob(jobId));
}
