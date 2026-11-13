import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../freelance/application/freelance_providers.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/presentation/flow_widgets.dart';
import '../../requests/presentation/requests_texts.dart';
import '../application/projects_providers.dart';
import '../domain/projects_domain.dart';

/// "100 – 300 TND", "≥ 100 TND", "≤ 300 TND", or null without a budget.
String? budgetRange(RemoteProject p, Locale locale) {
  final min = p.budgetMin;
  final max = p.budgetMax;
  if (min == null && max == null) return null;
  if (min != null && max != null) {
    return '${formatTnd(min, locale)} – ${formatTnd(max, locale)}';
  }
  return min != null
      ? '≥ ${formatTnd(min, locale)}'
      : '≤ ${formatTnd(max!, locale)}';
}

/// Title, type of work, brief, deliverables, budget, deadline and links.
class ProjectHeaderCard extends ConsumerWidget {
  const ProjectHeaderCard({super.key, required this.project});

  final RemoteProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final p = project;
    final cat = (ref.watch(digitalCategoriesProvider).value ?? const [])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    final budget = budgetRange(p, locale);
    return FlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusPill(
                label: statusLabel(l10n, p.status),
                tone: statusTone(p.status),
                icon: statusIcon(p.status),
              ),
              StatusPill(label: l10n.projRemote, icon: Icons.public_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(p.title, style: text.titleLarge),
          if (cat != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              cat.nameFor(locale),
              style: text.bodyMedium?.copyWith(color: muted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(p.description, style: text.bodyLarge),
          if ((p.deliverables ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.projDeliverables, style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(p.deliverables!, style: text.bodyMedium),
          ],
          if (budget != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.projBudget(budget), style: text.bodyMedium),
          ],
          if (p.neededBy != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.projDeadline(formatDate(p.neededBy!, locale)),
              style: text.bodyMedium,
            ),
          ],
          if (p.links.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.projLinks, style: text.labelLarge),
            for (final link in p.links)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    link,
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Deliveries of a remote job. The customer can ask for an included revision
/// while the job waits for them; the freelancer hands in work while it is in
/// progress (or again while it waits).
class DeliveriesSection extends ConsumerStatefulWidget {
  const DeliveriesSection({
    super.key,
    required this.bookingId,
    required this.asFreelancer,
    required this.canDeliver,
    required this.canAskRevision,
  });

  final String bookingId;
  final bool asFreelancer;
  final bool canDeliver;
  final bool canAskRevision;

  @override
  ConsumerState<DeliveriesSection> createState() => _DeliveriesSectionState();
}

class _DeliveriesSectionState extends ConsumerState<DeliveriesSection> {
  final _note = TextEditingController();
  final _link = TextEditingController();
  final _revision = TextEditingController();
  final _photos = <PreparedPhoto>[];
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    _link.dispose();
    _revision.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addPhoto() async {
    final photo = await ref.read(projectActionsProvider.notifier).pickPhoto();
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  Future<void> _deliver() async {
    final l10n = AppLocalizations.of(context);
    final note = _note.text.trim();
    final link = _link.text.trim();
    if (note.isEmpty && link.isEmpty && _photos.isEmpty) {
      setState(() => _error = l10n.projDeliverEmpty);
      return;
    }
    if (link.isNotEmpty && !isProjectLink(link)) {
      setState(() => _error = l10n.projErrLink);
      return;
    }
    final f = await ref
        .read(projectActionsProvider.notifier)
        .deliver(
          widget.bookingId,
          note: note,
          link: link,
          photos: [..._photos],
        );
    if (!mounted) return;
    if (f == null) {
      setState(() {
        _error = null;
        _photos.clear();
        _note.clear();
        _link.clear();
      });
      _say(l10n.projDelivered);
    } else {
      setState(() => _error = requestFailureText(l10n, f));
    }
  }

  Future<void> _askRevision() async {
    final l10n = AppLocalizations.of(context);
    if (_revision.text.trim().isEmpty) {
      setState(() => _error = l10n.projRevisionHint);
      return;
    }
    final f = await ref
        .read(projectActionsProvider.notifier)
        .requestRevision(widget.bookingId, _revision.text);
    if (!mounted) return;
    if (f == null) {
      _revision.clear();
      setState(() => _error = null);
      _say(l10n.projRevisionSent);
    } else {
      setState(() => _error = requestFailureText(l10n, f));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(projectActionsProvider);
    final data = ref.watch(deliveriesProvider(widget.bookingId)).value;
    final items = data?.items ?? const <Delivery>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(
          title: l10n.projDeliveriesTitle,
          note: data == null || data.revisionsIncluded == 0
              ? null
              : l10n.projRevisionLeft(data.revisionsLeft),
        ),
        if (items.isEmpty)
          Text(
            l10n.projNoDelivery,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        for (final d in items.reversed)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: FlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDate(d.createdAt, locale),
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if ((d.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(d.note!, style: text.bodyMedium),
                  ],
                  if (d.link != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(d.link!, style: text.bodySmall),
                    ),
                  ],
                  for (var i = 0; i < d.paths.length; i++)
                    AppButton(
                      label: l10n.projDeliveryFile(i + 1),
                      variant: AppButtonVariant.text,
                      icon: Icons.attach_file_rounded,
                      onPressed: () async {
                        final ok = await ref
                            .read(projectActionsProvider.notifier)
                            .openFile(d.paths[i]);
                        if (!ok && context.mounted) {
                          _say(l10n.projOpenFileFailed);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        if (widget.asFreelancer && widget.canDeliver) ...[
          const SizedBox(height: AppSpacing.md),
          SectionTitle(title: l10n.projDeliverTitle),
          AppTextField(
            label: l10n.projDeliverNote,
            controller: _note,
            maxLines: 3,
            maxLength: 1000,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: l10n.projDeliverLink,
            controller: _link,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_photos.isNotEmpty)
            Text(l10n.projDeliverPhotos(_photos.length), style: text.bodySmall),
          AppButton(
            label: l10n.projDeliverAddPhoto,
            variant: AppButtonVariant.secondary,
            icon: Icons.add_photo_alternate_outlined,
            onPressed: busy || _photos.length >= maxDeliveryPhotos
                ? null
                : _addPhoto,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.projDeliverSend,
            isLoading: busy,
            onPressed: busy ? null : _deliver,
          ),
        ],
        if (!widget.asFreelancer &&
            widget.canAskRevision &&
            (data?.revisionsLeft ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.projRevisionHint,
            controller: _revision,
            maxLines: 3,
            maxLength: 1000,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.projRevisionAsk,
            variant: AppButtonVariant.secondary,
            isLoading: busy,
            onPressed: busy ? null : _askRevision,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
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
  }
}
