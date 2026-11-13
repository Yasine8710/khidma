import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../haptics.dart';
import '../theme/app_spacing.dart';

/// The motion system of Khidma. Quiet and quick, like the apps people use
/// every day:
///  - content fades and rises into place once (lists cascade a little);
///  - tappable cards and buttons shrink slightly while pressed;
///  - numbers count up the first time they appear;
///  - swapped content cross-fades with a small slide.
/// Everything respects the system "Reduce Motion" setting: the final state is
/// shown at once and nothing waits for an animation.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 380);

  /// Decelerating entrance.
  static const enter = Curves.easeOutCubic;

  /// Gentle settle with a hint of overshoot (toggles, hearts, selections).
  static const settle = Cubic(0.25, 1.15, 0.4, 1.0);

  /// Kept for older call sites (same as [settle]).
  static const slam = settle;

  /// A soft spring for gesture release (mass, stiffness, damping).
  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 30);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// A soft card: rounded corners, a hairline border and an optional very soft
/// shadow ([elevated]). Kept under its old name so existing call sites build;
/// [offset] and [shadowColor] are ignored.
class StickerBox extends StatelessWidget {
  const StickerBox({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.radius = AppRadius.lg,
    this.offset = 0,
    this.border = AppInk.border,
    this.borderColor,
    this.shadowColor,
    this.elevated = false,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double offset;
  final double border;
  final Color? borderColor;
  final Color? shadowColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border == 0
            ? null
            : Border.all(
                color: borderColor ?? scheme.outlineVariant,
                width: border,
              ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Makes any child tappable with a soft press: it shrinks slightly while held
/// and springs back on release, with a light haptic. [onTap] null = disabled.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.depth = 0,
    this.scale = 0.97,
    this.haptic = true,
    this.semanticLabel,
    this.button = true,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Kept for older call sites; ignored.
  final double depth;

  /// Scale while pressed.
  final double scale;
  final bool haptic;
  final String? semanticLabel;
  final bool button;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduce = Motion.reduced(context);
    Widget body = AnimatedScale(
      scale: _down && enabled && !reduce ? widget.scale : 1,
      duration: Motion.fast,
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (!enabled) return body;
    return Semantics(
      button: widget.button,
      label: widget.semanticLabel,
      enabled: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          if (widget.haptic) AppHaptics.light();
          widget.onTap!();
        },
        child: body,
      ),
    );
  }
}

/// Plays an entrance once when first built: fade + small rise, delayed by
/// [index] (capped) so a list arrives as a gentle cascade. Nothing animates
/// again on rebuild or scroll-back. With Reduce Motion it appears at once.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.child,
    this.index = 0,
    this.rise = 12,
    this.stepMs = 40,
    this.maxSteps = 6,
  });

  final Widget child;
  final int index;
  final double rise;
  final int stepMs;
  final int maxSteps;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    final ms = widget.stepMs * widget.index.clamp(0, widget.maxSteps);
    // The first item starts at once: no zero-length timer left pending.
    if (ms == 0) {
      _c.forward();
      return;
    }
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Motion.enter);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * widget.rise),
          child: child,
        ),
      ),
    );
  }
}

/// A number that counts up to [value] the first time it appears.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.fractionDigits = 0,
    this.suffix = '',
  });

  final num value;
  final TextStyle? style;
  final int fractionDigits;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final v = value.toDouble();
    if (Motion.reduced(context) || v == 0) {
      return Text('${v.toStringAsFixed(fractionDigits)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: const Duration(milliseconds: 700),
      curve: Motion.enter,
      builder: (context, x, _) =>
          Text('${x.toStringAsFixed(fractionDigits)}$suffix', style: style),
    );
  }
}

/// Cross-fades between children with a small slide up. Give each child a
/// distinct key.
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.enter,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(a),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Kept for older call sites (same as [SoftSwitcher]).
class SlamSwitcher extends SoftSwitcher {
  const SlamSwitcher({super.key, required super.child});
}

/// Drives a value with a spring toward [target] (used by gesture-released
/// sheets and dials). Calls [onChanged] every frame.
class SpringTo {
  SpringTo(this.vsync, {required this.onChanged});

  final TickerProvider vsync;
  final ValueChanged<double> onChanged;
  Ticker? _ticker;

  void run(double from, double target, {double velocity = 0}) {
    _ticker?.dispose();
    final sim = SpringSimulation(Motion.spring, from, target, velocity);
    _ticker = vsync.createTicker((d) {
      final t = d.inMicroseconds / 1e6;
      onChanged(sim.x(t));
      if (sim.isDone(t)) {
        onChanged(target);
        _ticker?.stop();
      }
    })..start();
  }

  void dispose() => _ticker?.dispose();
}
