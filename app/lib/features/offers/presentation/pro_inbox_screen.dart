import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../professional/application/professional_providers.dart';
import '../../requests/presentation/ledger_widgets.dart';
import '../application/offers_providers.dart';
import '../domain/offers_domain.dart';
import 'offers_texts.dart';

/// Open requests a published professional can answer, with filters and paging.
/// Nothing here says who asked.
class ProInboxScreen extends ConsumerStatefulWidget {
  const ProInboxScreen({super.key});

  @override
  ConsumerState<ProInboxScreen> createState() => _ProInboxScreenState();
}

class _ProInboxScreenState extends ConsumerState<ProInboxScreen> {
  int? _category;
  bool _myArea = true;
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final proAsync = ref.watch(myProfessionalProvider);
    final mine = proAsync.value;
    final governorate = _myArea ? mine?.governorateId : null;
    final published = mine?.isPublished ?? false;

    OpenRequestsQuery query(int page) => (
      categoryId: _category,
      governorateId: governorate,
      offset: page * openRequestsPageSize,
    );

    final Widget body;
    // Nothing is asked of the server until we know the profile is published.
    if (mine == null) {
      body = proAsync.hasError
          ? ErrorState(onRetry: () => ref.invalidate(myProfessionalProvider))
          : const SkeletonGroup(
              child: Padding(
                padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
                child: Skeleton(height: 112, radius: AppRadius.lg),
              ),
            );
    } else if (!published) {
      body = EmptyState(
        icon: Icons.visibility_off_outlined,
        title: l10n.proInboxTitle,
        body: l10n.proInboxNeedsPublished,
        actionLabel: l10n.proCompleteCta,
        onAction: () => context.push(AppRoutes.proRegistration),
      );
    } else {
      body = _Pages(
        query: query,
        pages: _pages,
        onMore: () => setState(() => _pages++),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.proInboxTitle)),
      body: SafeArea(
        child: Column(
          children: [
            // Filters, then the register's ink head rule.
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  AppChip(
                    label: l10n.proInboxMyArea,
                    icon: Icons.place_outlined,
                    selected: _myArea,
                    onSelected: (v) => setState(() {
                      _myArea = v;
                      _pages = 1;
                    }),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  AppChip(
                    label: l10n.proInboxAllCategories,
                    selected: _category == null,
                    onSelected: (_) => setState(() {
                      _category = null;
                      _pages = 1;
                    }),
                  ),
                  for (final c in categories) ...[
                    const SizedBox(width: AppSpacing.sm),
                    AppChip(
                      label: c.nameFor(locale),
                      selected: _category == c.id,
                      onSelected: (_) => setState(() {
                        _category = c.id;
                        _pages = 1;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: LedgerRule(strong: true),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Pages extends ConsumerWidget {
  const _Pages({
    required this.query,
    required this.pages,
    required this.onMore,
  });

  final OpenRequestsQuery Function(int page) query;
  final int pages;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = <Widget>[];
    var more = false;
    for (var page = 0; page < pages; page++) {
      final q = query(page);
      final async = ref.watch(openRequestsPageProvider(q));
      if (async.hasError && !async.hasValue) {
        if (page == 0) {
          return ErrorState(
            onRetry: () => ref.invalidate(openRequestsPageProvider(q)),
          );
        }
        items.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
            child: AppButton(
              label: l10n.retry,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.invalidate(openRequestsPageProvider(q)),
            ),
          ),
        );
        break;
      }
      if (!async.hasValue) {
        if (page == 0) {
          return const SkeletonGroup(
            child: Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
              child: Skeleton(height: 112, radius: AppRadius.lg),
            ),
          );
        }
        items.add(
          const Padding(
            padding: EdgeInsetsDirectional.only(top: AppSpacing.md),
            child: Skeleton(height: 96),
          ),
        );
        break;
      }
      final list = async.requireValue;
      if (page == 0 && list.isEmpty) {
        return EmptyState(
          icon: Icons.inbox_outlined,
          title: l10n.proInboxEmptyTitle,
          body: l10n.proInboxEmptyBody,
        );
      }
      for (final r in list) {
        items.add(_RequestCard(request: r));
      }
      more = page == pages - 1 && list.length == openRequestsPageSize;
    }
    if (more) {
      items.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
          child: AppButton(
            label: l10n.loadMore,
            variant: AppButtonVariant.secondary,
            onPressed: onMore,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(openRequestsPageProvider),
      child: ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final OpenRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final category = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == request.categoryId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final place = (ref.watch(governoratesProvider).value ?? const [])
        .where((g) => g.id == request.governorateId)
        .map((g) => g.nameFor(locale))
        .firstOrNull;
    final mineStatus = request.myOfferStatus;
    final kicker = [
      ledgerRef(l10n, request.id),
      formatDate(request.createdAt, locale),
      ?category,
      ?place,
    ].join(' · ');
    return LedgerRow(
      semanticLabel: request.title,
      onTap: () => context.push(AppRoutes.proRequestPath(request.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LedgerKicker(kicker),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.title,
            style: text.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (mineStatus != null)
                LedgerStamp(
                  label: l10n.offerYours(offerStatusLabel(l10n, mineStatus)),
                  tone: offerStatusTone(mineStatus),
                ),
              Text(l10n.reqOffers(request.offersCount), style: text.labelLarge),
              if (request.budgetTnd != null)
                Text(
                  l10n.reqBudget(formatTnd(request.budgetTnd!, locale)),
                  style: text.bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
