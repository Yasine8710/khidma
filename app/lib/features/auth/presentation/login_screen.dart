import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_domain.dart';
import '../domain/auth_validators.dart';
import 'apple_sign_in_button.dart';
import 'auth_scaffold.dart';
import 'auth_texts.dart';

/// Leaves an auth screen after success: back to where the user came from, or
/// Home when there is nothing to go back to.
void leaveAuth(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _failure = null);
    final result = await ref
        .read(authActionsProvider.notifier)
        .signIn(_email.text, _password.text);
    if (!mounted) return;
    // Offer to save credentials only when they actually worked.
    TextInput.finishAutofillContext(shouldSave: result.isOk);
    if (result.isOk) {
      leaveAuth(context);
    } else {
      setState(() => _failure = result.failure);
    }
  }

  Future<void> _apple() async {
    setState(() => _failure = null);
    final result = await ref
        .read(authActionsProvider.notifier)
        .signInWithApple();
    if (!mounted) return;
    if (result.isOk) {
      leaveAuth(context);
    } else if (result.failure != AuthFailure.cancelled) {
      setState(() => _failure = result.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionsProvider);
    final available = ref.watch(authAvailableProvider);
    return AuthScaffold(
      title: l10n.signInTitle,
      subtitle: l10n.signInSubtitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.emailLabel,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.email],
                  enabled: !busy,
                  validator: (v) => l10n.emailProblemText(validateEmail(v)),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.passwordLabel,
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.password],
                  enabled: !busy,
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      l10n.passwordProblemText(validateExistingPassword(v)),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AppButton(
                    label: l10n.forgotPassword,
                    variant: AppButtonVariant.text,
                    expand: false,
                    onPressed: busy
                        ? null
                        : () => context.push(AppRoutes.forgotPassword),
                  ),
                ),
                if (_failure != null) ...[
                  InlineNotice(message: l10n.failureText(_failure!)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppButton(
                  label: l10n.signIn,
                  isLoading: busy,
                  onPressed: available ? _submit : null,
                ),
              ],
            ),
          ),
        ),
        AppleSignInSection(onPressed: _apple),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.noAccountYet,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            AppButton(
              label: l10n.createAccount,
              variant: AppButtonVariant.text,
              expand: false,
              // Switch screens instead of stacking them.
              onPressed: busy
                  ? null
                  : () => context.pushReplacement(AppRoutes.register),
            ),
          ],
        ),
      ],
    );
  }
}
