import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/rating.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/khidma_logo.dart';
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

/// A professional's page, set like a trade licence: a framed record with the
/// portrait, name, trade and the key facts as ruled rows; then about,
/// services, areas, work photos, reviews and contact. The Contact action
/// stays in reach at the bottom.
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
        actions: [
          ReportButton(target: ReportTarget.professional, targetId: widget.id),
          FavoriteButton(professionalId: widget.id, professionalName: p?.name),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      // The contact action stays within reach while reading the profile.
      bottomNavigationBar: p == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: BorderDirectional(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.gutter,
                    AppSpacing.sm + 2,
                    AppSpacing.gutter,
                    AppSpacing.sm + 2,
                  ),
                  child: FilledButton.icon(
                    onPressed: _toContact,
                    icon: const Icon(Icons.phone_outlined),
                    label: Text(l10n.contactTitle),
                  ),
                ),
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
                padding: EdgeInsetsDirectional.fromSTEB(
                  side,
                  AppSpacing.xs,
                  side,
                  AppSpacing.xl,
                ),
                children: [
                  _Licence(professional: p),
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
              );
            },
          );
        },
      ),
    );
  }
}

/// The framed record: a double rule (ink outside, hairline inside) around
/// the portrait, name, trade and the facts table.
class _Licence extends ConsumerWidget {
  const _Licence({required this.professional});

  final ProfessionalSummary professional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = professional;
    final cat = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    final category = cat?.nameFor(locale);
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

    final portrait = DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: scheme.onSurface)),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ProfessionalPhoto(
          avatarUrl: p.avatarUrl,
          slug: cat?.slug,
          icon: cat?.icon,
          width: 96,
          height: 96,
          radius: 0,
        ),
      ),
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(p.name, style: text.headlineMedium),
        ),
        if (category != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            category,
            style: text.titleMedium?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: scheme.primary,
              decorationThickness: 2,
            ),
          ),
        ],
        if (p.isVerified) ...[
          const SizedBox(height: AppSpacing.md),
          const VerifiedStamp(),
        ],
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.onSurface),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.discLicenceKicker.toUpperCase(),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    KhidmaMark(size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, box) {
                    final scale = MediaQuery.textScalerOf(context)
                        .scale(1)
                        .clamp(1.0, 2.0);
                    // Side by side only while the name keeps a decent measure.
                    if (box.maxWidth - 102 - AppSpacing.lg < 150 * scale) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          portrait,
                          const SizedBox(height: AppSpacing.md),
                          identity,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        portrait,
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: identity),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: scheme.onSurface),
                _Fact(
                  label: l10n.statRating,
                  semanticValue: p.reviewCount == 0
                      ? l10n.ratingNone
                      : l10n.ratingSummary(
                          formatRating(p.rating, locale),
                          p.reviewCount,
                        ),
                  value: _RatingValue(p: p),
                ),
                _Fact(
                  label: l10n.statReviews,
                  value: Text('${p.reviewCount}', style: text.titleSmall),
                ),
                _Fact(
                  label: l10n.discFactExperience,
                  value: Text(
                    years == null || years == 0
                        ? none
                        : l10n.yearsExperience(years),
                    style: text.titleSmall,
                  ),
                ),
                _Fact(
                  label: l10n.discFactAvailability,
                  value: AvailabilityMark(availability: p.availability),
                ),
                _Fact(
                  label: l10n.discFactArea,
                  value: Text(
                    zone.isEmpty ? none : zone,
                    style: text.titleSmall,
                  ),
                  last: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One definition row: the label in muted ink at the start, the value at the
/// end (it drops below the label when both do not fit), a rule underneath.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.semanticValue,
    this.last = false,
  });

  final String label;
  final Widget value;

  /// Read instead of the value widget (for values drawn as marks).
  final String? semanticValue;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.sm + 3,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value,
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last
            ? null
            : BorderDirectional(
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
      ),
      child: semanticValue == null
          ? Semantics(container: true, child: row)
          : Semantics(
              container: true,
              label: '$label: $semanticValue',
              excludeSemantics: true,
              child: row,
            ),
    );
  }
}

/// Five ochre stars and the average, or "no reviews yet".
class _RatingValue extends StatelessWidget {
  const _RatingValue({required this.p});

  final ProfessionalSummary p;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (p.reviewCount <= 0) {
      return Text(
        AppLocalizations.of(context).ratingNone,
        style: text.bodyMedium,
      );
    }
    final stars = p.rating.isNaN ? 0.0 : p.rating.clamp(0.0, 5.0);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              stars - i >= 0.75
                  ? Icons.star_rounded
                  : stars - i >= 0.25
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: 16,
              color: stars - i >= 0.25 ? AppColors.saffron : scheme.outline,
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatRating(p.rating, Localizations.localeOf(context)),
            style: text.titleSmall,
          ),
        ],
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
          children: [for (final s in items) _Tag(s)],
        ),
      ],
    ),
  );

  return [
    if (services.isNotEmpty) tags(l10n.servicesTitle, services),
    if (areas.isNotEmpty) tags(l10n.areasTitle, areas),
  ];
}

/// A printed label (not a control): sunken paper, small radius, no outline.
class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.xs + 2,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    ),
  );
}
