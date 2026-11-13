import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';

/// The welcome screen's moving rows: chips that slide slowly sideways,
/// forever, alternating direction from row to row, fading out at both
/// edges. Purely decorative: hidden from screen readers and from touch.
///
/// The rows follow [clock] (seconds of motion so far); when it stands still
/// (Reduce Motion, tests) the rows stand still too.
class WelcomeMarquee extends StatelessWidget {
  const WelcomeMarquee({
    super.key,
    required this.rows,
    required this.clock,
    required this.rowHeight,
  });

  /// The chips of each row.
  final List<List<Widget>> rows;
  final ValueListenable<double> clock;
  final double rowHeight;

  /// Logical pixels per second, per row (slow, a little different each).
  static const _speeds = [30.0, 26.0, 22.0];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(rect),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _MarqueeRow(
                  clock: clock,
                  speed: _speeds[i % _speeds.length],
                  reverse: i.isOdd,
                  height: rowHeight,
                  children: rows[i],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One endless row: a lazily built list that repeats [children], scrolled
/// by [clock] x [speed]. [reverse] runs it the other way.
class _MarqueeRow extends StatefulWidget {
  const _MarqueeRow({
    required this.clock,
    required this.speed,
    required this.reverse,
    required this.height,
    required this.children,
  });

  final ValueListenable<double> clock;
  final double speed;
  final bool reverse;
  final double height;
  final List<Widget> children;

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.clock.addListener(_follow);
  }

  @override
  void didUpdateWidget(_MarqueeRow old) {
    super.didUpdateWidget(old);
    if (old.clock != widget.clock) {
      old.clock.removeListener(_follow);
      widget.clock.addListener(_follow);
    }
  }

  void _follow() {
    if (_scroll.hasClients) _scroll.jumpTo(widget.clock.value * widget.speed);
  }

  @override
  void dispose() {
    widget.clock.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.children;
    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        reverse: widget.reverse,
        physics: const NeverScrollableScrollPhysics(),
        primary: false,
        // Endless: the same chips again and again.
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: items[i % items.length],
        ),
      ),
    );
  }
}

/// The white rounded box shared by both chip kinds.
class _ChipBox extends StatelessWidget {
  const _ChipBox({required this.leading, required this.child});

  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(9, 0, 14, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [leading, const SizedBox(width: 9), child],
        ),
      ),
    );
  }
}

/// A service category: grey icon tile and its name.
class WelcomeCategoryChip extends StatelessWidget {
  const WelcomeCategoryChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _ChipBox(
      leading: SizedBox.square(
        dimension: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.tint(0, theme.brightness),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: scheme.onSurface),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}

/// White initials on avatar colour [colorIndex] (`AppColors.avatar`), so
/// neighbouring sample faces never share a colour. Decorative.
class WelcomeInitials extends StatelessWidget {
  const WelcomeInitials({
    super.key,
    required this.name,
    required this.colorIndex,
    this.size = 34,
  });

  final String name;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.avatar(colorIndex),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              AppAvatar.initialsOf(name),
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.paper,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sample pro: initials avatar, first name, trade and a star rating.
/// Illustrative only (not a real person or score); the row is decorative.
class WelcomeProChip extends StatelessWidget {
  const WelcomeProChip({
    super.key,
    required this.name,
    required this.trade,
    required this.rating,
    required this.colorIndex,
  });

  final String name;
  final String trade;
  final String rating;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    return _ChipBox(
      leading: WelcomeInitials(name: name, colorIndex: colorIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              height: 1.25,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trade, maxLines: 1, softWrap: false, style: small),
              const SizedBox(width: 6),
              Icon(Icons.star_rounded, size: 13, color: scheme.tertiary),
              const SizedBox(width: 2),
              Text(rating, maxLines: 1, softWrap: false, style: small),
            ],
          ),
        ],
      ),
    );
  }
}
