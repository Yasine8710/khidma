import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../portfolio/presentation/portfolio_gallery.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';
import '../application/home_providers.dart';
import '../application/marketplace_providers.dart';
import '../application/search_providers.dart';
import '../domain/marketplace_domain.dart';
import 'contact_section.dart';
import 'marketplace_failure_view.dart';
import 'professional_card.dart';
import 'signal_blocks.dart';

/// A professional's page: a colour header block with the name in giant Anton
/// and a sticker avatar on its edge, the key facts as stat blocks and ruled
/// rows; then about, services, areas, work photos, reviews and contact. The
/// Contact action stays in a sticky bar at the bottom.
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

  /// Contact is the last section, below portfolio and reviews: the bottom
  /// button takes the person straight to it.
  void _toContact() {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (Motion.reduced(context)) {
      _scroll.jumpTo(end);
    } else {
      _scroll.animateTo(
        end,
        duration: Motion.slow,
        curve: Motion.enter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
      appBar: AppBar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: const Border(),
        actions: [
          ReportButton(target: ReportTarget.professional, targetId: widget.id),
          FavoriteButton(professionalId: widget.id, professionalName: p?.name),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      // The contact action stays within reach while reading the profile.
      bottomNavigationBar: p == null
          ? null
          : ActionBar(
              child: FilledButton.icon(
                onPressed: _toContact,
                icon: const Icon(Icons.phone_outlined),
                label: Text(l10n.contactTitle),
              ),
            ),
      body: async.when(
        loading: () => const SafeArea(
          child: SkeletonGroup(
            child: Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
              child: Skeleton(height: 320, radius: AppRadius.sm),
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
              return ListView(
                controller: _scroll,
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.xl,
                ),
                children: [
                  _Header(professional: p, side: side),
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(horizontal: side),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Facts(professional: p),
                        if (p.description.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          RegisterHeading(title: l10n.aboutLabel),
                          const SizedBox(height: AppSpacing.xs),
                          Text(p.description, style: text.bodyLarge),
                        ],
                        ..._detailSections(context, ref, p),
                        PortfolioGallery(professionalId: p.id),
                        ReviewsList(professionalId: p.id),
                        const SizedBox(height: AppSpacing.xxl),
                        ContactSection(professionalId: p.id),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The colour header block: trade as kicker, the name in giant Anton, the
/// sticker avatar on the block's edge, the verified stamp below.
class _Header extends ConsumerWidget {
  const _Header({required this.professional, required this.side});

  final ProfessionalSummary professional;
  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final p = professional;
    final cat = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    return ColorHeader(
      name: p.name,
      kicker: cat?.nameFor(locale),
      side: side,
      avatar: SignalAvatar(name: p.name, imageUrl: p.avatarUrl, size: 84),
      below: p.isVerified
          ? const Align(
              alignment: AlignmentDirectional.centerEnd,
              child: VerifiedStamp(),
            )
          : null,
    );
  }
}

/// Rating and review count as big count-up blocks, then experience,
/// availability and area as ruled rows.
class _Facts extends ConsumerWidget {
  const _Facts({required this.professional});

  final ProfessionalSummary professional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final p = professional;
    final city = (ref.watch(citiesProvider(null)).value ?? const [])
        .where((c) => c.id == p.cityId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final gov = (ref.watch(governoratesProvider).value ?? const [])
        .where((g) => g.id == p.governorateId)
        .map((g) => g.nameFor(locale))
        .firstOrNull;
    final zone = [?city, if (gov != city) ?gov].join(', ');
    final years = p.yearsExperience;
    const none = '—';
    final rated = p.reviewCount > 0;
    final stars = p.rating.isNaN ? 0.0 : p.rating.clamp(0.0, 5.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppInk.offset,
                  bottom: AppInk.offset,
                ),
                child: StatBlock(
                  value: stars,
                  fractionDigits: 1,
                  empty: !rated,
                  label: rated ? l10n.statRating : l10n.ratingNone,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppInk.offset,
                  bottom: AppInk.offset,
                ),
                child: StatBlock(
                  value: p.reviewCount,
                  label: l10n.statReviews,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FactRow(
          label: l10n.discFactExperience,
          value: Text(
            years == null || years == 0 ? none : l10n.yearsExperience(years),
            style: text.titleSmall,
          ),
        ),
        FactRow(
          label: l10n.discFactAvailability,
          value: AvailabilityMark(availability: p.availability),
        ),
        FactRow(
          label: l10n.discFactArea,
          value: Text(zone.isEmpty ? none : zone, style: text.titleSmall),
        ),
      ],
    );
  }
}

/// Other services and areas served. Hidden entirely while loading, on failure
/// or when there is nothing to show.
List<Widget> _detailSections(
  BuildContext context,
  WidgetRef ref,
  ProfessionalSummary p,
) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
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

  Widget tags(String title, List<String> items) => Padding(
    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegisterHeading(title: title),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [for (final s in items) TagBlock(s)],
        ),
      ],
    ),
  );

  return [
    if (services.isNotEmpty) tags(l10n.servicesTitle, services),
    if (areas.isNotEmpty) tags(l10n.areasTitle, areas),
  ];
}
