import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';

/// One onboarding page: an optional soft illustration (or a [leading] widget
/// such as the logo), a short title, one line of body and an optional
/// [extra] (the language list). Content fades and rises in quietly each time
/// the page becomes [active]. Scrolls on small screens or large text.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    this.icon,
    this.photo,
    this.leading,
    this.illustration,
    this.step,
    this.active = true,
    this.foreground,
    required this.title,
    required this.body,
    this.extra,
    this.hideIconWhenCompact = false,
  });

  /// Kept for older call sites; [illustration] replaces it.
  final IconData? icon;

  /// Ignored (photos are no longer shipped); kept for older call sites.
  final String? photo;

  /// Shown above the title instead of an illustration (e.g. the logo).
  final Widget? leading;

  /// A drawing above the title, made of simple shapes and icons.
  final Widget? illustration;

  /// Ignored (the step numerals are gone); kept for older call sites.
  final String? step;

  /// True while this is the visible page: the entrance plays once it is.
  final bool active;

  /// Text colour; defaults to the theme's.
  final Color? foreground;
  final String title;
  final String body;
  final Widget? extra;

  /// On short screens or large text, drop the decoration so the content
  /// (e.g. the language list) is reachable without scrolling.
  final bool hideIconWhenCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final fg = foreground ?? scheme.onSurface;
    final compact = media.size.height < 700 || media.textScaler.scale(10) > 13;
    final tight = media.size.height < 560 || media.textScaler.scale(10) > 13;
    final hideDecor = tight && hideIconWhenCompact;
    // A page with a list (language) reads from the start edge; the value
    // pages are centred like most onboarding screens.
    final centred = extra == null;
    final align = centred ? TextAlign.center : TextAlign.start;

    return LayoutBuilder(
      builder: (context, box) {
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
                crossAxisAlignment: centred
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.stretch,
                children: [
                  if (!hideDecor && (leading != null || illustration != null))
                    _Rise(
                      active: active,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          bottom: compact ? AppSpacing.lg : AppSpacing.xl + 8,
                        ),
                        child: leading != null
                            ? Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: leading,
                              )
                            : ExcludeSemantics(
                                child: SizedBox(
                                  height: compact ? 170 : 250,
                                  child: illustration,
                                ),
                              ),
                      ),
                    ),
                  _Rise(
                    active: active,
                    step: 1,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: text.headlineSmall?.copyWith(color: fg),
                        textAlign: align,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Rise(
                    active: active,
                    step: 2,
                    child: Text(
                      body,
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: align,
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _Rise(active: active, step: 3, child: extra!),
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

/// Fades its child in with a 12 px rise when [active] turns true, slightly
/// later for a higher [step]; resets when it turns false. With Reduce Motion
/// the final state shows at once.
class _Rise extends StatelessWidget {
  const _Rise({required this.active, required this.child, this.step = 0});

  final bool active;
  final Widget child;
  final int step;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: active
          ? Motion.slow + Duration(milliseconds: 60 * step)
          : Duration.zero,
      curve: Interval(step * 0.1, 1, curve: Motion.enter),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
