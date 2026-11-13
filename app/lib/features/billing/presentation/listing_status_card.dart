import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../application/billing_providers.dart';

/// On the professional board when subscriptions are enforced: a warning while
/// the profile is hidden for an unpaid subscription, or the end of the free
/// trial. Nothing otherwise.
class ListingStatusCard extends ConsumerWidget {
  const ListingStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(myListingStatusProvider).value;
    if (s == null || !(s.hidden || s.onTrial)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final bg = s.hidden
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final fg = s.hidden ? scheme.onErrorContainer : scheme.onSurface;
    final trialEnd = s.trialEndsAt;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Semantics(
        container: true,
        liveRegion: s.hidden,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.hidden ? l10n.listingHiddenTitle : l10n.listingTrialTitle,
                  style: text.titleMedium?.copyWith(color: fg),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.hidden
                      ? l10n.listingHiddenBody
                      : l10n.listingTrialBody(
                          trialEnd == null ? '' : formatDate(trialEnd, locale),
                        ),
                  style: text.bodyMedium?.copyWith(color: fg),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: l10n.listingPay,
                  variant: s.hidden
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  onPressed: () => context.push(AppRoutes.proBilling),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
