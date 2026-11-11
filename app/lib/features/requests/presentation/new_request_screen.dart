import 'package:flutter/material.dart';

import '../../../shared/widgets/category_photo.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/digits.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../portfolio/presentation/portfolio_screen.dart'
    show portfolioFailureText;
import '../application/requests_providers.dart';
import '../domain/requests_domain.dart';
import 'requests_texts.dart';

/// Ask for a quote: what, where, optional budget / date / photos. Everything
/// typed stays on screen if sending fails.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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

    const gap = SizedBox(height: AppSpacing.lg);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reqNew)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.reqFormPrivacy,
                  style: text.bodySmall?.copyWith(color: muted),
                ),
                gap,
                Text(l10n.reqFormCategory, style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, box) {
                    const columns = 3;
                    final width =
                        (box.maxWidth - AppSpacing.sm * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final c in categories)
                          SizedBox(
                            width: width,
                            height: width * 0.8,
                            child: CategoryTile(
                              name: c.nameFor(locale),
                              slug: c.slug,
                              icon: c.icon,
                              selected: _category == c.id,
                              onTap: () => setState(() {
                                _category = c.id;
                                _categoryError = false;
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_categoryError)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.sm,
                    ),
                    child: Text(
                      l10n.reqErrCategory,
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                gap,
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
                DropdownButtonFormField<int>(
                  initialValue: _governorate,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.regGovernorate,
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
                      : (v) => setState(() => _city = v),
                ),
                gap,
                AppTextField(
                  label: l10n.reqFormBudget,
                  controller: _budget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]')),
                  ],
                  maxLength: 9,
                  validator: (v) {
                    final t = toWesternDigits((v ?? '').trim())
                        .replaceAll(',', '.');
                    if (t.isEmpty) return null;
                    // Text that is not a number is an error, never "no budget".
                    final n = double.tryParse(t);
                    return n != null && RequestRules.budgetOk(n)
                        ? null
                        : l10n.reqErrBudget;
                  },
                ),
                gap,
                Text(l10n.reqFormNeededBy, style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.event_rounded, size: 18),
                      label: Text(
                        _neededBy == null
                            ? l10n.reqFormPickDate
                            : formatDate(_neededBy!, locale),
                      ),
                      onPressed: _pickDate,
                    ),
                    if (_neededBy != null)
                      TextButton(
                        onPressed: () => setState(() => _neededBy = null),
                        child: Text(l10n.reqFormNeededByNone),
                      ),
                  ],
                ),
                gap,
                Text(l10n.reqFormPhotos, style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.reqFormPhotosCount(_photos.length, maxRequestPhotos),
                  style: text.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.sm),
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
                if (_error != null) ...[
                  gap,
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
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: l10n.reqFormSubmit,
                  isLoading: busy,
                  onPressed: _send,
                ),
              ],
            ),
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
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Semantics(
              image: true,
              label: l10n.portfolioPhotoOf(index, 0),
              excludeSemantics: true,
              child: Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                cacheWidth: 264,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFFDDDDDD)),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton.filledTonal(
              tooltip: l10n.reqFormRemovePhoto(index),
              iconSize: 16,
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
