import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';

/// Signal building blocks shared by the marketplace-side features (home,
/// professionals, freelancers, portfolio, reviews, favorites). Colours come
/// from the colour scheme only; the world colour is `primaryContainer`.

/// The first letter of [label] in capitals ("Plomberie" -> "P"), or "?".
String glyphOf(String label) {
  final t = label.trim();
  return t.isEmpty ? '?' : t.characters.first.toUpperCase();
}

/// A square tile with one giant typographic glyph: the placeholder for any
/// photo. [color] defaults to the world colour.
class GlyphTile extends StatelessWidget {
  const GlyphTile({
    super.key,
    required this.label,
    this.size = 64,
    this.color,
    this.onColor,
    this.offset = 0,
    this.radius = AppRadius.md,
  });

  final String label;
  final double size;
  final Color? color;
  final Color? onColor;
  final double offset;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = onColor ?? scheme.onPrimaryContainer;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: StickerBox(
          color: color ?? scheme.primaryContainer,
          offset: offset,
          radius: radius,
          child: Center(
            child: Text(
              glyphOf(label),
              maxLines: 1,
              // The tile does not grow with the text size.
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: 1.2),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: fg,
                fontSize: size * 0.56,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sticker avatar: a square ink-bordered block holding the picture, or the
/// initial of the name on paper when there is none (or it fails to load).
class SignalAvatar extends StatelessWidget {
  const SignalAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 72,
    this.offset = AppInk.offset,
    this.color,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final double offset;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        glyphOf(name),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: scheme.onSurface,
          fontSize: size * 0.56,
          height: 1,
        ),
      ),
    );
    final url = imageUrl;
    final px = size * MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: StickerBox(
          color: color ?? scheme.surface,
          offset: offset,
          child: url == null || url.isEmpty
              ? fallback
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    cacheWidth: px.isFinite && px >= 1 ? px.round() : null,
                    errorBuilder: (_, _, _) => fallback,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A big number block: an Anton numeral that counts up, a small label below.
/// Reads as "label: value" for screen readers.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.fractionDigits = 0,
    this.suffix = '',
    this.color,
    this.empty = false,
  });

  final num value;
  final String label;
  final int fractionDigits;
  final String suffix;
  final Color? color;

  /// Show a dash instead of the number (nothing to count yet).
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = color == null ? scheme.onSurface : scheme.onPrimaryContainer;
    final style = text.displaySmall?.copyWith(color: fg);
    final spoken = empty
        ? label
        : '$label: ${value.toStringAsFixed(fractionDigits)}$suffix';
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: StickerBox(
        color: color ?? scheme.surface,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            empty
                ? Text('—', style: style)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: CountUp(
                      value: value,
                      fractionDigits: fractionDigits,
                      suffix: suffix,
                      style: style,
                    ),
                  ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour header block of a detail page: a flat world-colour field with a
/// small kicker, the name in giant Anton, then [below] (stamps, facts), and a
/// sticker avatar overlapping the bottom edge. Full bleed: place it outside
/// any horizontal padding.
class ColorHeader extends StatelessWidget {
  const ColorHeader({
    super.key,
    required this.name,
    required this.avatar,
    this.kicker,
    this.below,
    this.side = AppSpacing.gutter,
  });

  final String name;
  final Widget avatar;
  final String? kicker;
  final Widget? below;

  /// Horizontal inset of the content (wide screens centre it).
  final double side;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = scheme.onPrimaryContainer;
    const avatarSize = 84.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: avatarSize / 2,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.onSurface,
                      width: AppInk.border,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    side,
                    AppSpacing.sm,
                    side,
                    AppSpacing.xl + avatarSize / 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kicker != null)
                        Text(
                          kicker!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(color: on),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        header: true,
                        child: Text(
                          name,
                          style: text.displayMedium?.copyWith(color: on),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: side,
              bottom: 0,
              child: avatar,
            ),
          ],
        ),
        if (below != null)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              side,
              AppSpacing.md,
              side,
              0,
            ),
            child: below,
          ),
      ],
    );
  }
}

/// The sticky bottom action bar: paper block with a heavy ink rule on top.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.onSurface, width: AppInk.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.md,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A flat label block (a tag, never a control).
class TagBlock extends StatelessWidget {
  const TagBlock(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.onSurface, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

/// A ruled definition row: label in muted ink at the start, value at the end
/// (it drops below when both do not fit), heavy ink rule underneath.
class FactRow extends StatelessWidget {
  const FactRow({
    super.key,
    required this.label,
    required this.value,
    this.semanticValue,
  });

  final String label;
  final Widget value;

  /// Read instead of the value widget (for values drawn as marks).
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value,
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1.5)),
      ),
      child: semanticValue == null
          ? Semantics(container: true, child: row)
          : Semantics(
              container: true,
              label: '$label: $semanticValue',
              excludeSemantics: true,
              child: row,
            ),
    );
  }
}
