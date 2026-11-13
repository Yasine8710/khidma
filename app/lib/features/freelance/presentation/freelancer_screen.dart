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
import '../../marketplace/presentation/calm_blocks.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../marketplace/presentation/sectioned_profile.dart';
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
    final async = ref.watch(freelancerProvider(id));
    final loaded = async.value != null;
    return Scaffold(
      // The page draws its own band with round controls once loaded.
      appBar: loaded ? null : AppBar(),
      bottomNavigationBar: !loaded
          ? null
          : BottomBar(
              child: FilledButton.icon(
                onPressed: _toContact,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(l10n.contactTitle),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
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
    final cats = ref.watch(digitalCategoriesProvider).value ?? const [];
    final catIndex = cats.indexWhere((c) => c.id == f.categoryId);
    final cat = catIndex < 0 ? null : cats[catIndex];
    final category = cat?.nameFor(locale);
    final price = startingPriceText(l10n, locale, f);
    final years = f.yearsExperience;
    final work = ref.watch(freelancerPortfolioProvider(f.id)).value ?? const [];
    final rated = f.reviewCount > 0;
    final stars = f.rating.isNaN ? 0.0 : f.rating.clamp(0.0, 5.0);

    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > 720 + AppSpacing.gutter * 2
            ? (box.maxWidth - 720) / 2
            : AppSpacing.gutter;
        return SectionedProfile(
          controller: controller,
          side: side,
          header: ProfileHeader(
            name: f.name,
            imageUrl: f.avatarUrl,
            verified: f.isVerified,
            subtitle: f.headline.isEmpty ? category : f.headline,
            side: side,
            actions: [
              ReportButton(target: ReportTarget.freelancer, targetId: f.id),
            ],
            pills: [
              // Digital freelancers: identity verification only.
              if (f.isVerified)
                InfoPill(
                  label: l10n.identityVerified,
                  icon: Icons.verified_user_outlined,
                ),
              AvailabilityPill(availability: f.availability),
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
              StatItem(label: l10n.statReviews, value: f.reviewCount),
              StatItem(
                label: l10n.discFactExperience,
                text: years == null || years == 0
                    ? null
                    : l10n.yearsShort(years),
              ),
            ],
          ),
          sections: [
            ProfileSection(
              label: l10n.servicesTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ServiceRow(
                    icon: digitalCategoryIcon(cat?.icon ?? ''),
                    tint: catIndex < 0 ? 0 : catIndex,
                    title: category ?? l10n.flTitle,
                    detail: price,
                  ),
                  if (f.skills.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SectionTitle(title: l10n.flSkills, small: true),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [for (final s in f.skills) SoftTag(s)],
                    ),
                  ],
                ],
              ),
            ),
            if (work.isNotEmpty)
              ProfileSection(
                label: l10n.flPortfolio,
                child: _PortfolioGrid(freelancerId: f.id),
              ),
            ProfileSection(
              label: l10n.reviewsTitle,
              child: _Testimonials(freelancerId: f.id),
            ),
            ProfileSection(
              label: l10n.aboutLabel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (f.bio.isNotEmpty) ...[
                    Text(f.bio, style: text.bodyLarge),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  InfoRow(
                    label: l10n.discFactExperience,
                    value: years == null || years == 0
                        ? '—'
                        : l10n.yearsExperience(years),
                    last: f.languages.isEmpty,
                  ),
                  if (f.languages.isNotEmpty)
                    InfoRow(
                      label: l10n.flFactLanguages,
                      value: f.languages.join(', '),
                      last: true,
                    ),
                ],
              ),
            ),
          ],
          footer: FreelanceContactSection(freelancerId: f.id),
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
    final items = ref.watch(freelancerPortfolioProvider(freelancerId)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 520 ? 4 : 3;
        const gap = AppSpacing.md;
        final side = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: side,
                child: _Tile(item: items[i], side: side, tint: i),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item, required this.side, required this.tint});

  final FreelancePortfolioItem item;
  final double side;

  /// Placeholder tint for items without a picture.
  final int tint;

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
        : TintTile(icon: kindIcon(item.kind), tint: tint, radius: 0);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context, ref),
      child: Pressable(
        onTap: () => _open(context, ref),
        button: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: visual,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
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
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Invited by the freelancer, not verified reviews: said plainly.
        SectionTitle(title: l10n.flTestimonials, small: true),
        Text(l10n.flTestimonialsNote, style: muted),
        const SizedBox(height: AppSpacing.md),
        if (list.isEmpty)
          Text(l10n.flTestimonialsEmpty, style: text.bodyMedium)
        else
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
              child: StaggerIn(
                index: i,
                child: StickerBox(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InitialsAvatar(name: list[i].authorName, size: 36),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    list[i].authorName,
                                    if (list[i].createdAt != null)
                                      formatDate(list[i].createdAt!, locale),
                                  ].join(' · '),
                                  style: text.titleSmall,
                                ),
                                Text(l10n.flTestimonialLabel, style: muted),
                              ],
                            ),
                          ),
                          ReportButton(
                            target: ReportTarget.testimonial,
                            targetId: list[i].id,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StarsMark(count: list[i].rating),
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.md,
                        ),
                        child: Text(list[i].body, style: text.bodyLarge),
                      ),
                      if (list[i].projectTitle != null &&
                          list[i].projectTitle!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.flTestimonialProject(list[i].projectTitle!),
                          style: muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
