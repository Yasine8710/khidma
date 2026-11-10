import 'package:flutter/material.dart';

import '../../core/format/rating.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Five-star rating with the numeric value and review count beside it, so
/// meaning never depends on color alone. Never invents data: with no reviews
/// it shows "No reviews yet" instead of empty stars implying a score.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.size = 16,
  });

  /// Average 0-5, ignored when [reviewCount] is 0.
  final double rating;
  final int reviewCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (reviewCount <= 0) {
      return Text(
        l10n.ratingNone,
        style: text.bodySmall?.copyWith(color: muted),
      );
    }

    final value = formatRating(rating, locale);
    final stars = rating.isNaN ? 0.0 : rating.clamp(0.0, 5.0);
    return Semantics(
      label: l10n.ratingSummary(value, reviewCount),
      excludeSemantics: true,
      // Wrap, not Row: the value and count drop to a second line instead of
      // overflowing on narrow screens or at large text sizes.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          // Star order is not mirrored: ratings read left to right everywhere.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  _Star(fill: (stars - i).clamp(0.0, 1.0), size: size),
              ],
            ),
          ),
          Text.rich(
            textDirection: TextDirection.ltr,
            TextSpan(
              children: [
                TextSpan(text: value, style: text.labelMedium),
                const TextSpan(text: ' '),
                TextSpan(
                  text: '($reviewCount)',
                  style: text.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.fill, required this.size});

  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outline;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.star_rounded, size: size, color: empty),
          ClipRect(
            clipper: _FillClipper(fill),
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: AppColors.saffron,
            ),
          ),
        ],
      ),
    );
  }
}

class _FillClipper extends CustomClipper<Rect> {
  const _FillClipper(this.fill);
  final double fill;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fill, size.height);

  @override
  bool shouldReclip(_FillClipper old) => old.fill != fill;
}
