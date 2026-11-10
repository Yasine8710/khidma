import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// One onboarding page: tinted icon, title, body and optional extra content
/// (the language list). Scrolls on small screens or large text.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.extra,
    this.hideIconWhenCompact = false,
  });

  final IconData icon;
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
    final iconBox = compact ? 64.0 : 96.0;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          if (!(compact && hideIconWhenCompact)) ...[
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
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (extra != null) ...[const SizedBox(height: AppSpacing.xl), extra!],
        ],
      ),
    );
  }
}
