import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A settings-style group: [RegisterRow]s in one white rounded card with a
/// hairline border, separated by inset hairlines.
class RegisterGroup extends StatelessWidget {
  const RegisterGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StickerBox(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One settings row: an optional line icon on a soft tinted tile, a title
/// (and muted subtitle), and a trailing value or chevron. Tappable when
/// [onTap] is set: the whole row is then one button for screen readers, at
/// least 56 high.
class RegisterRow extends StatelessWidget {
  const RegisterRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
    this.tint,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Value or control on the end side. Replaces the chevron.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Printed in the error colour (e.g. "Delete my account"), no chevron.
  final bool destructive;

  /// Chevron on tappable rows without a [trailing] widget.
  final bool showChevron;

  /// Index into [AppColors.tint] for the icon tile; null = soft violet.
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final titleColor = destructive ? scheme.error : scheme.onSurface;
    final (tileBg, tileFg) = destructive
        ? (scheme.errorContainer, scheme.error)
        : tint != null
        ? (AppColors.tint(tint!, scheme.brightness), scheme.onSurface)
        : (scheme.primaryContainer, scheme.primary);
    final end =
        trailing ??
        (enabled && showChevron && !destructive
            // Mirrors itself in RTL.
            ? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant)
            : null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: tileFg),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: AppSpacing.md), end],
          ],
        ),
      ),
    );
    if (!enabled) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
