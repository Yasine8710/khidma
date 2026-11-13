import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/register_row.dart';
import '../application/billing_providers.dart';
import '../domain/billing_domain.dart';
import 'billing_text.dart';

/// The "Subscription" row of the professional's tools, with the status as its
/// subtitle. A failed or missing status shows no subtitle: the row still opens
/// the billing screen.
class BillingTile extends ConsumerWidget {
  const BillingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sub = ref.watch(mySubscriptionProvider);
    String? subtitle;
    if (sub.hasValue) {
      final s = sub.value;
      subtitle = s == null
          ? l10n.billNone
          : s.state == SubscriptionState.active
          ? '${l10n.billStatusActive} · ${l10n.billDaysLeft(s.daysLeft)}'
          : subscriptionStateText(l10n, s.state);
    }
    return RegisterRow(
      icon: Icons.workspace_premium_outlined,
      title: l10n.billTitle,
      subtitle: subtitle,
      onTap: () => context.push(AppRoutes.proBilling),
    );
  }
}
