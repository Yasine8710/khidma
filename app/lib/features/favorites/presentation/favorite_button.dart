import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../application/favorites_providers.dart';

/// The heart. Saved or not is announced as state, the action as the label.
/// Signed out (with a backend) it opens sign-in instead.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.professionalId,
    this.professionalName,
  });

  final String professionalId;

  /// Named in the label so assistive tech can tell the hearts apart.
  final String? professionalName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(isFavoriteProvider(professionalId));
    final scheme = Theme.of(context).colorScheme;

    Future<void> onPressed() async {
      if (ref.read(favoritesNeedSignInProvider)) {
        context.push(AppRoutes.login);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final failure = await ref
          .read(favoriteIdsProvider.notifier)
          .toggle(professionalId);
      if (failure == null) return;
      // The newest message replaces an older one still on screen.
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure == MarketplaceFailure.limitReached
                ? l10n.favoriteLimit
                : l10n.favoriteFailed,
          ),
        ),
      );
    }

    return IconButton(
      tooltip: switch ((saved, professionalName)) {
        (true, final n?) when n.isNotEmpty => l10n.favoriteRemoveNamed(n),
        (false, final n?) when n.isNotEmpty => l10n.favoriteAddNamed(n),
        (true, _) => l10n.favoriteRemove,
        (false, _) => l10n.favoriteAdd,
      },
      isSelected: saved,
      icon: Icon(Icons.favorite_border_rounded, color: scheme.onSurfaceVariant),
      selectedIcon: Icon(Icons.favorite_rounded, color: scheme.error),
      onPressed: onPressed,
    );
  }
}
