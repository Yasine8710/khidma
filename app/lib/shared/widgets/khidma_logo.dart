import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The Khidma mark: a terracotta doorway arch (Sidi Bou Said doors) with an
/// ochre lantern dot. Geometry matches `scripts/make_brand_assets.py` (120-unit
/// grid) so the in-app mark and the app icon are the same drawing.
class KhidmaMark extends StatelessWidget {
  const KhidmaMark({super.key, this.size = 48, this.color});

  final double size;

  /// Arch color; defaults to the theme's primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(color ?? Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The arch only fills ~53% of the 120 grid (room for the app-icon
    // margin). In-app we zoom about the center so it fills its box.
    const zoom = 1.45;
    final s = size.width / 120 * zoom;
    canvas.translate(size.width / 2 * (1 - zoom), size.height / 2 * (1 - zoom));
    Path arch(double x0, double x1, double spring, double bottom) {
      final r = (x1 - x0) / 2;
      return Path()
        ..moveTo(x0 * s, bottom * s)
        ..lineTo(x0 * s, spring * s)
        ..arcToPoint(Offset(x1 * s, spring * s), radius: Radius.circular(r * s))
        ..lineTo(x1 * s, bottom * s)
        ..close();
    }

    final path = Path.combine(
      PathOperation.difference,
      arch(36, 84, 52, 92),
      arch(48, 72, 52, 92),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      Offset(60 * s, 70 * s),
      5.5 * s,
      Paint()..color = AppColors.saffron,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// Mark plus the "Khidma" wordmark and the Arabic name. Brand names are not
/// translated, so this uses fixed text and fonts. Read as one "Khidma" label.
class KhidmaLogo extends StatelessWidget {
  const KhidmaLogo({super.key, this.markSize = 40});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Semantics(
      label: ar ? 'خدمة' : 'Khidma',
      excludeSemantics: true,
      // Shrinks instead of overflowing in narrow spaces.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KhidmaMark(size: markSize),
            SizedBox(width: markSize * 0.3),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The wordmark is set in the heading slab, like a shop sign.
                Text(
                  'Khidma',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontSize: markSize * 0.68,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.0,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'خدمة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTypography.arabicFamily,
                    fontSize: markSize * 0.34,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mark printed in a small ruled square on card paper, matching the framed
/// icons of [EmptyState].
class KhidmaMarkBadge extends StatelessWidget {
  const KhidmaMarkBadge({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: KhidmaMark(size: size * 0.6),
    );
  }
}
