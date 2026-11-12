import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';

/// The printed-ledger vocabulary of the request -> offer -> job -> chat flow:
/// reference kickers, rubber-stamp statuses, definition rows, rules and a
/// stepped job track. Flat, rectangular, ink on paper.

/// A short reference for a record ("N° 3F2A9C"): the first six letters or
/// digits of its id, upper case. It only helps people tell rows apart.
String ledgerRef(AppLocalizations l10n, String id) {
  final code = id.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
  return l10n.flowRef(code.length > 6 ? code.substring(0, 6) : code);
}

/// Small upper-case line in muted ink above a title ("N° 3F2A9C · 9 NOV.").
class LedgerKicker extends StatelessWidget {
  const LedgerKicker(this.text, {super.key, this.maxLines = 2});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.9,
      ),
    );
  }
}

/// A rectangular status stamp: coloured outline and text, no fill. Open and
/// pending read in plain ink; terracotta stays reserved for actions.
class LedgerStamp extends StatelessWidget {
  const LedgerStamp({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  static Color colorFor(BadgeTone tone, ColorScheme scheme) => switch (tone) {
    BadgeTone.info => scheme.onSurface,
    BadgeTone.neutral => scheme.onSurfaceVariant,
    _ => AppBadge.foreground(tone, scheme),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(tone, Theme.of(context).colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 6, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width rule: hairline by default, ink when [strong] (the head rule
/// of a register or a work order).
class LedgerRule extends StatelessWidget {
  const LedgerRule({super.key, this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: strong ? 1.5 : 1,
      color: strong ? scheme.onSurface : scheme.outlineVariant,
    );
  }
}

/// One tappable row of a register: content, a trailing chevron, a rule
/// under it. The whole row is one button for assistive tech.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.leading,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// A small square at the start (thumbnail, initials).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: child),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 14),
                child: Icon(
                  rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: InkWell(onTap: onTap, excludeFromSemantics: true, child: body),
    );
  }
}

/// Key facts of a record, one per row, like a receipt: label in muted ink on
/// the start side, value in ink on the end side, a rule under each row.
class FactTable extends StatelessWidget {
  const FactTable({super.key, required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LedgerRule(strong: true),
        for (final (label, value) in facts) ...[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: text.bodyMedium?.copyWith(color: muted),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  flex: 2,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const LedgerRule(),
        ],
      ],
    );
  }
}

/// A numbered section heading of a work order ("2 · Le besoin") over a rule.
class WorkOrderHeading extends StatelessWidget {
  const WorkOrderHeading({
    super.key,
    required this.number,
    required this.title,
    this.note,
  });

  final int number;
  final String title;

  /// Muted line under the heading (what the section is for, a count...).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LedgerRule(strong: true),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$number',
                  style: text.titleLarge?.copyWith(color: muted),
                ),
                const TextSpan(text: '  ·  '),
                TextSpan(text: title),
              ],
            ),
            style: text.titleLarge,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(note!, style: text.bodySmall?.copyWith(color: muted)),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Initials in a small framed square (people have no photo in this flow).
class InitialsBlock extends StatelessWidget {
  const InitialsBlock({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          AppAvatar.initialsOf(name),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontSize: size * 0.4, height: 1),
        ),
      ),
    );
  }
}

/// An unread count as a small terracotta stamp.
class CountStamp extends StatelessWidget {
  const CountStamp({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsetsDirectional.fromSTEB(5, 2, 5, 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onPrimary),
      ),
    );
  }
}

/// A job's steps as a vertical track: a small square per step joined by a
/// rule, filled up to the current step, the current label in bold. Each label
/// appears once.
class StepTimeline extends StatelessWidget {
  const StepTimeline({
    super.key,
    required this.steps,
    required this.current,
    this.complete = false,
  });

  final List<String> steps;

  /// Index of the current step; every earlier step is done.
  final int current;

  /// The last step is reached and done too (every square filled).
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            selected: i == current,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        Container(
                          width: 1,
                          height: 6,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= current
                                    ? scheme.onSurface
                                    : scheme.outlineVariant),
                        ),
                        _Marker(
                          done: complete || i < current,
                          now: !complete && i == current,
                        ),
                        Expanded(
                          child: Container(
                            width: 1,
                            color: i == steps.length - 1
                                ? Colors.transparent
                                : (i < current
                                      ? scheme.onSurface
                                      : scheme.outlineVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.md,
                      ),
                      child: Text(
                        steps[i],
                        style: i == current
                            ? text.titleSmall
                            : text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A one-line version for lists: squares joined by rules, no labels.
class StepTrack extends StatelessWidget {
  const StepTrack({
    super.key,
    required this.count,
    required this.current,
    this.complete = false,
  });

  final int count;
  final int current;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0)
              Container(
                width: 14,
                height: 1,
                color: i <= current ? scheme.onSurface : scheme.outlineVariant,
              ),
            _Marker(
              done: complete || i < current,
              now: !complete && i == current,
            ),
          ],
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.done, required this.now});

  final bool done;
  final bool now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: done ? ink : (now ? scheme.surface : Colors.transparent),
        border: Border.all(
          color: done || now ? ink : scheme.outline,
          width: now ? 2.5 : 1.2,
        ),
      ),
    );
  }
}
