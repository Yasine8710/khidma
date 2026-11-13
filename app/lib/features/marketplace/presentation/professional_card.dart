import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_domain.dart';
import 'calm_blocks.dart';

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

/// The "verified" pill. Only for people an admin verified.
class VerifiedStamp extends StatelessWidget {
  const VerifiedStamp({super.key, this.label});

  /// Defaults to "Vérifié".
  final String? label;

  @override
  Widget build(BuildContext context) => InfoPill(
    label: label ?? AppLocalizations.of(context).verified,
    icon: Icons.verified_rounded,
  );
}

/// Availability as a small round dot and its word (never colour alone).
class AvailabilityMark extends StatelessWidget {
  const AvailabilityMark({super.key, required this.availability});

  final Availability availability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppBadge.foreground(availabilityTone(availability), scheme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            availabilityLabel(AppLocalizations.of(context), availability),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Availability as a header pill (dot + word).
class AvailabilityPill extends StatelessWidget {
  const AvailabilityPill({super.key, required this.availability});

  final Availability availability;

  @override
  Widget build(BuildContext context) => InfoPill(
    label: availabilityLabel(AppLocalizations.of(context), availability),
    dot: AppBadge.foreground(
      availabilityTone(availability),
      Theme.of(context).colorScheme,
    ),
  );
}

/// One professional as a soft list card: round avatar, name with the
/// verified tick, trade and place, rating, the "verified" pill and
/// availability, and the heart. The verified marks appear only when the
/// professional really is verified.
class ProfessionalCard extends ConsumerWidget {
  const ProfessionalCard({
    super.key,
    required this.professional,
    this.onTap,
    this.rule = true,
  });

  final ProfessionalSummary professional;
  final VoidCallback? onTap;

  /// Kept for older call sites; cards are separate blocks now.
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

    final card = StickerBox(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfessionalPhoto(
            avatarUrl: p.avatarUrl,
            slug: cat?.slug,
            icon: cat?.icon,
            name: p.name,
            width: 56,
          ),
          const SizedBox(width: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.sm),
                RatingInline(
                  rating: p.rating,
                  reviewCount: p.reviewCount,
                  size: 14,
                ),
                const SizedBox(height: AppSpacing.sm),
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
    );

    final padded = Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: card,
    );

    // The heart is an IconButton: it needs a Material even outside a page.
    if (onTap == null) {
      return Material(type: MaterialType.transparency, child: padded);
    }
    return Semantics(
      container: true,
      button: true,
      label: p.name,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Pressable(onTap: onTap, button: false, child: padded),
      ),
    );
  }
}

/// Professionals as consecutive cards, each opening its profile and arriving
/// in a quick stagger.
class ProfessionalRegister extends StatelessWidget {
  const ProfessionalRegister({super.key, required this.list});

  final List<ProfessionalSummary> list;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < list.length; i++)
          StaggerIn(
            index: i,
            child: ProfessionalCard(
              professional: list[i],
              onTap: () => context.push(AppRoutes.professionalPath(list[i].id)),
            ),
          ),
      ],
    );
  }
}

/// The professional's own picture when they added one, otherwise their
/// initials on a round colour. Never a broken image; decoration: the name
/// sits next to it.
class ProfessionalPhoto extends StatelessWidget {
  const ProfessionalPhoto({
    super.key,
    required this.avatarUrl,
    required this.slug,
    required this.icon,
    this.name,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    this.frame,
  });

  final String? avatarUrl;
  final String? slug;
  final String? icon;
  final String? name;
  final double? width;
  final double? height;

  /// Kept for older call sites; the photo is always round.
  final double radius;

  /// Kept for older call sites.
  final Color? frame;

  @override
  Widget build(BuildContext context) => InitialsAvatar(
    name: name ?? slug ?? icon ?? '',
    imageUrl: avatarUrl,
    size: width ?? height ?? 56,
  );
}
