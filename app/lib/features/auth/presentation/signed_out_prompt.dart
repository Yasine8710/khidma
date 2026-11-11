import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';

/// Shown on tabs that need an account. Primary: sign in; secondary: create.
class SignedOutPrompt extends StatelessWidget {
  const SignedOutPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.photo,
  });

  final String? photo;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateVisual(icon: icon, photo: photo),
              const SizedBox(height: AppSpacing.xl),
              Text(title, style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: l10n.signIn,
                onPressed: () => context.push(AppRoutes.login),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.createAccount,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
