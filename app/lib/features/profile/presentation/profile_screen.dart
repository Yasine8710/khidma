import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../auth/application/auth_providers.dart';
import 'delete_account_dialog.dart';
import '../../professional/application/professional_providers.dart';
import '../application/profile_providers.dart';
import 'edit_profile_screen.dart';
import '../../auth/presentation/auth_texts.dart';
import '../../gallery/gallery_config.dart';
import '../../settings/presentation/language_selector.dart';
import '../../../core/haptics.dart';
import '../../../core/router/app_routes.dart';

/// Settings only for now (language, appearance). Account features arrive in
/// Phase 2.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(themeModeProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.navProfile, style: text.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          const _AccountCard(),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite_border_rounded),
            title: Text(l10n.favoritesTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.favorites),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.chooseLanguage, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          const LanguageSelector(),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.themeTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {mode},
            onSelectionChanged: (s) {
              AppHaptics.selection();
              ref.read(themeModeProvider.notifier).setMode(s.first);
            },
          ),
          if (kShowGallery) ...[
            const SizedBox(height: AppSpacing.xl),
            // Developer-only entry; not localized on purpose.
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Design gallery'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.gallery),
            ),
          ],
        ],
      ),
    );
  }
}

/// Who is signed in (with a sign-out button), or an invitation to sign in.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final myProfile = ref.watch(visibleProfileProvider);
    final busy = ref.watch(authActionsProvider);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (user == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.signedOutProfileTitle, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.signedOutProfileBody,
              style: text.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.lg),
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
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The saved profile name wins over the sign-up metadata, so an edit
          // shows up here right away.
          if ((myProfile?.fullName ?? user.fullName)?.isNotEmpty ?? false)
            Text(
              (myProfile?.fullName ?? user.fullName)!,
              style: text.titleMedium,
            ),
          Text(
            l10n.signedInAs(user.email),
            style: text.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.editProfile,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.editProfile),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ProfessionalSection(),
          AppButton(
            label: l10n.signOut,
            variant: AppButtonVariant.secondary,
            isLoading: busy,
            onPressed: () async {
              final r = await ref.read(authActionsProvider.notifier).signOut();
              if (!r.isOk && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.failureText(r.failure!))),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.deleteAccount,
            variant: AppButtonVariant.text,
            onPressed: busy
                ? null
                : () => confirmAndDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Shows "Professional" when the account offers services, otherwise an
/// invitation to start. Hidden while loading or when the profile cannot load
/// (the account card above still works).
class _ProfessionalSection extends ConsumerWidget {
  const _ProfessionalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(visibleProfileProvider);
    final busy = ref.watch(profileActionsProvider);
    if (profile == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    if (profile.isProfessional) {
      final draft = ref.watch(myProfessionalProvider).value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  AppBadge(
                    label: l10n.professionalBadge,
                    tone: BadgeTone.info,
                    icon: Icons.handyman_outlined,
                  ),
                  if (draft != null)
                    AppBadge(
                      label: draft.isPublished
                          ? l10n.proStatusPublished
                          : l10n.proStatusDraft,
                      tone: draft.isPublished
                          ? BadgeTone.success
                          : BadgeTone.warning,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.dashTitle,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(AppRoutes.proDashboard),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.becomeProfessionalTitle, style: text.titleSmall),
          Text(
            l10n.becomeProfessionalBody,
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.becomeProfessionalCta,
            variant: AppButtonVariant.secondary,
            isLoading: busy,
            onPressed: () async {
              final r = await ref
                  .read(profileActionsProvider.notifier)
                  .becomeProfessional();
              if (r.isOk && context.mounted) {
                context.push(AppRoutes.proRegistration);
              }
              if (!r.isOk && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(profileFailureText(l10n, r.failure!))),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
