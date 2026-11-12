import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../location/application/location_providers.dart';
import '../../location/domain/location_domain.dart';
import '../application/home_providers.dart';
import 'map_provider.dart';
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
  bool _map = false;

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.categoryId != widget.categoryId) {
      _filters = SearchFilters(
        categoryId: widget.categoryId,
        minRating: _filters.minRating,
        availableOnly: _filters.availableOnly,
        sort: _filters.sort,
        radiusKm: _filters.radiusKm,
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

  Future<void> _toggleNearMe(bool on) async {
    final position = ref.read(devicePositionProvider.notifier);
    if (!on) {
      position.clear();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final failure = await position.locate();
    if (failure == null || !mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          LocationFailure.denied => l10n.locationDenied,
          LocationFailure.deniedForever => l10n.locationDeniedForever,
          LocationFailure.serviceOff => l10n.locationServiceOff,
          LocationFailure.unavailable => l10n.locationUnavailable,
        }),
        action: failure == LocationFailure.deniedForever
            ? SnackBarAction(
                label: l10n.openSettings,
                onPressed: ref.read(locationServiceProvider).openSettings,
              )
            : null,
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showFiltersSheet(
      context,
      _filters,
      hasPosition: ref.read(devicePositionProvider) != null,
    );
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        _pages = 1;
      });
    }
  }

  SearchQuery _query(Place? place, LocationFix? where, int page) => SearchQuery(
    text: _text.trim().isEmpty ? null : _text,
    categoryId: _filters.categoryId,
    governorateId: place?.governorateId,
    cityId: place?.cityId,
    minRating: _filters.minRating,
    availableOnly: _filters.availableOnly,
    // Nearest and radius mean nothing without a position.
    sort: where == null && _filters.sort == ProfessionalSort.nearest
        ? ProfessionalSort.rating
        : _filters.sort,
    latitude: where?.latitude,
    longitude: where?.longitude,
    radiusKm: where == null ? null : _filters.radiusKm,
    limit: searchPageSize,
    offset: page * searchPageSize,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(selectedPlaceProvider);
    final where = ref.watch(devicePositionProvider);
    final mapAvailable = ref.watch(mapProviderProvider).isAvailable;
    ref.listen(devicePositionProvider, (_, now) {
      // Without a position, nearest/radius no longer apply.
      if (now == null &&
          (_filters.sort == ProfessionalSort.nearest ||
              _filters.radiusKm != null)) {
        setState(() {
          _filters = SearchFilters(
            categoryId: _filters.categoryId,
            minRating: _filters.minRating,
            availableOnly: _filters.availableOnly,
            // Only 'nearest' needs a position; other sorting stays.
            sort: _filters.sort == ProfessionalSort.nearest
                ? ProfessionalSort.rating
                : _filters.sort,
          );
          _pages = 1;
        });
      } else {
        setState(() => _pages = 1);
      }
    });
    final govs = ref.watch(governoratesProvider).value ?? const <Governorate>[];
    final cities = ref.watch(citiesProvider(null)).value ?? const <City>[];
    final locale = Localizations.localeOf(context);

    // Nothing asked yet: no text, no category and no other filter.
    final browsing =
        _text.trim().isEmpty &&
        _filters.activeCount == 0 &&
        place == null &&
        where == null;

    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder outline(double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: scheme.onSurface, width: width),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (mapAvailable)
            IconButton(
              tooltip: _map ? l10n.showList : l10n.showMap,
              icon: Icon(_map ? Icons.list_rounded : Icons.map_outlined),
              onPressed: () => setState(() => _map = !_map),
            ),
        ],
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
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurface),
            border: outline(1.2),
            enabledBorder: outline(1.2),
            focusedBorder: outline(2),
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
              // One scrolling row, aligned to the gutter (a Wrap inside a
              // Column shrank to its content and floated to the middle).
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Semantics(
                        label: l10n.filtersActive(_filters.activeCount),
                        excludeSemantics: true,
                        button: true,
                        onTap: _openFilters,
                        child: AppChip(
                          icon: Icons.tune_rounded,
                          label: _filters.activeCount == 0
                              ? l10n.filtersAction
                              : '${l10n.filtersAction} (${_filters.activeCount})',
                          selected: _filters.activeCount > 0,
                          onSelected: (_) => _openFilters(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        icon: Icons.place_outlined,
                        label: placeLabel(l10n, locale, place, govs, cities),
                        selected: place != null,
                        onSelected: (_) async {
                          await showPlaceSheet(context);
                          if (mounted) setState(() => _pages = 1);
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        icon: Icons.my_location_rounded,
                        label: l10n.nearMe,
                        selected: where != null,
                        onSelected: _toggleNearMe,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(color: scheme.outlineVariant),
            Expanded(
              child: browsing
                  ? EmptyState(
                      icon: Icons.search_rounded,
                      title: l10n.searchStartTitle,
                      body: l10n.searchStartBody,
                    )
                  : _map && mapAvailable
                  ? _MapResults(
                      queryFor: (page) => _query(place, where, page),
                      pages: _pages,
                      where: where,
                      onMore: () => setState(() => _pages++),
                    )
                  : _Results(
                      queryFor: (page) => _query(place, where, page),
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
        items.add(const _PageNotice(child: Skeleton(height: 92)));
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
          ProfessionalCard(
            professional: p,
            onTap: () => context.push(AppRoutes.professionalPath(p.id)),
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
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
    padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
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
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Skeleton(width: 64, height: 64),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 160, height: 14),
                      SizedBox(height: AppSpacing.sm),
                      Skeleton(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The loaded pages as markers on the map provider's map.
class _MapResults extends ConsumerWidget {
  const _MapResults({
    required this.queryFor,
    required this.pages,
    required this.where,
    required this.onMore,
  });

  final SearchQuery Function(int page) queryFor;
  final int pages;
  final LocationFix? where;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final markers = <MapMarker>[];
    Widget? footer;
    for (var page = 0; page < pages; page++) {
      final async = ref.watch(searchPageProvider(queryFor(page)));
      if (page == 0 && async.hasError && !async.hasValue) {
        return MarketplaceFailureView(
          error: async.error!,
          onRetry: () => ref.invalidate(searchPageProvider(queryFor(0))),
        );
      }
      if (page == 0 && !async.hasValue) return const _ResultsSkeleton();
      if (page > 0 && async.hasError && !async.hasValue) {
        footer = AppButton(
          label: l10n.retry,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.invalidate(searchPageProvider(queryFor(page))),
        );
        break;
      }
      if (page > 0 && !async.hasValue) {
        footer = const Skeleton(height: 48);
        break;
      }
      final list = async.requireValue;
      if (page == pages - 1 &&
          list.length == searchPageSize &&
          (page + 1) * searchPageSize <= _maxOffset) {
        footer = AppButton(
          label: l10n.loadMore,
          variant: AppButtonVariant.secondary,
          onPressed: onMore,
        );
      }
      for (final p in list) {
        // Only professionals with a position can be pinned.
        if (p.latitude != null && p.longitude != null) {
          markers.add(
            MapMarker(
              id: p.id,
              title: p.name,
              latitude: p.latitude!,
              longitude: p.longitude!,
            ),
          );
        }
      }
    }
    final Widget map = markers.isEmpty
        ? EmptyState(
            icon: Icons.map_outlined,
            title: l10n.mapNothingTitle,
            body: l10n.mapNothingBody,
          )
        : ref
              .watch(mapProviderProvider)
              .build(
                context,
                MapRequest(
                  markers: markers,
                  center: where,
                  onSelect: (id) =>
                      context.push(AppRoutes.professionalPath(id)),
                ),
              );
    // More pages can be asked for even when the loaded ones had nothing to
    // pin.
    return Column(
      children: [
        Expanded(child: map),
        if (footer != null)
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: footer,
          ),
      ],
    );
  }
}
