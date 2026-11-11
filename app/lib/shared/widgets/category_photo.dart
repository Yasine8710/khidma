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
