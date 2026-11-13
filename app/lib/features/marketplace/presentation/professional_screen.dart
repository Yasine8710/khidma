import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../portfolio/application/portfolio_providers.dart';
import '../../portfolio/presentation/portfolio_gallery.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';
import '../application/home_providers.dart';
import '../application/marketplace_providers.dart';
import '../application/search_providers.dart';
import '../domain/marketplace_domain.dart';
import 'calm_blocks.dart';
import 'category_icon.dart';
import 'contact_section.dart';
import 'marketplace_failure_view.dart';
import 'professional_card.dart';
import 'sectioned_profile.dart';

/// A professional's page: a soft grey band with round controls and the
/// avatar overlapping it, name, trade and city, pills, a stats card, then
/// Services / Réalisations / Avis / À propos as tabs over one scroll, and
/// contact. A sticky bar keeps "Contact" and "Demander un devis" in reach.
class ProfessionalScreen extends ConsumerStatefulWidget {
  const ProfessionalScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends ConsumerState<ProfessionalScreen> {
  bool _recorded = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Contact is the last block: the bottom button takes the person to it.
  void _toContact() {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (Motion.reduced(context)) {
      _scroll.jumpTo(end);
    } else {
      _scroll.animateTo(end, duration: Motion.slow, curve: Motion.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(professionalProvider(widget.id));

    // Remembered as recently viewed only once it really loaded.
    if (!_recorded && async.value != null) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(recentlyViewedProvider.notifier).add(widget.id);
        }
      });
    }

    final p = async.value;
    return Scaffold(
      // The page draws its own band with round controls once loaded.
      appBar: p == null ? AppBar() : null,
      bottomNavigationBar: p == null
          ? null
          : BottomBar(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _toContact,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        l10n.contactTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: () => context.push(
                        Uri(
                          path: AppRoutes.newRequest,
                          queryParameters: {'category': '${p.categoryId}'},
                        ).toString(),
                      ),
                      child: Text(
                        l10n.reqEmptyCta,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: async.when(
        loading: () => const SafeArea(
          child: SkeletonGroup(
            child: Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
              child: Skeleton(height: 320, radius: AppRadius.lg),
            ),
          ),
        ),
        error: (e, _) => SafeArea(
          child: MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(professionalProvider(widget.id)),
          ),
        ),
        data: (p) {
          if (p == null) {
            return SafeArea(
              child: EmptyState(
                icon: Icons.person_off_rounded,
                title: l10n.professionalNotFoundTitle,
                body: l10n.professionalNotFoundBody,
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, box) {
              final side = box.maxWidth > 720 + AppSpacing.gutter * 2
                  ? (box.maxWidth - 720) / 2
                  : AppSpacing.gutter;
              return _Page(professional: p, side: side, scroll: _scroll);
            },
          );
        },
      ),
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({
    required this.professional,
    required this.side,
    required this.scroll,
  });

  final ProfessionalSummary professional;
  final double side;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final p = professional;
    final cat = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    final city = (ref.watch(citiesProvider(null)).value ?? const [])
        .where((c) => c.id == p.cityId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final photos = ref.watch(portfolioProvider(p.id)).value ?? const [];
    final years = p.yearsExperience;
    final rated = p.reviewCount > 0;
    final stars = p.rating.isNaN ? 0.0 : p.rating.clamp(0.0, 5.0);

    return SectionedProfile(
      controller: scroll,
      side: side,
      header: ProfileHeader(
        name: p.name,
        imageUrl: p.avatarUrl,
        verified: p.isVerified,
        subtitle: [?cat?.nameFor(locale), ?city].join(' · '),
        side: side,
        actions: [
          ReportButton(target: ReportTarget.professional, targetId: p.id),
          FavoriteButton(professionalId: p.id, professionalName: p.name),
        ],
        pills: [
          // Only a real verification is ever shown.
          if (p.isVerified)
            InfoPill(
              label: p.verifiedUntil == null
                  ? l10n.docsVerified
                  : l10n.verifiedUntil(formatDate(p.verifiedUntil!, locale)),
              icon: Icons.verified_user_outlined,
            ),
          AvailabilityPill(availability: p.availability),
        ],
      ),
      stats: StatsCard(
        items: [
          rated
              ? StatItem(
                  label: l10n.statRating,
                  value: stars,
                  fractionDigits: 1,
                )
              : StatItem(label: l10n.statRating),
          StatItem(label: l10n.statReviews, value: p.reviewCount),
          StatItem(
            label: l10n.discFactExperience,
            text: years == null || years == 0 ? null : l10n.yearsShort(years),
          ),
        ],
      ),
      sections: [
        ProfileSection(
          label: l10n.servicesTitle,
          child: _Services(professional: p),
        ),
        if (photos.isNotEmpty)
          ProfileSection(
            label: l10n.portfolioSection,
            child: PortfolioGallery(professionalId: p.id),
          ),
        ProfileSection(
          label: l10n.reviewsTitle,
          child: ReviewsList(professionalId: p.id, emptyText: l10n.ratingNone),
        ),
        ProfileSection(
          label: l10n.aboutLabel,
          child: _About(professional: p, city: city),
        ),
      ],
      footer: ContactSection(professionalId: p.id),
    );
  }
}

/// The main trade and the other services as rows (tinted icon tile, name,
/// what it covers), then the areas served.
class _Services extends ConsumerWidget {
  const _Services({required this.professional});

  final ProfessionalSummary professional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final p = professional;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final governorates = ref.watch(governoratesProvider).value ?? const [];
    final cities = ref.watch(citiesProvider(null)).value ?? const [];
    // Hidden while loading or on failure: the main trade still shows.
    final details = ref.watch(professionalDetailsProvider(p.id)).value;

    final ids = [
      p.categoryId,
      for (final id in details?.serviceCategoryIds ?? const <int>[])
        if (id != p.categoryId) id,
    ];
    final rows = <Widget>[
      for (final id in ids)
        for (final (i, c) in categories.indexed)
          if (c.id == id)
            ServiceRow(
              icon: categoryIcon(c.icon),
              tint: i,
              title: c.nameFor(locale),
              detail: c.descriptionFor(locale),
            ),
    ];
    final areas = <String>[
      for (final a in details?.areas ?? const <ServiceArea>[])
        if (a.cityId != null)
          ...cities.where((c) => c.id == a.cityId).map((c) => c.nameFor(locale))
        else
          ...governorates
              .where((g) => g.id == a.governorateId)
              .map((g) => l10n.areaWhole(g.nameFor(locale))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (areas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SectionTitle(title: l10n.areasTitle, small: true),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final s in areas) SoftTag(s)],
          ),
        ],
      ],
    );
  }
}

/// The description, then experience and area as definition rows.
class _About extends ConsumerWidget {
  const _About({required this.professional, required this.city});

  final ProfessionalSummary professional;
  final String? city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final p = professional;
    final gov = (ref.watch(governoratesProvider).value ?? const [])
        .where((g) => g.id == p.governorateId)
        .map((g) => g.nameFor(locale))
        .firstOrNull;
    final zone = [?city, if (gov != city) ?gov].join(', ');
    final years = p.yearsExperience;
    const none = '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.description.isNotEmpty) ...[
          Text(p.description, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
        ],
        InfoRow(
          label: l10n.discFactExperience,
          value: years == null || years == 0
              ? none
              : l10n.yearsExperience(years),
        ),
        InfoRow(
          label: l10n.discFactArea,
          value: zone.isEmpty ? none : zone,
          last: true,
        ),
      ],
    );
  }
}
