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

/// A category photo with rounded corners; without a photo (or if it fails to
/// load) a tinted block with the category icon, never a broken image. It is
/// decoration: the name is always shown next to it.
class CategoryPhoto extends StatelessWidget {
  const CategoryPhoto({
    super.key,
    required this.slug,
    this.icon,
    this.width,
    this.height,
    this.radius = AppRadius.lg,
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
      color: scheme.primaryContainer,
      child: Center(
        child: Icon(
          categoryIcon(icon ?? ''),
          size: ((height ?? width ?? 64) * 0.4).clamp(20, 56).toDouble(),
          color: scheme.onPrimaryContainer,
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

/// A category as a photo tile with its name over a deep-blue fade. Used on
/// Home (opens the search) and in the request form (picks the category:
/// [selected] draws a blue ring and a check).
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
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CategoryPhoto(slug: slug, icon: icon, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00123D78), Color(0xE60E2F5E)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            PositionedDirectional(
              start: AppSpacing.sm,
              end: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            if (selected != null && on) ...[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: scheme.primary, width: 3),
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
              ),
              PositionedDirectional(
                top: AppSpacing.sm,
                end: AppSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
