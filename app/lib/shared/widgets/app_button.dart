import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button. While [isLoading] it ignores taps (it stays a disabled
/// button for assistive tech) and its spinner announces "loading". The label
/// stays visible so the width does not jump.
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
    final enabled = onPressed != null && !isLoading;
    final onTap = enabled
        ? () {
            AppHaptics.light();
            onPressed!();
          }
        : null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          Semantics(
            label: AppLocalizations.of(context).loading,
            liveRegion: true,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
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
    final inline = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(const Size(48, 52)),
    );
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onTap,
        style: expand ? null : inline,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: onTap,
        style: expand ? null : inline,
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: content,
      ),
    };

    if (variant == AppButtonVariant.text) return button;
    final sticker = _StickerPress(enabled: enabled, child: button);
    return expand ? SizedBox(width: double.infinity, child: sticker) : sticker;
  }
}

/// Gives a button the "sticker" look: a hard ink shadow behind it that the
/// button sinks into while pressed. Listens to raw pointer events, so the
/// button keeps its own tap handling.
class _StickerPress extends StatefulWidget {
  const _StickerPress({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_StickerPress> createState() => _StickerPressState();
}

class _StickerPressState extends State<_StickerPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduce = Motion.reduced(context);
    const o = AppInk.offset;
    final shadowOn = widget.enabled;
    final sink = shadowOn && _down ? o : 0.0;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          end: shadowOn ? o : 0,
          bottom: shadowOn ? o : 0,
        ),
        child: Stack(
          children: [
            if (shadowOn)
              Positioned.fill(
                left: rtl ? 0 : o,
                right: rtl ? o : 0,
                top: o,
                bottom: -o,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md + 1),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: reduce ? Duration.zero : Motion.fast,
              curve: Motion.slam,
              transform: Matrix4.translationValues(rtl ? -sink : sink, sink, 0),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
