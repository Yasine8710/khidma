import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/world_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../freelance/application/freelance_providers.dart';
import '../../freelance/domain/freelance_domain.dart';
import '../../freelance/presentation/freelance_widgets.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/marketplace_failure_view.dart';
import '../../marketplace/presentation/place_sheet.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../marketplace/presentation/signal_blocks.dart';
import '../../profile/application/profile_providers.dart';

/// Widest the page's text column grows on tablets.
const _maxContentWidth = 760.0;

/// Home as a launcher: the world switch on top (two huge blocks), one giant
/// question, the search block, the loud quote block, then the chunky
/// category tiles and the professionals (or, in the digital world, the
/// freelancers). Switching world swaps the content with a slam.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = _firstName(ref.watch(visibleProfileProvider)?.fullName);
    final isDemo = ref.watch(isDemoDataProvider);
    final world = ref.watch(worldProvider).world;

    Future<void> refresh() async {
      ref.invalidate(categoriesProvider);
      ref.invalidate(topRatedProvider);
      ref.invalidate(inYourAreaProvider);
      ref.invalidate(recentProfessionalsProvider);
      ref.invalidate(digitalCategoriesProvider);
      ref.invalidate(freelancerSearchProvider(_homeFreelancers));
      try {
        await ref.read(topRatedProvider.future);
      } catch (_) {}
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = math.max(
              AppSpacing.gutter,
              (box.maxWidth - _maxContentWidth) / 2,
            );
            return ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                side,
                AppSpacing.sm,
                side,
                AppSpacing.xl,
              ),
              children: [
                const _Masthead(),
                const SizedBox(height: AppSpacing.md),
                _WorldSwitch(current: world),
                if (isDemo) const _DemoStamp(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  name == null
                      ? l10n.homeGreeting
                      : l10n.homeGreetingNamed(name),
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  header: true,
                  child: Text(l10n.homeSubtitle, style: text.displayMedium),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SearchField(),
                const SizedBox(height: AppSpacing.lg),
                const _QuoteBlock(),
                const SizedBox(height: AppSpacing.xxl),
                SlamSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey(world),
                    child: world == AppWorld.trades
                        ? const _TradesWorld()
                        : const _DigitalWorld(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String? _firstName(String? fullName) {
  final words = fullName?.trim().split(RegExp(r'\s+')) ?? const [];
  return words.isEmpty || words.first.isEmpty ? null : words.first;
}

/// The short label of a world, as on a sign.
String _worldLabel(Locale locale, AppWorld w) => switch (locale.languageCode) {
  'ar' => w == AppWorld.trades ? 'حرف' : 'رقمي',
  'en' => w == AppWorld.trades ? 'TRADES' : 'DIGITAL',
  _ => w == AppWorld.trades ? 'MÉTIERS' : 'DIGITAL',
};

/// The wordmark on the start side, the area as a small sticker on the end.
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: const Row(
        children: [
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: KhidmaLogo(markSize: 30),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _PlaceLink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two huge world blocks. Tapping one switches the world; the shell
/// floods the screen with its colour from the tapped centre.
class _WorldSwitch extends ConsumerWidget {
  const _WorldSwitch({required this.current});

  final AppWorld current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in AppWorld.values) ...[
            if (w != AppWorld.values.first) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _WorldBlock(world: w, selected: w == current),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorldBlock extends ConsumerWidget {
  const _WorldBlock({required this.world, required this.selected});

  final AppWorld world;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final b = Theme.of(context).brightness;
    final color = world.accent(b);
    final on = world.onAccent(b);
    final label = _worldLabel(locale, world);
    final icon = world == AppWorld.trades
        ? Icons.handyman_rounded
        : Icons.laptop_mac_rounded;

    return Builder(
      builder: (blockContext) {
        void switchWorld() {
          final box = blockContext.findRenderObject() as RenderBox?;
          final origin = box != null && box.hasSize
              ? box.localToGlobal(box.size.center(Offset.zero))
              : null;
          ref.read(worldProvider.notifier).switchTo(world, origin: origin);
        }

        return Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          onTap: switchWorld,
          child: Pressable(
            onTap: switchWorld,
            button: false,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: selected ? AppInk.offset : 0,
                bottom: selected ? AppInk.offset : 0,
              ),
              child: StickerBox(
                color: color,
                // The chosen world sits sunk into the page.
                offset: selected ? 0 : AppInk.offset,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: on, size: 28),
                        const Spacer(),
                        if (selected)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.onSurface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.sm,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: scheme.surface,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(color: on),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The area picker: the chosen place as a small sticker.
class _PlaceLink extends ConsumerWidget {
  const _PlaceLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final place = ref.watch(selectedPlaceProvider);
    final govs = ref.watch(governoratesProvider).value ?? const <Governorate>[];
    final cities = ref.watch(citiesProvider(null)).value ?? const <City>[];
    final label = placeLabel(l10n, locale, place, govs, cities);
    return Semantics(
      button: true,
      label: '${l10n.placeChoose}: $label',
      excludeSemantics: true,
      onTap: () => showPlaceSheet(context),
      child: Pressable(
        onTap: () => showPlaceSheet(context),
        depth: 2,
        button: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 2, bottom: 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: StickerBox(
              offset: 2,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: scheme.onSurface),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 22,
                    color: scheme.onSurface,
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

/// The demo-data notice, a flat outlined block.
class _DemoStamp extends StatelessWidget {
  const _DemoStamp();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
      child: Semantics(
        container: true,
        child: StickerBox(
          offset: 0,
          color: scheme.surface,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_outlined, size: 18, color: scheme.onSurface),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.demoBannerTitle, style: text.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      l10n.demoBannerBody,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Looks like a field, opens the search screen.
class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    void open() => context.push(AppRoutes.search);
    return Semantics(
      button: true,
      label: l10n.searchHint,
      excludeSemantics: true,
      onTap: open,
      child: Pressable(
        onTap: open,
        button: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppInk.offset,
            bottom: AppInk.offset,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: StickerBox(
              color: scheme.surface,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: scheme.onSurface, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.searchHint,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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

/// The one loud block on Home: ask for quotes. Solid ink with a world-colour
/// arrow block.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;
    void open() => context.push(AppRoutes.newRequest);
    return Semantics(
      container: true,
      button: true,
      onTap: open,
      child: Pressable(
        onTap: open,
        button: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppInk.offset,
            bottom: AppInk.offset,
          ),
          child: StickerBox(
            color: scheme.primary,
            shadowColor: scheme.primaryContainer,
            borderColor: scheme.onSurface,
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeQuoteTitle,
                  style: text.labelLarge?.copyWith(color: on),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.reqEmptyCta,
                        style: text.headlineMedium?.copyWith(color: on),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.homeQuoteBody,
                  style: text.bodyMedium?.copyWith(color: on),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Trades world

class _TradesWorld extends StatelessWidget {
  const _TradesWorld();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Categories(),
        SizedBox(height: AppSpacing.xxl),
        _Professionals(kind: _Kind.topRated),
        SizedBox(height: AppSpacing.xl),
        _Professionals(kind: _Kind.area),
        _RecentSection(),
      ],
    );
  }
}

/// The trades as chunky glyph tiles, two to a row.
class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(categoriesProvider);
    final count = async.value?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegisterHeading(
          title: l10n.sectionCategories,
          figure: count == null || count == 0 ? null : _two(count),
        ),
        const SizedBox(height: AppSpacing.sm),
        async.when(
          loading: () => const _RowsSkeleton(thumb: 44, rows: 3),
          error: (e, _) => MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (list) => _TileGrid(
            tiles: [
              for (var i = 0; i < list.length; i++)
                _GlyphCategoryTile(
                  number: i + 1,
                  name: list[i].nameFor(locale),
                  onTap: () => context.push(
                    AppRoutes.searchPath(categoryId: list[i].id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lays tiles out in rows of two (three when wide), equal height per row.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 600 ? 3 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: i + j < tiles.length
                          ? StaggerIn(index: i + j, child: tiles[i + j])
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
          children: rows,
        );
      },
    );
  }
}

/// A chunky tile: small number, one giant letter, the name. Press-sinks.
class _GlyphCategoryTile extends StatelessWidget {
  const _GlyphCategoryTile({
    required this.number,
    required this.name,
    required this.onTap,
  });

  final int number;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        button: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppInk.offset,
            bottom: AppSpacing.md + AppInk.offset,
          ),
          child: StickerBox(
            color: scheme.surface,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _two(number),
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    border: Border.all(
                      color: scheme.onSurface,
                      width: AppInk.border,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          glyphOf(name),
                          style: text.displayLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  name,
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Kind { topRated, area }

/// A list of professional cards under its heading.
class _Professionals extends ConsumerWidget {
  const _Professionals({required this.kind});

  final _Kind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(selectedPlaceProvider);
    final provider = kind == _Kind.topRated
        ? topRatedProvider
        : inYourAreaProvider;
    final title = kind == _Kind.topRated
        ? l10n.sectionTopRated
        : l10n.sectionInYourArea;

    final Widget body;
    int? count;
    if (kind == _Kind.area && place == null) {
      body = _Note(l10n.sectionInYourAreaPrompt);
    } else {
      final async = ref.watch(provider);
      count = async.value?.length;
      body = async.when(
        loading: () => const _RowsSkeleton(thumb: 64, rows: 2),
        error: (e, _) => MarketplaceFailureView(
          error: e,
          onRetry: () => ref.invalidate(provider),
        ),
        data: (list) => list.isEmpty
            ? _Note(
                kind == _Kind.topRated
                    ? l10n.noProfessionalsBody
                    : l10n.noProfessionalsInArea,
              )
            : ProfessionalRegister(list: list),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegisterHeading(
          title: title,
          figure: count == null || count == 0 ? null : _two(count),
        ),
        const SizedBox(height: AppSpacing.xs),
        body,
      ],
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(recentProfessionalsProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegisterHeading(title: l10n.sectionRecent, figure: _two(list.length)),
          const SizedBox(height: AppSpacing.xs),
          ProfessionalRegister(list: list),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Digital world

const _homeFreelancers = FreelanceQuery(limit: 6);

class _DigitalWorld extends ConsumerWidget {
  const _DigitalWorld();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cats = ref.watch(digitalCategoriesProvider);
    final list = ref.watch(freelancerSearchProvider(_homeFreelancers));
    final catList = cats.value ?? const <DigitalCategory>[];
    void open() => context.push(AppRoutes.digital);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          container: true,
          onTap: open,
          child: Pressable(
            onTap: open,
            button: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppInk.offset,
                bottom: AppInk.offset,
              ),
              child: StickerBox(
                color: scheme.surface,
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.flTitle, style: text.headlineMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.flHomeSubtitle,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        border: Border.all(
                          color: scheme.onSurface,
                          width: AppInk.border,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (catList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          RegisterHeading(
            title: l10n.flCategories,
            figure: _two(catList.length),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TileGrid(
            tiles: [
              for (var i = 0; i < catList.length; i++)
                _GlyphCategoryTile(
                  number: i + 1,
                  name: catList[i].nameFor(locale),
                  onTap: open,
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        RegisterHeading(
          title: l10n.flResultsTitle,
          figure: list.value == null || list.value!.isEmpty
              ? null
              : _two(list.value!.length),
        ),
        const SizedBox(height: AppSpacing.xs),
        list.when(
          loading: () => const _RowsSkeleton(thumb: 64, rows: 2),
          error: (e, _) => _Note(l10n.flLoadFailed),
          data: (items) => items.isEmpty
              ? _Note(l10n.flEmptyBody)
              : FreelancerRegister(list: items, categories: catList),
        ),
      ],
    );
  }
}

/// A plain muted line in place of an empty list.
class _Note extends StatelessWidget {
  const _Note(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Placeholder rows while a list loads.
class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton({required this.thumb, required this.rows});

  final double thumb;
  final int rows;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Skeleton(width: thumb, height: thumb),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
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
