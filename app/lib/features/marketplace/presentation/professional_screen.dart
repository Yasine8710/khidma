import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/home_providers.dart';
import '../application/marketplace_providers.dart';
import '../application/search_providers.dart';
import 'marketplace_failure_view.dart';
import 'professional_card.dart';

/// Basic profile: identity, rating, badges, about. Contact, portfolio and
/// reviews arrive in the profile slice.
class ProfessionalScreen extends ConsumerStatefulWidget {
  const ProfessionalScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends ConsumerState<ProfessionalScreen> {
  bool _recorded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(professionalProvider(widget.id));

    // Remembered as recently viewed only once it really loaded.
    if (!_recorded && async.value != null) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(recentlyViewedProvider.notifier).add(widget.id);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: async.when(
          loading: () => const SkeletonGroup(
            child: Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
              child: Skeleton(height: 160, radius: AppRadius.lg),
            ),
          ),
          error: (e, _) => MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(professionalProvider(widget.id)),
          ),
          data: (p) {
            if (p == null) {
              return EmptyState(
                icon: Icons.person_off_rounded,
                title: l10n.professionalNotFoundTitle,
                body: l10n.professionalNotFoundBody,
              );
            }
            final category = (ref.watch(categoriesProvider).value ?? const [])
                .where((c) => c.id == p.categoryId)
                .map((c) => c.nameFor(locale))
                .firstOrNull;
            final years = p.yearsExperience;
            return ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
              children: [
                Row(
                  children: [
                    AppAvatar(name: p.name, size: 72, decorative: true),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(p.name, style: text.headlineSmall),
                          ),
                          if (category != null)
                            Text(
                              category,
                              style: text.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                RatingStars(rating: p.rating, reviewCount: p.reviewCount),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (p.isVerified) AppBadge.verified(context),
                    AppBadge(
                      label: availabilityLabel(l10n, p.availability),
                      tone: availabilityTone(p.availability),
                    ),
                    if (years != null && years > 0)
                      AppBadge(label: l10n.yearsExperience(years)),
                  ],
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(l10n.aboutLabel, style: text.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(p.description, style: text.bodyLarge),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
