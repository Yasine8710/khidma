import 'package:flutter/material.dart';

import '../../../core/format/rating.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';

/// Calm building blocks shared by the marketplace-side features (home,
/// professionals, freelancers, portfolio, reviews, favorites): soft cards,
/// tinted tiles with line icons, initials avatars, pills and the profile
/// header band. Colours come from the colour scheme and the [AppColors]
/// helpers only; insets are directional (RTL).

/// A stable small number for [s], used to pick a tint or avatar colour so the
/// same person or category always looks the same.
int seedOf(String s) {
  var h = 7;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return h;
}

/// A soft tinted square with a line icon: the placeholder for a category or
/// for a photo that does not exist yet. Decoration (the name is always shown
/// next to it).
class TintTile extends StatelessWidget {
  const TintTile({
    super.key,
    required this.icon,
    required this.tint,
    this.size,
    this.iconSize = 26,
    this.radius = AppRadius.md,
    this.iconColor,
  });

  final IconData icon;

  /// Index into [AppColors.tint].
  final int tint;

  /// Square side; null fills the parent.
  final double? size;
  final double iconSize;
  final double radius;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.tint(tint, theme.brightness),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? theme.colorScheme.onSurface,
        ),
      ),
    );
    return ExcludeSemantics(
      child: size == null ? box : SizedBox.square(dimension: size, child: box),
    );
  }
}

/// A round avatar: the person's picture when there is one, otherwise their
/// initials in white on a stable colour. A failed or loading picture shows
/// the initials, never a broken image. Decorative by default (the name is
/// shown next to it).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.ring = 0,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// Width of a surface-coloured ring around it (for avatars that overlap a
  /// band).
  final double ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = ColoredBox(
      color: AppColors.avatar(seedOf(name)),
      child: Center(
        child: Text(
          AppAvatar.initialsOf(name),
          maxLines: 1,
          // The circle does not grow with the text size.
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: 1.15),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
    final url = imageUrl;
    final px = size * MediaQuery.devicePixelRatioOf(context);
    Widget face = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url == null || url.isEmpty
            ? initials
            : Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: px.isFinite && px >= 1 ? px.round() : null,
                errorBuilder: (_, _, _) => initials,
                frameBuilder: (_, child, frame, sync) =>
                    frame == null && !sync ? initials : child,
              ),
      ),
    );
    if (ring > 0) {
      face = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface,
        ),
        child: Padding(padding: EdgeInsets.all(ring), child: face),
      );
    }
    return ExcludeSemantics(child: face);
  }
}

/// The small violet "verified" tick shown after a name. Read as "Verified".
class VerifiedTick extends StatelessWidget {
  const VerifiedTick({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).verified,
    excludeSemantics: true,
    child: Icon(
      Icons.verified_rounded,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

/// A name with the verified tick right after it (when [verified]); the name
/// wraps or ellipsizes, the tick stays beside it.
class NameLine extends StatelessWidget {
  const NameLine({
    super.key,
    required this.name,
    required this.verified,
    this.style,
    this.maxLines = 1,
    this.tickSize = 16,
  });

  final String name;
  final bool verified;
  final TextStyle? style;
  final int maxLines;
  final double tickSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (verified) ...[
          const SizedBox(width: AppSpacing.xs),
          VerifiedTick(size: tickSize),
        ],
      ],
    );
  }
}

