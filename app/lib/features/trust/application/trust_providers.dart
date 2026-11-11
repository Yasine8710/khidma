import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../portfolio/application/portfolio_providers.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';
import '../domain/trust_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final trustRepositoryProvider = Provider<TrustRepository>(
  (ref) => const NotConfiguredTrustRepository(),
);

/// The signed-in professional's latest verification request.
final myVerificationProvider = FutureProvider.autoDispose<VerificationInfo>(
  retry: (n, e) => null,
  (ref) {
    if (ref.watch(currentUserProvider.select((u) => u?.id)) == null) {
      return Future.value(
        const VerificationInfo(status: VerificationStatus.none),
      );
    }
    return ref.watch(trustRepositoryProvider).myVerification();
  },
);

/// Sends a report. [busy] is true while it runs (a double tap sends once).
final reportActionsProvider = NotifierProvider<ReportActions, bool>(
  ReportActions.new,
);

class ReportActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Returns the failure, or null on success.
  Future<RequestsFailure?> send(
    ReportTarget target,
    String targetId,
    ReportReason reason,
    String? details,
  ) async {
    if (state) return RequestsFailure.unknown;
    state = true;
    try {
      await ref
          .read(trustRepositoryProvider)
          .report(target, targetId, reason, details);
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

/// Picks, prepares, sends and cancels verification documents.
final verificationActionsProvider = NotifierProvider<VerificationActions, bool>(
  VerificationActions.new,
);

class VerificationActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Picks one document photo and prepares it. Null when the person cancels;
  /// a [PortfolioFailure] marker is not needed here: unreadable files surface
  /// as [RequestsFailure.invalidInput].
  Future<({PreparedPhoto? photo, RequestsFailure? failure})> pick() async {
    try {
      final Uint8List? bytes = await ref.read(photoPickerProvider).pick();
      if (bytes == null) return (photo: null, failure: null);
      final prepared = await ref.read(photoPreparerProvider)(bytes);
      return (photo: prepared, failure: null);
    } on PortfolioError {
      return (photo: null, failure: RequestsFailure.invalidInput);
    } catch (_) {
      return (photo: null, failure: RequestsFailure.unknown);
    }
  }

  Future<RequestsFailure?> submit(List<PreparedPhoto> documents) => _run(
    () => ref.read(trustRepositoryProvider).submitVerification(documents),
  );

  Future<RequestsFailure?> cancel() =>
      _run(() => ref.read(trustRepositoryProvider).cancelVerification());

  Future<RequestsFailure?> _run(Future<void> Function() action) async {
    if (state) return RequestsFailure.unknown;
    state = true;
    try {
      await action();
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) {
        state = false;
        // Whatever happened, the status may have changed.
        ref.invalidate(myVerificationProvider);
      }
    }
  }
}
