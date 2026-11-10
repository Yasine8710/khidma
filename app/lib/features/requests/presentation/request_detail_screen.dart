import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../portfolio/presentation/portfolio_image.dart';
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'received_offers_section.dart';
import 'requests_texts.dart';

/// One request: details, photos, status, and cancelling while it is open.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(requestProvider(id));
    final Widget body;
    final request = async.value;
    if (request != null) {
      body = _Details(request: request);
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(requestProvider(id)));
    } else if (async.isLoading) {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 160, radius: AppRadius.lg),
        ),
      );
    } else {
      body = EmptyState(
        icon: Icons.assignment_late_outlined,
        title: l10n.reqNotFound,
        body: '',
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reqDetailTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.request});

  final QuoteRequest request;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reqCancelTitle),
        content: Text(l10n.reqCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.reqCancelKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.reqCancel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final failure = await ref
        .read(requestActionsProvider.notifier)
        .cancel(request.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure == null
                ? l10n.reqCancelled
                : requestFailureText(l10n, failure),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final busy = ref.watch(requestActionsProvider);
    final category = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == request.categoryId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final photosAsync = ref.watch(requestPhotosProvider(request.id));
    final photos = photosAsync.value ?? const <RequestPhoto>[];

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
      children: [
        Semantics(
          header: true,
          child: Text(request.title, style: text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppBadge(
              label: statusLabel(l10n, request.status),
              tone: statusTone(request.status),
              icon: statusIcon(request.status),
            ),
            if (category != null)
              Text(category, style: text.bodyMedium?.copyWith(color: muted)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(request.description, style: text.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        if (request.budgetTnd != null)
          Text(
            l10n.reqBudget(formatTnd(request.budgetTnd!, locale)),
            style: text.bodyMedium,
          ),
        if (request.neededBy != null)
          Text(
            l10n.reqNeededBy(formatDate(request.neededBy!, locale)),
            style: text.bodyMedium,
          ),
        if (request.isOpen)
          Text(
            l10n.reqExpiresOn(formatDate(request.expiresAt, locale)),
            style: text.bodySmall?.copyWith(color: muted),
          ),
        if (photosAsync.hasError && !photosAsync.hasValue) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text(l10n.reqPhotosFailed)),
              AppButton(
                label: l10n.retry,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () =>
                    ref.invalidate(requestPhotosProvider(request.id)),
              ),
            ],
          ),
        ],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) => AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: PortfolioImage(
                    url: photos[i].url,
                    semanticLabel: l10n.reqPhotoLabel(i + 1, photos.length),
                    cacheWidth: 330,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        ReceivedOffersSection(request: request),
        if (request.status == RequestStatus.awarded)
          BookingSection(requestId: request.id),
        if (request.isOpen) ...[
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.reqCancel,
            variant: AppButtonVariant.secondary,
            isLoading: busy,
            onPressed: () => _cancel(context, ref),
          ),
        ],
      ],
    );
  }
}
