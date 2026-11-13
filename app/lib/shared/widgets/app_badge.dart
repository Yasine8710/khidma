import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

enum BadgeTone { neutral, info, success, warning, error }

/// Small rounded pill in a soft tint of its tone, like "Documents vérifiés"
/// on a profile. Always carries text (and usually an icon): colour alone
/// never conveys status. [filled] uses the solid tone with surface-coloured
/// text, for the rare badge that must stand out.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.filled = false,
  });

  /// Shown only when an admin has verified the professional. Callers must
  /// not render it from unverified data. Green, with a check seal.
  factory AppBadge.verified(BuildContext context) => AppBadge(
    label: AppLocalizations.of(context).verified,
    tone: BadgeTone.success,
    icon: Icons.verified_rounded,
  );

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Solid pill: the tone colour as background, surface-coloured text.
  final bool filled;

  /// Foreground color for [tone] in the given brightness.
  static Color foreground(BadgeTone tone, ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (tone) {
      BadgeTone.neutral => scheme.onSurfaceVariant,
      BadgeTone.info => scheme.primary,
      BadgeTone.success => dark ? AppColors.darkSuccess : AppColors.success,
      BadgeTone.warning => dark ? AppColors.darkWarning : AppColors.warning,
      BadgeTone.error => scheme.error,
    };
  }

  /// Background: a soft, opaque tint of the tone over the surface (light
  /// enough that the tone text keeps 4.5:1).
  static Color background(BadgeTone tone, ColorScheme scheme) =>
      Color.alphaBlend(
        foreground(tone, scheme).withValues(alpha: 0.06),
        scheme.surface,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = foreground(tone, scheme);
    final fg = filled ? scheme.surface : ink;
    final bg = filled ? ink : background(tone, scheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm + 2,
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
                    ?.copyWith(color: fg, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
