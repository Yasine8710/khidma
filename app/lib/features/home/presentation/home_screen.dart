import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/world_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../freelance/application/freelance_providers.dart';
import '../../freelance/domain/freelance_domain.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/calm_blocks.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../../marketplace/presentation/marketplace_failure_view.dart';
import '../../marketplace/presentation/place_sheet.dart';
import '../../profile/application/profile_providers.dart';

/// Widest the page's content grows on tablets.
const _maxContentWidth = 760.0;

/// Width of one card in a horizontal rail.
const _railCard = 236.0;

/// Home, like the service apps people know: where you are and the bell, the
/// Artisans | Freelance digital toggle, a search field with the filter
/// button, a carousel of short promos, the categories as tinted tiles and
/// the people as horizontal cards. Switching world swaps the content with a
/// soft cross-fade.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Widget pad(Widget child) => Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: side),
              child: child,
            );
            return ListView(
              padding: const EdgeInsetsDirectional.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xl,
              ),
              children: [
                pad(const _TopBar()),
                if (isDemo) pad(const _DemoNote()),
                const SizedBox(height: AppSpacing.lg),
                pad(_WorldToggle(current: world)),
                const SizedBox(height: AppSpacing.md),
                pad(_SearchRow(world: world)),
                const SizedBox(height: AppSpacing.lg),
                SoftSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey(world),
                    child: world == AppWorld.trades
                        ? _TradesWorld(side: side)
                        : _DigitalWorld(side: side),
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

/// The text size factor (1 at the default size).
double _scale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;

// ---------------------------------------------------------------------------
// Top of the page

/// The greeting over the chosen place (with a pin and a caret) on the start
/// side, the bell on the end.
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final name = _firstName(ref.watch(visibleProfileProvider)?.fullName);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? l10n.homeGreeting : l10n.homeGreetingNamed(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const _PlaceLink(),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: IconButton(
            tooltip: l10n.notifTitle,
            icon: Icon(
              Icons.notifications_none_rounded,
              color: scheme.onSurface,
            ),
            onPressed: () => context.push(AppRoutes.notificationSettings),
          ),
        ),
      ],
    );
  }
}

/// The area picker: pin, the chosen place in bold, a caret.
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
        button: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
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
    );
  }
}

