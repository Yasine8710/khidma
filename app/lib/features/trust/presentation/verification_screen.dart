import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';
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
          // The file's status, framed like the stamp box of a licence:
          // olive once verified, plain ink otherwise.
          Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: approved ? scheme.secondary : scheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      approved
                          ? Icons.verified_rounded
                          : pending
                          ? Icons.hourglass_top_rounded
                          : Icons.shield_outlined,
                      color: approved
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(switch (info.status) {
                        VerificationStatus.none => l10n.verifStatusNone,
                        VerificationStatus.pending => l10n.verifStatusPending,
                        VerificationStatus.approved => l10n.verifStatusApproved,
                        VerificationStatus.rejected => l10n.verifStatusRejected,
                        VerificationStatus.cancelled =>
                          l10n.verifStatusCancelled,
                      }, style: text.titleMedium),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
            style: text.bodyMedium,
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
            for (var i = 0; i < _documents.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    // A small framed print of the document.
                    DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.memory(
                          _documents[i].bytes,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          // The preview is decoration: the count says it all.
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.description_outlined),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.verifRemove(i + 1),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: busy
                          ? null
                          : () => setState(() => _documents.removeAt(i)),
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
