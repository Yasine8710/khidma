import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';

/// The app's card: white, radius 18, a 1 px hairline, no shadow. Tappable
/// when [onTap] is set: it shrinks slightly while pressed and the whole card
/// is then one button node (label + tap together), at least 48 high.
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

  /// Fill; defaults to the surface (white in light mode).
  final Color? color;

  /// Kept for older call sites: cards never carry a shadow now.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final box = StickerBox(color: color, padding: padding, child: child);
    if (onTap == null) return box;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        button: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: box,
        ),
      ),
    );
  }
}
