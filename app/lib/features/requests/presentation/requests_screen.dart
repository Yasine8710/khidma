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
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'ledger_widgets.dart';
import 'requests_texts.dart';

/// The customer's requests as a register of work orders, newest first, with
/// the one action of the tab on top: start a new request. Needs an account.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final list = async.value;
    final empty = list != null && list.isEmpty;

    final Widget body;
    if (list != null) {
      body = list.isEmpty
          // The button above already offers to ask for a quote.
          ? TypeEmpty(
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
                  0,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                itemCount: list.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    // The register's count over its ink head rule.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LedgerKicker(l10n.flowRequestCount(list.length)),
                        const SizedBox(height: AppSpacing.sm),
                        const LedgerRule(strong: true),
                      ],
                    );
                  }
                  return _RequestRow(request: list[i - 1], index: i - 1);
                },
              ),
            );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(myRequestsProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 96, radius: AppRadius.md),
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
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.reqMineTitle, style: text.displaySmall),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: empty ? l10n.reqEmptyCta : l10n.reqNew,
                  icon: Icons.add_rounded,
                  onPressed: () => context.push(AppRoutes.newRequest),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// One work order in the register: reference and date over the title, the
/// status stamp, the offer count; a rule under it.
class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request, this.index = 0});

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
    final kicker = [
      ledgerRef(l10n, request.id),
      formatDate(request.createdAt, locale),
      ?cat?.nameFor(locale),
    ].join(' · ');
    final offers = request.offerCount;

    return LedgerRow(
      semanticLabel: request.title,
      onTap: () => context.push(AppRoutes.requestPath(request.id)),
      index: index,
      leading: InitialsBlock(
        name: cat?.nameFor(locale) ?? request.title,
        size: 52,
      ),
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
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LedgerStamp(
                big: true,
                label: statusLabel(l10n, request.status),
                tone: statusTone(request.status),
              ),
              Text(
                l10n.reqOffers(offers),
                style: offers > 0
                    ? text.labelLarge
                    : text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
