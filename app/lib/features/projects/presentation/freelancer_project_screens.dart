import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_state.dart';
import '../../offers/application/offers_providers.dart';
import '../../offers/domain/offers_domain.dart';
import '../../requests/presentation/flow_widgets.dart';
import '../../requests/presentation/requests_texts.dart';
import '../application/projects_providers.dart';
import '../domain/projects_domain.dart';
import 'project_widgets.dart';

/// Open remote projects, for freelancers.
class ProjectInboxScreen extends ConsumerWidget {
  const ProjectInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = ref.watch(openProjectsProvider(null));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projOpenTitle)),
      body: switch (list) {
        AsyncData(:final value) when value.isEmpty => CalmEmpty(
          icon: Icons.public_rounded,
          title: l10n.projEmptyOpen,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(openProjectsProvider(null).future),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              for (final (i, p) in value.indexed)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.sm,
                  ),
                  child: FlowCard(
                    index: i,
                    semanticLabel: p.title,
                    onTap: () => context.push(AppRoutes.proProjectPath(p.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: text.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          [
                            ?budgetRange(p, locale),
                            if (p.neededBy != null)
                              l10n.projDeadline(
                                formatDate(p.neededBy!, locale),
                              ),
                            l10n.reqOffers(p.offerCount),
                          ].join(' · '),
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        AsyncError() => ErrorState(
          onRetry: () => ref.invalidate(openProjectsProvider(null)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// One project for the freelancer: details, their offer, and once accepted,
/// the job with its deliveries.
class ProProjectScreen extends ConsumerWidget {
  const ProProjectScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectProvider(id));
    final job = (ref.watch(myJobsProvider).value ?? const <Job>[])
        .where((j) => j.requestId == id)
        .firstOrNull;
    final p = project.value;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.projNewTitle)),
        body: project.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ErrorState(onRetry: () => ref.invalidate(projectProvider(id))),
      );
    }
    final canOffer =
        p.isOpen &&
        p.myOfferStatus != 'accepted' &&
        p.myOfferStatus != 'declined';
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: [
          ProjectHeaderCard(project: p),
          if (canOffer) _OfferForm(project: p),
          if (job != null) _JobPanel(job: job),
        ],
      ),
    );
  }
}

class _OfferForm extends ConsumerStatefulWidget {
  const _OfferForm({required this.project});

  final RemoteProject project;

  @override
  ConsumerState<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<_OfferForm> {
  final _price = TextEditingController();
  final _days = TextEditingController(text: '7');
  final _revisions = TextEditingController(text: '2');
  final _message = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_price, _days, _revisions, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    final days = int.tryParse(_days.text.trim());
    final revisions = int.tryParse(_revisions.text.trim());
    if (price == null ||
        price < 1 ||
        days == null ||
        days < 1 ||
        days > 365 ||
        revisions == null ||
        revisions < 0 ||
        revisions > maxRevisions) {
      setState(() => _error = l10n.projErrOffer);
      return;
    }
    final f = await ref
        .read(projectActionsProvider.notifier)
        .offer(
          widget.project.id,
          price: price,
          days: days,
          revisions: revisions,
          message: _message.text,
        );
    if (!mounted) return;
    if (f == null) {
      setState(() => _error = null);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.projOfferSent)));
    } else {
      setState(() => _error = requestFailureText(l10n, f));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(projectActionsProvider);
    const number = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(title: l10n.projOfferTitle),
        AppTextField(
          label: l10n.projOfferPrice,
          controller: _price,
          keyboardType: number,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.projOfferDays,
                controller: _days,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: l10n.projOfferRevisions,
                controller: _revisions,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.projOfferMessage,
          controller: _message,
          maxLines: 3,
          maxLength: 1000,
        ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.projOfferSend,
          isLoading: busy,
          onPressed: busy ? null : _send,
        ),
      ],
    );
  }
}

class _JobPanel extends ConsumerWidget {
  const _JobPanel({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(offerActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (job.status == BookingStatus.scheduled) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.projStartJob,
            isLoading: busy,
            onPressed: busy
                ? null
                : () async {
                    final f = await ref
                        .read(offerActionsProvider.notifier)
                        .start(job.id);
                    if (f != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(requestFailureText(l10n, f))),
                      );
                    }
                  },
          ),
        ],
        DeliveriesSection(
          bookingId: job.id,
          asFreelancer: true,
          canDeliver:
              job.status == BookingStatus.inProgress ||
              job.status == BookingStatus.pendingConfirmation,
          canAskRevision: false,
        ),
      ],
    );
  }
}
