import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/home_providers.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../../marketplace/presentation/marketplace_failure_view.dart';
import '../../marketplace/presentation/place_sheet.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../profile/application/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
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
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            if (isDemo) const _DemoBanner(),
            Semantics(
              header: true,
              child: Text(
                name == null ? l10n.homeGreeting : l10n.homeGreetingNamed(name),
                style: text.headlineMedium,
              ),
            ),
            Text(
              l10n.homeSubtitle,
              style: text.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _PlaceButton(),
            const SizedBox(height: AppSpacing.md),
            const _SearchBar(),
            const SizedBox(height: AppSpacing.lg),
            const _QuoteCard(),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.sectionCategories),
            const _Categories(),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.sectionTopRated),
            const _ProfessionalList(kind: _Kind.topRated),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.sectionInYourArea),
            const _ProfessionalList(kind: _Kind.area),
            const _RecentSection(),
          ],
        ),
      ),
    );
  }
}

String? _firstName(String? fullName) {
  final words = fullName?.trim().split(RegExp(r'\s+')) ?? const [];
  return words.isEmpty || words.first.isEmpty ? null : words.first;
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
          avatar: const Icon(Icons.place_rounded, size: 18),
          label: Text(label),
          onPressed: () => showPlaceSheet(context),
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                style: text.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.homeQuoteBody,
              style: text.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push(AppRoutes.search),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
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
        child: Skeleton(height: 96, radius: AppRadius.md),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = category.nameFor(locale);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: () => context.push(AppRoutes.searchPath(categoryId: category.id)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () =>
            context.push(AppRoutes.searchPath(categoryId: category.id)),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  categoryIcon(category.icon),
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Kind { topRated, area }

class _ProfessionalList extends ConsumerWidget {
  const _ProfessionalList({required this.kind});

  final _Kind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(selectedPlaceProvider);
    final provider = kind == _Kind.topRated
        ? topRatedProvider
        : inYourAreaProvider;

    if (kind == _Kind.area && place == null) {
      return Text(
        l10n.sectionInYourAreaPrompt,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return ref
        .watch(provider)
        .when(
          loading: () => const _CardsSkeleton(),
          error: (e, _) => MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(provider),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  kind == _Kind.topRated
                      ? l10n.noProfessionalsBody
                      : l10n.noProfessionalsInArea,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : _Cards(list: list),
        );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.list});

  final List<ProfessionalSummary> list;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final p in list) ...[
        ProfessionalCard(
          professional: p,
          onTap: () => context.push(AppRoutes.professionalPath(p.id)),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonGroup(
    child: Column(
      children: [
        Skeleton(height: 112, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 112, radius: AppRadius.lg),
      ],
    ),
  );
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
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: l10n.sectionRecent),
        _Cards(list: list),
      ],
    );
  }
}
