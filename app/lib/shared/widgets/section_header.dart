import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'app_button.dart';

/// Section title in Zilla Slab with an optional trailing text action ("See
/// all"). An optional [kicker] prints a small uppercase line in muted ink
/// above the title, like a register heading ("N° 01 · SERVICES"); set
/// [rule] to draw a hairline under the heading.
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

  /// Small uppercase label above the title. Read before the title.
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
      crossAxisAlignment: CrossAxisAlignment.end,
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

/// The small uppercase muted line above a heading ("N° 02 · ACTIVITÉ").
/// Uppercasing is skipped for Arabic, which has no case.
class SectionKicker extends StatelessWidget {
  const SectionKicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Text(
      ar ? text : text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: ar ? 0 : 1.2,
      ),
    );
  }
}