/// A soft violet pill with a line icon: a fact about a person ("Documents
/// vérifiés", "Disponible"). Never a control.
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label, this.icon, this.dot});

  final String label;
  final IconData? icon;

  /// A small coloured dot instead of an icon (availability).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null)
              SizedBox.square(
                dimension: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            if (dot != null || icon != null) const SizedBox(width: 6),
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

/// A quiet grey tag (skills, areas). Never a control.
class SoftTag extends StatelessWidget {
  const SoftTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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

/// A section title row: the title on the start side, an optional quiet link
/// ("Tout voir") on the end.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.small = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A sub-heading inside a section (titleMedium instead of titleLarge).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: small ? text.titleMedium : text.titleLarge,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              fit: FlexFit.loose,
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Text(
                    actionLabel!,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    style: text.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact rating: one star, the value and the review count ("★ 4,9
/// (126)"); "No reviews yet" when there are none. Read as one phrase.
class RatingInline extends StatelessWidget {
  const RatingInline({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.size = 16,
  });

  final double rating;
  final int reviewCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (reviewCount <= 0) {
      return Text(
        l10n.ratingNone,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: muted),
      );
    }
    final value = formatRating(rating, locale);
    return Semantics(
      label: l10n.ratingSummary(value, reviewCount),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size + 2, color: AppColors.star),
          const SizedBox(width: 3),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: text.titleSmall),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '($reviewCount)',
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// One column of a [StatsCard].
class StatItem {
  const StatItem({
    required this.label,
    this.value,
    this.fractionDigits = 0,
    this.suffix = '',
    this.text,
  });

  final String label;

  /// Counted up the first time it shows. Null shows [text] or a dash.
  final num? value;
  final int fractionDigits;
  final String suffix;

  /// Shown as is (no count-up) when [value] is null.
  final String? text;
}

/// The profile's stats: a soft card with up to three columns split by
/// hairlines, a big number (counting up once) over a small label. Each
/// column reads as "label: value".
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = text.headlineSmall;
    Widget column(StatItem s) {
      final shown = s.value == null
          ? (s.text ?? '—')
          : '${s.value!.toStringAsFixed(s.fractionDigits)}${s.suffix}';
      return Semantics(
        container: true,
        label: '${s.label}: $shown',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: s.value == null
                    ? Text(shown, style: style, maxLines: 1)
                    : CountUp(
                        value: s.value!,
                        fractionDigits: s.fractionDigits,
                        suffix: s.suffix,
                        style: style,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                s.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return StickerBox(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: scheme.outlineVariant,
                ),
              Expanded(child: column(items[i])),
            ],
          ],
        ),
      ),
    );
  }
}

/// A definition row: label in muted text on the start side, value on the end
/// (it drops below when both do not fit), a hairline underneath.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;

  /// No hairline under the last row.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.md,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: text.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// A service as a soft card row: tinted icon tile, title, a detail line and
/// an optional price on the end ("dès / 40 DT").
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    this.detail,
    this.price,
    this.priceLead,
  });

  final IconData icon;
  final int tint;
  final String title;
  final String? detail;

  /// The amount ("40 DT") and the small word above it ("dès").
  final String? price;
  final String? priceLead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Semantics(
        container: true,
        child: StickerBox(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              TintTile(icon: icon, tint: tint, size: 52, iconSize: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (priceLead != null)
                      Text(
                        priceLead!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    Text(price!, style: text.titleMedium),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A white circle holding a control (back, report, heart) on the profile
/// header band, with a very soft shadow.
class RoundControl extends StatelessWidget {
  const RoundControl({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: scheme.onSurface),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// The top of a profile: a soft violet band with round controls (back on the
/// start side, [actions] on the end), a large circular avatar overlapping its
/// lower edge, then the name with its verified tick, a subtitle and pills.
/// Full bleed: place it outside any horizontal padding.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.verified,
    this.subtitle,
    this.pills = const [],
    this.actions = const [],
    this.side = AppSpacing.gutter,
  });

  final String name;
  final String? imageUrl;
  final bool verified;
  final String? subtitle;
  final List<Widget> pills;
  final List<Widget> actions;

  /// Horizontal inset of the content (wide screens centre it).
  final double side;

  static const double _avatar = 96;
  static const double _ring = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    const lift = _avatar / 2 + _ring;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: lift),
              child: ColoredBox(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    side - AppSpacing.xs,
                    top + AppSpacing.sm,
                    side - AppSpacing.xs,
                    AppSpacing.sm + lift + AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      if (canPop) const RoundControl(child: BackButton()),
                      const Spacer(),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        RoundControl(child: actions[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: side - _ring,
              bottom: 0,
              child: InitialsAvatar(
                name: name,
                imageUrl: imageUrl,
                size: _avatar,
                ring: _ring,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(side, AppSpacing.md, side, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: NameLine(
                  name: name,
                  verified: verified,
                  style: text.headlineSmall,
                  maxLines: 3,
                  tickSize: 22,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (pills.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: pills,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The sticky bottom action bar: surface with a hairline on top.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
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

/// A muted line standing in for an empty list.
class QuietNote extends StatelessWidget {
  const QuietNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
