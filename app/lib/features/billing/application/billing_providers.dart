import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/contact_providers.dart'
    show urlOpenerProvider;
import '../../portfolio/application/portfolio_providers.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../domain/billing_domain.dart';

/// Overridden in `main()` with the Supabase repository when a backend is
/// configured.
final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => const NotConfiguredBillingRepository(),
);

/// Runs [load] for the signed-in account; nothing while signed out. Reads start
/// again for each account.
FutureProvider<T?> _perAccount<T>(
  Future<T> Function(BillingRepository repo) load,
) => FutureProvider.autoDispose<T?>(retry: (n, e) => null, (ref) async {
  final user = ref.watch(currentUserProvider.select((u) => u?.id));
  if (user == null) return null;
  return load(ref.watch(billingRepositoryProvider));
});

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>(
      retry: (n, e) => null,
      (ref) => ref.watch(billingRepositoryProvider).plans(),
    );

final mySubscriptionProvider = _perAccount((r) => r.mySubscription());

final myPaymentOrdersProvider = _perAccount((r) => r.myOrders());

final paymentInstructionsProvider = _perAccount((r) => r.instructions());

/// Creates orders and reports payments. The state is true while a call runs,
/// so a double tap cannot send two.
/// How many proofs the caller attached to one of their orders.
final paymentProofCountProvider = FutureProvider.autoDispose
    .family<int, String>(
      retry: (n, e) => null,
      (ref, orderId) =>
          ref.watch(billingRepositoryProvider).proofCount(orderId),
    );

final billingActionsProvider = NotifierProvider<BillingActions, bool>(
  BillingActions.new,
);

class BillingActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<T> _run<T>(
    Future<T> Function(BillingRepository repo) action,
    T Function(BillingFailure f) onFailure,
  ) async {
    if (state) return onFailure(BillingFailure.busy);
    state = true;
    try {
      return await action(ref.read(billingRepositoryProvider));
    } on BillingError catch (e) {
      return onFailure(e.failure);
    } catch (_) {
      return onFailure(BillingFailure.unknown);
    } finally {
      if (ref.mounted) state = false;
    }
  }

  void _reload() {
    if (!ref.mounted) return;
    ref.invalidate(myPaymentOrdersProvider);
    ref.invalidate(mySubscriptionProvider);
  }

  /// Creates (or finds again) the open order. Returns it, or the failure.
  Future<({PaymentOrder? order, BillingFailure? failure})> createOrder(
    String planCode,
    PaymentMethod method,
  ) async {
    final result = await _run<({PaymentOrder? order, BillingFailure? failure})>(
      (r) async =>
          (order: await r.createOrder(planCode, method), failure: null),
      (f) => (order: null, failure: f),
    );
    if (result.order != null) _reload();
    return result;
  }

  /// Gets the Flouci link of [order] and opens it in the browser.
  Future<BillingFailure?> payWithFlouci(PaymentOrder order) =>
      _run<BillingFailure?>((r) async {
        final link = await r.flouciLink(order.id);
        final opened = await ref.read(urlOpenerProvider)(link);
        return opened ? null : BillingFailure.cannotOpen;
      }, (f) => f);

  Future<BillingFailure?> markSent(PaymentOrder order, String? note) async {
    final failure = await _run<BillingFailure?>((r) async {
      await r.markSent(order.id, note);
      return null;
    }, (f) => f);
    if (failure == null) _reload();
    return failure;
  }

  /// Picks a receipt photo and attaches it. Null when it worked or the person
  /// cancelled the picker.
  Future<BillingFailure?> attachProof(PaymentOrder order) async {
    final failure = await _run<BillingFailure?>((r) async {
      final bytes = await ref.read(photoPickerProvider).pick();
      if (bytes == null) return null;
      final PreparedPhoto photo;
      try {
        photo = await ref.read(photoPreparerProvider)(bytes);
      } on PortfolioError {
        return BillingFailure.invalid;
      }
      await r.attachProof(order.id, photo);
      return null;
    }, (f) => f);
    if (ref.mounted) ref.invalidate(paymentProofCountProvider(order.id));
    return failure;
  }

  Future<BillingFailure?> cancel(PaymentOrder order) async {
    final failure = await _run<BillingFailure?>((r) async {
      await r.cancel(order.id);
      return null;
    }, (f) => f);
    if (failure == null) _reload();
    return failure;
  }
}
