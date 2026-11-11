import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// One onboarding page: tinted icon, title, body and optional extra content
/// (the language list). Scrolls on small screens or large text.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    this.icon,
    this.photo,
    this.leading,
    required this.title,
    required this.body,
    this.extra,
    this.hideIconWhenCompact = false,
  });

  final IconData? icon;

  /// Bundled photo shown instead of the icon badge (value pages).
  final String? photo;

  /// Replaces the icon badge (e.g. the brand logo on the first page).
  final Widget? leading;
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
    final compact = media.size.height < 700 || media.textScaler.scale(10) > 13;
    // Only drop decoration when space is really tight (very short screen or
    // large text); the brand logo should survive on ordinary small screens.
    final tight = media.size.height < 560 || media.textScaler.scale(10) > 13;
    final iconBox = compact ? 72.0 : 120.0;
    // The group sits in the middle of the page instead of hugging the top
    // with a dead zone below; it still scrolls when space is tight.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
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
              children: [
                if (!(tight && hideIconWhenCompact)) ...[
                  if (photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Image.asset(
                        photo!,
                        height: compact ? 200 : 320,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Decoration only: the title says everything.
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox(height: 120),
                      ),
                    )
                  else if (leading != null)
                    leading!
                  else
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: iconBox * 0.46,
                        color: scheme.brightness == Brightness.light
                            ? scheme.primary
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: text.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  body,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (extra != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  extra!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
