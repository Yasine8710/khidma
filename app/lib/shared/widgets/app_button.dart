import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button. While [isLoading] it ignores taps, shows a spinner and
/// announces "loading" to screen readers; the label keeps the width stable.
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
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    void handle() {
      AppHaptics.light();
      onPressed!();
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    final onTap = enabled ? handle : null;
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onTap,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: onTap,
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: content,
      ),
    };

    final sized = expand && variant != AppButtonVariant.text
        ? SizedBox(width: double.infinity, child: button)
        : button;
    return Semantics(
      label: isLoading
          ? '$label, ${AppLocalizations.of(context).loading}'
          : label,
      excludeSemantics: isLoading,
      child: sized,
    );
  }
}
