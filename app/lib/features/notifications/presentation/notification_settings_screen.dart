import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';
import '../../requests/presentation/flow_widgets.dart';
import '../application/notifications_providers.dart';
import '../domain/notifications_domain.dart';

/// What the person wants to be notified about. Saved on the server, so it
/// applies on every device.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    NotificationPrefs wanted,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(notificationActionsProvider.notifier)
        .save(wanted);
    if (ok) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.notifSaveFailed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final signedIn = ref.watch(currentUserProvider) != null;
    final pushAvailable = ref.watch(pushServiceProvider).isAvailable;
    final async = ref.watch(notificationPrefsProvider);
    // While a change is being saved, show what was asked for.
    final pending = ref.watch(notificationActionsProvider);
    final prefs = pending ?? async.value;

    final Widget body;
    if (!signedIn) {
      body = SignedOutPrompt(
        icon: Icons.notifications_none_rounded,
        title: l10n.notifTitle,
        body: l10n.notifIntro,
      );
    } else if (prefs != null) {
      Widget toggle(
        IconData icon,
        int seed,
        String title,
        bool value,
        ValueChanged<bool> onChanged,
      ) => Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          minTileHeight: 64,
          shape: const RoundedRectangleBorder(),
          secondary: IconTile(icon: icon, seed: seed, size: 40),
          title: Text(title, style: text.titleSmall),
          value: value,
          onChanged: onChanged,
        ),
      );
      body = ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
        children: [
          Text(l10n.notifIntro, style: text.bodyMedium?.copyWith(color: muted)),
          if (!pushAvailable) ...[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: muted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.notifNoPush,
                        style: text.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // One grouped card, like the phone's own settings.
          FlowCard(
            padding: EdgeInsetsDirectional.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toggle(
                  Icons.local_offer_outlined,
                  0,
                  l10n.notifOffers,
                  prefs.offers,
                  (v) => _change(context, ref, prefs.copyWith(offers: v)),
                ),
                const Hairline(indent: AppSpacing.lg + 40 + AppSpacing.lg),
                toggle(
                  Icons.chat_bubble_outline_rounded,
                  5,
                  l10n.notifMessages,
                  prefs.messages,
                  (v) => _change(context, ref, prefs.copyWith(messages: v)),
                ),
                const Hairline(indent: AppSpacing.lg + 40 + AppSpacing.lg),
                toggle(
                  Icons.handyman_outlined,
                  4,
                  l10n.notifJobs,
                  prefs.jobs,
                  (v) => _change(context, ref, prefs.copyWith(jobs: v)),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (async.hasError) {
      body = ErrorState(
        onRetry: () => ref.invalidate(notificationPrefsProvider),
      );
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 120, radius: AppRadius.lg),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifTitle)),
      body: SafeArea(child: body),
    );
  }
}
