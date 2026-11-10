import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_domain.dart';

String availabilityLabel(AppLocalizations l10n, Availability a) => switch (a) {
  Availability.available => l10n.availabilityAvailable,
  Availability.busy => l10n.availabilityBusy,
  Availability.offline => l10n.availabilityOffline,
};

BadgeTone availabilityTone(Availability a) => switch (a) {
  Availability.available => BadgeTone.success,
  Availability.busy => BadgeTone.warning,
  Availability.offline => BadgeTone.neutral,
};

/// One professional in a list. The verified badge appears only when the
/// professional really is verified; nothing is implied otherwise.
class ProfessionalCard extends ConsumerWidget {
  const ProfessionalCard({super.key, required this.professional, this.onTap});

  final ProfessionalSummary professional;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final p = professional;

    final categories = ref.watch(categoriesProvider).value ?? const [];
    final cities = ref.watch(citiesProvider(null)).value ?? const [];
    final category = categories
        .where((c) => c.id == p.categoryId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final city = cities
        .where((c) => c.id == p.cityId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final km = p.distanceKm;
    final subtitle = [
      ?category,
      ?city,
      if (km != null) l10n.distanceKm(km.toStringAsFixed(1)),
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      semanticLabel: p.name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: p.name, size: 52, decorative: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(color: muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSpacing.xs),
                RatingStars(
                  rating: p.rating,
                  reviewCount: p.reviewCount,
                  size: 14,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (p.isVerified) AppBadge.verified(context),
                    AppBadge(
                      label: availabilityLabel(l10n, p.availability),
                      tone: availabilityTone(p.availability),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FavoriteButton(professionalId: p.id, professionalName: p.name),
        ],
      ),
    );
  }
}
