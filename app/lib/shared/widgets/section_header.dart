import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'app_button.dart';

/// Section title row: the title on the start side, an optional violet text
/// link ("Tout voir") on the end side. An optional [kicker] prints a small
/// muted line above the title; set [rule] to draw a hairline under the row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.kicker,
    this.rule = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Small muted line above the title. Read before the title.
  final String? kicker;

  /// Hairline under the heading.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Semantics(
      header: true,
      child: Text(title, style: theme.textTheme.titleLarge),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: kicker == null
              ? heading
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionKicker(kicker!),
                    const SizedBox(height: 2),
                    heading,
                  ],
                ),
        ),
        if (actionLabel != null && onAction != null)
          // Capped so a long translation wraps instead of crowding the title.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.text,
                expand: false,
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: rule
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row,
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
              ],
            )
          : row,
    );
  }
}

/// A small muted line above a heading (e.g. a category above a name). Never
/// forced to capitals.
class SectionKicker extends StatelessWidget {
  const SectionKicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
