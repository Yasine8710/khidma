import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';

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
  const LedgerKicker(this.text, {super.key, this.maxLines = 2, this.color});

  final String text;
  final int maxLines;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.9,
      ),
    );
  }
}

/// A rectangular status stamp: ink border, flat colour fill chosen from the
/// scheme by tone, turned a few degrees like a rubber stamp. Text always says
/// the status; colour never carries it alone.
class LedgerStamp extends StatelessWidget {
  const LedgerStamp({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.big = false,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// A larger stamp (list cards), slightly rotated.
  final bool big;

  /// (fill, text) of a tone, both from the colour scheme.
  static (Color, Color) colorsFor(BadgeTone tone, ColorScheme scheme) =>
      switch (tone) {
        BadgeTone.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
        BadgeTone.success => (scheme.primary, scheme.onPrimary),
        BadgeTone.warning => (scheme.tertiary, scheme.onTertiary),
        BadgeTone.error => (scheme.error, scheme.onError),
        BadgeTone.neutral => (scheme.surface, scheme.onSurface),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fill, fg) = colorsFor(tone, scheme);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final stamp = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.onSurface, width: AppInk.border),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: big ? 10 : 6,
          vertical: big ? 5 : 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: big ? 16 : 13, color: fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style:
                    (big
                            ? Theme.of(context).textTheme.labelLarge
                            : Theme.of(context).textTheme.labelSmall)
                        ?.copyWith(color: fg, letterSpacing: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
    if (!big) return stamp;
    return Transform.rotate(angle: rtl ? 0.035 : -0.035, child: stamp);
  }
}

/// A full-width rule: hairline by default, heavy ink when [strong] (the head
/// rule of a register or a work order).
class LedgerRule extends StatelessWidget {
  const LedgerRule({super.key, this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: strong ? 3 : 1,
      color: strong ? scheme.onSurface : scheme.outlineVariant,
    );
  }
}

/// One tappable card of a register: a sticker block (ink border, hard shadow)
/// that sinks when pressed, a chevron at the end. The whole card is one
/// button for assistive tech. [index] staggers its first entrance.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.leading,
    this.index = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// A small square at the start (initials, glyph).
  final Widget? leading;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final card = StickerBox(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md + 2),
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
            Icon(
              rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
              color: scheme.onSurface,
            ),
          ],
        ],
      ),
    );
    final cell = Padding(
      padding: const EdgeInsetsDirectional.only(
        end: AppInk.offset,
        bottom: AppInk.offset + AppSpacing.md,
      ),
      child: onTap == null
          ? card
          : Semantics(
              container: true,
              button: true,
              label: semanticLabel,
              onTap: onTap,
              child: Pressable(onTap: onTap, button: false, child: card),
            ),
    );
    return StaggerIn(index: index, child: cell);
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
            padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
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
                    style: text.titleSmall,
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
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LedgerRule(strong: true),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 36),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    border: Border.all(
                      color: scheme.onSurface,
                      width: AppInk.border,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '$number',
                    style: text.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: text.headlineSmall)),
            ],
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
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: scheme.onSurface, width: AppInk.border),
        ),
        child: Text(
          AppAvatar.initialsOf(name),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: size * 0.45,
            height: 1,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// An unread count as a small ink block.
class CountStamp extends StatelessWidget {
  const CountStamp({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 6, 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.onSurface, width: AppInk.border),
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
                          width: 3,
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
                            width: 3,
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
                height: 3,
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
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: done ? ink : (now ? scheme.primaryContainer : scheme.surface),
        border: Border.all(color: ink, width: AppInk.border),
      ),
    );
  }
}

/// A typographic empty state: the title set big in display type, a glyph tile
/// (ink border, hard shadow, world colour) and the explanation. No photos.
class TypeEmpty extends StatelessWidget {
  const TypeEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          AppSpacing.xl,
          AppSpacing.gutter + AppInk.offset,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggerIn(
              child: ExcludeSemantics(
                child: StickerBox(
                  color: scheme.primaryContainer,
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Icon(icon, size: 44, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            StaggerIn(
              index: 1,
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textScaler: scaler,
                  style: text.displaySmall,
                ),
              ),
            ),
            if (body.isNotEmpty) const SizedBox(height: AppSpacing.md),
            if (body.isNotEmpty)
              StaggerIn(
                index: 2,
                child: Text(
                  body,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              StaggerIn(
                index: 3,
                child: AppButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
