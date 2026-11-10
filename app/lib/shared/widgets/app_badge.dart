import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

enum BadgeTone { neutral, info, success, warning, error }

/// Small status pill. Always carries text (and usually an icon): color alone
/// never conveys status.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  /// Shown only when an admin has verified the professional. Callers must
  /// not render it from unverified data.
  factory AppBadge.verified(BuildContext context) => AppBadge(
    label: AppLocalizations.of(context).verified,
    tone: BadgeTone.success,
    icon: Icons.verified_rounded,
  );

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Foreground color for [tone] in the given brightness.
  static Color foreground(BadgeTone tone, ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (tone) {
      BadgeTone.neutral =>
        dark ? scheme.onSurfaceVariant : AppColors.mutedStrong,
      BadgeTone.info => dark ? AppColors.darkPrimary : AppColors.primary,
      BadgeTone.success => dark ? AppColors.darkSuccess : AppColors.success,
      BadgeTone.warning => dark ? AppColors.darkWarning : AppColors.warning,
      BadgeTone.error => dark ? AppColors.darkError : AppColors.error,
    };
  }

  /// Background: the foreground tinted over the surface.
  static Color background(BadgeTone tone, ColorScheme scheme) =>
      Color.alphaBlend(
        foreground(tone, scheme).withValues(alpha: 0.12),
        scheme.surface,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground(tone, scheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background(tone, scheme),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
