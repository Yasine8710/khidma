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
import '../../../shared/widgets/khidma_logo.dart';
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

/// The Profile tab: a member card (who is signed in), then the settings as
/// ruled register rows: favorites, notifications, the pro space, language,
/// appearance and, last, account deletion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(themeModeProvider);
    final signedIn = ref.watch(currentUserProvider) != null;
    final profile = ref.watch(visibleProfileProvider);
    final busy = ref.watch(authActionsProvider);
    const section = SizedBox(height: AppSpacing.xxl);

    return ListView(
      // The tab bar is a solid band below the list, not floating over it.
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      // One child: the page is short and built whole, so the member card is
      // never dropped while the settings below are scrolled to.
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      child: Text(l10n.navProfile, style: text.displayMedium),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _AccountCard(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RegisterGroup(
                    children: [
                      RegisterRow(
                        icon: Icons.favorite_border_rounded,
                        title: l10n.favoritesTitle,
                        onTap: () => context.push(AppRoutes.favorites),
                      ),
                      RegisterRow(
                        icon: Icons.notifications_none_rounded,
                        title: l10n.notifTitle,
                        onTap: () =>
                            context.push(AppRoutes.notificationSettings),
                      ),
                      if (profile?.isProfessional ?? false)
                        RegisterRow(
                          icon: Icons.handyman_outlined,
                          title: l10n.dashTitle,
                          onTap: () => context.push(AppRoutes.proDashboard),
                        ),
                    ],
                  ),
                  if (signedIn) const _BecomeProfessional(),
                  section,
                  SectionHeader(kicker: '01', title: l10n.chooseLanguage),
                  const SizedBox(height: AppSpacing.xs),
                  const LanguageSelector(),
                  section,
                  SectionHeader(kicker: '02', title: l10n.themeTitle),
                  const SizedBox(height: AppSpacing.sm),
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
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeDark),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) {
                      AppHaptics.selection();
                      ref.read(themeModeProvider.notifier).setMode(s.first);
                    },
                  ),
                  if (signedIn) ...[
                    section,
                    SectionHeader(kicker: '03', title: l10n.acctAccount),
                    const SizedBox(height: AppSpacing.xs),
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
          ],
        ),
      ],
    );
  }
}

/// The member card: who is signed in (picture, name, e-mail, account type)
/// with edit and sign-out, or an invitation to sign in.
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
            Text(l10n.signedOutProfileTitle, style: text.headlineSmall),
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

    // The saved profile name wins over the sign-up metadata, so an edit
    // shows up here right away.
    final name = myProfile?.fullName ?? user.fullName;
    const inset = EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg);
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: scheme.onPrimaryContainer),
                        child: SectionKicker(l10n.acctMemberCard),
                      ),
                    ),
                    const KhidmaMark(size: 22),
                  ],
                ),
              ),
            ),
            _inkRule(scheme),
            Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Row(
                children: [
                  const AvatarEditor(size: 72),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name?.isNotEmpty ?? false)
                          Text(name!, style: text.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          l10n.signedInAs(user.email),
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Account type, as a definition row. Hidden while the profile
            // loads or cannot load, so nothing of another account shows.
            if (myProfile != null) ...[
              _inkRule(scheme),
              Padding(
                padding: inset.add(
                  const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.md,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.acctAccountType,
                        style: text.bodyMedium?.copyWith(color: muted),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: _MemberType(isPro: myProfile.isProfessional),
                    ),
                  ],
                ),
              ),
            ],
            _inkRule(scheme),
            Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.editProfile,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push(AppRoutes.editProfile),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: l10n.signOut,
                      variant: AppButtonVariant.secondary,
                      isLoading: busy,
                      onPressed: () async {
                        final r = await ref
                            .read(authActionsProvider.notifier)
                            .signOut();
                        if (!r.isOk && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.failureText(r.failure!)),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _inkRule(ColorScheme scheme) => Divider(
  color: scheme.onSurface,
  thickness: AppInk.border,
  height: AppInk.border,
);

/// "Customer", or the professional stamps (and the pro profile's state).
class _MemberType extends ConsumerWidget {
  const _MemberType({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!isPro) {
      return Text(
        l10n.acctCustomer,
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.titleSmall,
      );
    }
    final draft = ref.watch(myProfessionalProvider).value;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        AppBadge(label: l10n.professionalBadge, icon: Icons.handyman_outlined),
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xl),
      child: AppCard(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.becomeProfessionalTitle,
              style: text.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.becomeProfessionalBody,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
