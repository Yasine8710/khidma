import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../requests/presentation/ledger_widgets.dart';
import '../../../shared/widgets/app_button.dart';
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
                child: SelectableText(value, style: text.titleMedium),
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
            const LedgerRule(),
            if (bank != null) ...[
              if (bank.name != null) fact(l10n.billBankName, bank.name!),
              if (bank.name != null) const LedgerRule(),
              if (bank.holder != null) fact(l10n.billHolder, bank.holder!),
              if (bank.holder != null) const LedgerRule(),
              fact(l10n.billRib, bank.rib, copy: true),
            ],
            if (d17 != null) ...[
              fact(l10n.billD17Number, d17.number, copy: true),
              if (d17.holder != null) const LedgerRule(),
              if (d17.holder != null) fact(l10n.billHolder, d17.holder!),
            ],
            const LedgerRule(),
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
                LedgerStamp(
                  big: true,
                  label: orderStatusText(l10n, current.status),
                  tone: orderTone(current.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // The sum due, as one big ruled price block.
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppInk.offset,
                bottom: AppInk.offset,
              ),
              child: StickerBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.billAmount,
                      style: text.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      height: 3,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          formatTndAmount(
                            current.amountMillimes,
                            languageCode: lang,
                          ),
                          style: text.displayMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            WorkOrderHeading(number: 1, title: l10n.billReference),
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
            WorkOrderHeading(number: 2, title: l10n.billPayTo),
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
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: Theme.of(context).colorScheme.onSurface,
            width: AppInk.border,
          ),
        ),
      ),
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
