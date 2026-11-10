import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../domain/customer_offers_domain.dart';
import '../domain/requests_domain.dart';
import 'requests_providers.dart';

final customerOffersRepositoryProvider = Provider<CustomerOffersRepository>(
  (ref) => const NotConfiguredCustomerOffersRepository(),
);

String? _uid(Ref ref) => ref.watch(currentUserProvider.select((u) => u?.id));

/// Offers on one of my requests (empty for any other account).
final receivedOffersProvider = FutureProvider.autoDispose
    .family<List<ReceivedOffer>, String>(retry: (n, e) => null, (
      ref,
      requestId,
    ) {
      if (_uid(ref) == null) return Future.value(const <ReceivedOffer>[]);
      return ref.watch(customerOffersRepositoryProvider).offers(requestId);
    });

/// The public profiles (name, rating, verification) of the professionals who
/// offered, by id. A professional who is no longer published is simply absent.
final offerersProvider = FutureProvider.autoDispose
    .family<Map<String, ProfessionalSummary>, String>(retry: (n, e) => null, (
      ref,
      requestId,
    ) async {
      final offers = await ref.watch(receivedOffersProvider(requestId).future);
      if (offers.isEmpty) return const {};
      final pros = await ref.watch(marketplaceRepositoryProvider).professionals(
        [for (final o in offers) o.professionalId],
      );
      return {for (final p in pros) p.id: p};
    });

final bookingForRequestProvider = FutureProvider.autoDispose
    .family<CustomerBooking?, String>(retry: (n, e) => null, (ref, requestId) {
      if (_uid(ref) == null) return Future.value(null);
      return ref.watch(customerOffersRepositoryProvider).booking(requestId);
    });

/// Accepts, declines and moves the booking. [busy] is true while one runs, so
/// two taps cannot send two (the database would also refuse the second).
final customerOfferActionsProvider =
    NotifierProvider<CustomerOfferActions, bool>(CustomerOfferActions.new);

class CustomerOfferActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<RequestsFailure?> _run(
    String requestId,
    Future<void> Function(CustomerOffersRepository repo) action,
  ) async {
    if (state) return RequestsFailure.unknown;
    state = true;
    final account = ref.read(currentUserProvider)?.id;
    try {
      await action(ref.read(customerOffersRepositoryProvider));
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) {
        state = false;
        // Whatever the outcome, the screen may be out of date: reload it.
        if (ref.read(currentUserProvider)?.id == account) {
          ref.invalidate(receivedOffersProvider(requestId));
          ref.invalidate(bookingForRequestProvider(requestId));
          ref.invalidate(requestProvider(requestId));
          ref.invalidate(myRequestsProvider);
        }
      }
    }
  }

  Future<RequestsFailure?> accept(String requestId, String offerId) =>
      _run(requestId, (r) => r.accept(offerId));
  Future<RequestsFailure?> decline(String requestId, String offerId) =>
      _run(requestId, (r) => r.decline(offerId));
  Future<RequestsFailure?> confirm(String requestId, String bookingId) =>
      _run(requestId, (r) => r.confirmCompleted(bookingId));
  Future<RequestsFailure?> cancelBooking(String requestId, String bookingId) =>
      _run(requestId, (r) => r.cancelBooking(bookingId));
}
