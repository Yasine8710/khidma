import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/home_providers.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_domain.dart';
import 'marketplace_failure_view.dart';

/// The area label shown on Home: city, governorate or "all of Tunisia".
String placeLabel(
  AppLocalizations l10n,
  Locale locale,
  Place? place,
  List<Governorate> governorates,
  List<City> cities,
) {
  if (place == null) return l10n.placeAll;
  final city = cities.where((c) => c.id == place.cityId).firstOrNull;
  if (city != null) return city.nameFor(locale);
  final gov = governorates
      .where((g) => g.id == place.governorateId)
      .firstOrNull;
  return gov?.nameFor(locale) ?? l10n.placeAll;
}

Future<void> showPlaceSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => const _PlaceSheet(),
);

class _PlaceSheet extends ConsumerStatefulWidget {
  const _PlaceSheet();

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  int? _governorateId;

  Future<void> _pick(Place? place) async {
    await ref.read(selectedPlaceProvider.notifier).select(place);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final gid = _governorateId;
    final govsAsync = ref.watch(governoratesProvider);
    final citiesAsync = gid == null ? null : ref.watch(citiesProvider(gid));
    final active = citiesAsync ?? govsAsync;
    if (active.hasError && !active.hasValue) {
      return MarketplaceFailureView(
        error: active.error!,
        onRetry: () => ref.invalidate(
          gid == null ? governoratesProvider : citiesProvider(gid),
        ),
      );
    }
    if (!active.hasValue) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final govs = govsAsync.value ?? const <Governorate>[];
    final cities = citiesAsync?.value ?? const <City>[];
    final current = ref.watch(selectedPlaceProvider);
    final text = Theme.of(context).textTheme;
    final gov = govs.where((g) => g.id == gid).firstOrNull;

    final header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (gid != null) ...[
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _governorateId = null),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                gid == null ? l10n.placeChoose : (gov?.nameFor(locale) ?? ''),
                style: text.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (gid == null) ...[
                  _PlaceRow(
                    label: l10n.placeAll,
                    leading: Icons.public_rounded,
                    chosen: current == null,
                    onTap: () => _pick(null),
                  ),
                  for (final g in govs)
                    _PlaceRow(
                      label: g.nameFor(locale),
                      chosen: current?.governorateId == g.id,
                      more: true,
                      onTap: () => setState(() => _governorateId = g.id),
                    ),
                ] else ...[
                  _PlaceRow(
                    label: l10n.placeWholeGovernorate,
                    leading: Icons.select_all_rounded,
                    chosen:
                        current?.governorateId == gid &&
                        current?.cityId == null,
                    onTap: () => _pick(Place(governorateId: gid)),
                  ),
                  for (final c in cities)
                    _PlaceRow(
                      label: c.nameFor(locale),
                      chosen: current?.cityId == c.id,
                      onTap: () =>
                          _pick(Place(governorateId: gid, cityId: c.id)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One place in the sheet: a ruled row; the current choice is set in bold
/// with a check, a governorate leads on with a chevron.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.label,
    required this.onTap,
    this.leading,
    this.chosen = false,
    this.more = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? leading;
  final bool chosen;
  final bool more;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: chosen,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    Icon(leading, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: chosen ? text.titleMedium : text.bodyLarge,
                    ),
                  ),
                  if (chosen)
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: scheme.onSurface,
                    ),
                  if (more)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
