import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/digits.dart';
import '../../../core/haptics.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../portfolio/presentation/portfolio_screen.dart'
    show portfolioFailureText;
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'flow_widgets.dart';
import 'requests_texts.dart';

/// Ask for a quote in numbered steps (service, the need, where, when,
/// photos) under a thin progress bar; the send button stays at the bottom.
/// Everything typed stays on screen if sending fails.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key, this.categoryId});

  final int? categoryId;

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  late int? _category = widget.categoryId;
  int? _governorate;
  int? _city;
  DateTime? _neededBy;
  final _photos = <PreparedPhoto>[];
  bool _categoryError = false;
  bool _governorateError = false;
  bool _picking = false;
  String? _error;
  bool _placeInitialised = false;

  @override
  void initState() {
    super.initState();
    // The progress bar follows what is typed.
    _title.addListener(_onTyped);
    _description.addListener(_onTyped);
  }

  void _onTyped() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  double? get _budgetValue {
    final t = toWesternDigits(_budget.text.trim()).replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _addPhoto() async {
    if (_picking || _photos.length >= maxRequestPhotos) return;
    setState(() => _picking = true);
    final l10n = AppLocalizations.of(context);
    try {
      final photo = await ref.read(requestActionsProvider.notifier).pickPhoto();
      if (photo != null && mounted) setState(() => _photos.add(photo));
    } on PortfolioError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(portfolioFailureText(l10n, e.failure))),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.portfolioFailGeneric)));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now.add(const Duration(days: 3)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _neededBy = picked);
  }

  Future<void> _send() async {
    final ok = _formKey.currentState?.validate() ?? false;
    setState(() {
      _categoryError = _category == null;
      _governorateError = _governorate == null;
    });
    if (!ok || _category == null || _governorate == null) return;
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(requestActionsProvider.notifier)
        .send(
          NewRequest(
            title: _title.text,
            description: _description.text,
            categoryId: _category!,
            governorateId: _governorate!,
            cityId: _city,
            budgetTnd: _budgetValue,
            neededBy: _neededBy,
          ),
          List.of(_photos),
        );
    if (!mounted) return;
    if (!result.isOk) {
      final f = result.failure!;
      // The unknown failure from a double tap is not worth a message.
      setState(() => _error = requestFailureText(l10n, f));
      return;
    }
    final created = result.created!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            created.failedPhotos > 0 ? l10n.reqSentPhotosFailed : l10n.reqSent,
          ),
        ),
      );
    context.pushReplacement(AppRoutes.requestPath(created.id));
  }

  /// Required parts filled in: service, title, description, governorate.
  int get _requiredDone => [
    _category != null,
    RequestRules.titleOk(_title.text),
    RequestRules.descriptionOk(_description.text),
    _governorate != null,
  ].where((ok) => ok).length;

  static const _requiredTotal = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(requestActionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final governorates = ref.watch(governoratesProvider).value ?? const [];
    final cities = _governorate == null
        ? const <City>[]
        : (ref.watch(citiesProvider(_governorate)).value ?? const <City>[]);

    // Start from the area the person already chose on Home.
    if (!_placeInitialised) {
      _placeInitialised = true;
      final place = ref.read(selectedPlaceProvider);
      _governorate = place?.governorateId;
      _city = place?.cityId;
    }

    final done = _requiredDone;
    const gap = SizedBox(height: AppSpacing.lg);
    const section = SizedBox(height: AppSpacing.xl);
    Widget label(String s) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ExcludeSemantics(child: Text(s, style: text.titleSmall)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reqNew)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A thin bar: how much of what is required is filled in.
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: _ProgressBar(
                  value: done / _requiredTotal,
                  label: l10n.reqFormProgress(done, _requiredTotal),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PrivacyNote(text: l10n.reqFormPrivacy),
                      section,
                      _StepHeading(
                        number: 1,
                        title: l10n.flowSecService,
                        note: l10n.reqFormCategory,
                        done: _category != null,
                      ),
                      _CategoryGrid(
                        categories: categories,
                        selected: _category,
                        onSelect: (id) => setState(() {
                          _category = id;
                          _categoryError = false;
                        }),
                      ),
                      if (_categoryError)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.sm,
                          ),
                          child: Text(
                            l10n.reqErrCategory,
                            style: text.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                      section,
                      _StepHeading(
                        number: 2,
                        title: l10n.flowSecNeed,
                        done:
                            RequestRules.titleOk(_title.text) &&
                            RequestRules.descriptionOk(_description.text),
                      ),
                      AppTextField(
                        label: l10n.reqFormTitle,
                        hint: l10n.reqFormTitleHint,
                        controller: _title,
                        maxLength: RequestRules.titleMax,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            RequestRules.titleOk(v) ? null : l10n.reqErrTitle,
                      ),
                      gap,
                      AppTextField(
                        label: l10n.reqFormDescription,
                        helper: l10n.reqFormDescriptionHelper,
                        controller: _description,
                        maxLines: 5,
                        maxLength: RequestRules.descriptionMax,
                        validator: (v) => RequestRules.descriptionOk(v)
                            ? null
                            : l10n.reqErrDescription,
                      ),
                      gap,
                      AppTextField(
                        label: l10n.reqFormBudget,
                        controller: _budget,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9٠-٩.,]'),
                          ),
                        ],
                        maxLength: 9,
                        validator: (v) {
                          final t = toWesternDigits((v ?? '').trim())
                              .replaceAll(',', '.');
                          if (t.isEmpty) return null;
                          // Text that is not a number is an error, never
                          // "no budget".
                          final n = double.tryParse(t);
                          return n != null && RequestRules.budgetOk(n)
                              ? null
                              : l10n.reqErrBudget;
                        },
                      ),
                      section,
                      _StepHeading(
                        number: 3,
                        title: l10n.flowSecWhere,
                        done: _governorate != null,
                      ),
                      label(l10n.regGovernorate),
                      Semantics(
                        label: l10n.regGovernorate,
                        child: DropdownButtonFormField<int>(
                          initialValue: _governorate,
                          isExpanded: true,
                          decoration: InputDecoration(
                            errorText: _governorateError
                                ? l10n.reqErrGovernorate
                                : null,
                          ),
                          items: [
                            for (final g in governorates)
                              DropdownMenuItem(
                                value: g.id,
                                child: Text(g.nameFor(locale)),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            if (v != _governorate) _city = null;
                            _governorate = v;
                            _governorateError = false;
                          }),
                        ),
                      ),
                      gap,
                      label(l10n.regCity),
                      Semantics(
                        label: l10n.regCity,
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey(_governorate),
                          initialValue: _city,
                          isExpanded: true,
                          items: [
                            for (final c in cities)
                              DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.nameFor(locale)),
                              ),
                          ],
                          onChanged: _governorate == null
                              ? null
                              : (v) => setState(() => _city = v),
                        ),
                      ),
                      section,
                      _StepHeading(
                        number: 4,
                        title: l10n.flowSecWhen,
                        note: l10n.reqFormNeededBy,
                        done: _neededBy != null,
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppButton(
                            label: _neededBy == null
                                ? l10n.reqFormPickDate
                                : formatDate(_neededBy!, locale),
                            icon: Icons.event_outlined,
                            variant: AppButtonVariant.secondary,
                            expand: false,
                            onPressed: _pickDate,
                          ),
                          if (_neededBy != null)
                            AppButton(
                              label: l10n.reqFormNeededByNone,
                              variant: AppButtonVariant.text,
                              onPressed: () => setState(() => _neededBy = null),
                            ),
                        ],
                      ),
                      section,
                      _StepHeading(
                        number: 5,
                        title: l10n.flowSecPhotos,
                        note: l10n.reqFormPhotosCount(
                          _photos.length,
                          maxRequestPhotos,
                        ),
                        done: _photos.isNotEmpty,
                      ),
                      if (_photos.isNotEmpty) ...[
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (var i = 0; i < _photos.length; i++)
                              _PhotoTile(
                                photo: _photos[i],
                                index: i + 1,
                                onRemove: busy
                                    ? null
                                    : () => setState(() => _photos.removeAt(i)),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppButton(
                          label: l10n.reqFormAddPhoto,
                          icon: Icons.add_a_photo_outlined,
                          variant: AppButtonVariant.secondary,
                          expand: false,
                          isLoading: _picking,
                          onPressed: busy || _photos.length >= maxRequestPhotos
                              ? null
                              : _addPhoto,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The send bar stays put under a hairline while the form
              // scrolls.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: BorderDirectional(
                    top: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton(
                        label: l10n.reqFormSubmit,
                        isLoading: busy,
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin rounded progress bar that eases to its new value (at once with
/// Reduce Motion). Read as "2 of 4 steps filled in".
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget bar(double v) => ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(value: v, minHeight: 4),
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Motion.reduced(context)
          ? bar(value)
          : TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: Motion.base,
              curve: Motion.enter,
              builder: (context, v, _) => bar(v),
            ),
    );
  }
}

/// A numbered step of the form: a small circle with the number (a check
/// once the step is filled in), the title, and an optional muted note.
class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.number,
    required this.title,
    required this.done,
    this.note,
  });

  final int number;
  final String title;
  final bool done;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: AnimatedContainer(
              duration: Motion.reduced(context) ? Duration.zero : Motion.base,
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? scheme.primary : scheme.primaryContainer,
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                  : Text(
                      '$number',
                      textScaler: TextScaler.noScaling,
                      style: text.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleMedium),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The privacy promise at the head of the form, on a soft violet panel.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The service picker: tiles two per line (one on a very narrow screen),
/// each with its tinted icon. The chosen one gets a violet outline, a soft
/// violet fill and a check.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<ServiceCategory> categories;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth < 260 ? 1 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < categories.length; i += columns) {
          final line = categories.skip(i).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: j < line.length
                          ? _CategoryBox(
                              category: line[j],
                              selected: selected == line[j].id,
                              onTap: () => onSelect(line[j].id),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

class _CategoryBox extends StatelessWidget {
  const _CategoryBox({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ServiceCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final name = category.nameFor(locale);
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        haptic: false,
        button: false,
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              IconTile(
                icon: categoryIcon(category.icon),
                seed: category.id,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: fg),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.onRemove,
  });

  final PreparedPhoto photo;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Semantics(
              image: true,
              label: l10n.portfolioPhotoOf(index, 0),
              excludeSemantics: true,
              child: Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                cacheWidth: 264,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: scheme.surfaceContainerHighest),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              tooltip: l10n.reqFormRemovePhoto(index),
              iconSize: 16,
              style: IconButton.styleFrom(
                minimumSize: const Size(30, 30),
                fixedSize: const Size(30, 30),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: scheme.surface,
                foregroundColor: scheme.onSurface,
                shape: CircleBorder(
                  side: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
