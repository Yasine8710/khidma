import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../domain/requests_domain.dart';

String statusLabel(AppLocalizations l10n, RequestStatus s) => switch (s) {
  RequestStatus.open => l10n.reqStatusOpen,
  RequestStatus.awarded => l10n.reqStatusAwarded,
  RequestStatus.cancelled => l10n.reqStatusCancelled,
  RequestStatus.expired => l10n.reqStatusExpired,
};

BadgeTone statusTone(RequestStatus s) => switch (s) {
  RequestStatus.open => BadgeTone.info,
  RequestStatus.awarded => BadgeTone.success,
  RequestStatus.cancelled => BadgeTone.neutral,
  RequestStatus.expired => BadgeTone.warning,
};

IconData statusIcon(RequestStatus s) => switch (s) {
  RequestStatus.open => Icons.hourglass_top_rounded,
  RequestStatus.awarded => Icons.check_circle_outline_rounded,
  RequestStatus.cancelled => Icons.cancel_outlined,
  RequestStatus.expired => Icons.timer_off_outlined,
};

String requestFailureText(AppLocalizations l10n, RequestsFailure f) =>
    switch (f) {
      RequestsFailure.network => l10n.reqFailNetwork,
      RequestsFailure.rateLimited => l10n.reqFailRateLimited,
      RequestsFailure.limitReached => l10n.reqFailLimit,
      RequestsFailure.invalidInput => l10n.reqFailInvalid,
      RequestsFailure.notOpen => l10n.reqFailNotOpen,
      RequestsFailure.notConfigured => l10n.reqFailNotConfigured,
      RequestsFailure.ownRequest => l10n.reqFailOwn,
      RequestsFailure.offerClosed => l10n.reqFailOfferClosed,
      RequestsFailure.invalidTransition => l10n.reqFailTransition,
      RequestsFailure.forbidden => l10n.reqFailForbidden,
      _ => l10n.reqFailGeneric,
    };
