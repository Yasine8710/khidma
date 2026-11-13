import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../requests/domain/requests_domain.dart';
import '../application/reviews_providers.dart';
import '../domain/reviews_domain.dart';

String reviewFailureText(AppLocalizations l10n, RequestsFailure f) =>
    switch (f) {
      RequestsFailure.alreadyReviewed => l10n.reviewFailAlready,
      RequestsFailure.notCompleted => l10n.reviewFailNotCompleted,
      RequestsFailure.limitReached => l10n.reviewFailLimit,
      _ => l10n.reviewFailGeneric,
    };

/// Opens the review form for a completed job. [aboutCustomer] is the
/// professional rating the customer (private, not public).
Future<bool> showReviewSheet(
  BuildContext context, {
  required String bookingId,
  bool aboutCustomer = false,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ReviewSheet(bookingId: bookingId, aboutCustomer: aboutCustomer),
    ),
  );
  return done ?? false;
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.bookingId, required this.aboutCustomer});

  final String bookingId;
  final bool aboutCustomer;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _comment = TextEditingController();
  int? _rating;
  String? _error;
  bool _ratingError = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!ReviewRules.ratingOk(_rating)) {
      setState(() => _ratingError = true);
      return;
    }
    final failure = await ref
        .read(reviewActionsProvider.notifier)
        .submit(widget.bookingId, _rating!, _comment.text);
    if (!mounted) return;
    if (failure == null || failure == RequestsFailure.alreadyReviewed) {
      Navigator.of(context).pop(failure == null);
      return;
    }
    setState(() => _error = reviewFailureText(l10n, failure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final busy = ref.watch(reviewActionsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.aboutCustomer
                  ? l10n.reviewSheetTitlePro
                  : l10n.reviewSheetTitle,
              style: text.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.aboutCustomer
                ? l10n.reviewPrivateNote
                : l10n.reviewPublicNote,
            style: text.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          StarPicker(
            value: _rating,
            onChanged: (v) => setState(() {
              _rating = v;
              _ratingError = false;
            }),
          ),
          if (_ratingError)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Text(
                l10n.reviewErrRating,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.reviewComment,
            controller: _comment,
            maxLines: 4,
            maxLength: maxReviewComment,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.reviewSubmit,
            isLoading: busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Five stars to tap. Each is a button with its own label ("3 stars"); the
/// chosen one is announced as selected. Stars stay left to right in every
/// language, like rating displays elsewhere.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final empty = Theme.of(context).colorScheme.outline;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              selected: value == i,
              label: l10n.reviewStar(i),
              excludeSemantics: true,
              onTap: () => onChanged(i),
              child: InkResponse(
                radius: 28,
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.star_rounded,
                    size: 40,
                    color: value != null && i <= value!
                        ? AppColors.saffron
                        : empty,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A professional's published reviews as soft cards: rating, comment, month;
/// never who wrote them. Nothing is shown while loading or on failure; with
/// none, [emptyText] (when given) says so. No heading: the profile's "Avis"
/// tab names the section.
class ReviewsList extends ConsumerStatefulWidget {
  const ReviewsList({super.key, required this.professionalId, this.emptyText});

  final String professionalId;

  /// Shown when the professional has no published review yet.
  final String? emptyText;

  @override
  ConsumerState<ReviewsList> createState() => _ReviewsListState();
}

class _ReviewsListState extends ConsumerState<ReviewsList> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final reviews = <Review>[];
    var more = false;
    Widget? footer;
    for (var page = 0; page < _pages; page++) {
      final async = ref.watch(
        reviewsPageProvider((
          professionalId: widget.professionalId,
          page: page,
        )),
      );
      if (async.hasError && !async.hasValue) {
        if (page == 0) return const SizedBox.shrink();
        footer = AppButton(
          label: l10n.retry,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.invalidate(
            reviewsPageProvider((
              professionalId: widget.professionalId,
              page: page,
            )),
          ),
        );
        break;
      }
      if (!async.hasValue) {
        if (page == 0) return const SizedBox.shrink();
        footer = const Skeleton(height: 48);
        break;
      }
      reviews.addAll(async.requireValue);
      more = page == _pages - 1 && async.requireValue.length == reviewsPageSize;
    }
    if (reviews.isEmpty && footer == null) {
      // Reached only once the first page really loaded (not on failure).
      final empty = widget.emptyText;
      if (empty == null) return const SizedBox.shrink();
      return Text(empty, style: text.bodyMedium?.copyWith(color: muted));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < reviews.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
            child: _ReviewCard(review: reviews[i], locale: locale),
          ),
        if (footer != null || more) const SizedBox(height: AppSpacing.xs),
        ?footer,
        if (footer == null && more)
          AppButton(
            label: l10n.reviewsMore,
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _pages++),
          ),
      ],
    );
  }
}

/// One review as a soft card: an anonymous face, "Client · month" and the
/// stars, then the comment.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.locale});

  final Review review;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final r = review;
    final month = formatMonthYear(r.month, locale);
    return StickerBox(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.lg,
      ),
      child: Semantics(
        container: true,
        label: '${l10n.reviewStar(r.rating)}, $month',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${l10n.reviewAuthorAnon} · $month',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      // Stars read left to right in every language.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: i <= r.rating
                                    ? AppColors.star
                                    : scheme.outlineVariant,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ReportButton(
                  target: ReportTarget.review,
                  targetId: r.id,
                  compact: true,
                ),
              ],
            ),
            if (r.comment != null && r.comment!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: AppSpacing.sm,
                  end: AppSpacing.md,
                ),
                child: Text(r.comment!, style: text.bodyLarge),
              ),
          ],
        ),
      ),
    );
  }
}
