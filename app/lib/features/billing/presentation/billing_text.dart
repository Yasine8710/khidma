import '../../../l10n/generated/app_localizations.dart';
import '../domain/billing_domain.dart';

/// One plain sentence per failure; server text is never shown.
String billingFailureText(AppLocalizations l10n, BillingFailure f) =>
    switch (f) {
      BillingFailure.network => l10n.billErrNetwork,
      BillingFailure.notSignedIn => l10n.billErrSignedIn,
      BillingFailure.rateLimited => l10n.billErrRate,
      BillingFailure.invalid => l10n.billErrInvalid,
      BillingFailure.notFound => l10n.billErrNotFound,
      BillingFailure.notConfigured => l10n.billErrNotConfigured,
      BillingFailure.flouciUnavailable => l10n.billFlouciUnavailable,
      BillingFailure.cannotOpen => l10n.billCannotOpen,
      BillingFailure.forbidden => l10n.billNotProBody,
      BillingFailure.busy || BillingFailure.unknown => l10n.billErrUnknown,
    };

String subscriptionStateText(AppLocalizations l10n, SubscriptionState s) =>
    switch (s) {
      SubscriptionState.active => l10n.billStatusActive,
      SubscriptionState.pastDue => l10n.billStatusPastDue,
      SubscriptionState.expired => l10n.billStatusExpired,
      SubscriptionState.cancelled => l10n.billStatusCancelled,
    };

String orderStatusText(AppLocalizations l10n, OrderStatus s) => switch (s) {
  OrderStatus.pending => l10n.billOrderPending,
  OrderStatus.awaitingConfirmation => l10n.billOrderAwaiting,
  OrderStatus.paid => l10n.billOrderPaid,
  OrderStatus.failed => l10n.billOrderFailed,
  OrderStatus.cancelled => l10n.billOrderCancelled,
  OrderStatus.rejected => l10n.billOrderRejected,
};

String paymentMethodText(AppLocalizations l10n, PaymentMethod m) => switch (m) {
  PaymentMethod.flouci => l10n.billMethodFlouci,
  PaymentMethod.d17 => l10n.billMethodD17,
  PaymentMethod.bankTransfer => l10n.billMethodBank,
};
