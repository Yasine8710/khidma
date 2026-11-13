import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';

/// The calm building blocks of the request -> offer -> job -> chat flow:
/// white hairline cards, small tinted status pills, circular initials,
/// fact rows with hairlines, a quiet step track and soft empty states.

/// A short reference for a record ("N° 3F2A9C"): the first six letters or
/// digits of its id, upper case. It only helps people tell records apart.
String ledgerRef(AppLocalizations l10n, String id) {
  final code = id.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
  return l10n.flowRef(code.length > 6 ? code.substring(0, 6) : code);
}

/// A stable small number for a text (picks tints and avatar colours).
int seedOf(String s) {
  var h = 7;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return h;
}

/// (background, text) of a status tone: a soft tint of the tone colour with
/// the tone's text pulled toward the body text so it stays readable on it.
(Color, Color) toneColors(BadgeTone tone, ColorScheme scheme) {
  switch (tone) {
    case BadgeTone.neutral:
      return (scheme.surfaceContainerHighest, scheme.onSurface);
    case BadgeTone.info:
      return (scheme.primaryContainer, scheme.onPrimaryContainer);
    case BadgeTone.success:
    case BadgeTone.warning:
    case BadgeTone.error:
      final c = AppBadge.foreground(tone, scheme);
      final bg = Color.alphaBlend(c.withValues(alpha: 0.12), scheme.surface);
      final fg = Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.3), c);
      return (bg, fg);
  }
}

/// A small rounded status pill in a soft tint. The text always says the
/// status; colour never carries it alone.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone, Theme.of(context).colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 4),
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
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initials in a coloured circle (people have no photo in this flow). The
/// name is always written next to it, so it is hidden from screen readers.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.avatar(seedOf(name)),
          shape: BoxShape.circle,
        ),
        child: Text(
          AppAvatar.initialsOf(name),
          maxLines: 1,
          // The circle does not grow with the text size.
          textScaler: TextScaler.noScaling,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A soft tinted square with a line icon (category, plan, method...).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.seed = 0,
    this.size = 48,
    this.brand = false,
  });

  final IconData icon;

  /// Picks the tint (stable per seed).
  final int seed;
  final double size;

  /// Soft violet instead of a category tint.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand
              ? scheme.primaryContainer
              : AppColors.tint(seed, scheme.brightness),
          borderRadius: BorderRadius.circular(
            size >= 44 ? AppRadius.md : AppRadius.sm,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.46,
          color: brand ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
      ),
    );
  }
}

/// A white card with a hairline, radius 18. Tappable when [onTap] is set:
/// it shrinks a little while pressed and is one button for assistive tech.
/// [index] staggers its first entrance; [gap] is the space under it.
class FlowCard extends StatelessWidget {
  const FlowCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.index = 0,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.lg),
    this.gap = AppSpacing.md,
    this.color,
    this.borderColor,
    this.border = AppInk.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final int index;
  final EdgeInsetsGeometry padding;
  final double gap;
  final Color? color;
  final Color? borderColor;
  final double border;

  @override
  Widget build(BuildContext context) {
    final card = StickerBox(
      padding: padding,
      color: color,
      borderColor: borderColor,
      border: border,
      child: child,
    );
    final cell = Padding(
      padding: EdgeInsetsDirectional.only(bottom: gap),
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

/// A muted chevron pointing to the end side (RTL aware).
class EndChevron extends StatelessWidget {
  const EndChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: Icon(
        rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A full-width 1 px hairline.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});

  /// Space before the line on the start side.
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: Container(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// A section title ("Offres reçues"), with an optional muted note under it
/// and an optional widget on the end side.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.note, this.end});

  final String title;
  final String? note;
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: text.titleLarge),
                ),
              ),
              if (end != null) ...[const SizedBox(width: AppSpacing.sm), end!],
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note!,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Key facts of a record, one per row: label muted on the start side, value
/// on the end side, a hairline between rows. Meant to sit inside a card.
class FactRows extends StatelessWidget {
  const FactRows({super.key, required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) const Hairline(),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    facts[i].$1,
                    style: text.bodyMedium?.copyWith(color: muted),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  flex: 2,
                  child: Text(
                    facts[i].$2,
                    textAlign: TextAlign.end,
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// An unread count: a small violet pill with white digits.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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

/// A job's steps as a vertical track: a circle per step joined by a thin
/// line, done steps checked in violet, the current one ringed, its label in
/// bold. Each label appears once.
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

  /// The last step is reached and done too.
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Color line(bool on) => on ? scheme.primary : scheme.outlineVariant;
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
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 2,
                          height: 4,
                          color: i == 0
                              ? Colors.transparent
                              : line(i <= current),
                        ),
                        StepDot(
                          done: complete || i < current,
                          now: !complete && i == current,
                        ),
                        Expanded(
                          child: Container(
                            width: 2,
                            color: i == steps.length - 1
                                ? Colors.transparent
                                : line(i < current),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 4,
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

/// A one-line version for lists: dots joined by short lines, no labels.
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
                width: 12,
                height: 2,
                color: i <= current ? scheme.primary : scheme.outlineVariant,
              ),
            StepDot(
              done: complete || i < current,
              now: !complete && i == current,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }
}

/// One step marker: violet with a check when done, a violet ring when it is
/// the current step, a grey ring otherwise.
class StepDot extends StatelessWidget {
  const StepDot({
    super.key,
    required this.done,
    required this.now,
    this.size = 20,
  });

  final bool done;
  final bool now;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? scheme.primary
            : (now ? scheme.primaryContainer : scheme.surface),
        border: Border.all(
          color: done || now ? scheme.primary : scheme.outlineVariant,
          width: now ? 2 : 1.5,
        ),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: size * 0.7, color: scheme.onPrimary)
          : null,
    );
  }
}

/// A calm empty state: a soft tinted circle with a line icon, a short
/// title, one line of help and an optional button.
class CalmEmpty extends StatelessWidget {
  const CalmEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.body = '',
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StaggerIn(
                child: ExcludeSemantics(
                  child: Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 38,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              StaggerIn(
                index: 1,
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                StaggerIn(
                  index: 2,
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                StaggerIn(
                  index: 3,
                  child: AppButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    expand: false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
