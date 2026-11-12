import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Loading placeholder block in sunken paper with a flat blink (no glow). It is dropped
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
    // Sunken paper, the same block colour the rest of the app uses.
    final base = scheme.surfaceContainerHighest;
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
    // A hard on/off blink in two flat paper tones, no gradient sweep.
    return box
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .tint(
          color: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          duration: 700.ms,
          curve: Curves.easeInOut,
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
