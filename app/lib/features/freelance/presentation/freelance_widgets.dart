import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../../marketplace/presentation/signal_blocks.dart';
import '../domain/freelance_domain.dart';

String priceUnitLabel(AppLocalizations l10n, PriceUnit u) => switch (u) {
  PriceUnit.project => l10n.flUnitProject,
  PriceUnit.hour => l10n.flUnitHour,
  PriceUnit.day => l10n.flUnitDay,
};

/// "à partir de 300 DT / projet", or null when no price was given.
String? startingPriceText(
  AppLocalizations l10n,
  Locale locale,
  FreelancerSummary f,
) {
  final m = f.startingPriceMillimes;
  if (m == null) return null;
  return l10n.flPriceFrom(
    formatTnd(m / 1000, locale),
    priceUnitLabel(l10n, f.priceUnit),
  );
}

/// Failure of an owner action in words. [limit] says which limit was hit
/// (portfolio items by default).
String freelanceFailureText(
  AppLocalizations l10n,
  FreelanceFailure f, {
  String? limit,
}) => switch (f) {
  FreelanceFailure.notVerified => l10n.flErrNotVerified,
  FreelanceFailure.incomplete => l10n.flErrIncomplete,
  FreelanceFailure.suspended => l10n.flErrSuspended,
  FreelanceFailure.limitReached => limit ?? l10n.flPortLimit,
  FreelanceFailure.tooLarge => l10n.flPortTooLarge,
  FreelanceFailure.unsupportedFormat => l10n.flPortBadFormat,
  FreelanceFailure.notAnImage => l10n.portfolioFailNotImage,
  FreelanceFailure.invalidInput => l10n.flErrInvalid,
  FreelanceFailure.rateLimited => l10n.flErrRate,
  FreelanceFailure.notConfigured => l10n.flErrNotConfigured,
  _ => l10n.flErrGeneric,
};

/// One freelancer as a register row: avatar, name, headline, trade, rating,
/// starting price and the verified stamp; a hairline rule closes the row.
class FreelancerRow extends StatelessWidget {
  const FreelancerRow({
    super.key,
    required this.freelancer,
    this.categoryName,
    this.onTap,
  });

  final FreelancerSummary freelancer;
  final String? categoryName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final f = freelancer;
    final price = startingPriceText(l10n, locale, f);

    final row = Padding(
      padding: const EdgeInsetsDirectional.only(
        end: AppInk.offset,
        bottom: AppSpacing.lg,
      ),
      child: StickerBox(
        color: scheme.surface,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SignalAvatar(
              name: f.name,
              imageUrl: f.avatarUrl,
              size: 60,
              offset: 0,
            ),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    style: text.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (f.headline.isNotEmpty)
                    Text(
                      f.headline,
                      style: text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (categoryName != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(
                        categoryName!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  RatingStars(
                    rating: f.rating,
                    reviewCount: f.reviewCount,
                    size: 13,
                  ),
                  if (price != null || f.isVerified) ...[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (f.isVerified) const VerifiedStamp(),
                        if (price != null) Text(price, style: text.labelLarge),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: f.name,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Pressable(onTap: onTap, button: false, child: row),
      ),
    );
  }
}

/// Freelancers as consecutive register rows, each opening its page.
class FreelancerRegister extends StatelessWidget {
  const FreelancerRegister({
    super.key,
    required this.list,
    required this.categories,
  });

  final List<FreelancerSummary> list;
  final List<DigitalCategory> categories;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < list.length; i++)
          StaggerIn(
            index: i,
            child: FreelancerRow(
              freelancer: list[i],
              categoryName: categories
                  .where((c) => c.id == list[i].categoryId)
                  .map((c) => c.nameFor(locale))
                  .firstOrNull,
              onTap: () => context.push(AppRoutes.freelancerPath(list[i].id)),
            ),
          ),
      ],
    );
  }
}

/// Five small ochre stars for one testimonial's rating (never colour alone:
/// the screen reader hears "4 sur 5").
class StarsMark extends StatelessWidget {
  const StarsMark({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = count.clamp(0, 5);
    return Semantics(
      label: AppLocalizations.of(context).flStars(n),
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < n ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: i < n ? AppColors.saffron : scheme.outline,
              ),
          ],
        ),
      ),
    );
  }
}
