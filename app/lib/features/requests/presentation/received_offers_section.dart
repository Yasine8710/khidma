import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../offers/domain/offers_domain.dart';
import '../../offers/presentation/job_timeline.dart';
import '../../offers/presentation/offers_texts.dart';
import '../../messages/application/messages_providers.dart';
import '../../reviews/application/reviews_providers.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';
import '../application/customer_offers_providers.dart';
import '../domain/customer_offers_domain.dart';
import '../domain/requests_domain.dart';
import 'flow_widgets.dart';
import 'requests_texts.dart';

enum _Sort { price, rating, delay }

/// The offers on a request, side by side: price, delay, message and who is
/// behind each (name, rating, verified only when verified). The customer
/// accepts or declines here; accepting awards the request.
class ReceivedOffersSection extends ConsumerStatefulWidget {
  const ReceivedOffersSection({super.key, required this.request});

  final QuoteRequest request;

  @override
  ConsumerState<ReceivedOffersSection> createState() =>
      _ReceivedOffersSectionState();
}

class _ReceivedOffersSectionState extends ConsumerState<ReceivedOffersSection> {
  _Sort _sort = _Sort.price;

  List<ReceivedOffer> _ordered(
    List<ReceivedOffer> offers,
    Map<String, ProfessionalSummary> pros,
  ) {
    // Live offers first; the rest (declined, withdrawn) after, newest first.
    final live = offers
        .where((o) => o.isPending || o.status == OfferStatus.accepted)
        .toList();
    final rest = offers
        .where((o) => !(o.isPending || o.status == OfferStatus.accepted))
        .toList();
    int byPrice(ReceivedOffer a, ReceivedOffer b) =>
        a.priceTnd.compareTo(b.priceTnd);
    live.sort((a, b) {
      // The accepted offer always leads.
      final aWon = a.status == OfferStatus.accepted;
      final bWon = b.status == OfferStatus.accepted;
      if (aWon != bWon) return aWon ? -1 : 1;
      switch (_sort) {
        case _Sort.price:
          return byPrice(a, b);
        case _Sort.rating:
          final ra = pros[a.professionalId]?.rating ?? 0;
          final rb = pros[b.professionalId]?.rating ?? 0;
          final c = rb.compareTo(ra);
          return c != 0 ? c : byPrice(a, b);
        case _Sort.delay:
          final da = a.estimatedDays ?? 1 << 20;
          final db = b.estimatedDays ?? 1 << 20;
          final c = da.compareTo(db);
          return c != 0 ? c : byPrice(a, b);
      }
    });
    return [...live, ...rest];
  }

