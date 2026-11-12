import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/register_row.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/billing_providers.dart';
import '../domain/billing_domain.dart';
import 'billing_text.dart';
import 'payment_instructions_screen.dart';

BadgeTone subscriptionTone(SubscriptionState s) => switch (s) {
  SubscriptionState.active => BadgeTone.success,
  SubscriptionState.pastDue => BadgeTone.warning,
  SubscriptionState.expired => BadgeTone.error,
  SubscriptionState.cancelled => BadgeTone.neutral,
};

BadgeTone orderTone(OrderStatus s) => switch (s) {
  OrderStatus.paid => BadgeTone.success,
  OrderStatus.pending || OrderStatus.awaitingConfirmation => BadgeTone.warning,
  OrderStatus.failed || OrderStatus.rejected => BadgeTone.error,
  OrderStatus.cancelled => BadgeTone.neutral,
};

/// Subscription of the signed-in professional: where it stands, choosing a
/// plan and a way to pay, and the history of payments.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  String? _plan;
  PaymentMethod _method = PaymentMethod.flouci;

  /// The server said this account is not a professional.
  bool _notProfessional = false;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pay(String planCode) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(billingActionsProvider.notifier);
    final created = await actions.createOrder(planCode, _method);
    if (!mounted) return;
    final order = created.order;
    if (order == null) {
      final f = created.failure!;
      if (f == BillingFailure.busy) return;
      if (f == BillingFailure.forbidden) {
        setState(() => _notProfessional = true);
      } else {
        _say(billingFailureText(l10n, f));
      }
      return;
    }
    if (_method == PaymentMethod.flouci) {
      final failure = await actions.payWithFlouci(order);
      if (!mounted) return;
      if (failure == BillingFailure.busy) return;
      _say(
        failure == null
            ? l10n.billFlouciOpened
            : billingFailureText(l10n, failure),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PaymentInstructionsScreen(order: order),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plans = ref.watch(subscriptionPlansProvider);
    final Widget body;
    if (_notProfessional) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: l10n.billNotProTitle,
        body: l10n.billNotProBody,
        actionLabel: l10n.billNotProCta,
        onAction: () => context.push(AppRoutes.proRegistration),
      );
    } else if (plans.hasValue) {
      body = _content(context, plans.requireValue);
    } else if (plans.hasError) {
      final e = plans.error;
      body = ErrorState(
        onRetry: () => ref.invalidate(subscriptionPlansProvider),
        body: e is BillingError
            ? billingFailureText(l10n, e.failure)
            : l10n.errorBody,
      );
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 160, radius: AppRadius.lg),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.billTitle)),
      body: SafeArea(child: body),
    );
  }

  Widget _content(BuildContext context, List<SubscriptionPlan> plans) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final busy = ref.watch(billingActionsProvider);
    final chosen = plans.isEmpty
        ? null
        : plans.firstWhere((p) => p.code == _plan, orElse: () => plans.first);
    const gap = SizedBox(height: AppSpacing.xxl);

    Widget choice({
      required bool selected,
      required String title,
      String? subtitle,
      String? value,
      required VoidCallback onTap,
    }) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: RegisterRow(
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: AppSpacing.sm),
            ],
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    String methodHint(PaymentMethod m) => switch (m) {
      PaymentMethod.flouci => l10n.billMethodFlouciHint,
      PaymentMethod.d17 => l10n.billMethodD17Hint,
      PaymentMethod.bankTransfer => l10n.billMethodBankHint,
    };

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        SectionHeader(kicker: '01', title: l10n.billCurrent),
        const SizedBox(height: AppSpacing.sm),
        const _CurrentSubscription(),
        gap,
        SectionHeader(kicker: '02', title: l10n.billChoosePlan),
        const SizedBox(height: AppSpacing.xs),
        RegisterGroup(
          children: [
            for (final p in plans)
              choice(
                selected: p.code == chosen?.code,
                title: p.name(lang),
                subtitle: l10n.billPeriod(p.periodDays),
                value: formatTndAmount(p.amountMillimes, languageCode: lang),
                onTap: () => setState(() => _plan = p.code),
              ),
          ],
        ),
        gap,
        SectionHeader(kicker: '03', title: l10n.billChooseMethod),
        const SizedBox(height: AppSpacing.xs),
        RegisterGroup(
          children: [
            for (final m in PaymentMethod.values)
              choice(
                selected: m == _method,
                title: paymentMethodText(l10n, m),
                subtitle: methodHint(m),
                onTap: () => setState(() => _method = m),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.billPay,
          isLoading: busy,
          onPressed: chosen == null ? null : () => _pay(chosen.code),
        ),
        gap,
        SectionHeader(kicker: '04', title: l10n.billMyPayments),
        const SizedBox(height: AppSpacing.xs),
        const _Orders(),
      ],
    );
  }
}

class _CurrentSubscription extends ConsumerWidget {
  const _CurrentSubscription();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(mySubscriptionProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget fact(String label, Widget value) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: value,
            ),
          ),
        ],
      ),
    );

    return async.when(
      loading: () => const SkeletonGroup(child: Skeleton(height: 72)),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              e is BillingError
                  ? billingFailureText(l10n, e.failure)
                  : l10n.errorBody,
            ),
          ),
          AppButton(
            label: l10n.retry,
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => ref.invalidate(mySubscriptionProvider),
          ),
        ],
      ),
      data: (sub) {
        if (sub == null) return Text(l10n.billNone);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            fact(
              l10n.billStatusLabel,
              AppBadge(
                label: subscriptionStateText(l10n, sub.state),
                tone: subscriptionTone(sub.state),
              ),
            ),
            const Divider(),
            fact(
              l10n.billValidUntil,
              Text(formatDate(sub.currentPeriodEnd, locale)),
            ),
            if (sub.state == SubscriptionState.active) ...[
              const Divider(),
              fact(l10n.billDaysLeftLabel, Text('${sub.daysLeft}')),
            ],
            const Divider(),
          ],
        );
      },
    );
  }
}

class _Orders extends ConsumerWidget {
  const _Orders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(myPaymentOrdersProvider);
    return async.when(
      loading: () => const SkeletonGroup(child: Skeleton(height: 72)),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              e is BillingError
                  ? billingFailureText(l10n, e.failure)
                  : l10n.errorBody,
            ),
          ),
          AppButton(
            label: l10n.retry,
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => ref.invalidate(myPaymentOrdersProvider),
          ),
        ],
      ),
      data: (orders) {
        if (orders == null || orders.isEmpty) return Text(l10n.billNoPayments);
        return RegisterGroup(
          children: [
            for (final o in orders)
              RegisterRow(
                title:
                    '${o.reference} · ${formatTndAmount(o.amountMillimes, languageCode: locale.languageCode)}',
                subtitle: [
                  paymentMethodText(l10n, o.method),
                  if (o.createdAt != null) formatDate(o.createdAt!, locale),
                ].join(' · '),
                trailing: AppBadge(
                  label: orderStatusText(l10n, o.status),
                  tone: orderTone(o.status),
                ),
                // An unpaid manual order can be reopened to pay or cancel it.
                onTap: o.status.isOpen && o.method.isManual
                    ? () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => PaymentInstructionsScreen(order: o),
                        ),
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}
