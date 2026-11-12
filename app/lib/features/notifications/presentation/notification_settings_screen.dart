import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/register_row.dart';
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
      Widget toggle(String title, bool value, ValueChanged<bool> onChanged) =>
          SwitchListTile(
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xs,
            ),
            minTileHeight: 56,
            title: Text(title),
            value: value,
            onChanged: onChanged,
          );
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
          const SizedBox(height: AppSpacing.sm),
          // Ink switches on ruled rows: "on" is not the screen's action, so
          // it is not terracotta.
          Theme(
            data: Theme.of(context).copyWith(switchTheme: _inkSwitch(scheme)),
            child: RegisterGroup(
              children: [
                toggle(
                  l10n.notifOffers,
                  prefs.offers,
                  (v) => _change(context, ref, prefs.copyWith(offers: v)),
                ),
                toggle(
                  l10n.notifMessages,
                  prefs.messages,
                  (v) => _change(context, ref, prefs.copyWith(messages: v)),
                ),
                toggle(
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

  static SwitchThemeData _inkSwitch(ColorScheme cs) => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? cs.surface : cs.outline,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? cs.onSurface
          : cs.surfaceContainerHighest,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? cs.onSurface : cs.outline,
    ),
  );
}