  Future<void> _decide({
    required bool accept,
    required ReceivedOffer offer,
    required String proName,
  }) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accept ? l10n.offerAcceptTitle : l10n.offerDeclineTitle),
        content: Text(
          accept
              ? l10n.offerAcceptBody(proName, formatTnd(offer.priceTnd, locale))
              : l10n.offerDeclineBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(accept ? l10n.offerAccept : l10n.offerDecline),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final actions = ref.read(customerOfferActionsProvider.notifier);
    final failure = accept
        ? await actions.accept(widget.request.id, offer.id)
        : await actions.decline(widget.request.id, offer.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure != null
                ? requestFailureText(l10n, failure)
                : accept
                ? l10n.offerAcceptedMsg
                : l10n.offerDeclinedMsg,
          ),
        ),
      );
  }

  Future<void> _message(ReceivedOffer offer) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final (id, failure) = await ref
        .read(messageActionsProvider.notifier)
        .open(offer.id);
    if (id != null) {
      router.push(AppRoutes.chatPath(id));
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure == RequestsFailure.notOpen
                ? l10n.chatClosed
                : l10n.chatOpenFailed,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final offersAsync = ref.watch(receivedOffersProvider(widget.request.id));
    final pros =
        ref.watch(offerersProvider(widget.request.id)).value ??
        const <String, ProfessionalSummary>{};
    final busy = ref.watch(customerOfferActionsProvider);

    final offers = offersAsync.value;
    Widget body;
    if (offers == null) {
      body = offersAsync.hasError
          ? Row(
              children: [
                Expanded(child: Text(l10n.errorBody)),
                AppButton(
                  label: l10n.retry,
                  variant: AppButtonVariant.text,
                  expand: false,
                  onPressed: () =>
                      ref.invalidate(receivedOffersProvider(widget.request.id)),
                ),
              ],
            )
          : const SkeletonGroup(child: Skeleton(height: 96));
    } else if (offers.isEmpty) {
      body = Text(
        l10n.offersNoneYet,
        style: text.bodyMedium?.copyWith(color: muted),
      );
    } else {
      final ordered = _ordered(offers, pros);
      final pending = offers.where((o) => o.isPending).toList();
      final lowest = pending.length >= 2
          ? pending.map((o) => o.priceTnd).reduce((a, b) => a < b ? a : b)
          : null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.length >= 2) ...[
            Semantics(
              label: l10n.sortOffersBy,
              child: SegmentedButton<_Sort>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Sort.price,
                    label: Text(l10n.sortOffersPrice),
                  ),
                  ButtonSegment(
                    value: _Sort.rating,
                    label: Text(l10n.sortOffersRating),
                  ),
                  ButtonSegment(
                    value: _Sort.delay,
                    label: Text(l10n.sortOffersDelay),
                  ),
                ],
                selected: {_sort},
                onSelectionChanged: (s) => setState(() => _sort = s.first),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final o in ordered) ...[
            _OfferCard(
              offer: o,
              pro: pros[o.professionalId],
              isLowest: lowest != null && o.isPending && o.priceTnd == lowest,
              canAct: widget.request.isOpen && o.isPending && !busy,
              // The server refuses these too; do not offer what cannot work.
              canAccept:
                  pros[o.professionalId] != null &&
                  widget.request.expiresAt.isAfter(DateTime.now()),
              onAccept: (name) =>
                  _decide(accept: true, offer: o, proName: name),
              onDecline: (name) =>
                  _decide(accept: false, offer: o, proName: name),
              onMessage: () => _message(o),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: l10n.offersReceived,
          note: l10n.reqOffers(widget.request.offerCount),
        ),
        body,
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.pro,
    required this.isLowest,
    required this.canAct,
    required this.canAccept,
    required this.onAccept,
    required this.onDecline,
    required this.onMessage,
  });

  final ReceivedOffer offer;
  final ProfessionalSummary? pro;
  final bool isLowest;
  final bool canAct;
  final bool canAccept;
  final void Function(String name) onAccept;
  final void Function(String name) onDecline;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final name = pro?.name.isNotEmpty == true
        ? pro!.name
        : l10n.offerProUnknown;
    final live = offer.isPending || offer.status == OfferStatus.accepted;
    final won = offer.status == OfferStatus.accepted;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    // The quoted price, large and bold. Prices read left to right with
    // Western digits in every language.
    final price = Directionality(
      textDirection: TextDirection.ltr,
      child: Text(formatTnd(offer.priceTnd, locale), style: text.headlineSmall),
    );

    final who = Row(
      children: [
        PersonAvatar(name: name, size: 44),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: text.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (pro != null)
                RatingStars(
                  rating: pro!.rating,
                  reviewCount: pro!.reviewCount,
                  size: 14,
                ),
            ],
          ),
        ),
      ],
    );

    final slip = Opacity(
      opacity: live ? 1 : 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Side by side when there is room; the price under the name on a
          // narrow screen or with large text.
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 260 * scale
                ? Row(
                    children: [
                      Expanded(child: who),
                      const SizedBox(width: AppSpacing.md),
                      price,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      who,
                      const SizedBox(height: AppSpacing.sm),
                      price,
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (pro?.isVerified ?? false)
                StatusPill(
                  label: l10n.verified,
                  tone: BadgeTone.info,
                  icon: Icons.verified_rounded,
                ),
              if (isLowest)
                StatusPill(
                  label: l10n.offerLowest,
                  tone: BadgeTone.success,
                  icon: Icons.south_rounded,
                ),
              if (!offer.isPending)
                StatusPill(
                  label: offerStatusLabel(l10n, offer.status),
                  tone: offerStatusTone(offer.status),
                ),
              if (offer.estimatedDays != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 16, color: muted),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l10n.offerDelay(offer.estimatedDays!),
                        style: text.labelMedium,
                      ),
                    ),
                  ],
                ),
              Text(
                formatDate(offer.createdAt, locale),
                style: text.bodySmall?.copyWith(color: muted),
              ),
              // The customer can report a suspicious offer (e.g. pay first).
              ReportButton(
                target: ReportTarget.offer,
                targetId: offer.id,
                compact: true,
              ),
            ],
          ),
          if (offer.message != null && offer.message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Text(offer.message!, style: text.bodyMedium),
              ),
            ),
          ],
          if (live) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: l10n.chatAskPro,
                icon: Icons.chat_bubble_outline_rounded,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: onMessage,
              ),
            ),
          ],
          if (canAct) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.offerDecline,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => onDecline(name),
                  ),
                ),
                if (canAccept) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: l10n.offerAccept,
                      onPressed: () => onAccept(name),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    // The accepted offer gets a brand outline, like a selected card.
    return FlowCard(
      gap: 0,
      semanticLabel: '$name, ${formatTnd(offer.priceTnd, locale)}',
      onTap: pro == null
          ? null
          : () =>
                context.push(AppRoutes.professionalPath(offer.professionalId)),
      borderColor: won ? scheme.primary : null,
      border: won ? 1.5 : AppInk.border,
      child: slip,
    );
  }
}

