import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/tunisian_phone.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_state.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/auth_scaffold.dart';
import '../../auth/presentation/auth_texts.dart';
import '../application/profile_providers.dart';
import '../domain/profile_domain.dart';

String profileFailureText(AppLocalizations l10n, ProfileFailure f) =>
    switch (f) {
      ProfileFailure.network => l10n.failNetwork,
      ProfileFailure.invalidData => l10n.failProfileInvalid,
      ProfileFailure.notSignedIn => l10n.failInvalidCredentials,
      ProfileFailure.notConfigured => l10n.failNotConfigured,
      ProfileFailure.unknown => l10n.failUnknown,
    };

/// Edit the three personal fields. The language saved is the one the app is
/// using now, so the profile and the interface never disagree.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myProfileProvider);
    final mine = ref.watch(visibleProfileProvider);
    // While the profile reloads (e.g. the account just changed) show progress,
    // never the previous account's form.
    if (async.isLoading && mine == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          title: l10n.failProfileLoad,
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
      ),
      // Keyed by account, and only ever the *current* account's profile, so
      // one person's name or phone can never be saved into another's.
      data: (p) => (p == null || mine == null)
          ? const SizedBox.shrink()
          : _EditForm(key: ValueKey(mine.id), profile: mine),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({super.key, required this.profile});
  final AppProfile profile;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName ?? '');
  late final _phone = TextEditingController(
    text: widget.profile.phone == null
        ? ''
        : (TunisianPhone.display(widget.profile.phone!) ??
              widget.profile.phone!),
  );
  ProfileFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _failure = null);
    final phoneText = _phone.text.trim();
    final result = await ref
        .read(profileActionsProvider.notifier)
        .save(
          fullName: _name.text,
          phone: phoneText.isEmpty ? null : TunisianPhone.e164(phoneText),
          preferredLanguage: ref.read(localeProvider).languageCode,
        );
    if (!mounted) return;
    if (result.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
      );
      context.pop();
    } else {
      setState(() => _failure = result.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(profileActionsProvider);
    return AuthScaffold(
      title: l10n.editProfile,
      children: [
        Form(
          key: _form,
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
                label: l10n.phoneLabel,
                controller: _phone,
                hint: '+216 20 123 456',
                helper: l10n.phoneHelper,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.telephoneNumber],
                prefixIcon: Icons.phone_outlined,
                enabled: !busy,
                onSubmitted: (_) => _save(),
                // Optional, but when given it must be a Tunisian number.
                validator: (v) =>
                    (v ?? '').trim().isEmpty || TunisianPhone.isValid(v!)
                    ? null
                    : l10n.phoneInvalid,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_failure != null) ...[
                InlineNotice(message: profileFailureText(l10n, _failure!)),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppButton(label: l10n.save, isLoading: busy, onPressed: _save),
            ],
          ),
        ),
      ],
    );
  }
}
