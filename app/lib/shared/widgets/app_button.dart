import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button: filled brand (primary, 52 high, radius 14), white with
/// a hairline (secondary), or a plain brand text link (text). Buttons shrink
/// slightly while pressed. While [isLoading] it ignores taps (it stays a
/// disabled button for assistive tech) but keeps its colours, and its
/// spinner announces "loading". The label stays visible so the width does not
/// jump.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Full width (default). Text buttons are always content-sized.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isLoading;
    final onTap = enabled
        ? () {
            AppHaptics.light();
            onPressed!();
          }
        : null;
    final primary = variant == AppButtonVariant.primary;
    final spinnerColor = primary ? scheme.onPrimary : scheme.primary;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          Semantics(
            label: AppLocalizations.of(context).loading,
            liveRegion: true,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spinnerColor,
              ),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    // The theme's buttons are full-width (Size.fromHeight). Inline buttons
    // need a finite minimum width or they cannot lay out in a Row.
    var style = ButtonStyle(
      minimumSize: variant == AppButtonVariant.text
          ? const WidgetStatePropertyAll(Size(48, 48))
          : expand
          ? null
          : const WidgetStatePropertyAll(Size(48, 52)),
    );
    // A loading button is disabled but keeps its normal colours.
    if (isLoading) {
      style = style.merge(switch (variant) {
        AppButtonVariant.primary => FilledButton.styleFrom(
          disabledBackgroundColor: scheme.primary,
          disabledForegroundColor: scheme.onPrimary,
        ),
        AppButtonVariant.secondary => OutlinedButton.styleFrom(
          disabledForegroundColor: scheme.onSurface,
        ),
        AppButtonVariant.text => TextButton.styleFrom(
          disabledForegroundColor: scheme.primary,
        ),
      });
    }
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onTap,
        style: style,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: onTap,
        style: style,
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: onTap,
        style: style,
        child: content,
      ),
    };

    if (variant == AppButtonVariant.text) return button;
    final pressed = _PressScale(enabled: enabled, child: button);
    return expand ? SizedBox(width: double.infinity, child: pressed) : pressed;
  }
}

/// Shrinks a button slightly while a finger is on it. Listens to raw
/// pointer events, so the button keeps its own tap handling. Off with Reduce
/// Motion.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduced(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && widget.enabled && !reduce ? 0.97 : 1,
        duration: Motion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
