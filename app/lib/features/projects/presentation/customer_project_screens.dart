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
import '../../freelance/application/freelance_providers.dart';
import '../../requests/application/customer_offers_providers.dart';
import '../../requests/domain/requests_domain.dart';
import '../../requests/presentation/flow_widgets.dart';
import '../../requests/presentation/received_offers_section.dart';
import '../../requests/presentation/requests_texts.dart';
import '../../offers/domain/offers_domain.dart' show BookingStatus;
import '../application/projects_providers.dart';
import '../domain/projects_domain.dart';
import 'project_widgets.dart';

/// The customer posts a remote project: no address, no map.
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _brief = TextEditingController();
  final _deliverables = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _links = <TextEditingController>[TextEditingController()];
  int? _category;
  DateTime? _deadline;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _brief, _deliverables, _min, _max, ..._links]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
    );
    if (d != null) setState(() => _deadline = d);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_form.currentState?.validate() ?? false)) return;
    final min = _num(_min);
    final max = _num(_max);
    if (min != null && max != null && max < min) {
      setState(() => _error = l10n.projErrBudget);
      return;
    }
    final (:id, :failure) = await ref
        .read(projectActionsProvider.notifier)
        .create(
          NewProject(
            title: _title.text,
            description: _brief.text,
            categoryId: _category!,
            deliverables: _deliverables.text,
            budgetMin: min,
            budgetMax: max,
            neededBy: _deadline,
            links: [for (final c in _links) c.text],
          ),
        );
    if (!mounted) return;
    if (id == null) {
      setState(() => _error = requestFailureText(l10n, failure!));
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.projCreated)));
    context.pushReplacement(AppRoutes.projectPath(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(projectActionsProvider);
    final cats = ref.watch(digitalCategoriesProvider).value ?? const [];
    String? atLeast(String? v, int n, String msg) =>
        (v ?? '').trim().length >= n ? null : msg;
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projNewTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            AppTextField(
              label: l10n.projFieldTitle,
              controller: _title,
              maxLength: 120,
              validator: (v) => atLeast(v, 3, l10n.projErrRequired),
            ),
            gap,
            DropdownButtonFormField<int>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.projFieldCategory),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.nameFor(locale))),
              ],
              onChanged: (v) => setState(() => _category = v),
              validator: (v) => v == null ? l10n.projErrCategory : null,
            ),
            gap,
            AppTextField(
              label: l10n.projFieldBrief,
              controller: _brief,
              maxLines: 5,
              maxLength: 2000,
              validator: (v) => atLeast(v, 10, l10n.projErrBrief),
            ),
            gap,
            AppTextField(
              label: l10n.projFieldDeliverables,
              hint: l10n.projDeliverablesHint,
              controller: _deliverables,
              maxLines: 3,
              maxLength: 1000,
              validator: (v) => atLeast(v, 3, l10n.projErrRequired),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: l10n.projFieldBudgetMin,
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: l10n.projFieldBudgetMax,
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            gap,
            AppButton(
              label: _deadline == null
                  ? l10n.projFieldDeadline
                  : l10n.projDeadline(formatDate(_deadline!, locale)),
              variant: AppButtonVariant.secondary,
              icon: Icons.event_outlined,
              onPressed: _pickDate,
            ),
            gap,
            for (var i = 0; i < _links.length; i++) ...[
              AppTextField(
                label: l10n.projFieldLink,
                controller: _links[i],
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                validator: (v) =>
                    (v ?? '').trim().isEmpty || isProjectLink(v!.trim())
                    ? null
                    : l10n.projErrLink,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_links.length < maxProjectLinks)
              AppButton(
                label: l10n.projAddLink,
                variant: AppButtonVariant.text,
                icon: Icons.add_link_rounded,
                onPressed: () =>
                    setState(() => _links.add(TextEditingController())),
              ),
            if (_error != null) ...[
              gap,
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.projSubmit,
              isLoading: busy,
              onPressed: busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The customer's remote projects.
class MyProjectsScreen extends ConsumerWidget {
  const MyProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final projects = ref.watch(myProjectsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projMine)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newProject),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.projNewCta),
      ),
      body: switch (projects) {
        AsyncData(:final value) when value.isEmpty => CalmEmpty(
          icon: Icons.public_rounded,
          title: l10n.projEmpty,
          actionLabel: l10n.projNewCta,
          onAction: () => context.push(AppRoutes.newProject),
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            96,
          ),
          children: [
            for (final (i, p) in value.indexed)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.sm,
                ),
                child: FlowCard(
                  index: i,
                  onTap: () => context.push(AppRoutes.projectPath(p.id)),
                  semanticLabel: p.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: text.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${statusLabel(l10n, p.status)} · ${l10n.reqOffers(p.offerCount)} · ${formatDate(p.createdAt, locale)}',
                        style: text.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        AsyncError() => ErrorState(
          onRetry: () => ref.invalidate(myProjectsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// One of the customer's projects: details, offers (accepting shows the
/// payment terms), the job and its deliveries.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(myProjectsProvider);
    final p = projects.value?.where((x) => x.id == id).firstOrNull;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.projNewTitle)),
        body: projects.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ErrorState(onRetry: () => ref.invalidate(myProjectsProvider)),
      );
    }
    final booking = p.status == RequestStatus.awarded
        ? ref.watch(bookingForRequestProvider(p.id)).value
        : null;
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
          const SizedBox(height: AppSpacing.lg),
          ReceivedOffersSection(request: p.asRequest(), remote: true),
          if (p.status == RequestStatus.awarded)
            BookingSection(requestId: p.id),
          if (booking != null)
            DeliveriesSection(
              bookingId: booking.id,
              asFreelancer: false,
              canDeliver: false,
              canAskRevision:
                  booking.status == BookingStatus.pendingConfirmation,
            ),
        ],
      ),
    );
  }
}
