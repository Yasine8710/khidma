import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../requests/presentation/flow_widgets.dart';
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
      body = CalmEmpty(
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
    const gap = SizedBox(height: AppSpacing.xl);

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
        SectionTitle(title: l10n.billCurrent),
        const _CurrentSubscription(),
        gap,
        SectionTitle(title: l10n.billChoosePlan),
        for (var i = 0; i < plans.length; i++)
          _PlanCard(
            index: i,
            selected: plans[i].code == chosen?.code,
            title: plans[i].name(lang),
            subtitle: l10n.billPeriod(plans[i].periodDays),
            price: PriceTag(plans[i].amountMillimes, lang),
            onTap: () => setState(() => _plan = plans[i].code),
          ),
        gap,
        SectionTitle(title: l10n.billChooseMethod),
        FlowCard(
          padding: EdgeInsetsDirectional.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in PaymentMethod.values) ...[
                if (m.index > 0) const Hairline(),
                _MethodRow(
                  selected: m == _method,
                  icon: _methodIcon(m),
                  seed: m.index,
                  title: paymentMethodText(l10n, m),
                  subtitle: methodHint(m),
                  onTap: () => setState(() => _method = m),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.billPay,
          isLoading: busy,
          onPressed: chosen == null ? null : () => _pay(chosen.code),
        ),
        gap,
        SectionTitle(title: l10n.billMyPayments),
        const _Orders(),
      ],
    );
  }
}

IconData _methodIcon(PaymentMethod m) => switch (m) {
  PaymentMethod.flouci => Icons.account_balance_wallet_outlined,
  PaymentMethod.d17 => Icons.smartphone_outlined,
  PaymentMethod.bankTransfer => Icons.account_balance_outlined,
};

/// A price to show big: whole TND counts up, other amounts print as is.
class PriceTag {
  const PriceTag(this.millimes, this.lang);

  final int millimes;
  final String lang;
}

/// A round radio mark (the row carries the selected state for assistive
/// tech, so this is decoration).
class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 6.5 : 1.5,
          ),
          color: scheme.surface,
        ),
      ),
    );
  }
}

/// A plan to choose: name and period with a radio mark, the price large and
/// bold. The chosen plan gets a violet outline and a soft violet fill.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
    this.index = 0,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final PriceTag price;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final style = text.headlineMedium?.copyWith(color: fg);
    final whole = price.millimes % 1000 == 0;
    // Prices read left to right with Western digits in every language.
    final amount = Directionality(
      textDirection: TextDirection.ltr,
      child: whole
          ? CountUp(value: price.millimes ~/ 1000, suffix: ' TND', style: style)
          : Text(
              formatTndAmount(price.millimes, languageCode: price.lang),
              style: style,
            ),
    );
    return StaggerIn(
      index: index,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: text.titleMedium?.copyWith(color: fg),
                            ),
                            Text(
                              subtitle,
                              style: text.bodySmall?.copyWith(
                                color: selected ? fg : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RadioMark(selected: selected),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: amount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A way to pay, as a row of a grouped list: tinted icon, name and hint,
/// radio mark on the end side.
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.selected,
    required this.icon,
    required this.seed,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final int seed;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                IconTile(icon: icon, seed: seed, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _RadioMark(selected: selected),
              ],
            ),
          ),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = scheme.onSurfaceVariant;

    Widget fact(String label, Widget value) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: muted)),
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
        if (sub == null) {
          return Text(
            l10n.billNone,
            style: text.bodyMedium?.copyWith(color: muted),
          );
        }
        return FlowCard(
          gap: 0,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sub.state == SubscriptionState.active) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      const IconTile(
                        icon: Icons.workspace_premium_outlined,
                        brand: true,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: CountUp(
                          value: sub.daysLeft,
                          style: text.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.billDaysLeftLabel,
                          style: text.bodyMedium?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const Hairline(),
              ],
              fact(
                l10n.billStatusLabel,
                StatusPill(
                  label: subscriptionStateText(l10n, sub.state),
                  tone: subscriptionTone(sub.state),
                ),
              ),
              const Hairline(),
              fact(
                l10n.billValidUntil,
                Text(
                  formatDate(sub.currentPeriodEnd, locale),
                  style: text.titleSmall,
                ),
              ),
            ],
          ),
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
    final async = ref.watch(myPaymentOrdersProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
        final text = Theme.of(context).textTheme;
        if (orders == null || orders.isEmpty) {
          return Text(
            l10n.billNoPayments,
            style: text.bodyMedium?.copyWith(color: muted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < orders.length; i++)
              _OrderCard(order: orders[i], index: i),
          ],
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.index = 0});

  final PaymentOrder order;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    // An unpaid manual order can be reopened to pay or cancel it.
    final open = order.status.isOpen && order.method.isManual;
    return FlowCard(
      index: index,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md + 2),
      onTap: open
          ? () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PaymentInstructionsScreen(order: order),
              ),
            )
          : null,
      child: Row(
        children: [
          IconTile(
            icon: _methodIcon(order.method),
            seed: order.method.index,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.reference} · ${formatTndAmount(order.amountMillimes, languageCode: locale.languageCode)}',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    paymentMethodText(l10n, order.method),
                    if (order.createdAt != null)
                      formatDate(order.createdAt!, locale),
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusPill(
                  label: orderStatusText(l10n, order.status),
                  tone: orderTone(order.status),
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(width: AppSpacing.xs),
            const EndChevron(),
          ],
        ],
      ),
    );
  }
}
