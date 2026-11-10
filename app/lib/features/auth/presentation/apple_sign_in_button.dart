import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_providers.dart';

/// Sign in with Apple is offered on iOS only (the app is iOS-first). Overridden
/// in tests.
final appleSignInAvailableProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);

/// "or" divider plus Apple's button (black in light mode, white in dark, per
/// Apple's guidelines). Renders nothing where Apple sign-in is not available or
/// accounts are not configured.
class AppleSignInSection extends ConsumerWidget {
  const AppleSignInSection({super.key, required this.onPressed});

  /// Starts the Apple flow. Owned by the screen so it can react to the result.
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appleSignInAvailableProvider) ||
        !ref.watch(authAvailableProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(authActionsProvider);
    final dark = scheme.brightness == Brightness.dark;
    final bg = dark ? Colors.white : Colors.black;
    final fg = dark ? Colors.black : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant)),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Text(
                l10n.orSeparator,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          button: true,
          enabled: !busy,
          label: l10n.continueWithApple,
          excludeSemantics: true,
          onTap: busy ? null : onPressed,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: busy
                  ? null
                  : () {
                      AppHaptics.light();
                      onPressed();
                    },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apple, color: fg, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          l10n.continueWithApple,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
