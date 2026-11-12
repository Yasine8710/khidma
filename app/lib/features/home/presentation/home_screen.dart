import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/category_photo.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../../../shared/widgets/register_row.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/marketplace_failure_view.dart';
import '../../marketplace/presentation/place_sheet.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../profile/application/profile_providers.dart';

/// Widest the page's text column grows on tablets.
const _maxContentWidth = 760.0;

/// Home, laid out like the front page of a trade register: a masthead with
/// the area, one big question, the search field, the quote action, then the
/// trades and the professionals as ruled lists.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = _firstName(ref.watch(visibleProfileProvider)?.fullName);
    final isDemo = ref.watch(isDemoDataProvider);

    Future<void> refresh() async {
      ref.invalidate(categoriesProvider);
      ref.invalidate(topRatedProvider);
      ref.invalidate(inYourAreaProvider);
      ref.invalidate(recentProfessionalsProvider);
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
                AppSpacing.lg,
              ),
              children: [
                const _Masthead(),
                const _DoubleRule(),
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
                  child: Text(l10n.homeSubtitle, style: text.displaySmall),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SearchField(),
                const SizedBox(height: AppSpacing.md),
                const _QuoteBlock(),
                const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
                const _Categories(),
                const SizedBox(height: AppSpacing.lg),
                const _DigitalLink(),
                const SizedBox(height: AppSpacing.xxl),
                const _Professionals(kind: _Kind.topRated),
                const SizedBox(height: AppSpacing.xxl),
                const _Professionals(kind: _Kind.area),
                const _RecentSection(),
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

/// The wordmark on the start side, the area as an underlined link on the end.
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

/// A heavy rule over a hairline: the masthead's printed underline.
class _DoubleRule extends StatelessWidget {
  const _DoubleRule();

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 2, child: ColoredBox(color: ink)),
          const SizedBox(height: 2),
          SizedBox(height: 1, child: ColoredBox(color: ink)),
        ],
      ),
    );
  }
}

/// The area picker: the chosen place as a terracotta text link.
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
      child: InkWell(
        onTap: () => showPlaceSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: scheme.primary,
                      decorationThickness: 1.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 22,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The demo-data notice, printed as an outlined stamp rather than a box.
class _DemoStamp extends StatelessWidget {
  const _DemoStamp();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tone = AppBadge.foreground(BadgeTone.warning, scheme);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tone),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, size: 18, color: tone),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.demoBannerTitle,
                        style: text.labelLarge?.copyWith(color: tone),
                      ),
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
    return Semantics(
      button: true,
      label: l10n.searchHint,
      excludeSemantics: true,
      onTap: () => context.push(AppRoutes.search),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.onSurface, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.search),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md + 2,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: scheme.onSurface),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      l10n.searchHint,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
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

/// The one terracotta block on Home: ask for quotes.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;
    return Semantics(
      container: true,
      button: true,
      onTap: () => context.push(AppRoutes.newRequest),
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.newRequest),
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg + 2,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeQuoteTitle,
                  style: text.labelLarge?.copyWith(color: on),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.reqEmptyCta,
                        style: text.headlineSmall?.copyWith(color: on),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.arrow_forward_rounded, color: on, size: 26),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(height: 1, child: ColoredBox(color: on)),
                const SizedBox(height: AppSpacing.sm),
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

/// A one-line description of what a trade covers: the server's own text when
/// it has one, otherwise the bundled wording for the known trades.
String? _categoryHint(AppLocalizations l10n, ServiceCategory c, Locale locale) {
  final own = c.descriptionFor(locale).trim();
  if (own.isNotEmpty) return own;
  return switch (c.slug) {
    'plumbing' => l10n.discHintPlumbing,
    'electricity' => l10n.discHintElectricity,
    'air-conditioning' => l10n.discHintAirConditioning,
    'mechanics' => l10n.discHintMechanics,
    'painting' => l10n.discHintPainting,
    'carpentry' => l10n.discHintCarpentry,
    'cleaning' => l10n.discHintCleaning,
    'appliance-repair' => l10n.discHintAppliance,
    'construction' => l10n.discHintConstruction,
    'gardening' => l10n.discHintGardening,
    'moving' => l10n.discHintMoving,
    'maintenance' => l10n.discHintMaintenance,
    _ => null,
  };
}

String _two(int n) => n.toString().padLeft(2, '0');

/// The trades as a numbered register (two columns on wide screens).
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
        async.when(
          loading: () => const _RowsSkeleton(thumb: 44, rows: 4),
          error: (e, _) => MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (list) => LayoutBuilder(
            builder: (context, box) {
              Widget row(int i) => _CategoryRow(
                number: i + 1,
                category: list[i],
                hint: _categoryHint(l10n, list[i], locale),
                locale: locale,
              );
              if (box.maxWidth < 600) {
                return Column(
                  children: [for (var i = 0; i < list.length; i++) row(i)],
                );
              }
              // Read down the first column, then the second, like a ledger.
              final half = (list.length + 1) ~/ 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [for (var i = 0; i < half; i++) row(i)],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = half; i < list.length; i++) row(i),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.number,
    required this.category,
    required this.hint,
    required this.locale,
  });

  final int number;
  final ServiceCategory category;
  final String? hint;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = category.nameFor(locale);
    void open() => context.push(AppRoutes.searchPath(categoryId: category.id));
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: open,
      child: InkWell(
        onTap: open,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    _two(number),
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: CategoryPhoto(
                    slug: category.slug,
                    icon: category.icon,
                    width: 44,
                    height: 44,
                    radius: AppRadius.sm,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hint != null)
                        Text(
                          hint!,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The way into the second section: digital freelancers.
class _DigitalLink extends StatelessWidget {
  const _DigitalLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RegisterGroup(
      children: [
        RegisterRow(
          icon: Icons.laptop_mac_outlined,
          title: l10n.flTitle,
          subtitle: l10n.flHomeSubtitle,
          onTap: () => context.push(AppRoutes.digital),
        ),
      ],
    );
  }
}

enum _Kind { topRated, area }

/// A ruled list of professionals under its heading.
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
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegisterHeading(title: l10n.sectionRecent, figure: _two(list.length)),
          ProfessionalRegister(list: list),
        ],
      ),
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
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// Placeholder register rows while a list loads.
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
