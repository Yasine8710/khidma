import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../application/freelance_providers.dart';
import '../domain/freelance_domain.dart';
import 'freelance_invites_section.dart';
import 'freelance_portfolio_manager.dart';
import 'freelance_widgets.dart';

/// The owner's freelance space: become a freelancer, edit the page, check the
/// identity, publish, manage work and testimonial invitations.
class FreelanceManageScreen extends ConsumerWidget {
  const FreelanceManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myFreelancerProvider);
    final me = async.value;
    final Widget body;
    if (me != null) {
      body = _Editor(me: me);
    } else if (async.hasError) {
      body = ErrorState(
        onRetry: () => ref.invalidate(myFreelancerProvider),
        body: async.error is FreelanceError
            ? freelanceFailureText(
                l10n,
                (async.error as FreelanceError).failure,
              )
            : l10n.errorBody,
      );
    } else if (async.isLoading) {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 160, radius: AppRadius.lg),
        ),
      );
    } else {
      body = const _Intro();
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.flManageTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(freelanceActionsProvider);
    return EmptyState(
      icon: Icons.laptop_mac_outlined,
      title: l10n.flIntroTitle,
      body: l10n.flIntroBody,
      actionLabel: busy ? l10n.loading : l10n.flBecome,
      onAction: busy
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final f = await ref
                  .read(freelanceActionsProvider.notifier)
                  .become();
              if (f != null) {
                messenger
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text(freelanceFailureText(l10n, f))),
                  );
              }
            },
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.me});

  final MyFreelancer me;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.me.name);
  late final _headline = TextEditingController(text: widget.me.headline);
  late final _bio = TextEditingController(text: widget.me.bio);
  late final _skills = TextEditingController(text: widget.me.skills.join(', '));
  late final _languages = TextEditingController(
    text: widget.me.languages.join(', '),
  );
  late final _years = TextEditingController(
    text: widget.me.yearsExperience?.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: FreelanceRules.millimesToDinars(widget.me.startingPriceMillimes),
  );
  late int? _categoryId = widget.me.categoryId;
  late PriceUnit _unit = widget.me.priceUnit;
  late Availability _availability = widget.me.availability;

  @override
  void dispose() {
    for (final c in [
      _name,
      _headline,
      _bio,
      _skills,
      _languages,
      _years,
      _price,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  FreelanceInput _input() => FreelanceInput(
    name: _name.text,
    headline: _headline.text,
    bio: _bio.text,
    categoryId: _categoryId,
    skills: FreelanceRules.parseTags(
      _skills.text,
      max: FreelanceRules.maxSkills,
    ),
    languages: FreelanceRules.parseTags(
      _languages.text,
      max: FreelanceRules.maxLanguages,
    ),
    yearsExperience: int.tryParse(_years.text.trim()),
    startingPriceMillimes: FreelanceRules.dinarsToMillimes(_price.text),
    priceUnit: _unit,
    availability: _availability,
  );

  /// Validates and saves the form. Returns whether it was saved.
  Future<bool> _save({bool announce = true}) async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final f = await ref.read(freelanceActionsProvider.notifier).save(_input());
    if (!mounted) return false;
    if (f != null) {
      _toast(freelanceFailureText(l10n, f));
      return false;
    }
    if (announce) _toast(l10n.flSaved);
    return true;
  }

  Future<void> _togglePublish(bool on) async {
    final l10n = AppLocalizations.of(context);
    // What is on screen is saved first, so publishing checks the same page.
    if (on && !await _save(announce: false)) return;
    final f = await ref
        .read(freelanceActionsProvider.notifier)
        .setPublished(on);
    if (!mounted) return;
    if (f != null) _toast(freelanceFailureText(l10n, f));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(freelanceActionsProvider);
    final cats = ref.watch(digitalCategoriesProvider).value ?? const [];
    final me = widget.me;
    final canToggle = me.isVerified || me.isPublished;
    const gap = SizedBox(height: AppSpacing.md);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        // Identity and publication first: they decide what the rest is for.
        RegisterHeading(title: l10n.flIdentityTitle),
        Row(
          children: [
            if (me.isVerified)
              AppBadge.verified(context)
            else
              AppBadge(
                label: l10n.flIdentityNotVerified,
                tone: BadgeTone.warning,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          me.isVerified ? l10n.flIdentityVerified : l10n.flIdentityShared,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (!me.isVerified) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.verifCta,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.proVerification),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.flPublish),
          subtitle: Text(
            !canToggle
                ? l10n.flPublishBlocked
                : (me.isPublished
                      ? l10n.flPublishedHint
                      : l10n.flUnpublishedHint),
          ),
          value: me.isPublished,
          onChanged: canToggle && !busy ? _togglePublish : null,
        ),
        const SizedBox(height: AppSpacing.xl),
        RegisterHeading(title: l10n.flSectionProfile),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.flFieldName,
                controller: _name,
                maxLength: FreelanceRules.nameMax,
                validator: (v) =>
                    FreelanceRules.nameOk(v) ? null : l10n.flErrName,
              ),
              gap,
              AppTextField(
                label: l10n.flFieldHeadline,
                hint: l10n.flFieldHeadlineHint,
                controller: _headline,
                maxLength: FreelanceRules.headlineMax,
                validator: (v) =>
                    FreelanceRules.headlineOk(v) ? null : l10n.flErrHeadline,
              ),
              gap,
              Text(l10n.flFieldCategory, style: text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<int>(
                initialValue: cats.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                isExpanded: true,
                items: [
                  for (final c in cats)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.nameFor(locale),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              gap,
              AppTextField(
                label: l10n.flFieldBio,
                helper: l10n.flFieldBioHelp,
                controller: _bio,
                maxLines: 5,
                maxLength: FreelanceRules.bioMax,
                validator: (v) =>
                    FreelanceRules.bioOk(v) ? null : l10n.flErrBio,
              ),
              gap,
              AppTextField(
                label: l10n.flFieldSkills,
                helper: l10n.flFieldSkillsHelp,
                controller: _skills,
                validator: (v) =>
                    FreelanceRules.tagsOk(v, max: FreelanceRules.maxSkills)
                    ? null
                    : l10n.flErrTags(FreelanceRules.maxSkills),
              ),
              gap,
              AppTextField(
                label: l10n.flFieldLanguages,
                helper: l10n.flFieldLanguagesHelp,
                controller: _languages,
                validator: (v) =>
                    FreelanceRules.tagsOk(v, max: FreelanceRules.maxLanguages)
                    ? null
                    : l10n.flErrTags(FreelanceRules.maxLanguages),
              ),
              gap,
              AppTextField(
                label: l10n.flFieldYears,
                controller: _years,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return null;
                  final n = int.tryParse(s);
                  return n != null && n >= 0 && n <= FreelanceRules.yearsMax
                      ? null
                      : l10n.flErrYears;
                },
              ),
              gap,
              AppTextField(
                label: l10n.flFieldPrice,
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  return FreelanceRules.dinarsToMillimes(v) == null
                      ? l10n.flErrPrice
                      : null;
                },
              ),
              gap,
              Text(l10n.flFieldUnit, style: text.labelLarge),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final u in PriceUnit.values)
                    AppChip(
                      label: priceUnitLabel(l10n, u),
                      selected: _unit == u,
                      onSelected: (_) => setState(() => _unit = u),
                    ),
                ],
              ),
              gap,
              Text(l10n.flFieldAvailability, style: text.labelLarge),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final a in Availability.values)
                    AppChip(
                      label: availabilityLabel(l10n, a),
                      selected: _availability == a,
                      onSelected: (_) => setState(() => _availability = a),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: l10n.save, isLoading: busy, onPressed: _save),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const FreelancePortfolioManager(),
        const SizedBox(height: AppSpacing.xxl),
        const FreelanceInvitesSection(),
      ],
    );
  }
}
