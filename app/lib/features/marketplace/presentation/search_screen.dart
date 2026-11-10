import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/home_providers.dart';
import '../application/marketplace_providers.dart';
import '../application/search_providers.dart';
import '../domain/marketplace_domain.dart';
import 'filters_sheet.dart';
import 'marketplace_failure_view.dart';
import 'place_sheet.dart';
import 'professional_card.dart';

/// The server refuses offsets beyond this, so paging stops here.
const _maxOffset = 5000;

/// Search: text, category, minimum rating, availability, place, sorting and
/// paging. Pages load one at a time; each can fail and retry on its own.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.categoryId, this.initialText = ''});

  final int? categoryId;
  final String initialText;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  Timer? _debounce;
  late String _text = widget.initialText;
  late SearchFilters _filters = SearchFilters(categoryId: widget.categoryId);
  int _pages = 1;

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.categoryId != widget.categoryId) {
      _filters = SearchFilters(
        categoryId: widget.categoryId,
        minRating: _filters.minRating,
        availableOnly: _filters.availableOnly,
        sort: _filters.sort,
      );
      _pages = 1;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _text = value;
          _pages = 1;
        });
      }
    });
  }

  Future<void> _openFilters() async {
    final result = await showFiltersSheet(context, _filters);
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        _pages = 1;
      });
    }
  }

  SearchQuery _query(Place? place, int page) => SearchQuery(
    text: _text.trim().isEmpty ? null : _text,
    categoryId: _filters.categoryId,
    governorateId: place?.governorateId,
    cityId: place?.cityId,
    minRating: _filters.minRating,
    availableOnly: _filters.availableOnly,
    sort: _filters.sort,
    limit: searchPageSize,
    offset: page * searchPageSize,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(selectedPlaceProvider);
    final govs = ref.watch(governoratesProvider).value ?? const <Governorate>[];
    final cities = ref.watch(citiesProvider(null)).value ?? const <City>[];
    final locale = Localizations.localeOf(context);

    // Nothing asked yet: no text, no category and no other filter.
    final browsing =
        _text.trim().isEmpty && _filters.activeCount == 0 && place == null;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.categoryId == null && widget.initialText.isEmpty,
          textInputAction: TextInputAction.search,
          maxLength: 100,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _changed,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.place_rounded, size: 18),
                    label: Text(placeLabel(l10n, locale, place, govs, cities)),
                    onPressed: () async {
                      await showPlaceSheet(context);
                      if (mounted) setState(() => _pages = 1);
                    },
                  ),
                  Semantics(
                    label: l10n.filtersActive(_filters.activeCount),
                    excludeSemantics: true,
                    button: true,
                    onTap: _openFilters,
                    child: ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        _filters.activeCount == 0
                            ? l10n.filtersAction
                            : '${l10n.filtersAction} (${_filters.activeCount})',
                      ),
                      onPressed: _openFilters,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: browsing
                  ? EmptyState(
                      icon: Icons.search_rounded,
                      title: l10n.searchStartTitle,
                      body: l10n.searchStartBody,
                    )
                  : _Results(
                      queryFor: (page) => _query(place, page),
                      pages: _pages,
                      onMore: () => setState(() => _pages++),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.queryFor,
    required this.pages,
    required this.onMore,
  });

  final SearchQuery Function(int page) queryFor;
  final int pages;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = <Widget>[];
    var more = false;

    for (var page = 0; page < pages; page++) {
      final query = queryFor(page);
      final async = ref.watch(searchPageProvider(query));
      if (async.hasError && !async.hasValue) {
        if (page == 0) {
          return MarketplaceFailureView(
            error: async.error!,
            onRetry: () => ref.invalidate(searchPageProvider(query)),
          );
        }
        items.add(
          _PageNotice(
            child: AppButton(
              label: l10n.retry,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.invalidate(searchPageProvider(query)),
            ),
          ),
        );
        break;
      }
      if (!async.hasValue) {
        if (page == 0) return const _ResultsSkeleton();
        items.add(const _PageNotice(child: Skeleton(height: 112)));
        break;
      }
      final list = async.requireValue;
      if (page == 0 && list.isEmpty) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.searchNoResultsTitle,
          body: l10n.searchNoResultsBody,
        );
      }
      for (final p in list) {
        items.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
            child: ProfessionalCard(
              professional: p,
              onTap: () => context.push(AppRoutes.professionalPath(p.id)),
            ),
          ),
        );
      }
      more =
          page == pages - 1 &&
          list.length == searchPageSize &&
          (page + 1) * searchPageSize <= _maxOffset;
    }
    if (more) {
      items.add(
        _PageNotice(
          child: AppButton(
            label: l10n.loadMore,
            variant: AppButtonVariant.secondary,
            onPressed: onMore,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _PageNotice extends StatelessWidget {
  const _PageNotice({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
    child: child,
  );
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
      children: [
        for (var i = 0; i < 4; i++) ...[
          const Skeleton(height: 112, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}
