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

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (gid == null) ...[
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: Text(l10n.placeAll),
              onTap: () => _pick(null),
            ),
            for (final g in govs)
              ListTile(
                title: Text(g.nameFor(locale)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() => _governorateId = g.id),
              ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.check_rounded),
              title: Text(l10n.placeWholeGovernorate),
              onTap: () => _pick(Place(governorateId: gid)),
            ),
            for (final c in cities)
              ListTile(
                title: Text(c.nameFor(locale)),
                onTap: () => _pick(Place(governorateId: gid, cityId: c.id)),
              ),
          ],
        ],
      ),
    );
  }
}
