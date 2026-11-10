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

/// Where a password-reset link leads. Needs the recovery session the link
/// creates; without one (expired, already used, opened directly) it explains
/// and points back to the reset request.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  AuthFailure? _failure;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _failure = null);
    final result = await ref
        .read(authActionsProvider.notifier)
        .updatePassword(_password.text);
    if (!mounted) return;
    setState(() {
      if (result.isOk) {
        _done = true;
      } else {
        _failure = result.failure;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionsProvider);
    final user = ref.watch(currentUserProvider);

    if (_done) {
      return AuthScaffold(
        title: l10n.passwordUpdated,
        children: [
          AppButton(
            label: l10n.navHome,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      );
    }
    if (user == null) {
      return AuthScaffold(
        title: l10n.linkExpiredTitle,
        subtitle: l10n.linkExpiredBody,
        children: [
          AppButton(
            label: l10n.forgotPassword,
            onPressed: () => context.go(AppRoutes.forgotPassword),
          ),
        ],
      );
    }
    return AuthScaffold(
      title: l10n.newPasswordTitle,
      subtitle: l10n.newPasswordSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                label: l10n.savePassword,
                isLoading: busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
