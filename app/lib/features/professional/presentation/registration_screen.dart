import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/digits.dart';
import '../../../core/format/tunisian_phone.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../../location/domain/location_domain.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../application/professional_providers.dart';
import '../domain/professional_domain.dart';

enum _Step { business, location, areas, services, contact, review }

String failureText(AppLocalizations l10n, ProfessionalFailure f) => switch (f) {
  ProfessionalFailure.network => l10n.regFailNetwork,
  ProfessionalFailure.invalid => l10n.regFailInvalid,
  ProfessionalFailure.forbidden => l10n.regFailForbidden,
  ProfessionalFailure.notConfigured => l10n.regFailNotConfigured,
  _ => l10n.regFailGeneric,
};

String gapText(AppLocalizations l10n, ProfileGap g) => switch (g) {
  ProfileGap.name => l10n.gapName,
  ProfileGap.category => l10n.gapCategory,
  ProfileGap.description => l10n.gapDescription,
  ProfileGap.location => l10n.gapLocation,
  ProfileGap.phone => l10n.gapPhone,
};

/// Multi-step professional profile. Each step is saved when the person
/// continues, so leaving half-way keeps the draft and the next visit resumes.
class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myProfessionalProvider);
    final uid = ref.watch(currentUserProvider.select((u) => u?.id));
    // A reload (after a save) or a failed reload never removes the wizard:
    // whatever is on screen is kept, and it belongs to one account only.
    final draft = async.value;
    final Widget body;
    if (draft != null) {
      body = _Wizard(key: ValueKey(uid), initial: draft);
    } else if (async.hasError) {
      final e = async.error;
      body = ErrorState(
        onRetry: () => ref.invalidate(myProfessionalProvider),
        body: e is ProfessionalError
            ? failureText(l10n, e.failure)
            : l10n.errorBody,
      );
    } else if (async.isLoading) {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 200, radius: AppRadius.lg),
        ),
      );
    } else {
      body = ErrorState(onRetry: () => ref.invalidate(myProfessionalProvider));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.regTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Wizard extends ConsumerStatefulWidget {
  const _Wizard({super.key, required this.initial});
  final ProfessionalDraft initial;

  @override
  ConsumerState<_Wizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<_Wizard> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.businessName);
  late final _years = TextEditingController(
    text: widget.initial.yearsExperience?.toString() ?? '',
  );
  late final _description = TextEditingController(
    text: widget.initial.description,
  );
  late final _phone = TextEditingController(
    text: widget.initial.phone == null
        ? ''
        : TunisianPhone.parse(widget.initial.phone!) ?? '',
  );
  late int? _category = widget.initial.categoryId;
  late int? _governorate = widget.initial.governorateId;
  late int? _city = widget.initial.cityId;
  late LocationFix? _position = widget.initial.position;
  bool _locating = false;
  String? _positionError;
  late final Set<int> _areas = {
    for (final a in widget.initial.areas)
      if (a.cityId == null) a.governorateId,
  };
  late final Set<int> _services = {...widget.initial.serviceCategoryIds};
  _Step _step = _Step.business;
  String? _error;
  bool _categoryError = false;
  bool _governorateError = false;

  @override
  void dispose() {
    for (final c in [_name, _years, _description, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  ProfessionalProfileInput _input() => ProfessionalProfileInput(
    businessName: _name.text,
    categoryId: _category,
    description: _description.text,
    yearsExperience: int.tryParse(toWesternDigits(_years.text.trim())),
    governorateId: _governorate,
    cityId: _city,
    // Kept only while the city is the one on file.
    neighborhoodId: _city == widget.initial.cityId
        ? widget.initial.neighborhoodId
        : null,
    phone: _phone.text,
    position: _position,
  );

  /// The owner's approximate position (about 1 km, rounded before use).
  Future<void> _usePosition() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _positionError = null;
    });
    final (gov, city) = (_governorate, _city);
    LocationFix? fix;
    try {
      fix = await ref.read(locationServiceProvider).current();
    } catch (_) {
      // Permission refused, service off, timeout: the map falls back.
      fix = null;
    }
    if (!mounted) return;
    // The place was changed while waiting: this fix belongs to the old one.
    if (gov != _governorate || city != _city) {
      setState(() => _locating = false);
      return;
    }
    setState(() {
      _locating = false;
      if (fix != null) {
        _position = fix;
      } else {
        _positionError = AppLocalizations.of(context).regPositionFailed;
      }
    });
  }

  /// Areas stored: whole governorates chosen here, never the home one twice
  /// (its professionals already match through their base location), and any
  /// city-level areas set elsewhere are kept untouched.
  List<ServiceArea> _areaList() => [
    for (final g in _areas)
      if (g != _governorate) ServiceArea(governorateId: g),
    for (final a in widget.initial.areas)
      if (a.cityId != null) a,
  ];

  bool _validate() {
    final ok = _formKey.currentState?.validate() ?? true;
    var extra = true;
    setState(() {
      _categoryError = _step == _Step.business && _category == null;
      _governorateError = _step == _Step.location && _governorate == null;
      extra = !_categoryError && !_governorateError;
    });
    return ok && extra;
  }

  bool _working = false;

  Future<void> _next({bool leave = false}) async {
    if (_working || !_validate()) return;
    _working = true;
    try {
      await _saveStep(leave: leave);
    } finally {
      _working = false;
    }
  }

  Future<void> _saveStep({required bool leave}) async {
    final actions = ref.read(professionalActionsProvider.notifier);
    final failure = switch (_step) {
      _Step.business ||
      _Step.location ||
      _Step.contact => await actions.saveProfile(_input()),
      _Step.areas => await actions.saveAreas(_areaList()),
      _Step.services => await actions.saveServices(_services),
      _Step.review => null,
    };
    if (!mounted || failure == ProfessionalFailure.busy) return;
    if (failure != null) {
      setState(
        () => _error = failureText(AppLocalizations.of(context), failure),
      );
      return;
    }
    if (leave) {
      context.pop();
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.values[_step.index + 1];
    });
  }

  void _back() {
    // Not while a save runs: its result would land on the wrong step.
    if (_working || ref.read(professionalActionsProvider)) return;
    if (_step == _Step.business) {
      context.pop();
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.values[_step.index - 1];
    });
  }

  Future<void> _setPublished(bool value) async {
    final failure = await ref
        .read(professionalActionsProvider.notifier)
        .setPublished(value);
    if (!mounted || failure == ProfessionalFailure.busy) return;
    setState(
      () => _error = failure == null
          ? null
          : failureText(AppLocalizations.of(context), failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(professionalActionsProvider);
    final isReview = _step == _Step.review;
    final title = switch (_step) {
      _Step.business => l10n.regStepBusiness,
      _Step.location => l10n.regStepLocation,
      _Step.areas => l10n.regStepAreas,
      _Step.services => l10n.regStepServices,
      _Step.contact => l10n.regStepContact,
      _Step.review => l10n.regStepReview,
    };

    return PopScope(
      canPop: _step == _Step.business,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              // Not a lazy list: validation only reaches fields that are built.
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.regStepOf(_step.index + 1, _Step.values.length),
                        style: text.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(
                      value: (_step.index + 1) / _Step.values.length,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text(title, style: text.headlineSmall),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ..._fields(context),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: text.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: _step == _Step.business
                        ? l10n.regSaveDraft
                        : l10n.regBack,
                    variant: AppButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : _step == _Step.business
                        ? () => _next(leave: true)
                        : _back,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: isReview
                      ? _finishButton(l10n, busy)
                      : AppButton(
                          label: l10n.regNext,
                          isLoading: busy,
                          onPressed: _next,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The last step's main action lives in the footer, always visible: the
  /// publish button used to sit below the fold of the scrolling review.
  Widget _finishButton(AppLocalizations l10n, bool busy) {
    final draft = ref.watch(myProfessionalProvider).value ?? widget.initial;
    if (draft.isPublished) {
      return AppButton(label: l10n.regDone, onPressed: () => context.pop());
    }
    return AppButton(
      label: l10n.regPublish,
      isLoading: busy,
      onPressed: draft.gaps.isEmpty ? () => _setPublished(true) : null,
    );
  }

  List<Widget> _fields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final governorates = ref.watch(governoratesProvider).value ?? const [];
    final cities = _governorate == null
        ? const <City>[]
        : (ref.watch(citiesProvider(_governorate)).value ?? const <City>[]);
    const gap = SizedBox(height: AppSpacing.lg);

    switch (_step) {
      case _Step.business:
        return [
          AppTextField(
            label: l10n.regBusinessName,
            controller: _name,
            maxLength: ProfessionalRules.nameMax,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                ProfessionalRules.nameOk(v) ? null : l10n.regErrName,
          ),
          gap,
          Text(l10n.regCategory, style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in categories)
                ChoiceChip(
                  label: Text(c.nameFor(locale)),
                  selected: _category == c.id,
                  onSelected: (_) => setState(() {
                    _category = c.id;
                    _categoryError = false;
                  }),
                ),
            ],
          ),
          if (_categoryError)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Text(
                l10n.regErrCategory,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          gap,
          AppTextField(
            label: l10n.regDescription,
            helper: l10n.regDescriptionHelper,
            controller: _description,
            maxLines: 5,
            maxLength: ProfessionalRules.descriptionMax,
            validator: (v) => ProfessionalRules.descriptionOk(v)
                ? null
                : l10n.regErrDescription,
          ),
          gap,
          AppTextField(
            label: l10n.regYears,
            controller: _years,
            keyboardType: TextInputType.number,
            maxLength: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final t = toWesternDigits((v ?? '').trim());
              if (t.isEmpty) return null;
              return ProfessionalRules.yearsOk(int.tryParse(t))
                  ? null
                  : l10n.regErrYears;
            },
          ),
        ];
      case _Step.location:
        return [
          DropdownButtonFormField<int>(
            initialValue: _governorate,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.regGovernorate,
              errorText: _governorateError ? l10n.regErrGovernorate : null,
            ),
            items: [
              for (final g in governorates)
                DropdownMenuItem(value: g.id, child: Text(g.nameFor(locale))),
            ],
            onChanged: (v) => setState(() {
              if (v != _governorate) {
                _city = null;
                // A pin from another governorate would be wrong.
                _position = null;
                _positionError = null;
              }
              _governorate = v;
              _governorateError = false;
            }),
          ),
          gap,
          DropdownButtonFormField<int?>(
            key: ValueKey(_governorate),
            initialValue: _city,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.regCity),
            items: [
              for (final c in cities)
                DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(c.nameFor(locale)),
                ),
            ],
            onChanged: _governorate == null
                ? null
                : (v) => setState(() {
                    if (v != _city) _position = null;
                    _city = v;
                  }),
          ),
          gap,
          AppButton(
            label: l10n.regUsePosition,
            variant: AppButtonVariant.secondary,
            isLoading: _locating,
            onPressed: _governorate == null ? null : _usePosition,
          ),
          if (_position != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.regPositionSet,
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (_positionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _positionError!,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ];
      case _Step.areas:
        return [
          Text(
            l10n.regAreasBody,
            style: text.bodyMedium?.copyWith(color: muted),
          ),
          gap,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final g in governorates)
                if (g.id != _governorate)
                  FilterChip(
                    label: Text(g.nameFor(locale)),
                    selected: _areas.contains(g.id),
                    onSelected: (on) => setState(() {
                      on ? _areas.add(g.id) : _areas.remove(g.id);
                    }),
                  ),
            ],
          ),
        ];
      case _Step.services:
        return [
          Text(
            l10n.regServicesBody,
            style: text.bodyMedium?.copyWith(color: muted),
          ),
          gap,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in categories)
                if (c.id != _category)
                  FilterChip(
                    label: Text(c.nameFor(locale)),
                    selected: _services.contains(c.id),
                    onSelected: (on) => setState(() {
                      on ? _services.add(c.id) : _services.remove(c.id);
                    }),
                  ),
            ],
          ),
        ];
      case _Step.contact:
        return [
          Directionality(
            textDirection: TextDirection.ltr,
            child: AppTextField(
              label: l10n.regPhone,
              helper: l10n.regPhoneHelper,
              hint: '20 123 456',
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              prefixIcon: Icons.call_outlined,
              validator: (v) =>
                  TunisianPhone.isValid(v ?? '') ? null : l10n.regErrPhone,
            ),
          ),
          gap,
          Text(
            l10n.regPhotoLater,
            style: text.bodySmall?.copyWith(color: muted),
          ),
        ];
      case _Step.review:
        return _review(context);
    }
  }

  List<Widget> _review(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final busy = ref.watch(professionalActionsProvider);
    final draft = ref.watch(myProfessionalProvider).value ?? widget.initial;
    final gaps = draft.gaps;
    final locale = Localizations.localeOf(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final category = categories
        .where((c) => c.id == draft.categoryId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;

    return [
      Text(l10n.regReviewBody, style: text.bodyMedium?.copyWith(color: muted)),
      const SizedBox(height: AppSpacing.lg),
      Text(draft.businessName ?? '', style: text.titleLarge),
      if (category != null) Text(category, style: text.bodyMedium),
      const SizedBox(height: AppSpacing.sm),
      Text(draft.description ?? '', style: text.bodyMedium),
      const SizedBox(height: AppSpacing.lg),
      Semantics(
        liveRegion: true,
        child: Text(
          draft.isPublished ? l10n.regPublished : l10n.regDraft,
          style: text.titleSmall,
        ),
      ),
      if (gaps.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.regMissing(gaps.map((g) => gapText(l10n, g)).join(', ')),
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      if (draft.isPublished)
        AppButton(
          label: l10n.regUnpublish,
          variant: AppButtonVariant.secondary,
          isLoading: busy,
          onPressed: () => _setPublished(false),
        ),
    ];
  }
}
