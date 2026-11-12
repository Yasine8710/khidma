import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A block of [RegisterRow]s between hairline rules, like a page of a trade
/// register: a rule above, one between each row and one below.
class RegisterGroup extends StatelessWidget {
  const RegisterGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rule = BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One register line: an optional line icon, a title (and muted subtitle),
/// and a trailing value or chevron. Tappable when [onTap] is set: the whole
/// row is then one button for screen readers, at least 56 high.
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
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Value or control on the end side. Replaces the chevron.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Printed in the error ink (e.g. "Delete my account"), without a chevron.
  final bool destructive;

  /// Chevron on tappable rows without a [trailing] widget.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ink = destructive ? scheme.error : scheme.onSurface;
    final enabled = onTap != null;
    final end =
        trailing ??
        (enabled && showChevron && !destructive
            ? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant)
            : null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: ink),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.bodyLarge?.copyWith(color: ink)),
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
    return InkWell(onTap: onTap, child: row);
  }
}
