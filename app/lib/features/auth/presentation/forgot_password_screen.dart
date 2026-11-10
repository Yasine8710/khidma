import 'package:flutter/material.dart';
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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  AuthFailure? _failure;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _failure = null);
    final email = _email.text.trim();
    final result = await ref
        .read(authActionsProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted) return;
    // Same screen whether or not the address has an account (no enumeration).
    setState(() {
      if (result.isOk) {
        _sentTo = email;
      } else {
        _failure = result.failure;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionsProvider);
    final available = ref.watch(authAvailableProvider);

    final sentTo = _sentTo;
    if (sentTo != null) {
      return AuthScaffold(
        title: l10n.resetSentTitle,
        children: [
          Text(
            l10n.resetSentBody(sentTo),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.backToSignIn,
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.login),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: l10n.forgotTitle,
      subtitle: l10n.forgotSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.emailLabel,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                enabled: !busy,
                onSubmitted: (_) => _submit(),
                validator: (v) => l10n.emailProblemText(validateEmail(v)),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_failure != null) ...[
                InlineNotice(message: l10n.failureText(_failure!)),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppButton(
                label: l10n.sendResetLink,
                isLoading: busy,
                onPressed: available ? _submit : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
