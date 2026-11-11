import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/home_providers.dart';
import '../application/marketplace_providers.dart';
import '../application/search_providers.dart';
import '../domain/marketplace_domain.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../portfolio/presentation/portfolio_gallery.dart';
import '../../reviews/presentation/review_widgets.dart';
import 'contact_section.dart';
import 'marketplace_failure_view.dart';
import 'professional_card.dart';

/// Basic profile: identity, rating, badges, about. Contact, portfolio and
/// reviews arrive in the profile slice.
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

  /// Contact is the last section, below portfolio and reviews: the button
  /// near the top takes the person straight to it.
  void _toContact() {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (MediaQuery.of(context).disableAnimations) {
      _scroll.jumpTo(end);
    } else {
      _scroll.animateTo(
        end,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
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

    return Scaffold(
      appBar: AppBar(
        actions: [
          ReportButton(target: ReportTarget.professional, targetId: widget.id),
          FavoriteButton(
            professionalId: widget.id,
            professionalName: async.value?.name,
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const SkeletonGroup(
            child: Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
              child: Skeleton(height: 160, radius: AppRadius.lg),
            ),
          ),
          error: (e, _) => MarketplaceFailureView(
            error: e,
            onRetry: () => ref.invalidate(professionalProvider(widget.id)),
          ),
          data: (p) {
            if (p == null) {
              return EmptyState(
                icon: Icons.person_off_rounded,
                title: l10n.professionalNotFoundTitle,
                body: l10n.professionalNotFoundBody,
              );
            }
            final category = (ref.watch(categoriesProvider).value ?? const [])
                .where((c) => c.id == p.categoryId)
                .map((c) => c.nameFor(locale))
                .firstOrNull;
            final years = p.yearsExperience;
            return ListView(
              controller: _scroll,
              padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
              children: [
                Row(
                  children: [
                    AppAvatar(name: p.name, size: 72, decorative: true),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(p.name, style: text.headlineSmall),
                          ),
                          if (category != null)
                            Text(
                              category,
                              style: text.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                RatingStars(rating: p.rating, reviewCount: p.reviewCount),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (p.isVerified) AppBadge.verified(context),
                    AppBadge(
                      label: availabilityLabel(l10n, p.availability),
                      tone: availabilityTone(p.availability),
                    ),
                    if (years != null && years > 0)
                      AppBadge(label: l10n.yearsExperience(years)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _toContact,
                  icon: const Icon(Icons.phone_outlined),
                  label: Text(l10n.contactTitle),
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(l10n.aboutLabel, style: text.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(p.description, style: text.bodyLarge),
                ],
                ..._detailSections(context, ref, p, locale),
                PortfolioGallery(professionalId: p.id),
                ReviewsList(professionalId: p.id),
                const SizedBox(height: AppSpacing.xl),
                ContactSection(professionalId: p.id),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Other services and areas served. Hidden entirely while loading, on failure
/// or when there is nothing to show.
List<Widget> _detailSections(
  BuildContext context,
  WidgetRef ref,
  ProfessionalSummary p,
  Locale locale,
) {
  final l10n = AppLocalizations.of(context);
  final text = Theme.of(context).textTheme;
  final details = ref.watch(professionalDetailsProvider(p.id)).value;
  if (details == null) return const [];
  final categories = ref.watch(categoriesProvider).value ?? const [];
  final governorates = ref.watch(governoratesProvider).value ?? const [];
  final cities = ref.watch(citiesProvider(null)).value ?? const [];

  final services = [
    for (final id in details.serviceCategoryIds)
      if (id != p.categoryId)
        ...categories.where((c) => c.id == id).map((c) => c.nameFor(locale)),
  ];
  final areas = <String>[
    for (final a in details.areas)
      if (a.cityId != null)
        ...cities.where((c) => c.id == a.cityId).map((c) => c.nameFor(locale))
      else
        ...governorates
            .where((g) => g.id == a.governorateId)
            .map((g) => l10n.areaWhole(g.nameFor(locale))),
  ];

  Widget chips(String title, List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: AppSpacing.xl),
      Semantics(header: true, child: Text(title, style: text.titleMedium)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [for (final s in items) Chip(label: Text(s))],
      ),
    ],
  );

  return [
    if (services.isNotEmpty) chips(l10n.servicesTitle, services),
    if (areas.isNotEmpty) chips(l10n.areasTitle, areas),
  ];
}