/// The demo-data notice, a soft card.
class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: Semantics(
        container: true,
        child: StickerBox(
          color: scheme.surfaceContainerHighest,
          border: 0,
          radius: AppRadius.md,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.science_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
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

/// Artisans | Freelance digital: a segmented control whose violet thumb
/// slides to the chosen side. Each half is a button announced as selected.
class _WorldToggle extends ConsumerWidget {
  const _WorldToggle({required this.current});

  final AppWorld current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = Motion.reduced(context);
    String label(AppWorld w) =>
        w == AppWorld.trades ? l10n.worldTrades : l10n.worldDigital;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: current == AppWorld.trades
                    ? AlignmentDirectional.centerStart
                    : AlignmentDirectional.centerEnd,
                duration: reduce ? Duration.zero : Motion.base,
                curve: Motion.settle,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final w in AppWorld.values)
                  Expanded(
                    child: Builder(
                      builder: (segment) {
                        final selected = w == current;
                        void choose() {
                          final box = segment.findRenderObject() as RenderBox?;
                          final origin = box != null && box.hasSize
                              ? box.localToGlobal(box.size.center(Offset.zero))
                              : null;
                          ref
                              .read(worldProvider.notifier)
                              .switchTo(w, origin: origin);
                        }

                        return Semantics(
                          button: true,
                          selected: selected,
                          label: label(w),
                          excludeSemantics: true,
                          onTap: choose,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: choose,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.sm + 2,
                                ),
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: reduce
                                        ? Duration.zero
                                        : Motion.fast,
                                    style: text.titleSmall!.copyWith(
                                      color: selected
                                          ? scheme.onPrimary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    child: Text(
                                      label(w),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A field-like button that opens search, and the violet filter button.
class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.world});

  final AppWorld world;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final trades = world == AppWorld.trades;
    final hint = trades ? l10n.homeSubtitle : l10n.flSearchHint;
    void open() => context.push(trades ? AppRoutes.search : AppRoutes.digital);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: hint,
            excludeSemantics: true,
            onTap: open,
            child: Pressable(
              onTap: open,
              button: false,
              scale: 0.99,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: StickerBox(
                  radius: AppRadius.md,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        IconButton.filled(
          tooltip: l10n.filtersAction,
          onPressed: open,
          style: IconButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            fixedSize: const Size(52, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero carousel

class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.cta,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String body;
  final String cta;
  final IconData icon;
  final VoidCallback onTap;
}

/// Short promos on violet cards, one action each, with page dots. Advances
/// by itself every 5 s, pauses while touched, and stays put with Reduce
/// Motion (it can still be swiped).
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.slides, required this.side});

  final List<_Slide> slides;
  final double side;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _pages = PageController();
  Timer? _timer;
  int _index = 0;
  bool _held = false;
  bool _ticking = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not while the page is hidden (another tab or a pushed screen).
    _ticking = TickerMode.valuesOf(context).enabled;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!mounted || Motion.reduced(context) || widget.slides.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _advance());
  }

  void _advance() {
    if (!mounted || _held || !_ticking || !_pages.hasClients) return;
    final next = (_index + 1) % widget.slides.length;
    _pages.animateToPage(next, duration: Motion.slow, curve: Motion.enter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = Motion.reduced(context);
    final s = _scale(context);
    final height = 212 + 120 * (s - 1).clamp(0.0, 1.5);
    return Column(
      children: [
        Listener(
          onPointerDown: (_) => _held = true,
          onPointerUp: (_) {
            _held = false;
            _schedule();
          },
          onPointerCancel: (_) {
            _held = false;
            _schedule();
          },
          child: SizedBox(
            height: height,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: widget.side,
                ),
                child: _HeroCard(slide: widget.slides[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.slides.length; i++)
                AnimatedContainer(
                  duration: reduce ? Duration.zero : Motion.base,
                  curve: Motion.enter,
                  margin: const EdgeInsetsDirectional.symmetric(horizontal: 3),
                  width: i == _index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = scheme.onPrimary;
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: ColoredBox(
          color: scheme.primary,
          child: LayoutBuilder(
            builder: (context, box) {
              // The icon tile only when there is room beside the text.
              final art = box.maxWidth >= 340 && _scale(context) <= 1.3;
              return Stack(
                children: [
                  PositionedDirectional(
                    end: -box.maxHeight * 0.35,
                    top: -box.maxHeight * 0.1,
                    child: ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: box.maxHeight * 1.2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: on.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (art)
                    PositionedDirectional(
                      end: AppSpacing.xl,
                      top: AppSpacing.xl,
                      child: ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 76,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: on.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Icon(slide.icon, color: on, size: 36),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      art ? 120 : AppSpacing.gutter,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(color: on),
                        ),
                        const SizedBox(height: AppSpacing.xs + 2),
                        // Whole lines only: an ellipsis, never a half-cut line.
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final style = text.bodyMedium?.copyWith(
                                color: on.withValues(alpha: 0.9),
                              );
                              final line = MediaQuery.textScalerOf(context)
                                  .scale(
                                    (style?.fontSize ?? 14) *
                                        (style?.height ?? 1.45),
                                  );
                              final lines = (c.maxHeight / line).floor().clamp(
                                1,
                                3,
                              );
                              return Text(
                                slide.body,
                                maxLines: lines,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              );
                            },
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: slide.onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: on,
                            foregroundColor: scheme.primary,
                            minimumSize: const Size(48, 40),
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: Text(
                            slide.cta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces of both worlds

/// Category tiles four to a row (three at large text, six when wide): a
/// tinted square with a line icon, the name below.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final big = _scale(context) > 1.35;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 600 ? 6 : (big ? 3 : 4);
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          if (i > 0) rows.add(const SizedBox(height: AppSpacing.lg));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final int tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        button: false,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: TintTile(
                icon: icon,
                tint: tint,
                radius: AppRadius.lg,
                iconSize: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _TileLabel(
              name,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal rail of cards that runs to the screen edges.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.side,
    required this.height,
    required this.count,
    required this.builder,
  });

  final double side;
  final double height;
  final int count;
  final Widget Function(BuildContext, int) builder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsetsDirectional.symmetric(horizontal: side),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
      itemBuilder: (context, i) => builder(context, i),
    ),
  );
}

/// Cards loading in a rail.
class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton({required this.side, required this.height});

  final double side;
  final double height;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.symmetric(horizontal: side),
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Skeleton(width: _railCard, height: height, radius: AppRadius.lg),
          ],
        ],
      ),
    ),
  );
}

/// Height of the image area on top of a rail card.
const _cardArt = 118.0;

/// A rail card: the tinted image area (line icon, optional [corner] control)
/// on top, then [body]. One button for the whole card.
class _RailCard extends StatelessWidget {
  const _RailCard({
    required this.label,
    required this.onTap,
    required this.art,
    required this.tint,
    required this.body,
    this.corner,
  });

  final String label;
  final VoidCallback onTap;
  final IconData art;
  final int tint;
  final Widget body;
  final Widget? corner;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Pressable(
          onTap: onTap,
          button: false,
          child: SizedBox(
            width: _railCard,
            child: StickerBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: _cardArt,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TintTile(
                            icon: art,
                            tint: tint,
                            radius: 0,
                            iconSize: 40,
                            iconColor: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        if (corner != null)
                          PositionedDirectional(
                            top: AppSpacing.sm,
                            end: AppSpacing.sm,
                            child: RoundControl(child: corner!),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: body,
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

/// Avatar, name with the verified tick and one muted line beside it.
class _CardPerson extends StatelessWidget {
  const _CardPerson({
    required this.name,
    required this.imageUrl,
    required this.verified,
    required this.line,
  });

  final String name;
  final String? imageUrl;
  final bool verified;
  final String line;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        InitialsAvatar(name: name, imageUrl: imageUrl, size: 38),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NameLine(name: name, verified: verified, style: text.titleSmall),
              if (line.isNotEmpty)
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trades world

class _TradesWorld extends ConsumerWidget {
  const _TradesWorld({required this.side});

  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget pad(Widget child) => Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: side),
      child: child,
    );
    final slides = [
      _Slide(
        title: l10n.homeQuoteTitle,
        body: l10n.homeQuoteBody,
        cta: l10n.reqEmptyCta,
        icon: Icons.water_drop_outlined,
        onTap: () => context.push(AppRoutes.newRequest),
      ),
      _Slide(
        title: l10n.becomeProfessionalTitle,
        body: l10n.becomeProfessionalBody,
        cta: l10n.becomeProfessionalCta,
        icon: Icons.handyman_outlined,
        onTap: () => context.go(AppRoutes.profile),
      ),
      _Slide(
        title: l10n.flTitle,
        body: l10n.flHomeSubtitle,
        cta: l10n.homeHeroDigitalCta,
        icon: Icons.laptop_mac_outlined,
        onTap: () =>
            ref.read(worldProvider.notifier).switchTo(AppWorld.digital),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCarousel(slides: slides, side: side),
        const SizedBox(height: AppSpacing.xl),
        pad(const _Categories()),
        const SizedBox(height: AppSpacing.xl),
        _Professionals(kind: _Kind.area, side: side),
        const SizedBox(height: AppSpacing.xl),
        _Professionals(kind: _Kind.topRated, side: side),
        _RecentSection(side: side),
      ],
    );
  }
}

/// How many category tiles Home shows; "Tout voir" leads to all of them.
const _homeCategories = 8;

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(categoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: l10n.sectionCategories,
          actionLabel: l10n.seeAll,
          onAction: () => context.go(AppRoutes.explore),
        ),
        async.when(
          loading: () => const SkeletonGroup(
            child: Skeleton(height: 96, radius: AppRadius.lg),
          ),
          error: (e, _) => MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (list) => _TileGrid(
            tiles: [
              for (var i = 0; i < list.length && i < _homeCategories; i++)
                _CategoryTile(
                  name: list[i].nameFor(locale),
                  icon: categoryIcon(list[i].icon),
                  tint: i,
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

enum _Kind { topRated, area }

/// Height of a professional rail card at the current text size.
double _proCardHeight(BuildContext context) {
  final s = _scale(context);
  return _cardArt + 2 + 34 + math.max(38, 35.7 * s) + 20 * s + 16;
}

/// A heading and its professionals as a horizontal rail.
class _Professionals extends ConsumerWidget {
  const _Professionals({required this.kind, required this.side});

  final _Kind kind;
  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(selectedPlaceProvider);
    final provider = kind == _Kind.topRated
        ? topRatedProvider
        : inYourAreaProvider;
    final title = kind == _Kind.topRated
        ? l10n.sectionTopRated
        : l10n.homeNearbyTitle;
    final height = _proCardHeight(context);
    Widget pad(Widget child) => Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: side),
      child: child,
    );

    final Widget body;
    var any = false;
    if (kind == _Kind.area && place == null) {
      body = pad(QuietNote(l10n.sectionInYourAreaPrompt));
    } else {
      final async = ref.watch(provider);
      any = async.value?.isNotEmpty ?? false;
      body = async.when(
        loading: () => _RailSkeleton(side: side, height: height),
        error: (e, _) => pad(
          MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(provider),
          ),
        ),
        data: (list) => list.isEmpty
            ? pad(
                QuietNote(
                  kind == _Kind.topRated
                      ? l10n.noProfessionalsBody
                      : l10n.noProfessionalsInArea,
                ),
              )
            : _ProRail(list: list, side: side, height: height),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pad(
          SectionTitle(
            title: title,
            actionLabel: any ? l10n.seeAll : null,
            onAction: any ? () => context.push(AppRoutes.search) : null,
          ),
        ),
        body,
      ],
    );
  }
}

class _ProRail extends StatelessWidget {
  const _ProRail({
    required this.list,
    required this.side,
    required this.height,
  });

  final List<ProfessionalSummary> list;
  final double side;
  final double height;

  @override
  Widget build(BuildContext context) => _Rail(
    side: side,
    height: height,
    count: list.length,
    builder: (context, i) => _ProCard(professional: list[i]),
  );
}

/// A professional in a rail: tinted image area with the trade's line icon
/// and the heart, then avatar, name with the verified tick, trade and years,
/// and the rating (with the distance when known).
class _ProCard extends ConsumerWidget {
  const _ProCard({required this.professional});

  final ProfessionalSummary professional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final p = professional;
    final cats = ref.watch(categoriesProvider).value ?? const [];
    final i = cats.indexWhere((c) => c.id == p.categoryId);
    final cat = i < 0 ? null : cats[i];
    final years = p.yearsExperience;
    final line = [
      ?cat?.nameFor(locale),
      if (years != null && years > 0) l10n.yearsShort(years),
    ].join(' · ');
    final km = p.distanceKm;
    return _RailCard(
      label: p.name,
      onTap: () => context.push(AppRoutes.professionalPath(p.id)),
      art: categoryIcon(cat?.icon ?? ''),
      tint: i < 0 ? seedOf(p.id) : i,
      corner: FavoriteButton(professionalId: p.id, professionalName: p.name),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardPerson(
            name: p.name,
            imageUrl: p.avatarUrl,
            verified: p.isVerified,
            line: line,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RatingInline(
                    rating: p.rating,
                    reviewCount: p.reviewCount,
                    size: 14,
                  ),
                ),
              ),
              if (km != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.distanceKm(km.toStringAsFixed(1)),
                  maxLines: 1,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.side});

  final double side;

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
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: side),
            child: SectionTitle(title: l10n.sectionRecent),
          ),
          _ProRail(list: list, side: side, height: _proCardHeight(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Digital world

const _homeFreelancers = FreelanceQuery(limit: 6);

class _DigitalWorld extends ConsumerWidget {
  const _DigitalWorld({required this.side});

  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final cats = ref.watch(digitalCategoriesProvider);
    final list = ref.watch(freelancerSearchProvider(_homeFreelancers));
    final catList = cats.value ?? const <DigitalCategory>[];
    void open() => context.push(AppRoutes.digital);
    Widget pad(Widget child) => Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: side),
      child: child,
    );
    final height = _freelancerCardHeight(context);
    final slides = [
      _Slide(
        title: l10n.flTitle,
        body: l10n.flHomeSubtitle,
        cta: l10n.homeHeroDigitalCta,
        icon: Icons.laptop_mac_outlined,
        onTap: open,
      ),
      _Slide(
        title: l10n.flIntroTitle,
        body: l10n.homeHeroFreelanceBody,
        cta: l10n.flBecome,
        icon: Icons.brush_outlined,
        onTap: () => context.push(AppRoutes.proFreelance),
      ),
      _Slide(
        title: l10n.homeQuoteTitle,
        body: l10n.homeQuoteBody,
        cta: l10n.reqEmptyCta,
        icon: Icons.handyman_outlined,
        onTap: () => context.push(AppRoutes.newRequest),
      ),
    ];
    final any = list.value?.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCarousel(slides: slides, side: side),
        if (catList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          pad(
            SectionTitle(
              title: l10n.flCategories,
              actionLabel: l10n.seeAll,
              onAction: open,
            ),
          ),
          pad(
            _TileGrid(
              tiles: [
                for (var i = 0; i < catList.length && i < _homeCategories; i++)
                  _CategoryTile(
                    name: catList[i].nameFor(locale),
                    icon: digitalCategoryIcon(catList[i].icon),
                    tint: i,
                    onTap: open,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        pad(
          SectionTitle(
            title: l10n.flResultsTitle,
            actionLabel: any ? l10n.seeAll : null,
            onAction: any ? open : null,
          ),
        ),
        list.when(
          loading: () => _RailSkeleton(side: side, height: height),
          error: (e, _) => pad(QuietNote(l10n.flLoadFailed)),
          data: (items) => items.isEmpty
              ? pad(QuietNote(l10n.flEmptyBody))
              : _Rail(
                  side: side,
                  height: height,
                  count: items.length,
                  builder: (context, i) => _FreelancerCard(
                    freelancer: items[i],
                    categories: catList,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Height of a freelancer rail card at the current text size.
double _freelancerCardHeight(BuildContext context) {
  final s = _scale(context);
  // Padding, person row, skills, identity line, rating/price row, slack.
  return _cardArt +
      2 +
      24 +
      math.max(38, 35.7 * s) +
      8 +
      17.5 * s +
      6 +
      17.5 * s +
      6 +
      18.2 * s +
      18;
}

/// A freelancer in a rail: tinted image area with the category's line icon,
/// avatar, name with the verified tick, headline, skills, "Identité vérifiée"
/// when verified, the rating and "dès N DT".
class _FreelancerCard extends StatelessWidget {
  const _FreelancerCard({required this.freelancer, required this.categories});

  final FreelancerSummary freelancer;
  final List<DigitalCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final f = freelancer;
    final i = categories.indexWhere((c) => c.id == f.categoryId);
    final cat = i < 0 ? null : categories[i];
    final m = f.startingPriceMillimes;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return _RailCard(
      label: f.name,
      onTap: () => context.push(AppRoutes.freelancerPath(f.id)),
      art: digitalCategoryIcon(cat?.icon ?? ''),
      tint: i < 0 ? seedOf(f.id) : i,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardPerson(
            name: f.name,
            imageUrl: f.avatarUrl,
            verified: f.isVerified,
            line: f.headline.isNotEmpty
                ? f.headline
                : cat?.nameFor(locale) ?? '',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            f.skills.take(4).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
          const SizedBox(height: 6),
          if (f.isVerified)
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: scheme.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.identityVerified,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            )
          else
            SizedBox(height: 17.5 * _scale(context)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RatingInline(
                    rating: f.rating,
                    reviewCount: f.reviewCount,
                    size: 14,
                  ),
                ),
              ),
              if (m != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.priceFromShort(formatTnd(m / 1000, locale)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A two-line centred label that never breaks inside a word: when the
/// longest word is wider than the tile, the text is scaled down to fit.
class _TileLabel extends StatelessWidget {
  const _TileLabel(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scaler = MediaQuery.textScalerOf(context);
        var widest = 0.0;
        for (final word in text.split(RegExp(r'\s+'))) {
          final tp = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (tp.width > widest) widest = tp.width;
          tp.dispose();
        }
        final shrink = widest > c.maxWidth && widest > 0
            ? (c.maxWidth / widest).clamp(0.7, 1.0)
            : 1.0;
        final base = style?.fontSize ?? 13;
        return Text(
          text,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(fontSize: base * shrink),
        );
      },
    );
  }
}
