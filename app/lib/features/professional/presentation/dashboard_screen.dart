import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/register_row.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../profile/presentation/avatar_editor.dart';
import '../application/professional_providers.dart';
import '../domain/professional_domain.dart';
import 'registration_screen.dart' show failureText, gapText;

/// The professional's own space: publication status, what is missing,
/// availability and anonymous activity counts. Requests and offers join it
/// with the requests phase.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myProfessionalProvider);
    final draft = async.value;
    final Widget body;
    if (draft != null) {
      body = _Body(draft: draft);
    } else if (async.hasError) {
      final e = async.error;
      body = ErrorState(
        onRetry: () => ref.invalidate(myProfessionalProvider),
        body: e is ProfessionalError
            ? failureText(l10n, e.failure)
            : l10n.errorBody,
      );
    } else if (async.isLoading) {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 160, radius: AppRadius.lg),
        ),
      );
    } else {
      body = ErrorState(onRetry: () => ref.invalidate(myProfessionalProvider));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.draft});

  final ProfessionalDraft draft;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// The availability just saved, shown until the reloaded profile agrees (the
  /// reload may fail; the saved value is still the truth).
  Availability? _saved;

  ProfessionalDraft get draft => widget.draft;

  @override
  void didUpdateWidget(_Body old) {
    super.didUpdateWidget(old);
    if (widget.draft.availability == _saved) _saved = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final busy = ref.watch(professionalActionsProvider);
    final uid = ref.watch(currentUserProvider)?.id;
    final gaps = draft.gaps;
    // A reload that fails after a save must not pass unnoticed.
    ref.listen(myProfessionalProvider, (_, now) {
      if (now.hasError && now.hasValue) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.dashRefreshFailed)));
      }
    });

    Future<void> setAvailability(Availability a) async {
      final messenger = ScaffoldMessenger.of(context);
      final failure = await ref
          .read(professionalActionsProvider.notifier)
          .setAvailability(a);
      if (failure == null) {
        if (mounted) setState(() => _saved = a);
        return;
      }
      if (failure == ProfessionalFailure.busy) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(l10n.dashSaveFailed)));
    }

    Widget tool(IconData icon, String label, String route) =>
        RegisterRow(icon: icon, title: label, onTap: () => context.push(route));
    const section = SizedBox(height: AppSpacing.xxl);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      // One short page: built whole, so every section (and its data) loads
      // when the board opens, not when it is scrolled to.
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The workshop's name plate.
            SectionKicker(l10n.acctWorkshop),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const AvatarEditor(size: 64),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    draft.businessName ?? '',
                    style: text.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Status as a definition row with its stamps, like a licence.
            const Divider(),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.acctStatus,
                    style: text.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge(
                          label: draft.isPublished
                              ? l10n.proStatusPublished
                              : l10n.proStatusDraft,
                          tone: draft.isPublished
                              ? BadgeTone.success
                              : BadgeTone.warning,
                        ),
                        // Only a real verification is ever shown.
                        if (draft.verification == Verification.verified)
                          AppBadge.verified(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.regMissing(gaps.map((g) => gapText(l10n, g)).join(', ')),
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: gaps.isEmpty && draft.isPublished
                  ? l10n.proEditCta
                  : l10n.proCompleteCta,
              onPressed: () => context.push(AppRoutes.proRegistration),
            ),
            if (draft.isPublished && uid != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.dashViewPublic,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.professionalPath(uid)),
              ),
            ],
            section,
            // Everything a professional does, as register rows.
            SectionHeader(kicker: '01', title: l10n.acctTools),
            const SizedBox(height: AppSpacing.xs),
            RegisterGroup(
              children: [
                tool(
                  Icons.inbox_outlined,
                  l10n.proInboxTitle,
                  AppRoutes.proInbox,
                ),
                tool(
                  Icons.local_offer_outlined,
                  l10n.offersTitle,
                  AppRoutes.proOffers,
                ),
                tool(
                  Icons.handyman_outlined,
                  l10n.jobsTitle,
                  AppRoutes.proJobs,
                ),
                tool(
                  Icons.photo_library_outlined,
                  l10n.portfolioTitle,
                  AppRoutes.proPortfolio,
                ),
                tool(
                  Icons.verified_outlined,
                  l10n.verifCta,
                  AppRoutes.proVerification,
                ),
              ],
            ),
            section,
            SectionHeader(kicker: '02', title: l10n.dashAvailability),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<Availability>(
              showSelectedIcon: false,
              segments: [
                for (final a in Availability.values)
                  ButtonSegment(
                    value: a,
                    label: Text(availabilityLabel(l10n, a)),
                  ),
              ],
              selected: {_saved ?? draft.availability},
              onSelectionChanged: busy ? null : (s) => setAvailability(s.first),
            ),
            section,
            SectionHeader(kicker: '03', title: l10n.dashActivity),
            const SizedBox(height: AppSpacing.sm),
            const _Activity(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.dashActivityNote,
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _Activity extends ConsumerWidget {
  const _Activity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myActivityProvider);
    return async.when(
      loading: () => const SkeletonGroup(child: Skeleton(height: 72)),
      error: (_, _) => Row(
        children: [
          Expanded(child: Text(l10n.dashActivityFailed)),
          AppButton(
            label: l10n.retry,
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => ref.invalidate(myActivityProvider),
          ),
        ],
      ),
      data: (a) {
        final stats = a ?? const ProfessionalActivity();
        final rule = Theme.of(context).colorScheme.outlineVariant;
        // A ruled tally: three columns in one frame, split by hairlines.
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: rule),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Stat(
                    label: l10n.dashViews30d,
                    value: stats.contactViews30d,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: rule),
                Expanded(
                  child: _Stat(
                    label: l10n.dashViewsTotal,
                    value: stats.contactViewsTotal,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: rule),
                Expanded(
                  child: _Stat(
                    label: l10n.dashFavorites,
                    value: stats.favorites,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Digits always read left to right and are Western.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('$value', style: text.headlineMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
