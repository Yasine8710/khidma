import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';

/// Fades its child in with a small rise, once, when first built. Unlike
/// `StaggerIn` it starts at once (no timer), so a screen can be pumped and
/// thrown away in a test without a pending timer. With Reduce Motion the
/// child shows at once.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.rise = 12});

  final Widget child;
  final double rise;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * rise),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
