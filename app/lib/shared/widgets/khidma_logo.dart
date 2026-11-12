import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_typography.dart';

/// The Khidma mark: a hard ink block carrying a yellow Anton "K", like a
/// workshop sign. The same drawing as the app icon
/// (`scripts/make_brand_assets.py`). The brand colours are fixed (not themed)
/// so the mark never changes with the world; in dark mode a light ring keeps
/// the ink block visible.
class KhidmaMark extends StatelessWidget {
  const KhidmaMark({super.key, this.size = 48, this.color});

  final double size;

  /// Block colour; defaults to brand ink.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final ring = (size / 24).clamp(1.5, 4).toDouble();
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _MarkPainter(
            block: color ?? AppColors.ink,
            ring: dark ? scheme.onSurface : (color ?? AppColors.ink),
            ringWidth: ring,
          ),
          child: Center(
            child: Text(
              'K',
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: AppTypography.displayFamily,
                fontWeight: FontWeight.w400,
                fontSize: size * 0.74,
                height: 1.0,
                color: AppColors.yellow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.block,
    required this.ring,
    required this.ringWidth,
  });

  final Color block;
  final Color ring;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(r, Paint()..color = block);
    canvas.drawRRect(
      r.deflate(ringWidth / 2),
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.block != block || old.ring != ring || old.ringWidth != ringWidth;
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
                // The wordmark is set in Anton, like a shop sign.
                Text(
                  'Khidma',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFamily,
                    fontSize: markSize * 0.74,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1,
                    height: 1.0,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'خدمة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTypography.arabicDisplayFamily,
                    fontSize: markSize * 0.36,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: scheme.onSurface,
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

/// Mark on a yellow sticker block (heavy ink frame + hard shadow), matching
/// the framed glyphs of [EmptyState].
class KhidmaMarkBadge extends StatelessWidget {
  const KhidmaMarkBadge({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: StickerBox(
        color: scheme.primaryContainer,
        child: Center(child: KhidmaMark(size: size * 0.6)),
      ),
    );
  }
}
