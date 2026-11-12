import 'package:flutter/material.dart';

import '../../../core/haptics.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/profile_domain.dart';

/// Two large choices: find a professional, or offer services. There is no
/// admin option, by design.
class AccountTypeSelector extends StatelessWidget {
  const AccountTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final AccountType value;
  final ValueChanged<AccountType> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.accountTypeTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Option(
          selected: value == AccountType.customer,
          icon: Icons.search_rounded,
          title: l10n.accountCustomerTitle,
          body: l10n.accountCustomerBody,
          onTap: enabled ? () => _pick(AccountType.customer) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _Option(
          selected: value == AccountType.professional,
          icon: Icons.handyman_outlined,
          title: l10n.accountProfessionalTitle,
          body: l10n.accountProfessionalBody,
          onTap: enabled ? () => _pick(AccountType.professional) : null,
        ),
      ],
    );
  }

  void _pick(AccountType t) {
    if (t == value) return;
    AppHaptics.selection();
    onChanged(t);
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = scheme.onSurface;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      checked: selected,
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      onTap: onTap,
      // A form box to tick: ink frame and a check when chosen, flat paper.
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? scheme.onSurface : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall?.copyWith(color: fg)),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // A square tick box, empty until chosen.
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? scheme.onSurface : scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: selected ? scheme.onSurface : scheme.outline,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.surface,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
