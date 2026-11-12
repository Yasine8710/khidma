import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_domain.dart';
import 'signal_blocks.dart';

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

/// A section title in Signal: a heavy ink bar, the title in Anton, and an
/// optional figure (a count) in a small world-coloured block on the end side.
class RegisterHeading extends StatelessWidget {
  const RegisterHeading({super.key, required this.title, this.figure});

  final String title;

  /// A small number printed in a block at the end, e.g. how many rows follow.
  final String? figure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.onSurface, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: text.headlineSmall),
                ),
              ),
              if (figure != null) ...[
                const SizedBox(width: AppSpacing.md),
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      border: Border.all(
                        color: scheme.onSurface,
                        width: AppInk.border,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 1,
                      ),
                      child: Text(
                        figure!,
                        style: text.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
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

/// A small rectangular stamp: paper block, ink outline, coloured text.
class Stamp extends StatelessWidget {
  const Stamp({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.onSurface, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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

/// The "verified" stamp. Only for professionals an admin verified.
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
    final scheme = Theme.of(context).colorScheme;
    final color = AppBadge.foreground(availabilityTone(availability), scheme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: scheme.onSurface, width: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            availabilityLabel(AppLocalizations.of(context), availability),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

/// One professional as a sticker card: glyph or picture tile, name in Anton,
/// trade and place, rating, stamps, and the heart. The verified stamp
/// appears only when the professional really is verified.
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
      color: scheme.surface,
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
            width: 64,
            height: 64,
            radius: AppRadius.sm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: text.titleLarge,
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
    );

    // Room for the hard shadow, so neighbouring cards do not touch it.
    final padded = Padding(
      padding: const EdgeInsetsDirectional.only(
        end: AppInk.offset,
        bottom: AppSpacing.lg,
      ),
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

/// Professionals as consecutive sticker cards, each opening its profile and
/// arriving in a quick stagger.
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

/// The professional's own picture when they added one, otherwise a glyph tile
/// (the first letter of their name). Never a broken image; decoration: the
/// name sits next to it.
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
  final double radius;

  /// Kept for older call sites; the avatar always has its own ink frame.
  final Color? frame;

  @override
  Widget build(BuildContext context) {
    final size = width ?? height ?? 64;
    return SignalAvatar(
      name: name ?? slug ?? icon ?? '',
      imageUrl: avatarUrl,
      size: size,
      offset: 0,
    );
  }
}
