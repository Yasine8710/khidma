import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../requests/presentation/ledger_widgets.dart' show LedgerRule;
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../requests/domain/requests_domain.dart';
import '../application/trust_providers.dart';
import '../domain/trust_domain.dart';

String reportReasonLabel(AppLocalizations l10n, ReportReason r) => switch (r) {
  ReportReason.spam => l10n.reportReasonSpam,
  ReportReason.fake => l10n.reportReasonFake,
  ReportReason.abuse => l10n.reportReasonAbuse,
  ReportReason.scam => l10n.reportReasonScam,
  ReportReason.inappropriate => l10n.reportReasonInappropriate,
  ReportReason.other => l10n.reportReasonOther,
};

String reportFailureText(AppLocalizations l10n, RequestsFailure f) =>
    switch (f) {
      RequestsFailure.alreadyReported => l10n.reportFailAlready,
      RequestsFailure.rateLimited => l10n.reportFailRate,
      RequestsFailure.notFound => l10n.reportFailGone,
      _ => l10n.reportFailGeneric,
    };

/// Opens the report form. Shows a confirmation when the report was sent (or
/// was already open). Returns whether the form was submitted.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ReportSheet(target: target, targetId: targetId),
    ),
  );
  if (done == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).reportSent)),
    );
  }
  return done ?? false;
}

/// The "report" entry of an app bar or a list row.
class ReportButton extends StatelessWidget {
  const ReportButton({
    super.key,
    required this.target,
    required this.targetId,
    this.compact = false,
  });

  final ReportTarget target;
  final String targetId;

  /// A small icon (for list rows) instead of a regular app bar icon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.reportAction,
      iconSize: compact ? 18 : 24,
      visualDensity: compact ? VisualDensity.compact : null,
      icon: const Icon(Icons.flag_outlined),
      onPressed: () =>
          showReportSheet(context, target: target, targetId: targetId),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.target, required this.targetId});

  final ReportTarget target;
  final String targetId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  String? _error;
  bool _reasonError = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_reason == null) {
      setState(() => _reasonError = true);
      return;
    }
    final failure = await ref
        .read(reportActionsProvider.notifier)
        .send(widget.target, widget.targetId, _reason!, _details.text);
    if (!mounted) return;
    // Already reported: the goal is met, nothing more for the person to do.
    if (failure == null || failure == RequestsFailure.alreadyReported) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = reportFailureText(l10n, failure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(reportActionsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.reportTitle, style: text.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.reportHint,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          const LedgerRule(strong: true),
          // Reasons as ruled form lines, ticked in ink: the send button is the
          // sheet's one terracotta action.
          Theme(
            data: Theme.of(context).copyWith(
              radioTheme: RadioThemeData(
                fillColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? scheme.onSurface
                      : scheme.outline,
                ),
              ),
            ),
            child: RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() {
                _reason = v;
                _reasonError = false;
              }),
              child: Column(
                children: [
                  for (final r in ReportReason.values) ...[
                    RadioListTile<ReportReason>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(reportReasonLabel(l10n, r)),
                    ),
                    const LedgerRule(),
                  ],
                ],
              ),
            ),
          ),
          if (_reasonError)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.reportTitle,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: l10n.reportDetailsLabel,
            controller: _details,
            maxLines: 3,
            maxLength: maxReportDetails,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: l10n.reportSend, isLoading: busy, onPressed: _send),
        ],
      ),
    );
  }
}
