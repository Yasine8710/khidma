import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';

/// The Signal card: a [StickerBox] (ink border, hard offset shadow). Tappable
/// when [onTap] is set: it sinks into its shadow while pressed and the whole
/// card is then one button node (label + tap together), at least 48 high.
/// Interactive children inside a tappable card keep their own nodes.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.lg),
    this.semanticLabel,
    this.color,
    this.flat = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Spoken name for tappable cards (e.g. professional name and profession).
  final String? semanticLabel;

  /// Fill; defaults to paper. Pass the world colour for a loud block.
  final Color? color;

  /// No hard shadow (for cards nested in other blocks).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final offset = flat ? 0.0 : AppInk.offset;
    final box = StickerBox(
      color: color,
      offset: offset,
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        depth: offset,
        button: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: box,
        ),
      ),
    );
  }
}
