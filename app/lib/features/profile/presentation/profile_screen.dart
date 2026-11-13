import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../../shared/widgets/register_row.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_texts.dart';
import '../../gallery/gallery_config.dart';
import '../../professional/application/professional_providers.dart';
import '../../settings/presentation/language_selector.dart';
import '../application/profile_providers.dart';
import 'avatar_editor.dart';
import 'delete_account_dialog.dart';
import 'edit_profile_screen.dart';

/// The Profile tab, like the account tab of the apps people use: a header
/// card (picture, name, e-mail, edit), then grouped settings rows with
/// tinted icons and chevrons: the pro space, favourites, notifications,
/// language, appearance, help, sign-out and, last, account deletion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final signedIn = ref.watch(currentUserProvider) != null;
    final profile = ref.watch(visibleProfileProvider);
    final busy = ref.watch(authActionsProvider);
    const section = SizedBox(height: AppSpacing.xl);

    return ListView(
      // The tab bar is a solid band below the list, not floating over it.
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      // One child: the page is short and built whole, so the header card is
      // never dropped while the settings below are scrolled to.
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.navProfile, style: text.headlineSmall),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FadeIn(child: _AccountCard()),
                if (signedIn) const _BecomeProfessional(),
                section,
                RegisterGroup(
                  children: [
                    if (profile?.isProfessional ?? false)
                      RegisterRow(
                        icon: Icons.storefront_outlined,
                        tint: 5,
                        title: l10n.dashTitle,
                        onTap: () => context.push(AppRoutes.proDashboard),
                      ),
                    RegisterRow(
                      icon: Icons.favorite_border_rounded,
                      tint: 3,
                      title: l10n.favoritesTitle,
                      onTap: () => context.push(AppRoutes.favorites),
                    ),
                    RegisterRow(
                      icon: Icons.notifications_none_rounded,
                      tint: 1,
                      title: l10n.notifTitle,
                      onTap: () => context.push(AppRoutes.notificationSettings),
                    ),
                  ],
                ),
                section,
                SectionHeader(title: l10n.chooseLanguage),
                const LanguageSelector(),
                section,
                SectionHeader(title: l10n.themeTitle),
                const _ThemeChoice(),
                section,
                RegisterGroup(
                  children: [
                    RegisterRow(
                      icon: Icons.help_outline_rounded,
                      tint: 0,
                      title: l10n.profileHelp,
                      onTap: () => _showHelp(context),
                    ),
                    if (signedIn) const _SignOutRow(),
                  ],
                ),
                if (signedIn) ...[
                  const SizedBox(height: AppSpacing.md),
                  RegisterGroup(
                    children: [
                      RegisterRow(
                        icon: Icons.delete_outline_rounded,
                        title: l10n.deleteAccount,
                        destructive: true,
                        onTap: busy
                            ? null
                            : () => confirmAndDeleteAccount(context, ref),
                      ),
                    ],
                  ),
                ],
                if (kShowGallery) ...[
                  section,
                  // Developer-only entry; not localized on purpose.
                  RegisterGroup(
                    children: [
                      RegisterRow(
                        icon: Icons.palette_outlined,
                        title: 'Design gallery',
                        onTap: () => context.push(AppRoutes.gallery),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The header card: who is signed in (picture, name, e-mail, account type)
/// with an edit button, or an invitation to sign in.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final myProfile = ref.watch(visibleProfileProvider);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (user == null) {
      return AppCard(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg + 4),
        child: Column(
          children: [
            const StateVisual(icon: Icons.person_outline_rounded),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.signedOutProfileTitle,
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.signedOutProfileBody,
              style: text.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
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

    // The saved profile name wins over the sign-up metadata, so an edit
    // shows up here right away.
    final name = myProfile?.fullName ?? user.fullName;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AvatarEditor(size: 64),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name?.isNotEmpty ?? false)
                      Text(name!, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      l10n.signedInAs(user.email),
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                    // Account type. Hidden while the profile loads or cannot
                    // load, so nothing of another account shows.
                    if (myProfile != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MemberType(isPro: myProfile.isProfessional),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.editProfile,
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.editProfile),
          ),
        ],
      ),
    );
  }
}

/// "Customer", or the professional pills (and the pro profile's state).
class _MemberType extends ConsumerWidget {
  const _MemberType({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!isPro) {
      return AppBadge(
        label: l10n.acctCustomer,
        icon: Icons.person_outline_rounded,
      );
    }
    final draft = ref.watch(myProfessionalProvider).value;
    return Wrap(
      spacing: AppSpacing.xs,
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
            tone: draft.isPublished ? BadgeTone.success : BadgeTone.warning,
          ),
      ],
    );
  }
}

/// For customers: an invitation to offer services. Hidden while the profile
/// loads or cannot load, and for professionals.
class _BecomeProfessional extends ConsumerWidget {
  const _BecomeProfessional();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(visibleProfileProvider);
    final busy = ref.watch(profileActionsProvider);
    if (profile == null || profile.isProfessional) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: AppCard(
        color: scheme.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.storefront_outlined, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.becomeProfessionalTitle,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.becomeProfessionalBody,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.becomeProfessionalCta,
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
                    SnackBar(
                      content: Text(profileFailureText(l10n, r.failure!)),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// System / light / dark as a settings group with a radio on each row.
class _ThemeChoice extends ConsumerWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final options = <(ThemeMode, IconData, String)>[
      (ThemeMode.system, Icons.brightness_auto_outlined, l10n.themeSystem),
      (ThemeMode.light, Icons.light_mode_outlined, l10n.themeLight),
      (ThemeMode.dark, Icons.dark_mode_outlined, l10n.themeDark),
    ];
    return RegisterGroup(
      children: [
        for (final (value, icon, label) in options)
          Semantics(
            selected: value == mode,
            inMutuallyExclusiveGroup: true,
            child: RegisterRow(
              icon: icon,
              title: label,
              trailing: _Radio(selected: value == mode),
              onTap: () {
                AppHaptics.selection();
                ref.read(themeModeProvider.notifier).setMode(value);
              },
            ),
          ),
      ],
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : scheme.surface,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outline,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15, color: scheme.onPrimary)
          : null,
    );
  }
}

/// Sign out, with a spinner while it runs and a message if it fails.
class _SignOutRow extends ConsumerWidget {
  const _SignOutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionsProvider);
    return RegisterRow(
      icon: Icons.logout_rounded,
      tint: 2,
      title: l10n.signOut,
      showChevron: false,
      trailing: busy
          ? Semantics(
              label: l10n.loading,
              child: const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
      onTap: busy
          ? null
          : () async {
              final r = await ref.read(authActionsProvider.notifier).signOut();
              if (!r.isOk && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.failureText(r.failure!))),
                );
              }
            },
    );
  }
}

/// "How Khidma works": the three steps from onboarding, in a sheet.
void _showHelp(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final steps = <(IconData, String, String)>[
    (Icons.verified_user_outlined, l10n.onbTitle1, l10n.onbBody1),
    (Icons.request_quote_outlined, l10n.onbTitle2, l10n.onbBody2),
    (Icons.forum_outlined, l10n.onbTitle3, l10n.onbBody3),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.profileHelpTitle, style: text.titleLarge),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(steps[i].$1, color: scheme.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$2, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$3,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.close,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );
}
