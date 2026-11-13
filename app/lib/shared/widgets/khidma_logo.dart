import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The Khidma mark: a violet rounded square with a white "K" drawn in three
/// round-capped strokes. The same drawing as the app icon and the SVG
/// (`scripts/make_brand_assets.py`, same geometry). Brand colours are fixed,
/// not themed, so the mark looks the same everywhere.
class KhidmaMark extends StatelessWidget {
  const KhidmaMark({super.key, this.size = 48, this.color});

  final double size;

  /// Square colour; defaults to the brand violet.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: KhidmaMarkPainter(
            block: color ?? AppColors.violet,
            glyph: AppColors.paper,
          ),
        ),
      ),
    );
  }
}

/// Paints the mark into its box. Geometry in an 80-unit square (the script
/// draws the same numbers, offset into a 120 grid).
class KhidmaMarkPainter extends CustomPainter {
  const KhidmaMarkPainter({required this.block, required this.glyph});

  final Color block;
  final Color glyph;

  /// Corner radius, stroke width and the K's strokes (x0, y0, x1, y1).
  static const radius = 20.0;
  static const stroke = 9.0;
  static const strokes = <(double, double, double, double)>[
    (28, 22, 28, 58), // stem
    (28, 46, 52, 22), // upper arm
    (37, 37, 53, 58), // lower leg
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 80;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius * k)),
      Paint()..color = block,
    );
    final pen = Paint()
      ..color = glyph
      ..strokeWidth = stroke * k
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (x0, y0, x1, y1) in strokes) {
      canvas.drawLine(Offset(x0 * k, y0 * k), Offset(x1 * k, y1 * k), pen);
    }
  }

  @override
  bool shouldRepaint(KhidmaMarkPainter old) =>
      old.block != block || old.glyph != glyph;
}

/// Mark plus the "Khidma" wordmark (bold platform font) and the Arabic name
/// (Tajawal). Brand names are not translated, so this uses fixed text. Read
/// as one "Khidma" label.
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
            SizedBox(width: markSize * 0.28),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khidma',
                  textDirection: TextDirection.ltr,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: AppTypography.latinFamily,
                    fontSize: markSize * 0.56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.05,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'خدمة',
                  textDirection: TextDirection.rtl,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: AppTypography.arabicFamily,
                    fontSize: markSize * 0.34,
                    fontWeight: FontWeight.w700,
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

/// The mark on a soft violet rounded tile, like the icon tiles elsewhere.
class KhidmaMarkBadge extends StatelessWidget {
  const KhidmaMarkBadge({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Center(child: KhidmaMark(size: size * 0.56)),
      ),
    );
  }
}