/// The job created by accepting an offer, with the customer's next step.
class BookingSection extends ConsumerWidget {
  const BookingSection({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(customerOfferActionsProvider);
    final bookingAsync = ref.watch(bookingForRequestProvider(requestId));
    final booking = bookingAsync.value;
    if (booking == null) {
      // An awarded request has a job: while it loads, or if loading failed,
      // say so instead of silently hiding the job controls.
      if (bookingAsync.hasError) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xl),
          child: Row(
            children: [
              Expanded(child: Text(l10n.errorBody)),
              AppButton(
                label: l10n.retry,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () =>
                    ref.invalidate(bookingForRequestProvider(requestId)),
              ),
            ],
          ),
        );
      }
      if (bookingAsync.isLoading) {
        return const Padding(
          padding: EdgeInsetsDirectional.only(top: AppSpacing.xl),
          child: SkeletonGroup(child: Skeleton(height: 56)),
        );
      }
      return const SizedBox.shrink();
    }

    Future<void> run(
      Future<RequestsFailure?> Function() action,
      String okMessage,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      final failure = await action();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              failure == null ? okMessage : requestFailureText(l10n, failure),
            ),
          ),
        );
    }

    Future<void> cancel() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.bookingCancelTitle),
          content: Text(l10n.bookingCancelBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.jobKeep),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.jobCancel),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await run(
        () => ref
            .read(customerOfferActionsProvider.notifier)
            .cancelBooking(requestId, booking.id),
        l10n.bookingCancelled,
      );
    }

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
      child: FlowCard(
        gap: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.handyman_outlined, brand: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l10n.bookingTitle, style: text.titleLarge),
                      ),
                      Text(
                        l10n.jobAgreedPrice(
                          formatTnd(booking.priceTnd, locale),
                        ),
                        style: text.bodyMedium?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Hairline(),
            const SizedBox(height: AppSpacing.md),
            if (booking.status == BookingStatus.cancelled)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusPill(
                  label: jobStatusLabel(l10n, booking.status),
                  tone: jobStatusTone(booking.status),
                ),
              )
            else
              JobTimeline(status: booking.status),
            if (booking.status == BookingStatus.completed)
              _ReviewPrompt(bookingId: booking.id, aboutCustomer: false),
            if (booking.canConfirm) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.bookingWaitingForYou, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.bookingConfirm,
                isLoading: busy,
                onPressed: () => run(
                  () => ref
                      .read(customerOfferActionsProvider.notifier)
                      .confirm(requestId, booking.id),
                  l10n.bookingConfirmed,
                ),
              ),
            ],
            if (booking.canCancel) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.jobCancel,
                variant: AppButtonVariant.secondary,
                onPressed: busy ? null : cancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Leave a review" for a completed job, or a thank-you once it was given.
class _ReviewPrompt extends ConsumerWidget {
  const _ReviewPrompt({required this.bookingId, required this.aboutCustomer});

  final String bookingId;
  final bool aboutCustomer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reviewed = ref.watch(reviewedBookingsProvider).value;
    // Unknown (loading or failed) shows nothing rather than a wrong button.
    if (reviewed == null) return const SizedBox.shrink();
    if (reviewed.contains(bookingId)) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill(
            label: l10n.reviewDone,
            tone: BadgeTone.success,
            icon: Icons.check_rounded,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: AppButton(
        label: aboutCustomer ? l10n.reviewCtaPro : l10n.reviewCta,
        icon: Icons.star_outline_rounded,
        variant: AppButtonVariant.secondary,
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final done = await showReviewSheet(
            context,
            bookingId: bookingId,
            aboutCustomer: aboutCustomer,
          );
          if (done) {
            messenger
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text(l10n.reviewThanks)));
          }
        },
      ),
    );
  }
}
