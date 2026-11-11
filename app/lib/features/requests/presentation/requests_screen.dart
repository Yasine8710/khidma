import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'requests_texts.dart';

/// The customer's requests with their status. Needs an account.
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
          photo: 'assets/photos/onb-compare.jpg',
          title: l10n.requestsSignedOutTitle,
          body: l10n.requestsSignedOutBody,
        ),
      );
    }
    final async = ref.watch(myRequestsProvider);
    final text = Theme.of(context).textTheme;

    final Widget body;
    final list = async.value;
    if (list != null) {
      body = list.isEmpty
          ? EmptyState(
              icon: Icons.assignment_outlined,
              photo: 'assets/photos/onb-compare.jpg',
              title: l10n.requestsEmptyTitle,
              body: l10n.requestsEmptyBody,
              actionLabel: l10n.reqEmptyCta,
              onAction: () => context.push(AppRoutes.newRequest),
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myRequestsProvider);
                try {
                  await ref.read(myRequestsProvider.future);
                } catch (_) {}
              },
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _RequestCard(request: list[i]),
              ),
            );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(myRequestsProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 96, radius: AppRadius.lg),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.reqMineTitle, style: text.headlineMedium),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: AppButton(
                    label: l10n.reqNew,
                    icon: Icons.add_rounded,
                    expand: false,
                    onPressed: () => context.push(AppRoutes.newRequest),
                  ),
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

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final QuoteRequest request;

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
    return AppCard(
      semanticLabel: request.title,
      onTap: () => context.push(AppRoutes.requestPath(request.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.title,
            style: text.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (category != null)
            Text(category, style: text.bodySmall?.copyWith(color: muted)),
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
              Text(l10n.reqOffers(request.offerCount), style: text.bodySmall),
              Text(
                formatDate(request.createdAt, locale),
                style: text.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
