import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Photos no longer ship with the app (the owner supplies real ones later).
/// Kept so older call sites compile: always null.
String? categoryPhotoAsset(String? slug) => null;

/// A flat tile standing in for a category picture: one giant Anton letter on
/// a colour field with one flat geometric shape, chosen deterministically
/// from the slug so a category always looks the same. Colours come only from
/// the theme. Decoration: the name is always shown next to it, so it is
/// hidden from screen readers. Keeps the old photo-widget API ([icon] is
/// accepted for older call sites).
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

  /// Category icon name (unused by the glyph tile; kept for call sites).
  final String? icon;
  final double? width;
  final double? height;
  final double radius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: GlyphTile(seed: slug ?? icon ?? '?', letterSource: slug),
        ),
      ),
    );
  }
}

/// A square-cornered colour block with a giant Anton letter and a flat shape.
/// Public so other screens can use it for any text-only placeholder.
class GlyphTile extends StatelessWidget {
  const GlyphTile({super.key, required this.seed, this.letterSource});

  /// Picks colours and shape (stable per seed).
  final String seed;

  /// Text whose first letter is shown; defaults to [seed].
  final String? letterSource;

  static int _hash(String s) {
    var h = 7;
    for (final u in s.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final h = _hash(seed);
    final (bg, fg) = switch (h % 4) {
      0 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      1 => (scheme.onSurface, scheme.tertiary),
      2 => (scheme.secondary, scheme.onSecondary),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    final src = (letterSource ?? seed).trim();
    final letter = src.isEmpty ? '?' : src.characters.first.toUpperCase();
    final style = TextStyle(
      fontFamily: AppTypography.displayFor(locale),
      fontWeight: FontWeight.w400,
      color: fg,
      height: 1,
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: bg),
      child: CustomPaint(
        painter: _ShapePainter(
          variant: (h ~/ 4) % 3,
          color: fg.withValues(alpha: 0.18),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                letter,
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: style.copyWith(fontSize: 120),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({required this.variant, required this.color});

  final int variant;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    switch (variant) {
      case 0: // a quarter disc from the bottom-end corner
        canvas.drawCircle(Offset(w, h), w * 0.62, fill);
      case 1: // a diagonal slab
        canvas.drawPath(
          Path()
            ..moveTo(0, h)
            ..lineTo(w * 0.55, h)
            ..lineTo(w, h * 0.45)
            ..lineTo(w, h * 0.1)
            ..close(),
          fill,
        );
      default: // a bar along the bottom
        canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), fill);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.variant != variant || old.color != color;
}

/// A category as a sticker tile: the glyph block above, its name on a label
/// strip below, inside a heavy ink frame with a hard shadow. [selected] fills
/// the strip with ink and adds a check (and the tile sinks), like a selected
/// chip.
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
    final labelColor = on ? scheme.surface : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        button: false,
        child: StickerBox(
          offset: on ? 0 : AppInk.offset,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CategoryPhoto(slug: slug, icon: icon, radius: 0),
                ),
                AnimatedContainer(
                  duration: reduce ? Duration.zero : Motion.fast,
                  decoration: BoxDecoration(
                    color: on ? scheme.onSurface : scheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: scheme.onSurface,
                        width: AppInk.border,
                      ),
                    ),
                  ),
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
      ),
    );
  }
}
