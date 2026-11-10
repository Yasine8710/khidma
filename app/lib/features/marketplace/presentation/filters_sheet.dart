import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/digits.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_domain.dart';

/// The filters and sorting the sheet edits (place is chosen on Home / in its
/// own sheet and applies everywhere).
class SearchFilters {
  const SearchFilters({
    this.categoryId,
    this.minRating,
    this.availableOnly = false,
    this.sort = ProfessionalSort.rating,
  });

  final int? categoryId;
  final double? minRating;
  final bool availableOnly;
  final ProfessionalSort sort;

  /// How many filters differ from the defaults (sorting is not a filter).
  int get activeCount =>
      (categoryId != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (availableOnly ? 1 : 0);
}

const _ratingChoices = <double?>[null, 3, 4, 4.5];

/// Sorting offered today. 'Nearest' needs the device location (map slice).
const _sortChoices = [ProfessionalSort.rating, ProfessionalSort.reviews];

Future<SearchFilters?> showFiltersSheet(
  BuildContext context,
  SearchFilters current,
) => showModalBottomSheet<SearchFilters>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _FiltersSheet(initial: current),
);

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial});

  final SearchFilters initial;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late int? _category = widget.initial.categoryId;
  late double? _minRating = widget.initial.minRating;
  late bool _available = widget.initial.availableOnly;
  late ProfessionalSort _sort = widget.initial.sort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? const <ServiceCategory>[];

    Widget heading(String label) => Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(label, style: text.titleSmall),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.filtersTitle, style: text.titleLarge),
                ),
                heading(l10n.filterCategory),
                if (categoriesAsync.hasError && !categoriesAsync.hasValue)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton(
                      label: l10n.retry,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: () => ref.invalidate(categoriesProvider),
                    ),
                  ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.filterAllCategories),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c.nameFor(locale)),
                        selected: _category == c.id,
                        onSelected: (_) => setState(() => _category = c.id),
                      ),
                  ],
                ),
                heading(l10n.filterMinRating),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final r in _ratingChoices)
                      ChoiceChip(
                        label: Text(
                          r == null
                              ? l10n.filterRatingAny
                              : l10n.filterRatingAtLeast(
                                  toWesternDigits(r.toString()),
                                ),
                        ),
                        selected: _minRating == r,
                        onSelected: (_) => setState(() => _minRating = r),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.filterAvailableOnly),
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                ),
                heading(l10n.sortBy),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in _sortChoices)
                      ChoiceChip(
                        label: Text(switch (s) {
                          ProfessionalSort.reviews => l10n.sortReviews,
                          _ => l10n.sortRating,
                        }),
                        selected: _sort == s,
                        onSelected: (_) => setState(() => _sort = s),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
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
                    label: l10n.filtersReset,
                    variant: AppButtonVariant.secondary,
                    onPressed: () =>
                        Navigator.of(context).pop(const SearchFilters()),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: l10n.filtersApply,
                    onPressed: () => Navigator.of(context).pop(
                      SearchFilters(
                        categoryId: _category,
                        minRating: _minRating,
                        availableOnly: _available,
                        sort: _sort,
                      ),
                    ),
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
