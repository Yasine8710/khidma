import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';

/// What may never be offered as a freelance service. Shown before the first
/// publication (as a confirmation) and from the report form.
List<String> prohibitedServices(AppLocalizations l10n) => [
  l10n.flPolicyIllegal,
  l10n.flPolicyAcademic,
  l10n.flPolicyDocuments,
  l10n.flPolicyPlagiarism,
  l10n.flPolicyAccounts,
];

/// Opens the policy. With [confirm], it ends with "I agree and publish" and
/// returns true only when that is tapped.
Future<bool> showProhibitedPolicy(
  BuildContext context, {
  bool confirm = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PolicySheet(confirm: confirm),
  );
  return ok ?? false;
}

/// A text link that opens the policy (for forms and settings).
class ProhibitedPolicyLink extends StatelessWidget {
  const ProhibitedPolicyLink({super.key});

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: AppLocalizations.of(context).flPolicyLink,
      variant: AppButtonVariant.text,
      icon: Icons.rule_rounded,
      onPressed: () => showProhibitedPolicy(context),
    );
  }
}

class _PolicySheet extends StatelessWidget {
  const _PolicySheet({required this.confirm});

  final bool confirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
          Text(l10n.flPolicyTitle, style: text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.flPolicyIntro,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in prohibitedServices(l10n))
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block_rounded, size: 18, color: scheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(item, style: text.bodyMedium)),
                ],
              ),
            ),
          if (confirm) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.flPolicyAccept,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ],
      ),
    );
  }
}
