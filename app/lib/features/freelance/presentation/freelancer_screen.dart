import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/contact_providers.dart'
    show urlOpenerProvider;
import '../../marketplace/presentation/professional_card.dart';
import '../../portfolio/presentation/portfolio_image.dart';
import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';
import '../application/freelance_providers.dart';
import '../domain/freelance_domain.dart';
import 'freelance_contact_section.dart';
import 'freelance_widgets.dart';

/// A freelancer's public page: header, key facts, skills, about, work,
/// client testimonials and contact.
class FreelancerScreen extends ConsumerWidget {
  const FreelancerScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(freelancerProvider(id));
    return Scaffold(
      appBar: AppBar(
        actions: [
          ReportButton(target: ReportTarget.freelancer, targetId: id),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const SkeletonGroup(
            child: Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
              child: Skeleton(height: 240, radius: AppRadius.sm),
            ),
          ),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.errorTitle,
            body: l10n.flLoadFailed,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(freelancerProvider(id)),
          ),
          data: (f) => f == null
              ? EmptyState(
                  icon: Icons.person_off_rounded,
                  title: l10n.flNotFoundTitle,
                  body: l10n.flNotFoundBody,
                )
              : _Page(f: f),
        ),
      ),
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({required this.f});

  final FreelancerSummary f;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cats = ref.watch(digitalCategoriesProvider).value ?? const [];
    final category = cats
        .where((c) => c.id == f.categoryId)
        .map((c) => c.nameFor(locale))
        .firstOrNull;
    final price = startingPriceText(l10n, locale, f);
    final years = f.yearsExperience;

    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > 720 + AppSpacing.gutter * 2
            ? (box.maxWidth - 720) / 2
            : AppSpacing.gutter;
        return ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            side,
            AppSpacing.xs,
            side,
            AppSpacing.xl,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  name: f.name,
                  imageUrl: f.avatarUrl,
                  size: 72,
                  decorative: true,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(f.name, style: text.headlineMedium),
                      ),
                      if (f.headline.isNotEmpty)
                        Text(f.headline, style: text.bodyLarge),
                      if (category != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xs,
                          ),
                          child: Text(
                            category,
                            style: text.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (f.isVerified) const VerifiedStamp(),
                          AvailabilityMark(availability: f.availability),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            if (price != null) _Fact(label: l10n.flFactPrice, value: price),
            _Fact(
              label: l10n.discFactExperience,
              value: years == null || years == 0
                  ? '—'
                  : l10n.yearsExperience(years),
            ),
            if (f.languages.isNotEmpty)
              _Fact(label: l10n.flFactLanguages, value: f.languages.join(', ')),
            _Fact(
              label: l10n.statRating,
              last: true,
              child: RatingStars(
                rating: f.rating,
                reviewCount: f.reviewCount,
                size: 14,
              ),
            ),
            if (f.skills.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              RegisterHeading(title: l10n.flSkills),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [for (final s in f.skills) _Tag(s)],
              ),
            ],
            if (f.bio.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              RegisterHeading(title: l10n.aboutLabel),
              const SizedBox(height: AppSpacing.xs),
              Text(f.bio, style: text.bodyLarge),
            ],
            _PortfolioGrid(freelancerId: f.id),
            _Testimonials(freelancerId: f.id),
            const SizedBox(height: AppSpacing.xxl),
            FreelanceContactSection(freelancerId: f.id),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, this.value, this.child, this.last = false});

  final String label;
  final String? value;
  final Widget? child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          bottom: BorderSide(
            color: last ? scheme.onSurface : scheme.outlineVariant,
          ),
        ),
      ),
      child: Padding(
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
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            child ?? Text(value ?? '', style: text.titleSmall),
          ],
        ),
      ),
    );
  }
}

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

String kindLabel(AppLocalizations l10n, PortfolioKind k) => switch (k) {
  PortfolioKind.image => l10n.flKindImage,
  PortfolioKind.videoFile => l10n.flKindClip,
  PortfolioKind.videoLink => l10n.flKindVideoLink,
  PortfolioKind.link => l10n.flKindLink,
};

IconData kindIcon(PortfolioKind k) => switch (k) {
  PortfolioKind.image => Icons.image_outlined,
  PortfolioKind.videoFile => Icons.movie_outlined,
  PortfolioKind.videoLink => Icons.play_circle_outline_rounded,
  PortfolioKind.link => Icons.link_rounded,
};

class _PortfolioGrid extends ConsumerWidget {
  const _PortfolioGrid({required this.freelancerId});

  final String freelancerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(freelancerPortfolioProvider(freelancerId)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegisterHeading(
            title: l10n.flPortfolio,
            figure: items.length.toString().padLeft(2, '0'),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 520 ? 4 : 3;
              const gap = AppSpacing.sm;
              final side = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: side,
                      child: _Tile(item: item, side: side),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item, required this.side});

  final FreelancePortfolioItem item;
  final double side;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final url = item.url;
    if (item.kind.opensInApp && url != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: PortfolioImage(
                    url: url,
                    semanticLabel: item.title,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              PositionedDirectional(
                top: AppSpacing.md,
                end: AppSpacing.md,
                child: SafeArea(
                  child: IconButton.outlined(
                    tooltip: l10n.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    final uri = url == null ? null : Uri.tryParse(url);
    // Only https addresses ever leave the app.
    var ok = false;
    if (uri != null && uri.scheme == 'https') {
      try {
        ok = await ref.read(urlOpenerProvider)(uri);
      } catch (_) {}
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.contactLaunchFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = item.kind.opensInApp
        ? item.title
        : l10n.flOpenItem(item.title);
    final Widget visual = item.kind == PortfolioKind.image && item.url != null
        ? PortfolioImage(
            url: item.url!,
            semanticLabel: item.title,
            cacheWidth: 360,
          )
        : ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Center(
              child: Icon(kindIcon(item.kind), color: scheme.onSurface),
            ),
          );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context, ref),
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: side,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: visual,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.title,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Testimonials extends ConsumerWidget {
  const _Testimonials({required this.freelancerId});

  final String freelancerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(freelancerTestimonialsProvider(freelancerId)).value;
    if (list == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegisterHeading(
            title: l10n.flTestimonials,
            figure: list.isEmpty
                ? null
                : list.length.toString().padLeft(2, '0'),
          ),
          Text(
            l10n.flTestimonialsNote,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (list.isEmpty)
            Text(l10n.flTestimonialsEmpty, style: text.bodyMedium)
          else
            for (final t in list)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.flTestimonialLabel.toUpperCase(),
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ReportButton(
                            target: ReportTarget.testimonial,
                            targetId: t.id,
                            compact: true,
                          ),
                        ],
                      ),
                      StarsMark(count: t.rating),
                      const SizedBox(height: AppSpacing.xs),
                      Text(t.body, style: text.bodyMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          t.authorName,
                          if (t.createdAt != null)
                            formatDate(t.createdAt!, locale),
                        ].join(' · '),
                        style: text.labelMedium,
                      ),
                      if (t.projectTitle != null && t.projectTitle!.isNotEmpty)
                        Text(
                          l10n.flTestimonialProject(t.projectTitle!),
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
