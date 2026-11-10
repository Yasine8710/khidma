import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_state.dart';
import '../domain/marketplace_domain.dart';

/// Error state for a failed marketplace load, worded by the kind of failure.
class MarketplaceFailureView extends StatelessWidget {
  const MarketplaceFailureView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = error is MarketplaceError
        ? (error as MarketplaceError).failure
        : MarketplaceFailure.unknown;
    final body = switch (failure) {
      MarketplaceFailure.network => l10n.errorBody,
      MarketplaceFailure.forbidden => l10n.failForbidden,
      _ => l10n.failLoadProfessionals,
    };
    return ErrorState(onRetry: onRetry, body: body);
  }
}
