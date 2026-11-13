import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../domain/marketplace_domain.dart';

/// Failed marketplace load, worded by the kind of failure: a ruled notice
/// with a plain outlined retry, quiet enough to sit inside a list or fill a
/// page.
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final failure = error is MarketplaceError
        ? (error as MarketplaceError).failure
        : MarketplaceFailure.unknown;
    final body = switch (failure) {
      MarketplaceFailure.network => l10n.errorBody,
      MarketplaceFailure.forbidden => l10n.failForbidden,
      _ => l10n.failLoadProfessionals,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(l10n.errorTitle, style: text.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: l10n.retry,
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
