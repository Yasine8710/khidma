import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Soft onboarding drawings made only of shapes and line icons (no photos,
/// no generated images). Each is laid out on a fixed 300 x 250 canvas and
/// scaled to fit, so it never overflows; positions are directional, so the
/// drawing mirrors in RTL. Decoration only (callers exclude semantics).
class _Canvas extends StatelessWidget {
  const _Canvas({required this.children, this.tint = 5});

  final List<Widget> children;
  final int tint;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).colorScheme.brightness;
    return FittedBox(
      child: SizedBox(
        width: 300,
        height: 250,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.tint(tint, b),
            borderRadius: BorderRadius.circular(AppRadius.xl + 8),
          ),
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }
}

/// A placeholder line of text.
class _Line extends StatelessWidget {
  const _Line(this.width, {this.color, this.height = 8});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
  );
}

/// A small floating white card.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.width, this.selected = false});

  final Widget child;
  final double? width;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: StickerBox(
        elevated: true,
        radius: AppRadius.md,
        borderColor: selected ? scheme.primary : null,
        border: selected ? 1.5 : 1,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon, {required this.tint, this.size = 44});

  final IconData icon;
  final int tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.tint(tint, scheme.brightness),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.48, color: scheme.onSurface),
    );
  }
}

/// A floating tile with a white rim, used around the cards.
class _FloatTile extends StatelessWidget {
  const _FloatTile(this.icon, {required this.tint});

  final IconData icon;
  final int tint;

  @override
  Widget build(BuildContext context) {
    return StickerBox(
      elevated: true,
      radius: AppRadius.md,
      padding: const EdgeInsetsDirectional.all(5),
      child: _IconTile(icon, tint: tint, size: 42),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.index, {this.size = 40});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.avatar(index),
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.paper),
  );
}

/// Page 1: a pro's card with a verified seal and stars, trade tiles around.
class FindProsIllustration extends StatelessWidget {
  const FindProsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Canvas(
      children: [
        PositionedDirectional(
          start: 50,
          top: 62,
          child: _Card(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Avatar(0),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Line(78, color: scheme.onSurface),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const _Line(56),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppColors.star,
                      ),
                    const Spacer(),
                    _Line(44, color: scheme.primaryContainer, height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
        const PositionedDirectional(
          start: 22,
          top: 20,
          child: _FloatTile(Icons.water_drop_outlined, tint: 0),
        ),
        const PositionedDirectional(
          end: 24,
          top: 30,
          child: _FloatTile(Icons.bolt_rounded, tint: 1),
        ),
        const PositionedDirectional(
          end: 40,
          bottom: 18,
          child: _FloatTile(Icons.format_paint_outlined, tint: 3),
        ),
      ],
    );
  }
}

/// Page 2: three quotes side by side, the best one picked.
class QuotesIllustration extends StatelessWidget {
  const QuotesIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget quote(int avatar, {bool picked = false}) => _Card(
      width: 210,
      selected: picked,
      child: Row(
        children: [
          _Avatar(avatar, size: 32),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_Line(80), SizedBox(height: 6), _Line(50)],
            ),
          ),
          if (picked)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 15,
                color: scheme.onPrimary,
              ),
            )
          else
            _Line(34, color: scheme.primaryContainer, height: 16),
        ],
      ),
    );
    return _Canvas(
      tint: 0,
      children: [
        PositionedDirectional(start: 26, top: 22, child: quote(1)),
        PositionedDirectional(end: 22, top: 92, child: quote(3, picked: true)),
        PositionedDirectional(start: 34, top: 162, child: quote(5)),
      ],
    );
  }
}

/// Page 3: a short chat, with call and message buttons.
class ContactIllustration extends StatelessWidget {
  const ContactIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    BorderRadiusGeometry bubble({required bool mine}) =>
        BorderRadiusDirectional.only(
          topStart: const Radius.circular(18),
          topEnd: const Radius.circular(18),
          bottomStart: Radius.circular(mine ? 18 : 4),
          bottomEnd: Radius.circular(mine ? 4 : 18),
        );
    Widget round(IconData icon, Color bg, Color fg) => Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 24),
    );
    return _Canvas(
      tint: 4,
      children: [
        PositionedDirectional(
          start: 24,
          top: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _Avatar(2, size: 30),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: bubble(mine: false),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_Line(120), SizedBox(height: 6), _Line(80)],
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          end: 24,
          top: 98,
          child: Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: bubble(mine: true),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(110, color: scheme.onPrimary.withValues(alpha: 0.8)),
                const SizedBox(height: 6),
                _Line(64, color: scheme.onPrimary.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              round(Icons.call_outlined, scheme.primary, scheme.onPrimary),
              const SizedBox(width: AppSpacing.lg),
              round(
                Icons.chat_bubble_outline_rounded,
                scheme.surface,
                scheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
