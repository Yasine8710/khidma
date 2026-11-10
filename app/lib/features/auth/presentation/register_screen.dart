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
import 'auth_scaffold.dart';
import 'auth_texts.dart';
import 'login_screen.dart' show leaveAuth;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  AuthFailure? _failure;
  String? _confirmationSentTo;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _failure = null);
    final email = _email.text.trim();
    final result = await ref
        .read(authActionsProvider.notifier)
        .signUp(email: email, password: _password.text, fullName: _name.text);
    if (!mounted) return;
    TextInput.finishAutofillContext(shouldSave: result.isOk);
    if (!result.isOk) {
      setState(() => _failure = result.failure);
    } else if (result.outcome == SignUpOutcome.signedIn) {
      leaveAuth(context);
    } else {
      setState(() => _confirmationSentTo = email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionsProvider);
    final available = ref.watch(authAvailableProvider);

    final sentTo = _confirmationSentTo;
    if (sentTo != null) {
      return AuthScaffold(
        title: l10n.confirmEmailTitle,
        children: [
          Text(
            l10n.confirmEmailBody(sentTo),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.backToSignIn,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.pushReplacement(AppRoutes.login),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.fullNameLabel,
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  enabled: !busy,
                  maxLength: 120,
                  validator: (v) => l10n.nameProblemText(validateName(v)),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !busy,
                  helper: l10n.errPasswordShort,
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      l10n.passwordProblemText(validateNewPassword(v)),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_failure != null) ...[
                  InlineNotice(message: l10n.failureText(_failure!)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppButton(
                  label: l10n.createAccount,
                  isLoading: busy,
                  onPressed: available ? _submit : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.haveAccount,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            AppButton(
              label: l10n.signIn,
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: busy
                  ? null
                  : () => context.pushReplacement(AppRoutes.login),
            ),
          ],
        ),
      ],
    );
  }
}
