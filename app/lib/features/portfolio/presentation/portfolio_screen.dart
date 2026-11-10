import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../application/portfolio_providers.dart';
import '../domain/portfolio_domain.dart';
import 'portfolio_image.dart';

String portfolioFailureText(AppLocalizations l10n, PortfolioFailure f) =>
    switch (f) {
      PortfolioFailure.tooLarge => l10n.portfolioFailTooLarge,
      PortfolioFailure.notAnImage => l10n.portfolioFailNotImage,
      PortfolioFailure.limitReached => l10n.portfolioFailLimit,
      PortfolioFailure.network => l10n.portfolioFailNetwork,
      PortfolioFailure.notConfigured => l10n.portfolioFailNotConfigured,
      _ => l10n.portfolioFailGeneric,
    };

/// The professional's own photos: add (system picker, prepared on device) and
/// remove. Everything shown here is what customers see on the profile.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final uid = ref.watch(currentUserProvider)?.id;
    final busy = ref.watch(portfolioActionsProvider);

    Widget body;
    if (uid == null) {
      body = ErrorState(onRetry: () {});
    } else {
      final async = ref.watch(portfolioProvider(uid));
      final items = async.value;
      if (items != null) {
        body = ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
          children: [
            Text(
              l10n.portfolioHint,
              style: text.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.portfolioCount(items.length, maxPortfolioPhotos),
                style: text.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              Text(l10n.portfolioEmpty, style: text.bodyMedium)
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _Thumb(
                      professionalId: uid,
                      item: items[i],
                      index: i + 1,
                      total: items.length,
                      busy: busy,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: busy ? l10n.portfolioPreparing : l10n.portfolioAdd,
              icon: Icons.add_a_photo_outlined,
              isLoading: busy,
              onPressed: items.length >= maxPortfolioPhotos
                  ? null
                  : () => _add(context, ref, uid),
            ),
          ],
        );
      } else if (async.hasError) {
        body = ErrorState(
          onRetry: () => ref.invalidate(portfolioProvider(uid)),
        );
      } else {
        body = const SkeletonGroup(
          child: Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
            child: Skeleton(height: 160, radius: AppRadius.lg),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.portfolioTitle)),
      body: SafeArea(child: body),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(portfolioActionsProvider.notifier)
        .addFromLibrary(uid);
    if (failure == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(portfolioFailureText(l10n, failure))),
      );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({
    required this.professionalId,
    required this.item,
    required this.index,
    required this.total,
    required this.busy,
  });

  final String professionalId;
  final PortfolioItem item;
  final int index;
  final int total;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: PortfolioImage(
            url: item.url,
            semanticLabel: l10n.portfolioPhotoOf(index, total),
            cacheWidth: 400,
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: IconButton.filledTonal(
            tooltip: '${l10n.portfolioRemove} ($index)',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: busy ? null : () => _confirmRemove(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.portfolioRemoveTitle),
        content: Text(l10n.portfolioRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.portfolioRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final failure = await ref
        .read(portfolioActionsProvider.notifier)
        .remove(professionalId, item);
    if (failure == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(portfolioFailureText(l10n, failure))),
      );
  }
}
