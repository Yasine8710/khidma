import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../haptics.dart';
import '../theme/app_spacing.dart';

/// The motion system of Khidma ("Signal"). One vocabulary used everywhere:
///  - things SLAM into place (short, springy), they do not drift;
///  - pressed blocks sink into their own hard shadow;
///  - lists arrive in a quick stagger, once;
///  - numbers count up;
///  - the world switch floods the screen with the new colour.
/// Everything respects the system "Reduce Motion" setting: the final state is
/// shown at once and nothing waits for an animation.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);

  /// Decelerating entrance.
  static const enter = Curves.easeOutCubic;

  /// The signature overshoot used for slams and toggles.
  static const slam = Cubic(0.2, 1.4, 0.4, 1.0);

  /// A tight spring for gesture release (mass, stiffness, damping).
  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 24);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// A block with a heavy ink outline and a hard offset "sticker" shadow. The
/// shadow offset flips for RTL so it always falls toward the end side.
class StickerBox extends StatelessWidget {
  const StickerBox({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.radius = AppRadius.md,
    this.offset = AppInk.offset,
    this.border = AppInk.border,
    this.borderColor,
    this.shadowColor,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double radius;

  /// Shadow offset in px; 0 draws no shadow (a pressed or flat block).
  final double offset;
  final double border;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = borderColor ?? scheme.onSurface;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = rtl ? -offset : offset;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 1),
        boxShadow: offset == 0
            ? null
            : [
                BoxShadow(
                  color: shadowColor ?? scheme.onSurface,
                  offset: Offset(dx, offset),
                  blurRadius: 0,
                ),
              ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? scheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ink, width: border),
        ),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Makes any child tappable with the signature press: it sinks into its
/// shadow (translate by the shadow offset), springs back on release, with a
/// light haptic. [onTap] null = disabled (no animation).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.depth = AppInk.offset,
    this.haptic = true,
    this.semanticLabel,
    this.button = true,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far the block sinks: match the child's shadow offset.
  final double depth;
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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduce = Motion.reduced(context);
    final d = _down && enabled ? widget.depth : 0.0;
    Widget body = AnimatedContainer(
      duration: reduce ? Duration.zero : Motion.fast,
      curve: Motion.slam,
      transform: Matrix4.translationValues(rtl ? -d : d, d, 0),
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

/// Plays an entrance once when first built: fade + rise, delayed by [index]
/// (capped) so a list arrives as a quick cascade. Nothing animates again on
/// rebuild or scroll-back. With Reduce Motion it appears immediately.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.child,
    this.index = 0,
    this.rise = 18,
    this.stepMs = 45,
    this.maxSteps = 8,
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
    final delay = Duration(
      milliseconds: widget.stepMs * widget.index.clamp(0, widget.maxSteps),
    );
    Future<void>.delayed(delay, () {
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
      duration: Motion.slow * 1.6,
      curve: Motion.enter,
      builder: (context, x, _) =>
          Text('${x.toStringAsFixed(fractionDigits)}$suffix', style: style),
    );
  }
}

/// Switches between children with a quick slam (scale + fade).
class SlamSwitcher extends StatelessWidget {
  const SlamSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.slam,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(a),
          child: c,
        ),
      ),
      child: child,
    );
  }
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
