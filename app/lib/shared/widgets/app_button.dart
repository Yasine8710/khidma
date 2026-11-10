import 'package:flutter/material.dart';

import '../../core/haptics.dart';
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

    return expand && variant != AppButtonVariant.text
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
