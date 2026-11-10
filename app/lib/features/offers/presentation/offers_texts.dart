import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../requests/domain/requests_domain.dart';
import '../../requests/presentation/requests_texts.dart';
import '../domain/offers_domain.dart';

String offerStatusLabel(AppLocalizations l10n, OfferStatus s) => switch (s) {
  OfferStatus.pending => l10n.offerStatusPending,
  OfferStatus.accepted => l10n.offerStatusAccepted,
  OfferStatus.declined => l10n.offerStatusDeclined,
  OfferStatus.withdrawn => l10n.offerStatusWithdrawn,
};

BadgeTone offerStatusTone(OfferStatus s) => switch (s) {
  OfferStatus.pending => BadgeTone.info,
  OfferStatus.accepted => BadgeTone.success,
  OfferStatus.declined => BadgeTone.neutral,
  OfferStatus.withdrawn => BadgeTone.neutral,
};

/// Failure wording for offers (the shared wording talks about requests).
String offerFailureText(AppLocalizations l10n, RequestsFailure f) =>
    f == RequestsFailure.limitReached
    ? l10n.offerFailLimit
    : requestFailureText(l10n, f);

String jobStatusLabel(AppLocalizations l10n, BookingStatus s) => switch (s) {
  BookingStatus.scheduled => l10n.jobScheduled,
  BookingStatus.inProgress => l10n.jobInProgress,
  BookingStatus.pendingConfirmation => l10n.jobPendingConfirmation,
  BookingStatus.completed => l10n.jobCompleted,
  BookingStatus.cancelled => l10n.jobCancelled,
};

BadgeTone jobStatusTone(BookingStatus s) => switch (s) {
  BookingStatus.scheduled => BadgeTone.info,
  BookingStatus.inProgress => BadgeTone.warning,
  BookingStatus.pendingConfirmation => BadgeTone.warning,
  BookingStatus.completed => BadgeTone.success,
  BookingStatus.cancelled => BadgeTone.neutral,
};
