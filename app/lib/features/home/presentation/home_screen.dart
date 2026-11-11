import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/category_photo.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/marketplace_failure_view.dart';
import '../../marketplace/presentation/place_sheet.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../profile/application/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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

    // The photo header runs under the status bar; the list scrolls beneath
    // the floating navigation, so it needs room at the bottom.
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 112),
        children: [
          _Hero(
            title: name == null
                ? l10n.homeGreeting
                : l10n.homeGreetingNamed(name),
            subtitle: l10n.homeSubtitle,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl + AppSpacing.md),
                if (isDemo) const _DemoBanner(),
                SectionHeader(title: l10n.sectionCategories),
                const _Categories(),
                const SizedBox(height: AppSpacing.xl),
                const _QuoteCard(),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(title: l10n.sectionTopRated),
              ],
            ),
          ),
          const _Carousel(kind: _Kind.topRated),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.xl,
              AppSpacing.gutter,
              0,
            ),
            child: SectionHeader(title: l10n.sectionInYourArea),
          ),
          const _Carousel(kind: _Kind.area),
          const _RecentSection(),
        ],
      ),
    );
  }
}

String? _firstName(String? fullName) {
  final words = fullName?.trim().split(RegExp(r'\s+')) ?? const [];
  return words.isEmpty || words.first.isEmpty ? null : words.first;
}

/// Full-bleed photo header: area picker on top, greeting at the bottom, and
/// the search bar floating over the lower edge.
class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  static const _baseHeight = 300.0;
  static const _overlap = 28.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Taller with large text, so the greeting never gets squeezed.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final height = _baseHeight + 140 * (scale - 1);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: Image.asset(
                  'assets/photos/hero-home.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.25, -0.2),
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                    ),
                  ),
                ),
              ),
              // Deep blue wash: keeps the white text readable on any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99123D78),
                      Color(0x66123D78),
                      Color(0xE60E2F5E),
                    ],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    _overlap + AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PlaceButton(),
                      const Spacer(),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: text.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: text.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const PositionedDirectional(
          start: AppSpacing.gutter,
          end: AppSpacing.gutter,
          bottom: -_overlap,
          child: _SearchBar(),
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppBadge.background(
              BadgeTone.warning,
              Theme.of(context).colorScheme,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.science_rounded,
                  color: AppBadge.foreground(
                    BadgeTone.warning,
                    Theme.of(context).colorScheme,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.demoBannerTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        l10n.demoBannerBody,
                        style: Theme.of(context).textTheme.bodySmall,
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

/// The area picker, a white pill floating on the photo.
class _PlaceButton extends ConsumerWidget {
  const _PlaceButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final place = ref.watch(selectedPlaceProvider);
    final govs = ref.watch(governoratesProvider).value ?? const <Governorate>[];
    final cities = ref.watch(citiesProvider(null)).value ?? const <City>[];
    final label = placeLabel(l10n, locale, place, govs, cities);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: '${l10n.placeChoose}: $label',
        excludeSemantics: true,
        onTap: () => showPlaceSheet(context),
        child: ActionChip(
          avatar: const Icon(
            Icons.place_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          label: Text(label),
          labelStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.ink),
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          side: BorderSide.none,
          onPressed: () => showPlaceSheet(context),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l10n.searchHint,
      excludeSemantics: true,
      onTap: () => context.push(AppRoutes.search),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: scheme.brightness == Brightness.light
              ? AppColors.softShadow
              : null,
          border: scheme.brightness == Brightness.light
              ? null
              : Border.all(color: scheme.outlineVariant),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            onTap: () => context.push(AppRoutes.search),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
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
      ),
    );
  }
}

/// The main customer action, one tap from Home: ask for quotes.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332F7DE1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.homeQuoteTitle,
                style: text.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.homeQuoteBody,
              style: text.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
              ),
              onPressed: () => context.push(AppRoutes.newRequest),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(l10n.reqEmptyCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final async = ref.watch(categoriesProvider);
    return async.when(
      loading: () => const SkeletonGroup(
        child: Skeleton(height: 120, radius: AppRadius.lg),
      ),
      error: (e, _) => MarketplaceFailureView(
        error: e,
        onRetry: () => ref.invalidate(categoriesProvider),
      ),
      data: (list) => LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 480 ? 4 : 3;
          final gap = AppSpacing.md;
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final c in list)
                SizedBox(
                  width: width,
                  height: width,
                  child: _CategoryTile(category: c, locale: locale),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.locale});

  final ServiceCategory category;
  final Locale locale;

  @override
  Widget build(BuildContext context) => CategoryTile(
    name: category.nameFor(locale),
    slug: category.slug,
    icon: category.icon,
    onTap: () => context.push(AppRoutes.searchPath(categoryId: category.id)),
  );
}

enum _Kind { topRated, area }

/// A horizontally scrolling row of professional tiles.
class _Carousel extends ConsumerWidget {
  const _Carousel({required this.kind});

  final _Kind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(selectedPlaceProvider);
    final provider = kind == _Kind.topRated
        ? topRatedProvider
        : inYourAreaProvider;
    Widget note(String s) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.gutter,
      ),
      child: Text(s, style: Theme.of(context).textTheme.bodyMedium),
    );

    if (kind == _Kind.area && place == null) {
      return note(l10n.sectionInYourAreaPrompt);
    }
    return ref
        .watch(provider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            child: _CardsSkeleton(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            child: MarketplaceFailureView(
              error: e,
              onRetry: () => ref.invalidate(provider),
            ),
          ),
          data: (list) => list.isEmpty
              ? note(
                  kind == _Kind.topRated
                      ? l10n.noProfessionalsBody
                      : l10n.noProfessionalsInArea,
                )
              : ProfessionalCarousel(list: list),
        );
  }
}

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton();

  @override
  Widget build(BuildContext context) =>
      const SkeletonGroup(child: Skeleton(height: 220, radius: AppRadius.lg));
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(recentProfessionalsProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter,
            AppSpacing.xl,
            AppSpacing.gutter,
            0,
          ),
          child: SectionHeader(title: l10n.sectionRecent),
        ),
        ProfessionalCarousel(list: list),
      ],
    );
  }
}
