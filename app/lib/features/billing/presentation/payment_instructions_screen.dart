import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../requests/presentation/flow_widgets.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
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

    Future<void> attachProof() async {
      final failure = await ref
          .read(billingActionsProvider.notifier)
          .attachProof(current);
      if (!context.mounted) return;
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

    // One line of the payment details: the label over the value, and a copy
    // button for what has to be typed elsewhere.
    Widget fact(String label, String value, {bool copy = false}) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(value, style: text.titleMedium),
                ),
              ],
            ),
          ),
          if (copy) ...[
            const SizedBox(width: AppSpacing.sm),
            _CopyButton(value: value, label: '${l10n.billCopy}: $label'),
          ],
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
        if (bank == null && d17 == null) {
          return Text(
            l10n.billNoDetails,
            style: text.bodyMedium?.copyWith(color: muted),
          );
        }
        final rows = <Widget>[
          if (bank != null) ...[
            if (bank.name != null) fact(l10n.billBankName, bank.name!),
            if (bank.holder != null) fact(l10n.billHolder, bank.holder!),
            fact(l10n.billRib, bank.rib, copy: true),
          ],
          if (d17 != null) ...[
            fact(l10n.billD17Number, d17.number, copy: true),
            if (d17.holder != null) fact(l10n.billHolder, d17.holder!),
          ],
        ];
        return FlowCard(
          gap: 0,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(),
                rows[i],
              ],
            ],
          ),
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
            // How, its status, and the sum due on a soft grey panel.
            FlowCard(
              gap: AppSpacing.md,
              child: Row(
                children: [
                  IconTile(
                    icon: current.method == PaymentMethod.d17
                        ? Icons.smartphone_outlined
                        : Icons.account_balance_outlined,
                    seed: current.method.index,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paymentMethodText(l10n, current.method),
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        StatusPill(
                          label: orderStatusText(l10n, current.status),
                          tone: orderTone(current.status),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FlowCard(
              index: 1,
              gap: 0,
              color: scheme.primaryContainer,
              border: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.billAmount,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
                        style: text.displaySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionTitle(
              title: l10n.billReference,
              note: l10n.billReferenceHint,
            ),
            FlowCard(
              gap: 0,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(
                        current.reference,
                        style: text.headlineSmall,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CopyButton(
                    value: current.reference,
                    label: '${l10n.billCopy}: ${l10n.billReference}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionTitle(title: l10n.billPayTo),
            accounts,
            const SizedBox(height: AppSpacing.xl),
            if (awaiting) ...[
              Semantics(
                liveRegion: true,
                child: Text(l10n.billAwaitingBody, style: text.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (current.status == OrderStatus.rejected &&
                (current.adminNote ?? '').isNotEmpty) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.billRejectedNote(current.adminNote!),
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (open && current.isManual) ...[
              _ProofRow(orderId: current.id, busy: busy, onAttach: attachProof),
              const SizedBox(height: AppSpacing.md),
            ],
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

/// A round soft grey copy button with a spoken name.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: label,
      style: IconButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.copy_rounded, size: 20),
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

/// Receipts attached so far, and the button to add one (up to 3).
class _ProofRow extends ConsumerWidget {
  const _ProofRow({
    required this.orderId,
    required this.busy,
    required this.onAttach,
  });

  final String orderId;
  final bool busy;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final count = ref.watch(paymentProofCountProvider(orderId)).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          count == 0 ? l10n.billProofHint : l10n.billProofCount(count),
          style: text.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.billAttachProof,
          icon: Icons.receipt_long_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: busy || count >= maxPaymentProofs ? null : onAttach,
        ),
      ],
    );
  }
}
