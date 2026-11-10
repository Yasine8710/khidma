import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Loading placeholder block with a soft shimmer. The shimmer is dropped
/// when the system asks to reduce motion. Hidden from screen readers; wrap a
/// group in [SkeletonGroup] to announce "Loading" once.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = dark ? const Color(0xFF222833) : const Color(0xFFECE9E2);
    final box = Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return box;
    return box
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: dark ? const Color(0x22FFFFFF) : const Color(0x99FFFFFF),
        );
  }
}

/// Announces "Loading" once for a set of skeletons.
class SkeletonGroup extends StatelessWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).loading,
      liveRegion: true,
      child: ExcludeSemantics(child: child),
    );
  }
}
