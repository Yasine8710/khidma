import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

enum BadgeTone { neutral, info, success, warning, error }

/// Small rectangular stamp, like the ink stamp on a trade licence: a 1px
/// frame in the tone's colour around short text. Always carries text (and
/// usually an icon): colour alone never conveys status. [filled] inks the
/// whole stamp (used for "verified").
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.filled = false,
  });

  /// Shown only when an admin has verified the professional. Callers must
  /// not render it from unverified data. Olive, solid, with a check.
  factory AppBadge.verified(BuildContext context) => AppBadge(
    label: AppLocalizations.of(context).verified,
    tone: BadgeTone.success,
    icon: Icons.verified_rounded,
    filled: true,
  );

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Solid stamp: the tone colour as background, paper-coloured text.
  final bool filled;

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

  /// Background: a faint wash of the foreground over the surface.
  static Color background(BadgeTone tone, ColorScheme scheme) =>
      Color.alphaBlend(
        foreground(tone, scheme).withValues(alpha: 0.08),
        scheme.surface,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = foreground(tone, scheme);
    // A solid stamp prints the surface colour on the tone (>= 4.5:1 for the
    // success tone in both themes).
    final fg = filled ? scheme.surface : ink;
    final bg = filled ? ink : background(tone, scheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: ink),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm - 2,
          vertical: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: fg, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
