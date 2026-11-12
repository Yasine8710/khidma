import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';

/// One onboarding page, set like a poster: a giant Anton step numeral, a
/// sticker glyph, a huge headline that slams in when the page becomes
/// [active], and a short body. The page sits on a flat colour field chosen by
/// the screen: [foreground] is the ink for that field. Scrolls on small
/// screens or large text.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    this.icon,
    this.photo,
    this.leading,
    this.step,
    this.active = true,
    this.foreground,
    required this.title,
    required this.body,
    this.extra,
    this.hideIconWhenCompact = false,
  });

  /// Glyph in the sticker block.
  final IconData? icon;

  /// Ignored (photos are no longer shipped); kept for older call sites.
  final String? photo;

  /// Replaces the glyph (e.g. the brand logo on the first page).
  final Widget? leading;

  /// Giant numeral printed at the top ("01"). Null prints none.
  final String? step;

  /// True while this is the visible page: the entrance plays once it is.
  final bool active;

  /// Ink for the page's colour field; defaults to the theme's text colour.
  final Color? foreground;
  final String title;
  final String body;
  final Widget? extra;

  /// On short screens or large text, drop the decoration so the content
  /// (e.g. the language list) is reachable without scrolling.
  final bool hideIconWhenCompact;

  /// Largest size (<= [max]) at which the longest word of [text] fits on one
  /// line of [width], so a giant headline wraps between words only.
  static double fitSize(
    String text,
    TextStyle style,
    double width,
    TextScaler scaler, {
    double max = 56,
    double min = 22,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var size = max;
    for (final w in words) {
      final p = TextPainter(
        text: TextSpan(
          text: w,
          style: style.copyWith(fontSize: size),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final wpx = p.width;
      p.dispose();
      if (wpx > width && wpx > 0) size = size * width / wpx;
    }
    return size.clamp(min, max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final fg = foreground ?? scheme.onSurface;
    final compact = media.size.height < 700 || media.textScaler.scale(10) > 13;
    final tight = media.size.height < 560 || media.textScaler.scale(10) > 13;
    final hideDecor = tight && hideIconWhenCompact;

    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth - AppSpacing.gutter * 2;
        final headStyle = text.displayLarge!.copyWith(color: fg);
        final size = fitSize(title, headStyle, inner, media.textScaler);
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: box.maxHeight - AppSpacing.lg * 2,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!hideDecor &&
                      (step != null || leading != null || icon != null)) ...[
                    _Slam(
                      active: active,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (leading != null)
                            Flexible(child: leading!)
                          else if (step != null)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  step!,
                                  textDirection: TextDirection.ltr,
                                  textScaler: TextScaler.noScaling,
                                  style: text.displayLarge?.copyWith(
                                    fontSize: compact ? 96 : 144,
                                    height: 0.9,
                                    color: fg,
                                  ),
                                ),
                              ),
                            ),
                          if (leading == null) const Spacer(),
                          if (icon != null && leading == null)
                            ExcludeSemantics(
                              child: StickerBox(
                                color: scheme.surface,
                                padding: const EdgeInsetsDirectional.all(
                                  AppSpacing.md,
                                ),
                                child: Icon(
                                  icon,
                                  size: 36,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
                  ],
                  _Slam(
                    active: active,
                    delay: 0.15,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: headStyle.copyWith(fontSize: size),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Slam(
                    active: active,
                    delay: 0.3,
                    child: Text(
                      body,
                      style: text.bodyLarge?.copyWith(color: fg),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _Slam(active: active, delay: 0.45, child: extra!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slams its child in (rise + overshoot + fade) when [active] turns true and
/// resets when it turns false. [delay] is a 0..1 fraction of the duration.
/// With Reduce Motion the final state shows at once.
class _Slam extends StatelessWidget {
  const _Slam({required this.active, required this.child, this.delay = 0});

  final bool active;
  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: active ? Motion.slow + Motion.base * delay : Duration.zero,
      curve: Motion.slam,
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 36),
            child: Transform.scale(
              scale: 0.9 + 0.1 * t,
              alignment: AlignmentDirectional.centerStart,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
