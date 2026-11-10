import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
      body = ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
        children: [
          Text(l10n.notifIntro, style: text.bodyMedium?.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.md),
          if (!pushAvailable) ...[
            Text(
              l10n.notifNoPush,
              style: text.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifOffers),
            value: prefs.offers,
            onChanged: (v) => _change(context, ref, prefs.copyWith(offers: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifMessages),
            value: prefs.messages,
            onChanged: (v) =>
                _change(context, ref, prefs.copyWith(messages: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifJobs),
            value: prefs.jobs,
            onChanged: (v) => _change(context, ref, prefs.copyWith(jobs: v)),
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
