import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'flow_widgets.dart';
import 'requests_texts.dart';

enum _Filter { all, open, closed }

/// The customer's requests, newest first, as calm cards (category tile,
/// title, date, status pill, offers), with an All / Open / Closed filter and
/// the one action of the tab on top: start a new request. Needs an account.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  _Filter _filter = _Filter.all;

  bool _keep(QuoteRequest r) => switch (_filter) {
    _Filter.all => true,
    _Filter.open => r.status == RequestStatus.open,
    _Filter.closed => r.status != RequestStatus.open,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentUserProvider) != null;
    if (!signedIn) {
      return SafeArea(
        child: SignedOutPrompt(
          icon: Icons.assignment_outlined,
          title: l10n.requestsSignedOutTitle,
          body: l10n.requestsSignedOutBody,
        ),
      );
    }
    final async = ref.watch(myRequestsProvider);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = async.value;
    final empty = list != null && list.isEmpty;

    final Widget body;
    if (list != null) {
      final shown = list.where(_keep).toList();
      body = list.isEmpty
          // The button above already offers to ask for a quote.
          ? CalmEmpty(
              icon: Icons.assignment_outlined,
              title: l10n.requestsEmptyTitle,
              body: l10n.requestsEmptyBody,
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myRequestsProvider);
                try {
                  await ref.read(myRequestsProvider.future);
                } catch (_) {}
              },
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                itemCount: shown.isEmpty ? 1 : shown.length,
                itemBuilder: (context, i) => shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: AppSpacing.xxl,
                        ),
                        child: Text(
                          l10n.reqFilterEmpty,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: muted),
                        ),
                      )
                    : _RequestCard(request: shown[i], index: i),
              ),
            );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(myRequestsProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 104, radius: AppRadius.lg),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title with the new-request button on the end side; on
                // a narrow screen or with large text the button goes under.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(l10n.reqMineTitle, style: text.headlineSmall),
                    ),
                    if (!empty)
                      AppButton(
                        label: l10n.reqNew,
                        icon: Icons.add_rounded,
                        expand: false,
                        onPressed: () => context.push(AppRoutes.newRequest),
                      ),
                  ],
                ),
                if (empty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: l10n.reqEmptyCta,
                    icon: Icons.add_rounded,
                    onPressed: () => context.push(AppRoutes.newRequest),
                  ),
                ],
                if (list != null && list.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<_Filter>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: _Filter.all,
                        label: Text(l10n.reqFilterAll),
                      ),
                      ButtonSegment(
                        value: _Filter.open,
                        label: Text(l10n.reqFilterOpen),
                      ),
                      ButtonSegment(
                        value: _Filter.closed,
                        label: Text(l10n.reqFilterClosed),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// One request: category tile, title, date and category, the status pill
/// and the number of offers; the whole card opens the request.
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, this.index = 0});

  final QuoteRequest request;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cat = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == request.categoryId)
        .firstOrNull;
    final meta = [
      formatDate(request.createdAt, locale),
      ?cat?.nameFor(locale),
    ].join(' · ');
    final offers = request.offerCount;

    return FlowCard(
      semanticLabel: request.title,
      onTap: () => context.push(AppRoutes.requestPath(request.id)),
      index: index,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: categoryIcon(cat?.icon ?? ''),
            seed: request.categoryId,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      label: statusLabel(l10n, request.status),
                      tone: statusTone(request.status),
                      icon: statusIcon(request.status),
                    ),
                    Text(
                      l10n.reqOffers(offers),
                      style: offers > 0
                          ? text.labelLarge?.copyWith(color: scheme.primary)
                          : text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const EndChevron(),
        ],
      ),
    );
  }
}
