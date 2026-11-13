import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../../portfolio/presentation/portfolio_image.dart';
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'flow_widgets.dart';
import 'received_offers_section.dart';
import 'requests_texts.dart';

/// One request: a clean header card (category, title, status, description
/// and the facts), the photos, then the quotes received and the job.
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
      body = CalmEmpty(
        icon: Icons.assignment_late_outlined,
        title: l10n.reqNotFound,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reqDetailTitle)),
      body: SafeArea(child: body),
    );
  }
}

/// The head of a request, shared by the customer's and the professional's
/// view: category tile, reference and date, title, status, description, then
/// the facts as hairline rows, all on one white card.
class RequestHeaderCard extends ConsumerWidget {
  const RequestHeaderCard({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.governorateId,
    required this.createdAt,
    this.cityId,
    this.budgetTnd,
    this.neededBy,
    this.expiresAt,
    this.status,
  });

  final String id;
  final String title;
  final String description;
  final int categoryId;
  final int governorateId;
  final int? cityId;
  final DateTime createdAt;
  final double? budgetTnd;
  final DateTime? neededBy;

  /// Shown while the request can still receive offers.
  final DateTime? expiresAt;

  /// Status pill under the title.
  final Widget? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cat = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == categoryId)
        .firstOrNull;
    final category = cat?.nameFor(locale);
    final governorate = (ref.watch(governoratesProvider).value ?? const [])
        .where((g) => g.id == governorateId)
        .map((g) => g.nameFor(locale))
        .firstOrNull;
    final city = cityId == null
        ? null
        : (ref.watch(citiesProvider(governorateId)).value ?? const [])
              .where((c) => c.id == cityId)
              .map((c) => c.nameFor(locale))
              .firstOrNull;
    final place = [?city, ?governorate].join(', ');
    final facts = [
      if (category != null) (l10n.flowSecService, category),
      if (place.isNotEmpty) (l10n.flowFactPlace, place),
      if (budgetTnd != null)
        (l10n.flowFactBudget, formatTnd(budgetTnd!, locale)),
      if (neededBy != null)
        (l10n.flowFactNeededBy, formatDate(neededBy!, locale)),
      if (expiresAt != null)
        (l10n.flowFactExpires, formatDate(expiresAt!, locale)),
    ];

    return FlowCard(
      gap: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: categoryIcon(cat?.icon ?? ''), seed: categoryId),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ledgerRef(l10n, id)} · ${formatDate(createdAt, locale)}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: Text(title, style: text.titleLarge),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      status!,
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: text.bodyMedium),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Hairline(),
            FactRows(facts: facts),
          ],
        ],
      ),
    );
  }
}

/// The photos of a request in a grid of rounded squares, three per line,
/// or a retry line.
class RequestPhotos extends ConsumerWidget {
  const RequestPhotos({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final photosAsync = ref.watch(requestPhotosProvider(requestId));
    final photos = photosAsync.value ?? const <RequestPhoto>[];
    if (photosAsync.hasError && !photosAsync.hasValue) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(l10n.reqPhotosFailed)),
            AppButton(
              label: l10n.retry,
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: () => ref.invalidate(requestPhotosProvider(requestId)),
            ),
          ],
        ),
      );
    }
    if (photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = AppSpacing.sm;
          final side = ((box.maxWidth - 2 * gap) / 3).floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < photos.length; i++)
                SizedBox(
                  width: side,
                  height: side,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: PortfolioImage(
                      url: photos[i].url,
                      semanticLabel: l10n.reqPhotoLabel(i + 1, photos.length),
                      cacheWidth: 360,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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
    final busy = ref.watch(requestActionsProvider);

    // Everything is built at once (no lazy list): the page is short and its
    // lower parts (the job, the review) must be reachable by scrolling.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestHeaderCard(
            id: request.id,
            title: request.title,
            description: request.description,
            categoryId: request.categoryId,
            governorateId: request.governorateId,
            cityId: request.cityId,
            createdAt: request.createdAt,
            budgetTnd: request.budgetTnd,
            neededBy: request.neededBy,
            expiresAt: request.isOpen ? request.expiresAt : null,
            status: StatusPill(
              label: statusLabel(l10n, request.status),
              tone: statusTone(request.status),
              icon: statusIcon(request.status),
            ),
          ),
          RequestPhotos(requestId: request.id),
          const SizedBox(height: AppSpacing.lg),
          ReceivedOffersSection(request: request),
          if (request.status == RequestStatus.awarded)
            BookingSection(requestId: request.id),
          if (request.isOpen) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.reqCancel,
              variant: AppButtonVariant.secondary,
              isLoading: busy,
              onPressed: () => _cancel(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
