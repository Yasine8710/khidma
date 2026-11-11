import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
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

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
      children: [
        Row(
          children: [
            const AvatarEditor(size: 72),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(draft.businessName ?? '', style: text.headlineSmall),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            AppBadge(
              label: draft.isPublished
                  ? l10n.proStatusPublished
                  : l10n.proStatusDraft,
              tone: draft.isPublished ? BadgeTone.success : BadgeTone.warning,
            ),
            // Only a real verification is ever shown.
            if (draft.verification == Verification.verified)
              AppBadge.verified(context),
          ],
        ),
        if (gaps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.xl),
        // Everything a professional does, as a grid of tiles.
        LayoutBuilder(
          builder: (context, box) {
            final gap = AppSpacing.md;
            final width = (box.maxWidth - gap) / 2;
            Widget tile(IconData icon, String label, String route) => SizedBox(
              width: width,
              child: _ActionTile(
                icon: icon,
                label: label,
                onTap: () => context.push(route),
              ),
            );
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                tile(
                  Icons.inbox_outlined,
                  l10n.proInboxTitle,
                  AppRoutes.proInbox,
                ),
                tile(
                  Icons.local_offer_outlined,
                  l10n.offersTitle,
                  AppRoutes.proOffers,
                ),
                tile(
                  Icons.handyman_outlined,
                  l10n.jobsTitle,
                  AppRoutes.proJobs,
                ),
                tile(
                  Icons.photo_library_outlined,
                  l10n.portfolioTitle,
                  AppRoutes.proPortfolio,
                ),
                tile(
                  Icons.verified_outlined,
                  l10n.verifCta,
                  AppRoutes.proVerification,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(l10n.dashAvailability, style: text.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<Availability>(
          showSelectedIcon: false,
          segments: [
            for (final a in Availability.values)
              ButtonSegment(value: a, label: Text(availabilityLabel(l10n, a))),
          ],
          selected: {_saved ?? draft.availability},
          onSelectionChanged: busy ? null : (s) => setAvailability(s.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(l10n.dashActivity, style: text.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _Activity(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.dashActivityNote,
          style: text.bodySmall?.copyWith(color: muted),
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
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.dashViews30d,
                  value: stats.contactViews30d,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  label: l10n.dashViewsTotal,
                  value: stats.contactViewsTotal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(label: l10n.dashFavorites, value: stats.favorites),
              ),
            ],
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
    return AppCard(
      semanticLabel: '$label: $value',
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Digits always read left to right and are Western.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('$value', style: text.headlineSmall),
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
    );
  }
}

/// A square-ish tile: tinted icon on top, label below.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
