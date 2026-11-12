import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/marketplace/presentation/category_icon.dart';

/// The bundled photo for a category slug, or null for a category without one
/// (a new category must still render).
String? categoryPhotoAsset(String? slug) {
  const files = {
    'plumbing': 'cat-plumbing',
    'electricity': 'cat-electricity',
    'air-conditioning': 'cat-air-conditioning',
    'mechanics': 'cat-mechanics',
    'painting': 'cat-painting',
    'carpentry': 'cat-carpentry',
    'cleaning': 'cat-cleaning',
    'appliance-repair': 'cat-appliance',
    'construction': 'cat-construction',
    'gardening': 'cat-gardening',
    'moving': 'cat-moving',
    'maintenance': 'cat-maintenance',
  };
  final f = files[slug];
  return f == null ? null : 'assets/photos/$f.jpg';
}

/// A category photo, cut square-cornered (radius 4-6) like a print pasted in
/// a ledger. Without a photo (or if it fails to load) a sunken paper block
/// with the category icon in ink, never a broken image. It is decoration:
/// the name is always shown next to it.
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

  /// Category icon name, for the fallback.
  final String? icon;
  final double? width;
  final double? height;
  final double radius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final asset = categoryPhotoAsset(slug);
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          categoryIcon(icon ?? ''),
          size: ((height ?? width ?? 64) * 0.42).clamp(18, 56).toDouble(),
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final px =
        (width ?? height ?? 120) * MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: asset == null
              ? fallback
              : Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: alignment,
                  cacheWidth: px.isFinite && px >= 1 ? px.round() : null,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// A category as a small specimen card: the photo above, its name on a paper
/// label strip below, inside a 1px rule. Used where a category is picked
/// (the request form): [selected] draws an ink frame and inverts the label
/// (ink strip, paper text, a check), like a selected chip.
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
    final ink = scheme.onSurface;
    final labelColor = on ? scheme.surface : ink;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: on
              ? BorderSide(color: ink, width: 2)
              : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CategoryPhoto(slug: slug, icon: icon, radius: 0),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: on ? ink : scheme.surface,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs + 1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: labelColor),
                      ),
                    ),
                    if (on) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.check_rounded, size: 14, color: labelColor),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
