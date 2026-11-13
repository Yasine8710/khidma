import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/marketplace/presentation/category_icon.dart';

/// Photos no longer ship with the app (the owner supplies real ones later).
/// Kept so older call sites compile: always null.
String? categoryPhotoAsset(String? slug) => null;

/// The line icon for a category: from its stored icon name when known,
/// otherwise from its slug (trades and digital categories), otherwise a
/// generic tool.
IconData categoryGlyph(String? slug, [String? icon]) {
  if (icon != null && icon.isNotEmpty) {
    final named = categoryIcon(icon);
    if (named != Icons.handyman_rounded || icon == 'handyman') return named;
  }
  return switch (slug) {
    'plumbing' => Icons.water_drop_outlined,
    'electricity' => Icons.bolt_rounded,
    'air-conditioning' => Icons.ac_unit_rounded,
    'mechanics' => Icons.car_repair_rounded,
    'painting' => Icons.format_paint_outlined,
    'carpentry' => Icons.carpenter_rounded,
    'cleaning' => Icons.cleaning_services_outlined,
    'appliance-repair' => Icons.kitchen_outlined,
    'construction' => Icons.construction_rounded,
    'gardening' => Icons.yard_outlined,
    'moving' => Icons.local_shipping_outlined,
    'maintenance' => Icons.handyman_outlined,
    'web-development' => Icons.code_rounded,
    'mobile-development' => Icons.phone_iphone_rounded,
    'design' => Icons.brush_outlined,
    'video-editing' => Icons.movie_outlined,
    'marketing' => Icons.campaign_outlined,
    'content-writing' => Icons.edit_note_rounded,
    _ => Icons.handyman_outlined,
  };
}

/// A soft tinted tile standing in for a category picture: one line icon on
/// a pale colour, chosen from the slug so a category always looks the same.
/// Decoration: the name is always shown next to it, so it is hidden from
/// screen readers. Keeps the old photo-widget API.
class CategoryPhoto extends StatelessWidget {
  const CategoryPhoto({
    super.key,
    required this.slug,
    this.icon,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    this.alignment = Alignment.center,
  });

  final String? slug;

  /// Category icon name (see `categoryIcon`).
  final String? icon;
  final double? width;
  final double? height;
  final double radius;

  /// Kept for older call sites (the icon is always centred).
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: GlyphTile(
            seed: slug ?? icon ?? '?',
            icon: categoryGlyph(slug, icon),
          ),
        ),
      ),
    );
  }
}

/// A pale tinted block with a centred line icon. Public so other screens can
/// use it for any placeholder (e.g. a pro card's picture area). Small tiles
/// get an ink icon; large placeholders a quiet muted one.
class GlyphTile extends StatelessWidget {
  const GlyphTile({
    super.key,
    required this.seed,
    this.letterSource,
    this.icon,
  });

  /// Picks the tint (stable per seed).
  final String seed;

  /// Kept for older call sites; letters are no longer drawn.
  final String? letterSource;

  /// The line icon; defaults to the glyph for [seed] as a category slug.
  final IconData? icon;

  static int hashOf(String s) {
    var h = 7;
    for (final u in s.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glyph = icon ?? categoryGlyph(seed);
    return ColoredBox(
      color: AppColors.tint(hashOf(seed), scheme.brightness),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.biggest.shortestSide.isFinite
              ? box.biggest.shortestSide
              : 48.0;
          final big = side >= 96;
          return Center(
            child: Icon(
              glyph,
              size: (side * (big ? 0.3 : 0.42)).clamp(14.0, 64.0),
              color: big
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                  : scheme.onSurface,
            ),
          );
        },
      ),
    );
  }
}

/// A category as a tile: a soft tinted rounded square with its icon, and the
/// name under it. [selected] adds a brand edge, a check and a brand name.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.name,
    required this.slug,
    required this.icon,
    required this.onTap,
    this.selected,
  });

  final String name;
  final String? slug;
  final String? icon;
  final VoidCallback onTap;

  /// Null when the tile is only a link (no selection state).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = selected ?? false;
    final reduce = Motion.reduced(context);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        button: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CategoryPhoto(
                      slug: slug,
                      icon: icon,
                      radius: AppRadius.lg,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: reduce ? Duration.zero : Motion.fast,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: on ? scheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (on)
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: on ? scheme.primary : scheme.onSurface,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
