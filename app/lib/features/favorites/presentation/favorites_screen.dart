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
        photo: 'assets/photos/onb-find.jpg',
        title: l10n.favoritesSignInTitle,
        body: l10n.favoritesSignInBody,
      );
    } else {
      body = async.when(
        loading: () => const SkeletonGroup(
          child: Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
            child: Skeleton(height: 112, radius: AppRadius.lg),
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
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => ProfessionalCard(
                professional: shown[i],
                onTap: () =>
                    context.push(AppRoutes.professionalPath(shown[i].id)),
              ),
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
