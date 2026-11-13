import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/register_row.dart';
import '../../marketplace/application/contact_providers.dart'
    show urlOpenerProvider;
import '../../marketplace/presentation/calm_blocks.dart';
import '../application/freelance_providers.dart';
import '../domain/freelance_domain.dart';
import 'freelance_widgets.dart';

/// Invitations for past clients: create a personal link, copy or share it,
/// see which are open, used or expired, and revoke them.
class FreelanceInvitesSection extends ConsumerStatefulWidget {
  const FreelanceInvitesSection({super.key});

  @override
  ConsumerState<FreelanceInvitesSection> createState() =>
      _FreelanceInvitesSectionState();
}

class _FreelanceInvitesSectionState
    extends ConsumerState<FreelanceInvitesSection> {
  final _label = TextEditingController();

  /// The link just created. Shown once; never stored.
  String? _link;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create(String baseUrl) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(freelanceActionsProvider.notifier)
        .createInvite(label: _label.text);
    if (!mounted) return;
    final token = result.token;
    if (token != null) {
      final link = testimonialLink(baseUrl, token);
      setState(() => _link = link);
      _label.clear();
      return;
    }
    final f = result.failure;
    if (f != null) {
      _toast(freelanceFailureText(l10n, f, limit: l10n.flInvLimit));
    }
  }

  Future<void> _share(String link) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.https('wa.me', '/', {'text': l10n.flInvShareText(link)});
    var ok = false;
    try {
      ok = await ref.read(urlOpenerProvider)(uri);
    } catch (_) {}
    if (!ok && mounted) _toast(l10n.contactLaunchFailed);
  }

  Future<void> _revoke(TestimonialInvite inv) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.flInvRevokeTitle),
        content: Text(l10n.flInvRevokeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.flInvRevoke),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final failure = await ref
        .read(freelanceActionsProvider.notifier)
        .revokeInvite(inv.id);
    if (failure != null && mounted) _toast(freelanceFailureText(l10n, failure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(freelanceActionsProvider);
    final baseUrl = ref.watch(testimonialBaseUrlProvider);
    // A link is only ever built for a configured https address.
    final configured = testimonialLink(baseUrl, 'x') != null;
    final invites = ref.watch(myInvitesProvider);
    final now = DateTime.now();

    String status(InviteStatus s) => switch (s) {
      InviteStatus.open => l10n.flInvStatusOpen,
      InviteStatus.used => l10n.flInvStatusUsed,
      InviteStatus.expired => l10n.flInvStatusExpired,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l10n.flInvTitle),
        Text(
          l10n.flInvHint,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!configured)
          Text(l10n.flInvNotConfigured, style: text.bodyMedium)
        else ...[
          AppTextField(
            label: l10n.flInvLabelField,
            controller: _label,
            maxLength: FreelanceRules.maxInviteLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.flInvCreate,
            variant: AppButtonVariant.secondary,
            isLoading: busy,
            onPressed: () => _create(baseUrl),
          ),
        ],
        if (_link != null) ...[
          const SizedBox(height: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.flInvLinkTitle, style: text.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(_link!, style: text.bodySmall),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.flInvLinkWarn,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.flInvCopy,
                    icon: Icons.copy_rounded,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _link!));
                      if (mounted) _toast(l10n.flInvCopied);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: l10n.flInvShare,
                    icon: Icons.chat_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _share(_link!),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        switch (invites) {
          AsyncData(:final value) when value.isEmpty => Text(
            l10n.flInvEmpty,
            style: text.bodyMedium,
          ),
          AsyncData(:final value) => RegisterGroup(
            children: [
              for (final inv in value)
                RegisterRow(
                  title: inv.label ?? l10n.flInvNoLabel,
                  subtitle:
                      '${status(inv.statusAt(now))} · ${l10n.flInvExpires(formatDate(inv.expiresAt, locale))}',
                  showChevron: false,
                  trailing: IconButton(
                    tooltip:
                        '${l10n.flInvRevoke}: ${inv.label ?? l10n.flInvNoLabel}',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: busy ? null : () => _revoke(inv),
                  ),
                ),
            ],
          ),
          AsyncError() => Text(l10n.flErrGeneric, style: text.bodyMedium),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}
