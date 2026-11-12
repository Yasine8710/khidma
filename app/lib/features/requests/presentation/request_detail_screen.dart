import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../portfolio/presentation/portfolio_image.dart';
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'ledger_widgets.dart';
import 'received_offers_section.dart';
import 'requests_texts.dart';

/// One request as a work order: reference, title and status stamp, the facts
/// as ruled rows, photos; then the quotes received and the job.
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
          child: Skeleton(height: 160, radius: AppRadius.md),
        ),
      );
    } else {
      body = TypeEmpty(
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

/// The head of a work order, shared by the customer's and the
/// professional's view of a request: reference line with the status stamp,
/// title, description, then the facts.
class WorkOrderHeader extends ConsumerWidget {
  const WorkOrderHeader({
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
    this.stamp,
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

  /// Status stamp at the end of the reference line.
  final Widget? stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final category = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == categoryId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
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

    final scheme = Theme.of(context).colorScheme;
    final onWorld = scheme.onPrimaryContainer;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The colour header block: reference, stamp, the title in big type.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppInk.offset,
            bottom: AppInk.offset + AppSpacing.lg,
          ),
          child: StickerBox(
            color: scheme.primaryContainer,
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: LedgerKicker(
                        '${ledgerRef(l10n, id)} · ${formatDate(createdAt, locale)}',
                        color: onWorld,
                      ),
                    ),
                    if (stamp != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: stamp!),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textScaler: scaler,
                    style: text.headlineMedium?.copyWith(color: onWorld),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: text.bodyLarge?.copyWith(color: onWorld),
                ),
              ],
            ),
          ),
        ),
        FactTable(
          facts: [
            if (category != null) (l10n.flowSecService, category),
            if (place.isNotEmpty) (l10n.flowFactPlace, place),
            if (budgetTnd != null)
              (l10n.flowFactBudget, formatTnd(budgetTnd!, locale)),
            if (neededBy != null)
              (l10n.flowFactNeededBy, formatDate(neededBy!, locale)),
            if (expiresAt != null)
              (l10n.flowFactExpires, formatDate(expiresAt!, locale)),
          ],
        ),
      ],
    );
  }
}

/// The photos of a request: framed squares in a strip, or a retry line.
class RequestPhotoStrip extends ConsumerWidget {
  const RequestPhotoStrip({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
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
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) => AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: scheme.onSurface,
                  width: AppInk.border,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: PortfolioImage(
                  url: photos[i].url,
                  semanticLabel: l10n.reqPhotoLabel(i + 1, photos.length),
                  cacheWidth: 288,
                ),
              ),
            ),
          ),
        ),
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
          WorkOrderHeader(
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
            stamp: LedgerStamp(
              big: true,
              label: statusLabel(l10n, request.status),
              tone: statusTone(request.status),
            ),
          ),
          RequestPhotoStrip(requestId: request.id),
          const SizedBox(height: AppSpacing.xl),
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
