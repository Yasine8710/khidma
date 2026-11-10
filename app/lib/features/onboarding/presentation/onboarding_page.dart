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
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 44,
              color: scheme.brightness == Brightness.light
                  ? scheme.primary
                  : scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
