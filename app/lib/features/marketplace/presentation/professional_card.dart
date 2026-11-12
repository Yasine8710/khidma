import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/category_photo.dart';
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

/// A register section title: a short ink rule above a slab-serif title, with
/// an optional figure (a count) on the end side. The trade-register
/// equivalent of a card header.
class RegisterHeading extends StatelessWidget {
  const RegisterHeading({super.key, required this.title, this.figure});

  final String title;

  /// A small number printed at the end of the rule, e.g. how many rows follow.
  final String? figure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: BorderSide(color: scheme.onSurface, width: 1.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: text.titleLarge),
                ),
              ),
              if (figure != null) ...[
                const SizedBox(width: AppSpacing.md),
                ExcludeSemantics(
                  child: Text(
                    figure!,
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rectangular stamp: outlined, never filled, always with text.
class Stamp extends StatelessWidget {
  const Stamp({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color, letterSpacing: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The olive "verified" stamp. Only for professionals an admin verified.
class VerifiedStamp extends StatelessWidget {
  const VerifiedStamp({super.key});

  @override
  Widget build(BuildContext context) => Stamp(
    label: AppLocalizations.of(context).verified,
    icon: Icons.check_rounded,
    color: AppBadge.foreground(
      BadgeTone.success,
      Theme.of(context).colorScheme,
    ),
  );
}

/// Availability as a small square mark and its word (never colour alone).
class AvailabilityMark extends StatelessWidget {
  const AvailabilityMark({super.key, required this.availability});

  final Availability availability;

  @override
  Widget build(BuildContext context) {
    final color = AppBadge.foreground(
      availabilityTone(availability),
      Theme.of(context).colorScheme,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 7, child: ColoredBox(color: color)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            availabilityLabel(AppLocalizations.of(context), availability),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// One professional as a register row: framed square photo, name, trade and
/// place, rating, stamps, and the heart; a hairline rule closes the row.
/// The verified stamp appears only when the professional really is verified.
class ProfessionalCard extends ConsumerWidget {
  const ProfessionalCard({
    super.key,
    required this.professional,
    this.onTap,
    this.rule = true,
  });

  final ProfessionalSummary professional;
  final VoidCallback? onTap;

  /// Draw the hairline under the row (off for the last row of a framed list).
  final bool rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = professional;

    final categories = ref.watch(categoriesProvider).value ?? const [];
    final cities = ref.watch(citiesProvider(null)).value ?? const [];
    final cat = categories.where((c) => c.id == p.categoryId).firstOrNull;
    final city = cities
        .where((c) => c.id == p.cityId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final km = p.distanceKm;
    final subtitle = [
      ?cat?.nameFor(locale),
      ?city,
      if (km != null) l10n.distanceKm(km.toStringAsFixed(1)),
    ].join(' · ');

    final row = DecoratedBox(
      decoration: BoxDecoration(
        border: rule
            ? BorderDirectional(
                bottom: BorderSide(color: scheme.outlineVariant),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.md + 2,
          bottom: AppSpacing.md + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The category photo stands in until they add their own.
            ProfessionalPhoto(
              avatarUrl: p.avatarUrl,
              slug: cat?.slug,
              icon: cat?.icon,
              width: 64,
              height: 64,
              radius: AppRadius.sm,
              frame: scheme.outlineVariant,
            ),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  RatingStars(
                    rating: p.rating,
                    reviewCount: p.reviewCount,
                    size: 13,
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (p.isVerified) const VerifiedStamp(),
                      AvailabilityMark(availability: p.availability),
                    ],
                  ),
                ],
              ),
            ),
            FavoriteButton(professionalId: p.id, professionalName: p.name),
          ],
        ),
      ),
    );

    // The heart is an IconButton: it needs a Material even outside a page.
    if (onTap == null) {
      return Material(type: MaterialType.transparency, child: row);
    }
    return Semantics(
      container: true,
      button: true,
      label: p.name,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, excludeFromSemantics: true, child: row),
      ),
    );
  }
}

/// Professionals as consecutive register rows, each opening its profile.
class ProfessionalRegister extends StatelessWidget {
  const ProfessionalRegister({super.key, required this.list});

  final List<ProfessionalSummary> list;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in list)
          ProfessionalCard(
            professional: p,
            onTap: () => context.push(AppRoutes.professionalPath(p.id)),
          ),
      ],
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
    this.frame,
  });

  final String? avatarUrl;
  final String? slug;
  final String? icon;
  final double? width;
  final double? height;
  final double radius;

  /// A 1px frame drawn over the picture's edge, when set.
  final Color? frame;

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
    final px =
        (width ?? height ?? 120) * MediaQuery.devicePixelRatioOf(context);
    final Widget picture = url == null || url.isEmpty
        ? fallback
        : ExcludeSemantics(
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
    if (frame == null) return picture;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: frame!),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: picture,
    );
  }
}
