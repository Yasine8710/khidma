import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../application/billing_providers.dart';
import '../domain/billing_domain.dart';
import 'billing_screen.dart' show orderTone;
import 'billing_text.dart';

/// How to pay a D17 or bank transfer order: the amount, the reference to write
/// in the motif, where to send the money, then "I paid" and cancel.
class PaymentInstructionsScreen extends ConsumerWidget {
  const PaymentInstructionsScreen({super.key, required this.order});

  /// The order as it was when the screen opened; the live status comes from
  /// the payments list.
  final PaymentOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final busy = ref.watch(billingActionsProvider);
    final orders = ref.watch(myPaymentOrdersProvider).value;
    final current = orders?.where((o) => o.id == order.id).firstOrNull ?? order;
    final details = ref.watch(paymentInstructionsProvider);

    Future<void> say(String message) async {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> iPaid() async {
      final note = await showDialog<String>(
        context: context,
        builder: (_) => const _PaidDialog(),
      );
      if (note == null || !context.mounted) return;
      final failure = await ref
          .read(billingActionsProvider.notifier)
          .markSent(current, note);
      if (failure != null && failure != BillingFailure.busy) {
        await say(billingFailureText(l10n, failure));
      }
    }

    Future<void> cancel() async {
      final failure = await ref
          .read(billingActionsProvider.notifier)
          .cancel(current);
      if (!context.mounted) return;
      if (failure == null) {
        Navigator.of(context).pop();
      } else if (failure != BillingFailure.busy) {
        await say(billingFailureText(l10n, failure));
      }
    }

    Widget fact(String label, String value, {bool copy = false}) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: muted)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(value, style: text.bodyLarge),
              ),
            ),
          ),
          if (copy)
            _CopyButton(value: value, label: '${l10n.billCopy}: $label'),
        ],
      ),
    );

    final open = current.status.isOpen;
    final awaiting = current.status == OrderStatus.awaitingConfirmation;

    final accounts = details.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        e is BillingError
            ? billingFailureText(l10n, e.failure)
            : l10n.errorBody,
      ),
      data: (d) {
        final bank = current.method == PaymentMethod.bankTransfer
            ? d?.bank
            : null;
        final d17 = current.method == PaymentMethod.d17 ? d?.d17 : null;
        if (bank == null && d17 == null) return Text(l10n.billNoDetails);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            if (bank != null) ...[
              if (bank.name != null) fact(l10n.billBankName, bank.name!),
              if (bank.name != null) const Divider(),
              if (bank.holder != null) fact(l10n.billHolder, bank.holder!),
              if (bank.holder != null) const Divider(),
              fact(l10n.billRib, bank.rib, copy: true),
            ],
            if (d17 != null) ...[
              fact(l10n.billD17Number, d17.number, copy: true),
              if (d17.holder != null) const Divider(),
              if (d17.holder != null) fact(l10n.billHolder, d17.holder!),
            ],
            const Divider(),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billInstructionsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    paymentMethodText(l10n, current.method),
                    style: text.headlineSmall,
                  ),
                ),
                AppBadge(
                  label: orderStatusText(l10n, current.status),
                  tone: orderTone(current.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            fact(
              l10n.billAmount,
              formatTndAmount(current.amountMillimes, languageCode: lang),
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(kicker: '01', title: l10n.billReference),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      current.reference,
                      style: text.displaySmall,
                    ),
                  ),
                ),
                _CopyButton(
                  value: current.reference,
                  label: '${l10n.billCopy}: ${l10n.billReference}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.billReferenceHint,
              style: text.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(kicker: '02', title: l10n.billPayTo),
            const SizedBox(height: AppSpacing.sm),
            accounts,
            const SizedBox(height: AppSpacing.xl),
            if (awaiting)
              Semantics(
                liveRegion: true,
                child: Text(l10n.billAwaitingBody, style: text.bodyMedium),
              ),
            if (open) ...[
              if (!awaiting)
                AppButton(
                  label: l10n.billIPaid,
                  isLoading: busy,
                  onPressed: iPaid,
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.billCancelOrder,
                variant: AppButtonVariant.secondary,
                onPressed: busy ? null : cancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: label,
      icon: const Icon(Icons.copy_outlined),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: value));
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.billCopied)));
      },
    );
  }
}

class _PaidDialog extends StatefulWidget {
  const _PaidDialog();

  @override
  State<_PaidDialog> createState() => _PaidDialogState();
}

class _PaidDialogState extends State<_PaidDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.billPaidTitle),
      content: TextField(
        controller: _note,
        maxLength: 200,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(labelText: l10n.billNoteLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: Text(l10n.billSend),
        ),
      ],
    );
  }
}
