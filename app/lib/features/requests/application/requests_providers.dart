import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../portfolio/application/portfolio_providers.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../domain/requests_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final requestsRepositoryProvider = Provider<RequestsRepository>(
  (ref) => const NotConfiguredRequestsRepository(),
);

/// The signed-in customer's requests. Starts again for each account.
final myRequestsProvider = FutureProvider.autoDispose<List<QuoteRequest>>(
  retry: (n, e) => null,
  (ref) async {
    final user = ref.watch(currentUserProvider.select((u) => u?.id));
    if (user == null) return const [];
    return ref.watch(requestsRepositoryProvider).mine();
  },
);

final requestProvider = FutureProvider.autoDispose
    .family<QuoteRequest?, String>(retry: (n, e) => null, (ref, id) {
      // Another account (or none) never inherits what was loaded before.
      if (ref.watch(currentUserProvider.select((u) => u?.id)) == null) {
        return Future.value(null);
      }
      return ref.watch(requestsRepositoryProvider).get(id);
    });

final requestPhotosProvider = FutureProvider.autoDispose
    .family<List<RequestPhoto>, String>(retry: (n, e) => null, (ref, id) {
      if (ref.watch(currentUserProvider.select((u) => u?.id)) == null) {
        return Future.value(const <RequestPhoto>[]);
      }
      return ref.watch(requestsRepositoryProvider).photos(id);
    });

class SendResult {
  const SendResult({this.created, this.failure});
  final CreatedRequest? created;
  final RequestsFailure? failure;
  bool get isOk => failure == null && created != null;
}

/// Sends and cancels requests. [busy] is true while one runs, so a double tap
/// cannot send two.
final requestActionsProvider = NotifierProvider<RequestActions, bool>(
  RequestActions.new,
);

class RequestActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<SendResult> send(
    NewRequest request,
    List<PreparedPhoto> photos,
  ) async {
    if (state) return const SendResult(failure: RequestsFailure.unknown);
    state = true;
    try {
      final created = await ref
          .read(requestsRepositoryProvider)
          .create(request, photos);
      if (ref.mounted) ref.invalidate(myRequestsProvider);
      return SendResult(created: created);
    } on RequestsError catch (e) {
      return SendResult(failure: e.failure);
    } catch (_) {
      return const SendResult(failure: RequestsFailure.unknown);
    } finally {
      if (ref.mounted) state = false;
    }
  }

  /// Returns the failure, or null on success.
  Future<RequestsFailure?> cancel(String id) async {
    if (state) return RequestsFailure.unknown;
    state = true;
    try {
      await ref.read(requestsRepositoryProvider).cancel(id);
      if (ref.mounted) {
        ref.invalidate(myRequestsProvider);
        ref.invalidate(requestProvider(id));
      }
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) state = false;
    }
  }

  /// Picks one photo and prepares it (resize, strip metadata). Null when the
  /// person cancels. Throws [PortfolioError] when it cannot be used.
  Future<PreparedPhoto?> pickPhoto() async {
    final picked = await ref.read(photoPickerProvider).pick();
    if (picked == null) return null;
    return ref.read(photoPreparerProvider)(picked);
  }
}
