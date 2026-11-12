import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/presentation/signed_out_prompt.dart';
import '../../marketplace/presentation/marketplace_failure_view.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../application/favorites_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final needSignIn = ref.watch(favoritesNeedSignInProvider);
    final saved = ref.watch(favoriteIdsProvider).value ?? const <String>[];
    final async = ref.watch(favoriteProfessionalsProvider);

    final Widget body;
    if (needSignIn) {
      body = SignedOutPrompt(
        icon: Icons.favorite_border_rounded,
        title: l10n.favoritesSignInTitle,
        body: l10n.favoritesSignInBody,
      );
    } else {
      body = async.when(
        loading: () => const SkeletonGroup(
          child: Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
            child: Skeleton(height: 92, radius: AppRadius.sm),
          ),
        ),
        error: (e, _) => MarketplaceFailureView(
          error: e,
          onRetry: () {
            ref.invalidate(favoriteIdsProvider);
            ref.invalidate(favoriteProfessionalsProvider);
          },
        ),
        data: (list) {
          // A heart removed here disappears at once, before any reload.
          final shown = [
            for (final p in list)
              if (saved.contains(p.id)) p,
          ];
          if (shown.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              title: l10n.favoritesEmptyTitle,
              body: l10n.favoritesEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(favoriteIdsProvider);
              try {
                await ref.read(favoriteProfessionalsProvider.future);
              } catch (_) {}
            },
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              itemCount: shown.length + 1,
              itemBuilder: (context, i) {
                // A ruled count line heads the list, like a register page.
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.lg,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.professionalsCount(shown.length),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  );
                }
                final p = shown[i - 1];
                return ProfessionalCard(
                  professional: p,
                  onTap: () => context.push(AppRoutes.professionalPath(p.id)),
                );
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: SafeArea(child: body),
    );
  }
}
