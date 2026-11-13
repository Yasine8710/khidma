import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../requests/domain/requests_domain.dart';
import '../application/trust_providers.dart';
import '../domain/trust_domain.dart';

/// Shown on the professional board while the account is suspended: why,
/// until when, and the appeal form (one open appeal at a time). Nothing
/// when the account is in good standing.
class SuspensionCard extends ConsumerWidget {
  const SuspensionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(myAccountStatusProvider).value;
    if (status == null || !status.suspended) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final until = status.suspendedUntil;
    final reason = status.reason;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.block_rounded,
                      color: scheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.suspendedTitle,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  until == null
                      ? l10n.suspendedIndefinite
                      : l10n.suspendedUntil(formatDate(until, locale)),
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.suspendedReason(reason),
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                switch (status.appeal) {
                  AppealStatus.open => Text(
                    l10n.appealPending,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  _ => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (status.appeal == AppealStatus.rejected) ...[
                        Text(
                          l10n.appealRejected,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton(
                        label: l10n.appealAction,
                        icon: Icons.gavel_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _openAppeal(context),
                      ),
                    ],
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAppeal(BuildContext context) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const _AppealSheet(),
      ),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).appealSent)),
      );
    }
  }
}

class _AppealSheet extends ConsumerStatefulWidget {
  const _AppealSheet();

  @override
  ConsumerState<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends ConsumerState<_AppealSheet> {
  final _message = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_message.text.trim().length < minAppealLength) {
      setState(() => _error = l10n.appealTooShort);
      return;
    }
    final failure = await ref
        .read(appealActionsProvider.notifier)
        .send(_message.text);
    if (!mounted) return;
    if (failure == null || failure == RequestsFailure.alreadyPending) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(
      () => _error = failure == RequestsFailure.rateLimited
          ? l10n.appealFailRate
          : l10n.appealFailGeneric,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(appealActionsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.appealAction, style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: maxAppealLength,
            decoration: InputDecoration(
              hintText: l10n.appealHint,
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.appealSend,
            isLoading: busy,
            onPressed: busy ? null : _send,
          ),
        ],
      ),
    );
  }
}
