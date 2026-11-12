import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/digits.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../messages/application/messages_providers.dart';
import '../../requests/domain/requests_domain.dart';
import '../../requests/presentation/ledger_widgets.dart';
import '../../requests/presentation/request_detail_screen.dart'
    show RequestPhotoStrip, WorkOrderHeader;
import '../application/offers_providers.dart';
import '../domain/offers_domain.dart';
import 'offers_texts.dart';

/// One open request from the professional's side: details, photos, and the
/// offer (send, update, withdraw).
class ProRequestScreen extends ConsumerWidget {
  const ProRequestScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(openRequestProvider(id));
    final Widget body;
    final request = async.value;
    if (request != null) {
      body = _Body(request: request);
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(openRequestProvider(id)));
    } else if (async.isLoading) {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 160, radius: AppRadius.lg),
        ),
      );
    } else {
      body = EmptyState(
        icon: Icons.assignment_late_outlined,
        title: l10n.reqNotFound,
        body: '',
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reqDetailTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.request});

  final OpenRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mine = request.myOfferStatus;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkOrderHeader(
            id: request.id,
            title: request.title,
            description: request.description,
            categoryId: request.categoryId,
            governorateId: request.governorateId,
            cityId: request.cityId,
            createdAt: request.createdAt,
            budgetTnd: request.budgetTnd,
            neededBy: request.neededBy,
            expiresAt: request.expiresAt,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.offerOthers(
              // Without my own offer, if I have one.
              (request.offersCount - (mine == null ? 0 : 1)).clamp(0, 1 << 30),
            ),
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          RequestPhotoStrip(requestId: request.id),
          const SizedBox(height: AppSpacing.xl),
          // The quote being written, on its own framed slip.
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(l10n.offerTitle, style: text.titleLarge),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const LedgerRule(strong: true),
                  const SizedBox(height: AppSpacing.lg),
                  _OfferGate(request: request),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The offer form needs the existing offer (if any) before it is shown, so
/// nothing typed can be overwritten later; it is keyed by request and offer.
class _OfferGate extends ConsumerWidget {
  const _OfferGate({required this.request});

  final OpenRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsOffer = request.myOfferStatus != null;
    if (!needsOffer) {
      return _OfferSection(
        key: ValueKey('${request.id}/none'),
        request: request,
        mine: null,
      );
    }
    final async = ref.watch(myOfferForProvider(request.id));
    if (async.hasError && !async.hasValue) {
      return ErrorState(
        onRetry: () => ref.invalidate(myOfferForProvider(request.id)),
      );
    }
    if (!async.hasValue) {
      return const SkeletonGroup(child: Skeleton(height: 120));
    }
    final mine = async.value;
    return _OfferSection(
      key: ValueKey('${request.id}/${mine?.id}'),
      request: request,
      mine: mine,
    );
  }
}

class _OfferSection extends ConsumerStatefulWidget {
  const _OfferSection({super.key, required this.request, required this.mine});

  final OpenRequest request;
  final MyOffer? mine;

  @override
  ConsumerState<_OfferSection> createState() => _OfferSectionState();
}

class _OfferSectionState extends ConsumerState<_OfferSection> {
  final _formKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _message = TextEditingController();
  final _days = TextEditingController();
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _message.dispose();
    _days.dispose();
    super.dispose();
  }

  double? _parsePrice(String v) {
    final t = toWesternDigits(v.trim()).replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final days = int.tryParse(toWesternDigits(_days.text.trim()));
    final failure = await ref
        .read(offerActionsProvider.notifier)
        .submit(
          widget.request.id,
          OfferInput(
            priceTnd: _parsePrice(_price.text)!,
            message: _message.text,
            estimatedDays: days,
          ),
        );
    if (!mounted) return;
    setState(
      () => _error = failure == null ? null : offerFailureText(l10n, failure),
    );
    if (failure == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.offerSent)));
    }
  }

  Future<void> _openChat(MyOffer offer) async {
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

  Future<void> _withdraw(MyOffer offer) async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(offerActionsProvider.notifier)
        .withdraw(offer.id, widget.request.id);
    if (!mounted) return;
    setState(
      () => _error = failure == null ? null : offerFailureText(l10n, failure),
    );
    if (failure == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.offerWithdrawn)));
      _prefilled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(offerActionsProvider);
    final status = widget.request.myOfferStatus;
    final mine = widget.mine;

    // Start the form from the existing offer, once.
    if (!_prefilled && mine != null && status == OfferStatus.pending) {
      _prefilled = true;
      _price.text = mine.priceTnd == mine.priceTnd.roundToDouble()
          ? mine.priceTnd.round().toString()
          : mine.priceTnd.toString();
      _message.text = mine.message ?? '';
      _days.text = mine.estimatedDays?.toString() ?? '';
    }

    if (status == OfferStatus.declined) {
      return Text(l10n.offerDeclinedNote, style: text.bodyMedium);
    }
    if (status == OfferStatus.accepted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LedgerStamp(
            label: offerStatusLabel(l10n, OfferStatus.accepted),
            tone: BadgeTone.success,
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.offerAcceptedNote, style: text.bodyMedium),
        ],
      );
    }

    const gap = SizedBox(height: AppSpacing.md);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LedgerStamp(
                label: l10n.offerYours(offerStatusLabel(l10n, status)),
                tone: offerStatusTone(status),
              ),
            ),
          if (status != null) gap,
          AppTextField(
            label: l10n.offerPrice,
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]')),
            ],
            maxLength: 9,
            validator: (v) {
              final n = _parsePrice(v ?? '');
              return OfferRules.priceOk(n) ? null : l10n.offerErrPrice;
            },
          ),
          gap,
          AppTextField(
            label: l10n.offerMessage,
            controller: _message,
            maxLines: 4,
            maxLength: OfferRules.messageMax,
            validator: (v) =>
                OfferRules.messageOk(v) ? null : l10n.offerErrMessage,
          ),
          gap,
          AppTextField(
            label: l10n.offerDays,
            controller: _days,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            validator: (v) {
              final t = toWesternDigits((v ?? '').trim());
              if (t.isEmpty) return null;
              return OfferRules.daysOk(int.tryParse(t))
                  ? null
                  : l10n.offerErrDays;
            },
          ),
          if (_error != null) ...[
            gap,
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
            label: status == null ? l10n.offerSend : l10n.offerUpdate,
            isLoading: busy,
            onPressed: _submit,
          ),
          if (mine != null &&
              (status == OfferStatus.pending ||
                  status == OfferStatus.accepted)) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.chatWriteCustomer,
              icon: Icons.chat_bubble_outline_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _openChat(mine),
            ),
          ],
          if (status == OfferStatus.pending && mine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.offerWithdraw,
              variant: AppButtonVariant.secondary,
              onPressed: busy ? null : () => _withdraw(mine),
            ),
          ],
          if (locale.languageCode == 'ar') const SizedBox.shrink(),
        ],
      ),
    );
  }
}
