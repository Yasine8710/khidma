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
import '../../requests/presentation/ledger_widgets.dart';
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
      body = TypeEmpty(
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
      PriceTag? price,
      required VoidCallback onTap,
      int index = 0,
    }) => _ChoiceBlock(
      selected: selected,
      title: title,
      subtitle: subtitle,
      price: price,
      onTap: onTap,
      index: index,
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
        WorkOrderHeading(number: 1, title: l10n.billCurrent),
        const _CurrentSubscription(),
        gap,
        WorkOrderHeading(number: 2, title: l10n.billChoosePlan),
        for (var i = 0; i < plans.length; i++)
          choice(
            index: i,
            selected: plans[i].code == chosen?.code,
            title: plans[i].name(lang),
            subtitle: l10n.billPeriod(plans[i].periodDays),
            price: PriceTag(plans[i].amountMillimes, lang),
            onTap: () => setState(() => _plan = plans[i].code),
          ),
        gap,
        WorkOrderHeading(number: 3, title: l10n.billChooseMethod),
        for (final m in PaymentMethod.values)
          choice(
            index: m.index,
            selected: m == _method,
            title: paymentMethodText(l10n, m),
            subtitle: methodHint(m),
            onTap: () => setState(() => _method = m),
          ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.billPay,
          isLoading: busy,
          onPressed: chosen == null ? null : () => _pay(chosen.code),
        ),
        gap,
        WorkOrderHeading(number: 4, title: l10n.billMyPayments),
        const _Orders(),
      ],
    );
  }
}

/// A price to show big: whole TND counts up, other amounts print as is.
class PriceTag {
  const PriceTag(this.millimes, this.lang);

  final int millimes;
  final String lang;
}

/// A chunky choice (plan or payment method): a sticker block that sinks when
/// pressed; the chosen one is flooded with the world colour. Plans carry a big
/// ruled price block under the name.
class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.price,
    this.index = 0,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final PriceTag? price;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final p = price;
    Widget? amount;
    if (p != null) {
      final style = text.displaySmall?.copyWith(color: fg);
      final whole = p.millimes % 1000 == 0;
      // Prices read left to right with Western digits in every language.
      amount = Directionality(
        textDirection: TextDirection.ltr,
        child: whole
            ? CountUp(value: p.millimes ~/ 1000, suffix: ' TND', style: style)
            : Text(
                formatTndAmount(p.millimes, languageCode: p.lang),
                style: style,
              ),
      );
    }
    return StaggerIn(
      index: index,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppInk.offset,
            bottom: AppInk.offset + AppSpacing.md,
          ),
          child: Pressable(
            onTap: onTap,
            child: StickerBox(
              color: selected ? scheme.primaryContainer : scheme.surface,
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: text.headlineSmall?.copyWith(color: fg),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        selected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: fg,
                      ),
                    ],
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(height: 3, color: fg),
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
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: text.bodyMedium?.copyWith(color: fg),
                    ),
                  ],
                ],
              ),
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
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sub.state == SubscriptionState.active)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppInk.offset,
                  bottom: AppInk.offset + AppSpacing.md,
                ),
                child: StickerBox(
                  color: scheme.primaryContainer,
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: CountUp(
                          value: sub.daysLeft,
                          style: text.displayLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: Text(
                            l10n.billDaysLeftLabel,
                            style: text.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const LedgerRule(strong: true),
            fact(
              l10n.billStatusLabel,
              LedgerStamp(
                big: true,
                label: subscriptionStateText(l10n, sub.state),
                tone: subscriptionTone(sub.state),
              ),
            ),
            const LedgerRule(),
            fact(
              l10n.billValidUntil,
              Text(
                formatDate(sub.currentPeriodEnd, locale),
                style: text.titleSmall,
              ),
            ),
            const LedgerRule(strong: true),
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
        final text = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < orders.length; i++)
              LedgerRow(
                index: i,
                // An unpaid manual order can be reopened to pay or cancel it.
                onTap: orders[i].status.isOpen && orders[i].method.isManual
                    ? () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PaymentInstructionsScreen(order: orders[i]),
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${orders[i].reference} · ${formatTndAmount(orders[i].amountMillimes, languageCode: locale.languageCode)}',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        paymentMethodText(l10n, orders[i].method),
                        if (orders[i].createdAt != null)
                          formatDate(orders[i].createdAt!, locale),
                      ].join(' · '),
                      style: text.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LedgerStamp(
                      big: true,
                      label: orderStatusText(l10n, orders[i].status),
                      tone: orderTone(orders[i].status),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
