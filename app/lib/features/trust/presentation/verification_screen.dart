import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';
import '../../requests/presentation/flow_widgets.dart';
import '../application/trust_providers.dart';
import '../domain/trust_domain.dart';

String verificationFailureText(AppLocalizations l10n, RequestsFailure f) =>
    switch (f) {
      RequestsFailure.alreadyPending => l10n.verifFailPending,
      RequestsFailure.alreadyVerified => l10n.verifFailVerified,
      RequestsFailure.rateLimited => l10n.verifFailLimit,
      RequestsFailure.invalidInput => l10n.verifFailImage,
      _ => l10n.verifFailGeneric,
    };

/// Where a professional sends identity or trade documents for the verified
/// badge, and sees the answer. The photos stay on the device until sent.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _documents = <PreparedPhoto>[];
  String? _error;

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(verificationActionsProvider.notifier).pick();
    if (!mounted) return;
    if (r.failure != null) {
      setState(() => _error = verificationFailureText(l10n, r.failure!));
    } else if (r.photo != null) {
      setState(() {
        _error = null;
        _documents.add(r.photo!);
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(verificationActionsProvider.notifier)
        .submit(List.of(_documents));
    if (!mounted) return;
    if (failure == null) {
      setState(() {
        _documents.clear();
        _error = null;
      });
      _toast(l10n.verifSent);
    } else {
      setState(() => _error = verificationFailureText(l10n, failure));
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(verificationActionsProvider.notifier)
        .cancel();
    if (!mounted) return;
    if (failure == null) {
      setState(() => _error = null);
      _toast(l10n.verifCancelled);
    } else {
      setState(() => _error = verificationFailureText(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(verificationActionsProvider);
    final async = ref.watch(myVerificationProvider);

    Widget body;
    final info = async.value;
    if (info != null) {
      final pending = info.status == VerificationStatus.pending;
      final approved = info.status == VerificationStatus.approved;
      final canSend = !pending && !approved;
      body = ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
        children: [
          // Where the file stands, then its steps: send, review, badge.
          FlowCard(
            gap: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: approved
                                ? scheme.primary
                                : scheme.primaryContainer,
                          ),
                          child: Icon(
                            approved
                                ? Icons.verified_rounded
                                : pending
                                ? Icons.hourglass_top_rounded
                                : Icons.shield_outlined,
                            size: 26,
                            color: approved
                                ? scheme.onPrimary
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(switch (info.status) {
                          VerificationStatus.none => l10n.verifStatusNone,
                          VerificationStatus.pending => l10n.verifStatusPending,
                          VerificationStatus.approved =>
                            l10n.verifStatusApproved,
                          VerificationStatus.rejected =>
                            l10n.verifStatusRejected,
                          VerificationStatus.cancelled =>
                            l10n.verifStatusCancelled,
                        }, style: text.titleLarge),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Hairline(),
                const SizedBox(height: AppSpacing.md),
                _Steps(
                  steps: [
                    l10n.verifStepSend,
                    l10n.verifStepReview,
                    l10n.verifStepBadge,
                  ],
                  current: approved ? 2 : (pending ? 1 : 0),
                  complete: approved,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (info.status == VerificationStatus.rejected &&
              info.rejectReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.verifRejectReason(info.rejectReason!),
              style: text.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            pending ? l10n.verifPendingBody : l10n.verifIntro,
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.verifPrivacy,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (canSend) ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.verifCount(_documents.length, maxVerificationDocuments),
                style: text.titleSmall,
              ),
            ),
            if (_documents.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                // Rounded previews side by side, each with a remove button.
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < _documents.length; i++)
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.memory(
                                _documents[i].bytes,
                                fit: BoxFit.cover,
                                // Decoration: the count says it all.
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.description_outlined,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              top: 0,
                              end: 0,
                              child: IconButton(
                                tooltip: l10n.verifRemove(i + 1),
                                iconSize: 16,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(30, 30),
                                  fixedSize: const Size(30, 30),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                  backgroundColor: scheme.surface,
                                  foregroundColor: scheme.onSurface,
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.close_rounded),
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => _documents.removeAt(i),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.verifAdd,
              icon: Icons.add_a_photo_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: busy || _documents.length >= maxVerificationDocuments
                  ? null
                  : _add,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.verifSubmit,
              isLoading: busy,
              onPressed: _documents.isEmpty ? null : _submit,
            ),
          ],
          if (pending) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.verifCancel,
              variant: AppButtonVariant.secondary,
              isLoading: busy,
              onPressed: _cancel,
            ),
          ],
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
        ],
      );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(myVerificationProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 120, radius: AppRadius.lg),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifTitle)),
      body: SafeArea(child: body),
    );
  }
}

/// The steps of a verification side by side: a dot per step joined by thin
/// lines, the label under it (the current one in bold).
class _Steps extends StatelessWidget {
  const _Steps({
    required this.steps,
    required this.current,
    required this.complete,
  });

  final List<String> steps;
  final int current;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget line(bool on, bool show) => Expanded(
      child: Container(
        height: 2,
        color: !show
            ? Colors.transparent
            : (on ? scheme.primary : scheme.outlineVariant),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Semantics(
              selected: i == current,
              child: Column(
                children: [
                  Row(
                    children: [
                      line(i <= current, i > 0),
                      StepDot(
                        done: complete || i < current,
                        now: !complete && i == current,
                      ),
                      line(i < current, i < steps.length - 1),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 2,
                    ),
                    child: Text(
                      steps[i],
                      textAlign: TextAlign.center,
                      style: i == current && !complete
                          ? text.labelMedium
                          : text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
