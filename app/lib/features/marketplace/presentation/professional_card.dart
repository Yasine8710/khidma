import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/category_photo.dart';
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
    final cat = categories.where((c) => c.id == p.categoryId).firstOrNull;
    final category = cat?.nameFor(locale);
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
          // The category photo stands in until the professional has their own.
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfessionalPhoto(
                avatarUrl: p.avatarUrl,
                slug: cat?.slug,
                icon: cat?.icon,
                width: 88,
                height: 100,
                radius: AppRadius.md,
              ),
              if (p.isVerified)
                PositionedDirectional(
                  end: -6,
                  bottom: -6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.verified_rounded,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

/// A horizontally scrolling row of [ProfessionalTile]s (Home).
class ProfessionalCarousel extends StatelessWidget {
  const ProfessionalCarousel({super.key, required this.list});

  final List<ProfessionalSummary> list;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SizedBox(
      height: ProfessionalTile.photoHeight + 148 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.sm,
        ),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => SizedBox(
          width: ProfessionalTile.width,
          child: ProfessionalTile(
            professional: list[i],
            onTap: () => context.push(AppRoutes.professionalPath(list[i].id)),
          ),
        ),
      ),
    );
  }
}

/// A compact vertical professional card: photo on top, details below.
class ProfessionalTile extends ConsumerWidget {
  const ProfessionalTile({super.key, required this.professional, this.onTap});

  static const width = 232.0;
  static const photoHeight = 128.0;

  final ProfessionalSummary professional;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = professional;
    final cat = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    final city = (ref.watch(citiesProvider(null)).value ?? const [])
        .where((c) => c.id == p.cityId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final subtitle = [cat?.nameFor(locale), city].nonNulls.join(' · ');

    return AppCard(
      onTap: onTap,
      semanticLabel: p.name,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ProfessionalPhoto(
                avatarUrl: p.avatarUrl,
                slug: cat?.slug,
                icon: cat?.icon,
                width: double.infinity,
                height: photoHeight,
                radius: 0,
              ),
              PositionedDirectional(
                top: AppSpacing.sm,
                end: AppSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: FavoriteButton(
                    professionalId: p.id,
                    professionalName: p.name,
                  ),
                ),
              ),
              if (p.isVerified)
                PositionedDirectional(
                  start: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: AppBadge.verified(context),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
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
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSpacing.xs),
                RatingStars(
                  rating: p.rating,
                  reviewCount: p.reviewCount,
                  size: 14,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppBadge(
                  label: availabilityLabel(l10n, p.availability),
                  tone: availabilityTone(p.availability),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The professional's own picture when they added one, otherwise the photo of
/// their category (never a broken image). Decoration: the name sits next to it.
class ProfessionalPhoto extends StatelessWidget {
  const ProfessionalPhoto({
    super.key,
    required this.avatarUrl,
    required this.slug,
    required this.icon,
    this.width,
    this.height,
    this.radius = AppRadius.md,
  });

  final String? avatarUrl;
  final String? slug;
  final String? icon;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = CategoryPhoto(
      slug: slug,
      icon: icon,
      width: width,
      height: height,
      radius: radius,
    );
    final url = avatarUrl;
    if (url == null || url.isEmpty) return fallback;
    final px =
        (width ?? height ?? 120) * MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: px.isFinite && px >= 1 ? px.round() : null,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback,
          ),
        ),
      ),
    );
  }
}
