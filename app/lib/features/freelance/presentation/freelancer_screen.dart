import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/application/contact_providers.dart'
    show urlOpenerProvider;
import '../../marketplace/presentation/professional_card.dart';
import '../../marketplace/presentation/signal_blocks.dart';
import '../../portfolio/presentation/portfolio_image.dart';
import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';
import '../application/freelance_providers.dart';
import '../domain/freelance_domain.dart';
import 'freelance_contact_section.dart';
import 'freelance_widgets.dart';

/// A freelancer's public page: header, key facts, skills, about, work,
/// client testimonials and contact.
class FreelancerScreen extends ConsumerStatefulWidget {
  const FreelancerScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<FreelancerScreen> createState() => _FreelancerScreenState();
}

class _FreelancerScreenState extends ConsumerState<FreelancerScreen> {
  final _scroll = ScrollController();

  String get id => widget.id;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Contact is the last section: the sticky bar takes the person to it.
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
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(freelancerProvider(id));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: const Border(),
        actions: [
          ReportButton(target: ReportTarget.freelancer, targetId: id),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      bottomNavigationBar: async.value == null
          ? null
          : ActionBar(
              child: FilledButton.icon(
                onPressed: _toContact,
                icon: const Icon(Icons.phone_outlined),
                label: Text(l10n.contactTitle),
              ),
            ),
      body: SafeArea(
        top: false,
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
              : _Page(f: f, controller: _scroll),
        ),
      ),
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({required this.f, required this.controller});

  final FreelancerSummary f;
  final ScrollController controller;

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
        final rated = f.reviewCount > 0;
        final stars = f.rating.isNaN ? 0.0 : f.rating.clamp(0.0, 5.0);
        Widget stat(Widget child) => Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              end: AppInk.offset,
              bottom: AppInk.offset,
            ),
            child: child,
          ),
        );
        return ListView(
          controller: controller,
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
          children: [
            ColorHeader(
              name: f.name,
              kicker: f.headline.isEmpty ? category : f.headline,
              side: side,
              avatar: SignalAvatar(
                name: f.name,
                imageUrl: f.avatarUrl,
                size: 84,
              ),
              below: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (f.isVerified) const VerifiedStamp(),
                  AvailabilityMark(availability: f.availability),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: side),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  if (f.headline.isNotEmpty && category != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.md,
                      ),
                      child: Text(
                        category,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      stat(
                        StatBlock(
                          value: stars,
                          fractionDigits: 1,
                          empty: !rated,
                          label: rated ? l10n.statRating : l10n.ratingNone,
                          color: scheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      stat(
                        StatBlock(
                          value: f.reviewCount,
                          label: l10n.statReviews,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (price != null)
                    FactRow(
                      label: l10n.flFactPrice,
                      value: Text(price, style: text.titleSmall),
                    ),
                  FactRow(
                    label: l10n.discFactExperience,
                    value: Text(
                      years == null || years == 0
                          ? '—'
                          : l10n.yearsExperience(years),
                      style: text.titleSmall,
                    ),
                  ),
                  if (f.languages.isNotEmpty)
                    FactRow(
                      label: l10n.flFactLanguages,
                      value: Text(
                        f.languages.join(', '),
                        style: text.titleSmall,
                      ),
                    ),
                  if (f.skills.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    RegisterHeading(title: l10n.flSkills),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [for (final s in f.skills) TagBlock(s)],
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
              ),
            ),
          ],
        );
      },
    );
  }
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
      child: Pressable(
        onTap: () => _open(context, ref),
        depth: 2,
        button: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: side,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 2, bottom: 2),
                child: StickerBox(
                  offset: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: visual,
                  ),
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
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppInk.offset,
                  bottom: AppSpacing.lg,
                ),
                child: StickerBox(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
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
