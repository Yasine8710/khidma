import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../requests/presentation/requests_texts.dart';
import '../../reviews/application/reviews_providers.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../application/offers_providers.dart';
import '../domain/offers_domain.dart';
import 'offers_texts.dart';

/// The professional's offers with their status; opens the request.
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(myOffersProvider);
    final list = async.value;
    final Widget body;
    if (list != null) {
      body = list.isEmpty
          ? EmptyState(
              icon: Icons.local_offer_outlined,
              title: l10n.offersTitle,
              body: l10n.offersEmpty,
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myOffersProvider),
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final o = list[i];
                  return AppCard(
                    semanticLabel: o.requestTitle,
                    onTap: () =>
                        context.push(AppRoutes.proRequestPath(o.requestId)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.requestTitle,
                          style: text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppBadge(
                              label: offerStatusLabel(l10n, o.status),
                              tone: offerStatusTone(o.status),
                            ),
                            Text(
                              formatTnd(o.priceTnd, locale),
                              style: text.titleSmall,
                            ),
                            Text(
                              formatDate(o.createdAt, locale),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(myOffersProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 96, radius: AppRadius.lg),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offersTitle)),
      body: SafeArea(child: body),
    );
  }
}

/// The professional's jobs and the next step for each.
class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  Future<void> _step(
    BuildContext context,
    WidgetRef ref,
    Future<dynamic> Function() run,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await run();
    if (failure == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(requestFailureText(l10n, failure))),
      );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Job job) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.jobCancelTitle),
        content: Text(l10n.jobCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.jobKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.jobCancel),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _step(
      context,
      ref,
      () => ref.read(offerActionsProvider.notifier).cancel(job.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(offerActionsProvider);
    final async = ref.watch(myJobsProvider);
    final list = async.value;
    final Widget body;
    if (list != null) {
      body = list.isEmpty
          ? EmptyState(
              icon: Icons.handyman_outlined,
              title: l10n.jobsTitle,
              body: l10n.jobsEmpty,
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myJobsProvider),
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final j = list[i];
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          j.requestTitle,
                          style: text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppBadge(
                              label: jobStatusLabel(l10n, j.status),
                              tone: jobStatusTone(j.status),
                            ),
                            Text(
                              l10n.jobAgreedPrice(
                                formatTnd(j.priceTnd, locale),
                              ),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                        if (j.status == BookingStatus.completed)
                          _JobReview(bookingId: j.id),
                        if (j.canStart || j.canMarkDone || j.canCancel) ...[
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              if (j.canStart)
                                AppButton(
                                  label: l10n.jobStart,
                                  expand: false,
                                  onPressed: busy
                                      ? null
                                      : () => _step(
                                          context,
                                          ref,
                                          () => ref
                                              .read(
                                                offerActionsProvider.notifier,
                                              )
                                              .start(j.id),
                                        ),
                                ),
                              if (j.canMarkDone)
                                AppButton(
                                  label: l10n.jobDone,
                                  expand: false,
                                  onPressed: busy
                                      ? null
                                      : () => _step(
                                          context,
                                          ref,
                                          () => ref
                                              .read(
                                                offerActionsProvider.notifier,
                                              )
                                              .markDone(j.id),
                                        ),
                                ),
                              if (j.canCancel)
                                AppButton(
                                  label: l10n.jobCancel,
                                  variant: AppButtonVariant.secondary,
                                  expand: false,
                                  onPressed: busy
                                      ? null
                                      : () => _cancel(context, ref, j),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(myJobsProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 96, radius: AppRadius.lg),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobsTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _JobReview extends ConsumerWidget {
  const _JobReview({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reviewed = ref.watch(reviewedBookingsProvider).value;
    if (reviewed == null) return const SizedBox.shrink();
    if (reviewed.contains(bookingId)) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
        child: AppBadge(label: l10n.reviewDone, tone: BadgeTone.success),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: AppButton(
        label: l10n.reviewCtaPro,
        icon: Icons.star_outline_rounded,
        variant: AppButtonVariant.secondary,
        expand: false,
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final done = await showReviewSheet(
            context,
            bookingId: bookingId,
            aboutCustomer: true,
          );
          if (done) {
            messenger
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text(l10n.reviewThanks)));
          }
        },
      ),
    );
  }
}
